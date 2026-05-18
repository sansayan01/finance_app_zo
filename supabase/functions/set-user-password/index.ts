import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Service role client — has full admin access to auth
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders() })
  }

  try {
    // 1. Verify the caller is authenticated
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return errorResponse('Missing authorization header', 401)
    }

    // Create a client with the caller's JWT to verify identity
    const callerClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { data: { user: caller }, error: authError } = await callerClient.auth.getUser()
    if (authError || !caller) {
      return errorResponse('Unauthorized: invalid token', 401)
    }

    // 2. Verify the caller is an executive admin or manager
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('id, role, org_id')
      .eq('user_id', caller.id)
      .single()

    if (profileError || !callerProfile) {
      return errorResponse('Caller profile not found', 403)
    }

    const allowedRoles = ['superAdmin', 'executiveAdmin', 'manager']
    if (!allowedRoles.includes(callerProfile.role)) {
      return errorResponse('Forbidden: insufficient permissions', 403)
    }

    // 3. Parse request body
    const { target_user_id, new_password } = await req.json()

    if (!target_user_id || !new_password) {
      return errorResponse('Missing required fields: target_user_id, new_password', 400)
    }

    // Validate password strength
    if (new_password.length < 6) {
      return errorResponse('Password must be at least 6 characters', 400)
    }

    // 4. Verify the target user belongs to the same organization
    const { data: targetProfile, error: targetError } = await supabaseAdmin
      .from('profiles')
      .select('id, user_id, org_id, role, full_name')
      .eq('user_id', target_user_id)
      .single()

    if (targetError || !targetProfile) {
      return errorResponse('Target user not found', 404)
    }

    // Org isolation: can only reset passwords within your own org
    if (targetProfile.org_id !== callerProfile.org_id) {
      return errorResponse('Forbidden: target user is in a different organization', 403)
    }

    // Prevent managers from resetting admin passwords
    if (callerProfile.role === 'manager' && 
        ['superAdmin', 'executiveAdmin'].includes(targetProfile.role)) {
      return errorResponse('Forbidden: managers cannot reset admin passwords', 403)
    }

    // 5. Reset the password using admin API
    const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      target_user_id,
      { password: new_password }
    )

    if (updateError) {
      console.error('Password update error:', updateError)
      return errorResponse(`Failed to update password: ${updateError.message}`, 500)
    }

    // 6. Log the action in audit_logs
    try {
      await supabaseAdmin.from('audit_logs').insert({
        org_id: callerProfile.org_id,
        user_id: caller.id,
        action: 'admin.password_reset',
        entity_type: 'profile',
        entity_id: targetProfile.id,
        details: {
          target_name: targetProfile.full_name,
          target_role: targetProfile.role,
          reset_by: callerProfile.role,
        }
      })
    } catch (e) {
      // Don't fail the operation if audit logging fails
      console.error('Audit log error:', e)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Password updated for ${targetProfile.full_name || 'user'}` 
      }),
      { 
        headers: { ...getCorsHeaders(), 'Content-Type': 'application/json' },
        status: 200 
      }
    )
  } catch (error) {
    console.error('set-user-password error:', error)
    const message = error instanceof Error ? error.message : String(error)
    return errorResponse(message, 500)
  }
})

function errorResponse(message: string, status: number) {
  return new Response(
    JSON.stringify({ success: false, message }),
    { 
      headers: { ...getCorsHeaders(), 'Content-Type': 'application/json' },
      status 
    }
  )
}

function getCorsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
}
