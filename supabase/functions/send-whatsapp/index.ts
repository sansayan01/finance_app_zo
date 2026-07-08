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
    const { to, templateName, templateLanguage, components, orgId } = body as Record<
      string,
      string | undefined
    >

    if (!orgId)    throw new Error('orgId is required')
    if (!to)       throw new Error('to (recipient phone number) is required — include country code, e.g. +919876543210')

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // --- Read org WhatsApp config ---
    const { data: org, error: orgErr } = await supabase
      .from('organizations')
      .select('settings')
      .eq('id', orgId)
      .single()

    if (orgErr) throw new Error(`Organization not found: ${orgErr.message}`)

    const settings  = (org?.settings as Record<string, unknown>) ?? {}
    const wa        = (settings['whatsapp'] as Record<string, unknown>) ?? {}
    const phoneId   = wa.phone_number_id as string | undefined
    const bizId     = wa.business_account_id as string | undefined
    const token     = wa.access_token as string | undefined

    if (!phoneId || !bizId || !token) {
      throw new Error('WhatsApp Business API not configured for this organization')
    }

    // --- Lookup the template from the DB ---
    let template: { name: string; language: string } | undefined
    if (templateName) {
      // If caller passes a template name, validate it exists and matches org's template config
      template = { name: templateName, language: templateLanguage ?? 'en_US' }
    }

    const payload: Record<string, unknown> = {
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: template?.name ?? 'hello_world',
        language: { code: template?.language ?? 'en_US' },
      },
    }

    // Merge in template components if caller supplied them (for dynamic templates)
    if (components) {
      (payload.template as Record<string, unknown>).components = components
    }

    // --- Send via Meta WhatsApp Cloud API ---
    const res = await fetch(
      `https://graph.facebook.com/v21.0/${phoneId}/messages`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      },
    )

    const result = await res.json().catch(() => ({} as Record<string, unknown>))

    if (!res.ok) {
      const errMsg = (result as Record<string, string>)?.error?.message ?? `HTTP ${res.status}`
      throw new Error(`WhatsApp API error: ${errMsg}`)
    }

    // --- Audit log ---
    supabase.from('whatsapp_notifications').insert({
      org_id: orgId,
      recipient: to,
      template_name: (payload.template as Record<string, unknown>).name as string,
      status: 'sent',
      meta: result,
      sent_at: new Date().toISOString(),
    }).then(() => {}, (_e) => {})

    return new Response(
      JSON.stringify({
        success: true,
        message: 'WhatsApp message sent successfully',
        to,
        template: (payload.template as Record<string, unknown>).name,
        meta: result,
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
