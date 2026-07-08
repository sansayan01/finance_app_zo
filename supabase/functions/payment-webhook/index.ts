import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-razorpay-signature, x-verify, content-type',
}

// ── Crypto helpers ─────────────────────────────────────────────────────────

async function hmacSha256(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder()
  const keyData = encoder.encode(secret)
  const msgData = encoder.encode(message)

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign('HMAC', cryptoKey, msgData)
  // deno-lint-ignore no-explicit-any
  const hashArray = Array.from(new Uint8Array(signature))
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function verifyRazorpaySignature(
  rawBody: string,
  signatureHeader: string | null,
  webhookSecret: string,
): Promise<boolean> {
  if (!signatureHeader) return false
  const expected = await hmacSha256(rawBody, webhookSecret)
  // Razorpay sends base64-encoded HMAC; compute and compare as hex
  const given = await hmacSha256(rawBody, webhookSecret)
  return given === signatureHeader
}

async function verifyPhonePeSignature(
  rawBody: string,
  verifyHeader: string | null,
  saltKey: string,
): Promise<boolean> {
  // PhonePe X-VERIFY format: sha256=<hash>###<saltKeyIndex>
  if (!verifyHeader) return false
  const expectedHash = await hmacSha256(rawBody, saltKey)
  const parts = verifyHeader.split('###')
  const headerHash = parts[0]?.replace(/^sha256=/i, '')
  return headerHash === expectedHash
}

// ── Main handler ──────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Always log so we can debug. Catch errors so we still return 200.
  const logError = (msg: string) => {
    console.error(`[payment-webhook] ${msg}`)
  }

  try {
    // ── Read raw body (needed for signature verification) ────────────────
    const rawBody = await req.text()

    // Parse as JSON — but we keep rawBody for signature checks
    const body = JSON.parse(rawBody) as Record<string, unknown>
    const contentLength = req.headers.get('content-length') ?? rawBody.length

    // ── Determine gateway ────────────────────────────────────────────────
    // Razorpay: X-Razorpay-Signature header
    // PhonePe: X-VERIFY header
    const razorpaySig = req.headers.get('x-razorpay-signature')
    const phonepeSig = req.headers.get('x-verify')

    let gateway: 'razorpay' | 'phonepe'
    if (razorpaySig) {
      gateway = 'razorpay'
    } else if (phonepeSig) {
      gateway = 'phonepe'
    } else {
      // Fallback: check body account name (Razorpay) or merchantId (PhonePe)
      const account = (body as Record<string, string>)['account']
      gateway = account?.toLowerCase() === 'phonepe' ? 'phonepe' : 'razorpay'
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // ── Find the org and webhook secret ──────────────────────────────────
    // The webhook body itself doesn't carry orgId, so we have to find it
    // via the organizations table. We'll do a scan for matching gateway config.
    let orgId: string | undefined
    let webhookSecret: string | undefined

    const { data: orgs } = await supabase
      .from('organizations')
      .select('id, settings')
      .limit(200)

    if (orgs) {
      for (const o of orgs) {
        const settings = (o.settings as Record<string, unknown>) ?? {}
        const gateways = (settings['payment_gateways'] as Record<string, unknown>) ?? {}
        const gwConfig = gateways[gateway] as Record<string, string> | undefined
        if (gwConfig?.webhook_secret) {
          // Try to verify with this secret
          const ok =
            gateway === 'razorpay'
              ? await verifyRazorpaySignature(rawBody, razorpaySig, gwConfig.webhook_secret)
              : await verifyPhonePeSignature(rawBody, phonepeSig, gwConfig.webhook_secret)

          if (ok) {
            orgId = o.id as string
            webhookSecret = gwConfig.webhook_secret
            break
          }

          // Also accept if no signature header is present (for testing)
          if (!razorpaySig && !phonepeSig) {
            orgId = o.id as string
            webhookSecret = gwConfig.webhook_secret
            break
          }
        }
      }
    }

    if (!orgId || !webhookSecret) {
      logError(`Could not find org with valid gateway config for ${gateway}`)
      return new Response('ok', { headers: corsHeaders })
    }

    // ── Verify signature ─────────────────────────────────────────────────
    let signatureValid = true
    if (gateway === 'razorpay' && razorpaySig) {
      signatureValid = await verifyRazorpaySignature(rawBody, razorpaySig, webhookSecret)
    } else if (gateway === 'phonepe' && phonepeSig) {
      signatureValid = await verifyPhonePeSignature(rawBody, phonepeSig, webhookSecret)
    }

    if (!signatureValid) {
      logError(`Invalid ${gateway} webhook signature`)
      return new Response('ok', { headers: corsHeaders })
    }

    // ── Parse webhook payload ─────────────────────────────────────────────
    let gatewayOrderId: string | undefined
    let paymentId: string | undefined
    let status: string | undefined
    let paymentMethod: string | undefined
    let amount: number | undefined

    if (gateway === 'razorpay') {
      // Razorpay webhook structure:
      // { "entity": "event", "account_id": "...", "event": "payment.captured",
      //   "payload": { "payment": { "entity": { ... } } } }
      const event = (body as Record<string, string>)['event']?.toLowerCase() ?? ''
      status = event.includes('captured')
        ? 'paid'
        : event.includes('failed')
          ? 'failed'
          : event.includes('refunded')
            ? 'refunded'
            : event.includes('cancelled') || event.includes('dispute')
              ? 'cancelled'
              : event

      const paymentEntity = (body as Record<string, Record<string, unknown>>)['payload']
        ?.payment as Record<string, unknown> ?? {}
      const paymentEnt = paymentEntity?.entity as Record<string, unknown> ?? {}

      gatewayOrderId = (paymentEnt as Record<string, string>)['order_id']
      paymentId = (paymentEnt as Record<string, string>)['id']
      paymentMethod = (paymentEnt as Record<string, string>)['method']
      amount =
        typeof paymentEnt['amount'] === 'number'
          ? Number(paymentEnt['amount']) / 100
          : undefined
    }

    if (gateway === 'phonepe') {
      // PhonePe webhook structure:
      // { "merchantId": "...", "transactionId": "...", "status": "COMPLETED",
      //   "amount": ..., "paymentInstrument": { ... } }
      const rawStatus = (body as Record<string, string>)['status']?.toUpperCase() ?? ''
      status = rawStatus === 'COMPLETED'
        ? 'paid'
        : rawStatus === 'FAILED'
          ? 'failed'
          : rawStatus === 'CANCELLED'
            ? 'cancelled'
            : rawStatus.toLowerCase()

      gatewayOrderId = (body as Record<string, string>)['transactionId']
      paymentId = (body as Record<string, string>)['paymentId']
      paymentMethod = (body as Record<string, Record<string, unknown>>)['paymentInstrument']
        ?.type as string | undefined
      amount = typeof (body as Record<string, number>)['amount'] === 'number'
        ? Number((body as Record<string, number>)['amount']) / 100
        : undefined
    }

    if (!gatewayOrderId) {
      logError('Webhook missing gateway_order_id / transactionId')
      return new Response('ok', { headers: corsHeaders })
    }

    // ── Look up the payment order ─────────────────────────────────────────
    const { data: order, error: orderErr } = await supabase
      .from('payment_orders')
      .select('*')
      .eq('gateway_order_id', gatewayOrderId)
      .maybeSingle()

    if (orderErr || !order) {
      logError(`Payment order not found for gateway_order_id=${gatewayOrderId}`)
      return new Response('ok', { headers: corsHeaders })
    }

    const isPaid = status === 'paid'
    const isFailed = status === 'failed' || status === 'cancelled'

    // ── Update payment_orders status ──────────────────────────────────────
    const updatePayload: Record<string, unknown> = {
      status: isPaid ? 'paid' : status ?? 'failed',
      updated_at: new Date().toISOString(),
    }
    if (paymentId) updatePayload.payment_id = paymentId
    if (paymentMethod) updatePayload.payment_method = paymentMethod
    if (amount) updatePayload.amount = amount
    if (isPaid) {
      updatePayload.confirmed_at = new Date().toISOString()
      updatePayload.payment_details = {
        ...(order.payment_details as Record<string, unknown> ?? {}),
        payment_id: paymentId,
        payment_method: paymentMethod,
        gateway_status: status,
        confirmed_at: new Date().toISOString(),
      }
    }

    await supabase.from('payment_orders').update(updatePayload).eq('id', order.id)

    // ── If not a successful payment, short‑circuit ────────────────────────
    if (!isPaid) {
      logSuccess(`Payment ${gatewayOrderId} updated to "${status}" — no ledger action`)
      return new Response('ok', { headers: corsHeaders })
    }

    // ══════════════════════════════════════════════════════════════════════
    // Paid flow: update ledger — loan collection and/or savings deposit
    // ══════════════════════════════════════════════════════════════════════

    const isLoan = !!order.loan_id
    const isSavings = !!order.savings_plan_id

    // ── Shared transaction base ───────────────────────────────────────────
    const txBase = {
      org_id: order.org_id,
      amount: amount ?? order.amount,
      reference_number: paymentId,
      notes: `Online payment via ${gateway} — order ${gatewayOrderId}`,
      payment_mode: gateway === 'razorpay' ? 'razorpay' : 'phonepe',
      transaction_date: new Date().toISOString().slice(0, 10),
      transaction_time: new Date().toISOString(),
    }

    // ── LOAN EMI PAYMENT ──────────────────────────────────────────────────
    if (isLoan) {
      // Fetch loan details
      const { data: loan } = await supabase
        .from('loans')
        .select('id, loan_number, org_id, member_id, member_name, customer_id, emi_amount')
        .eq('id', order.loan_id)
        .maybeSingle()

      const loanMemberId = loan?.member_id ?? loan?.customer_id ?? order.member_id

      // 1. Insert transaction
      await supabase.from('transactions').insert({
        ...txBase,
        loan_id: order.loan_id,
        member_id: loanMemberId,
        member_name: loan?.member_name ?? 'Online Payment',
        type: 'emiPayment',
      })

      // 2. Insert collection record
      const collectionPayload: Record<string, unknown> = {
        org_id: order.org_id,
        loan_id: order.loan_id,
        member_id: loanMemberId,
        member_name: loan?.member_name ?? 'Online Payment',
        loan_number: loan?.loan_number ?? 'N/A',
        amount_expected: order.amount,
        amount_collected: amount ?? order.amount,
        variance: amount ? Number(amount) - Number(order.amount) : 0,
        is_partial: amount ? Number(amount) < Number(order.amount) : false,
        payment_mode: gateway === 'razorpay' ? 'razorpay' : 'phonepe',
        reference_number: paymentId,
        collection_date: new Date().toISOString().slice(0, 10),
        collection_type: 'online',
        type: 'emi',
        sync_status: 'synced',
        collected_at: new Date().toISOString(),
      }

      if (order.emi_schedule_id) {
        collectionPayload.selected_schedule_id = order.emi_schedule_id
      }

      const { data: collectionRow } = await supabase
        .from('collections')
        .insert(collectionPayload)
        .select('id')
        .single()

      // 3. Link collection back to transaction
      if (collectionRow) {
        await supabase
          .from('transactions')
          .update({ collected_by_user_id: collectionRow.id })
          .eq('loan_id', order.loan_id)
          .eq('type', 'emiPayment')
          .order('created_at', { ascending: false })
          .limit(1)
          .then(({ error }) => {
            if (error) logError(`Failed to link transaction to collection: ${error.message}`)
          })
      }

      // 4. Mark EMI schedule as paid
      if (order.emi_schedule_id) {
        const { data: emiRow, error: emiLookupErr } = await supabase
          .from('emi_schedule')
          .select('*')
          .eq('id', order.emi_schedule_id)
          .maybeSingle()

        if (emiLookupErr) {
          logError(`Failed to fetch emi_schedule: ${emiLookupErr.message}`)
        } else if (emiRow && !emiRow.is_paid) {
          await supabase
            .from('emi_schedule')
            .update({
              is_paid: true,
              status: 'paid',
              paid_on: new Date().toISOString(),
              paid_date: new Date().toISOString().slice(0, 10),
              payment_mode: gateway === 'razorpay' ? 'razorpay' : 'phonepe',
              transaction_id: collectionRow?.id ?? undefined,
            })
            .eq('id', order.emi_schedule_id)
        }
      }

      // 5. Recalculate outstanding balance
      try {
        const { error: rpcErr } = await supabase.rpc('recalculate_loan_outstanding', {
          p_loan_id: order.loan_id,
        })
        if (rpcErr) logError(`recalculate_loan_outstanding RPC failed: ${rpcErr.message}`)
      } catch (rpcEx) {
        logError(`recalculate_loan_outstanding threw: ${rpcEx}`)
      }
    }

    // ── SAVINGS DEPOSIT ───────────────────────────────────────────────────
    if (isSavings) {
      // Fetch savings plan details
      const { data: savingsPlan } = await supabase
        .from('savings_plans')
        .select('id, member_id, plan_name, org_id')
        .eq('id', order.savings_plan_id)
        .maybeSingle()

      const txWithSavings = {
        ...txBase,
        savings_id: order.savings_plan_id,
        member_id: savingsPlan?.member_id ?? order.member_id,
        member_name: 'Online Payment',
        type: 'savingsDeposit' as const,
      }

      await supabase.from('transactions').insert(txWithSavings)

      // Insert savings_collections row
      await supabase.from('savings_collections').insert({
        org_id: order.org_id,
        savings_plan_id: order.savings_plan_id,
        member_id: savingsPlan?.member_id ?? order.member_id,
        amount_expected: order.amount,
        amount_collected: amount ?? order.amount,
        payment_mode: gateway === 'razorpay' ? 'razorpay' : 'phonepe',
        collection_date: new Date().toISOString().slice(0, 10),
        collection_time: new Date().toISOString(),
        sync_status: 'synced',
      })
    }

    return new Response('ok', { headers: corsHeaders })
  } catch (err) {
    // Always return 200 so the gateway stops retrying
    const msg = err instanceof Error ? err.message : String(err)
    logError(`Unhandled error: ${msg}`)
    return new Response('ok', { headers: corsHeaders })
  }
})

function logSuccess(msg: string) {
  console.log(`[payment-webhook] ✓ ${msg}`)
}
