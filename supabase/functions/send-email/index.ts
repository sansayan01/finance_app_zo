import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json().catch(() => ({}))
    const { to, subject, html, orgId, templateKey, variables, replyTo } = body as Record<string, string | undefined>

    if (!orgId) throw new Error('orgId is required')
    if (!to)    throw new Error('to (recipient email) is required')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // --- Resolve subject + html (either direct, or via template lookup) ---
    let emailSubject = subject
    let emailHtml = html

    if (templateKey && !subject) {
      const { data: tpl, error: tplErr } = await supabase
        .from('email_templates')
        .select('subject, body, variables')
        .eq('org_id', orgId)
        .eq('template_key', templateKey)
        .maybeSingle()

      if (tplErr) throw new Error(`Template fetch failed: ${tplErr.message}`)
      if (!tpl)   throw new Error(`Template "${templateKey}" not found for this org`)

      emailSubject = tpl.subject
      emailHtml = tpl.body

      if (variables && tpl.variables) {
        const vars = variables as Record<string, string>
        for (const v of (tpl.variables as Array<{ name: string }>)) {
          const re = new RegExp(`\\{\\{${v.name}\\}\\}`, 'g')
          emailHtml = (emailHtml as string).replace(re, vars[v.name] ?? '')
        }
      }
    }

    if (!emailSubject || !emailHtml) {
      throw new Error('Either subject+html or templateKey must be provided')
    }

    // --- Read org communications config ---
    const { data: org, error: orgErr } = await supabase
      .from('organizations')
      .select('settings')
      .eq('id', orgId)
      .single()

    if (orgErr) throw new Error(`Organization not found: ${orgErr.message}`)

    const settings  = (org?.settings as Record<string, unknown>) ?? {}
    const comms     = (settings['communications'] as Record<string, unknown>) ?? {}
    const provider  = comms.provider as string | undefined

    if (!provider || provider === 'none') {
      throw new Error('Email provider not configured for this organization')
    }

    const fromEmail = (comms.from_email as string | undefined) ?? 'noreply@microflowpro.com'
const fromName  = (comms.from_name as string | undefined) ?? 'MicroFlow Pro'
    const from      = `${fromName} <${fromEmail}>`

    let res: Response

    // ── Provider: Resend (API key) ──────────────────────────────────────────
    if (provider === 'resend') {
      const apiKey = comms.api_key as string | undefined
      if (!apiKey) throw new Error('Resend API key not configured')

      res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [to],
          subject: emailSubject,
          html: emailHtml,
          replyTo: replyTo || fromEmail,
        }),
      })
    }
    // ── Provider: SMTP (Deno SMTP) ─────────────────────────────────────────
    else if (provider === 'smtp') {
      const { SmtpClient } = await import(
        "https://deno.land/x/smtp@v1.2.0/mod.ts"
      )

      const client = new SmtpClient()

      await client.connectTLS({
        hostname: comms.smtp_host as string,
        port: Number(comms.smtp_port ?? 465),
        username: comms.smtp_username as string | undefined,
        password: comms.smtp_password as string | undefined,
      })

      const id = await client.send({
        from: fromEmail,
        to: [to],
        subject: emailSubject,
        content: emailHtml as string,
      })

      res = new Response(
        JSON.stringify({ success: true, messageId: String(id ?? '') }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
      )
    }
    else {
      throw new Error(`Unsupported email provider: ${provider}`)
    }

    if (provider !== 'smtp' && !res.ok) {
      const errBody = await res.json().catch(() => ({}))
      throw new Error(`Email provider error: ${(errBody as Record<string, string>)?.message ?? res.status}`)
    }

    // --- Audit log (fire-and-forget) ---
    supabase.from('email_notifications').insert({
      org_id: orgId,
      recipient: to,
      subject: emailSubject,
      status: 'sent',
      provider,
      sent_at: new Date().toISOString(),
    }).then(() => {}, (_e) => {})

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email sent successfully',
        to,
        subject: emailSubject,
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
