import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ── helpers ────────────────────────────────────────────────────────────────

function randomSuffix(len = 8): string {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
  let out = ''
  for (let i = 0; i < len; i++) {
    out += chars[Math.floor(Math.random() * chars.length)]
  }
  return out
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const {
      orgId,
      gateway,
      loanId,
      savingsPlanId,
      emiScheduleId,
      amount,
      customerName,
      customerPhone,
      customerEmail,
      notes,
    } = body as Record<string, string | number | undefined>

    // ── Validate ──────────────────────────────────────────────────────────
    if (!orgId) throw new Error('orgId is required')
    if (!gateway || (gateway !== 'razorpay' && gateway !== 'phonepe')) {
      throw new Error("gateway must be 'razorpay' or 'phonepe'")
    }
    if (typeof amount !== 'number' || amount <= 0) {
      throw new Error('amount must be a positive number (in INR)')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // ── Read gateway config from org settings ─────────────────────────────
    const { data: org, error: orgErr } = await supabase
      .from('organizations')
      .select('settings')
      .eq('id', orgId)
      .single()

    if (orgErr) throw new Error(`Organization not found: ${orgErr.message}`)

    const settings = (org?.settings as Record<string, unknown>) ?? {}
    const gateways = (settings['payment_gateways'] as Record<string, unknown>) ?? {}
    const gwConfig = gateways[gateway] as Record<string, string | boolean> | undefined

    if (!gwConfig) {
      throw new Error(`Payment gateway "${gateway}" is not configured for this organization`)
    }

    const apiKey = gwConfig.api_key as string | undefined
    const apiSecret = gwConfig.api_secret as string | undefined
    const webhookSecret = gwConfig.webhook_secret as string | undefined
    const sandbox = String(gwConfig.sandbox ?? 'false') === 'true'

    if (!apiKey || !apiSecret) {
      throw new Error(
        `Incomplete gateway config: api_key and api_secret are required for ${gateway}`
      )
    }

    // ── Determine context references ──────────────────────────────────────
    const contextNotes: Record<string, unknown> = {
      ...(loanId ? { loanId } : {}),
      ...(savingsPlanId ? { savingsPlanId } : {}),
      ...(emiScheduleId ? { emiScheduleId } : {}),
      ...(customerName ? { customerName } : {}),
      ...(customerPhone ? { customerPhone } : {}),
      ...(customerEmail ? { customerEmail } : {}),
    }

    if (notes && typeof notes === 'object') {
      contextNotes.customNotes = notes
    }

    const baseReceipt = `${gateway}_${Date.now()}_${randomSuffix(8)}`
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString()
    let gatewayOrderId: string | undefined
    let paymentUrl = ''

    // ══════════════════════════════════════════════════════════════════════
    // Razorpay: create order via API
    // ══════════════════════════════════════════════════════════════════════
    if (gateway === 'razorpay') {
      const authHeader = `Basic ${btoa(`${apiKey}:${apiSecret}`)}`

      const orderPayload: Record<string, unknown> = {
        amount: Math.round(amount * 100), // paise
        currency: 'INR',
        receipt: baseReceipt,
        payment_capture: true,
        notes: contextNotes,
      }

      if (customerEmail) {
        orderPayload.customer = {
          ...(customerName ? { name: customerName } : {}),
          email: customerEmail,
          ...(customerPhone ? { contact: customerPhone } : {}),
        }
      }

      const razorRes = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(orderPayload),
      })

      const razorData = (await razorRes.json().catch(() => ({}))) as Record<
        string,
        unknown
      >

      if (!razorRes.ok) {
        const errMsg =
          (razorData as Record<string, string>)?.error?.description ??
          (razorData as Record<string, string>)?.error?.message ??
          `HTTP ${razorRes.status}`
        throw new Error(`Razorpay API error: ${errMsg}`)
      }

      gatewayOrderId = razorData.id as string
      paymentUrl = `https://api.razorpay.com/v1/checkout/embedded/${razorData.id}`

      // For sandbox, use the test payment page
      if (sandbox) {
        paymentUrl = `https://checkout.razorpay.com/v1/${razorData.id}`
      }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PhonePe: placeholder — SDK integration will provide the real URL
    // ══════════════════════════════════════════════════════════════════════
    if (gateway === 'phonepe') {
      gatewayOrderId = `phonepe_${Date.now()}_${randomSuffix(8)}`
      // PhonePe uses a merchant-initiated SDK flow; paymentUrl will be
      // populated once the PhonePe checkout SDK is integrated on the client.
    }

    // ── Insert payment order ──────────────────────────────────────────────
    const { data: orderRow, error: insertErr } = await supabase
      .from('payment_orders')
      .insert({
        org_id: orgId,
        gateway,
        gateway_order_id: gatewayOrderId,
        ...(loanId ? { loan_id: loanId } : {}),
        ...(savingsPlanId ? { savings_plan_id: savingsPlanId } : {}),
        ...(emiScheduleId ? { emi_schedule_id: emiScheduleId } : {}),
        amount,
        currency: 'INR',
        status: 'pending',
        payment_details: {
          receipt: baseReceipt,
          expires_at: expiresAt,
          sandbox,
          customer: { name: customerName, phone: customerPhone, email: customerEmail },
          notes: contextNotes,
          payment_url: paymentUrl,
        },
      })
      .select('id')
      .single()

    if (insertErr) throw new Error(`Failed to create payment order: ${insertErr.message}`)

    return new Response(
      JSON.stringify({
        success: true,
        orderId: orderRow.id,
        gatewayOrderId,
        paymentUrl,
        amount,
        currency: 'INR',
        gateway,
        status: 'pending',
        expiresAt,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ success: false, message: msg }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 },
    )
  }
})
