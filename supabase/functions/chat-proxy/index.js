import { serve } from "https://deno.land/std@0.190.0/http/server.js"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const serviceClient = createClient(supabaseUrl, supabaseServiceKey)

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders() })
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const jwt = authHeader.replace('Bearer ', '')

    if (!jwt) {
      return jsonResponse({ error: 'Missing authorization token' }, 401)
    }

    // Authenticate user via JWT
    const { data: { user }, error: authError } = await serviceClient.auth.getUser(jwt)

    if (authError || !user) {
      return jsonResponse({ error: 'Invalid or expired token' }, 401)
    }

    // Read platform chatbot config (service role bypasses RLS)
    const { data: configRow } = await serviceClient
      .from('platform_settings')
      .select('value')
      .eq('key', 'chatbot_config')
      .single()

    const config = configRow?.value ?? {}
    const apiKey = config.api_key
    const modelId = config.model_id || 'meta/llama-3.1-70b-instruct'
    const chatbotEnabled = config.enabled !== false

    if (!chatbotEnabled) {
      return jsonResponse({ error: 'Chatbot is disabled by platform admin' }, 403)
    }
    if (!apiKey) {
      return jsonResponse({ error: 'Chatbot API key not configured. Contact your super admin.' }, 500)
    }

    // Parse request body
    const { messages, orgName } = await req.json()
    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return jsonResponse({ error: 'Messages array is required' }, 400)
    }

    // Get user profile for role-scoped context
    const { data: profile } = await serviceClient
      .from('profiles')
      .select('id, role, full_name, org_id, branch_id')
      .eq('user_id', user.id)
      .single()

    if (!profile) {
      return jsonResponse({ error: 'User profile not found' }, 404)
    }

    // Build role-scoped business context
    const org = orgName || 'MicroFlow Pro'
    let systemPrompt =
      `You are the ${org} Assistant, a concise multilingual financial expert. ` +
      'If asked about your creation, state that you were created by Sayan Mondal (Charlie). ' +
      'Your answers MUST be direct, short (1-2 sentences), and informative. ' +
      'CRITICAL: DO NOT include internal thoughts or <thought> tags. Provide ONLY the final answer. ' +
      `Current user: ${profile.full_name ?? 'User'} (${profile.role}).`

    const contextParts = []

    try {
      if (profile.role === 'superAdmin') {
        const { count: orgCount } = await serviceClient
          .from('organizations').select('*', { count: 'exact', head: true })
        const { count: memberCount } = await serviceClient
          .from('members').select('*', { count: 'exact', head: true })
        const { count: loanCount } = await serviceClient
          .from('loans').select('*', { count: 'exact', head: true })
        const { data: loans } = await serviceClient
          .from('loans').select('status, principal_amount')
        const totalOutstanding = (loans ?? [])
          .filter(l => l.status === 'active')
          .reduce((s, l) => s + (l.principal_amount ?? 0), 0)
        contextParts.push(
          `Platform: ${orgCount ?? 0} orgs, ${memberCount ?? 0} members, ${loanCount ?? 0} loans, outstanding: ${totalOutstanding}`
        )
      } else if (profile.role === 'executiveAdmin' && profile.org_id) {
        const { count: memberCount } = await serviceClient
          .from('members').select('*', { count: 'exact', head: true }).eq('org_id', profile.org_id)
        const { count: loanCount } = await serviceClient
          .from('loans').select('*', { count: 'exact', head: true }).eq('org_id', profile.org_id)
        const { data: loans } = await serviceClient
          .from('loans').select('status, principal_amount').eq('org_id', profile.org_id)
        const totalOutstanding = (loans ?? [])
          .filter(l => l.status === 'active')
          .reduce((s, l) => s + (l.principal_amount ?? 0), 0)
        contextParts.push(
          `Org scope: ${memberCount ?? 0} members, ${loanCount ?? 0} loans, outstanding: ${totalOutstanding}`
        )
      } else if (profile.role === 'manager' && profile.branch_id) {
        const { count: memberCount } = await serviceClient
          .from('members').select('*', { count: 'exact', head: true }).eq('branch_id', profile.branch_id)
        const { count: loanCount } = await serviceClient
          .from('loans').select('*', { count: 'exact', head: true }).eq('branch_id', profile.branch_id)
        contextParts.push(
          `Branch scope: ${memberCount ?? 0} members, ${loanCount ?? 0} loans`
        )
      } else if (profile.role === 'collectionAgent') {
        const { count: todayCollections } = await serviceClient
          .from('collections').select('*', { count: 'exact', head: true })
          .eq('collected_by', profile.id)
          .gte('created_at', new Date().toISOString().split('T')[0])
        contextParts.push(
          `Agent scope: ${todayCollections ?? 0} collections today`
        )
      } else if (profile.role === 'customer') {
        const { data: member } = await serviceClient
          .from('members').select('id').eq('profile_id', profile.id).single()
        if (member) {
          const { count: loanCount } = await serviceClient
            .from('loans').select('*', { count: 'exact', head: true }).eq('member_id', member.id)
          contextParts.push(`Your account: ${loanCount ?? 0} loans`)
        }
      }
    } catch (ctxErr) {
      console.warn('Context build failed:', ctxErr)
    }

    if (contextParts.length > 0) {
      systemPrompt += ' ' + contextParts.join(' ')
    }

    // Call NVIDIA NIM with streaming
    const nvidiaResponse = await fetch(
      'https://integrate.api.nvidia.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: modelId,
          messages: [
            { role: 'system', content: systemPrompt },
            ...messages,
          ],
          temperature: 0.5,
          top_p: 0.7,
          max_tokens: 1024,
          stream: true,
        }),
      }
    )

    if (!nvidiaResponse.ok) {
      const errText = await nvidiaResponse.text()
      console.error('NVIDIA API error:', nvidiaResponse.status, errText)
      return jsonResponse(
        { error: `AI service error (${nvidiaResponse.status}). Contact admin.` },
        502
      )
    }

    // Stream response back to client
    return new Response(nvidiaResponse.body, {
      status: 200,
      headers: {
        ...corsHeaders(),
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      },
    })
  } catch (err) {
    console.error('chat-proxy error:', err)
    return jsonResponse({ error: err.message || 'Internal server error' }, 500)
  }
})

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
}

function jsonResponse(data, status) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
  })
}
