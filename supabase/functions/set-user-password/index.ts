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
    // Lookup by either profile ID or auth user_id to handle client inconsistencies
    const { data: targetProfile, error: targetError } = await supabaseAdmin
      .from('profiles')
      .select('id, user_id, org_id, role, full_name')
      .or(`id.eq.${target_user_id},user_id.eq.${target_user_id}`)
      .single()

    if (targetError || !targetProfile) {
      return errorResponse('Target user not found', 404)
    }

    // 5. Handle the two cases: profile has no auth account yet, or account exists
    if (targetProfile.user_id) {
      // --- CASE A: auth account already linked — just update the password ---
      if (targetProfile.org_id !== callerProfile.org_id) {
        return errorResponse('Forbidden: target user is in a different organization', 403)
      }

      // Prevent managers from resetting admin passwords
      if (callerProfile.role === 'manager' &&
          ['superAdmin', 'executiveAdmin'].includes(targetProfile.role)) {
        return errorResponse('Forbidden: managers cannot reset admin passwords', 403)
      }

      const { error: updateError, data: updateData } =
        await supabaseAdmin.auth.admin.updateUserById(
          targetProfile.user_id,
          { password: new_password }
        )

      if (updateError) {
        console.error('Password update error:', updateError)
        const msg = updateError.message ?? 'Unknown error'
        // GoTrue may return HTTP 400 if the auth user record is in a bad state
        if (msg.includes('missing') || msg.includes('not found') || msg.includes('invalid')) {
          return errorResponse(
            `Auth account for ${targetProfile.full_name ?? 'this user'} is in an unrecoverable state. ` +
            `Please delete and recreate the user. Details: ${msg}`,
            400
          )
        }
        return errorResponse(`Failed to update password: ${msg}`, 500)
      }

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
        console.error('Audit log error:', e)
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: `Password updated for ${targetProfile.full_name ?? 'user'}`
        }),
        {
          headers: { ...getCorsHeaders(), 'Content-Type': 'application/json' },
          status: 200
        }
      )
    }

    // --- CASE B: profile has no auth account — try to create and link one ---
    if (targetProfile.org_id !== callerProfile.org_id) {
      return errorResponse('Forbidden: target user is in a different organization', 403)
    }

    const { data: fullProfile } = await supabaseAdmin
      .from('profiles')
      .select('email')
      .eq('id', targetProfile.id)
      .single()

    const email = fullProfile?.email
    if (!email) {
      return errorResponse('Target user has no email address — cannot create a login account. Please add an email to their profile first.', 400)
    }

    // Look up any existing auth user by email so we can link to it
    const { data: existingAuthUsers } =
      await supabaseAdmin.auth.admin.listUsers({ email, perPage: 1 })

    const foundUser = (existingAuthUsers?.users ?? []).find(
      (u) => u.email === email
    )

    if (foundUser) {
      // Auth account exists but was never linked to this profile — link it now
      const { error: linkError } = await supabaseAdmin
        .from('profiles')
        .update({ user_id: foundUser.id })
        .eq('id', targetProfile.id)

      if (linkError) {
        console.error('Failed to link auth account:', linkError)
        return errorResponse(
          `An auth account already exists for this email but could not be linked. ` +
          `Error: ${linkError.message}`,
          500
        )
      }

      // Now update the password for the linked account
      const { error: updateError2 } =
        await supabaseAdmin.auth.admin.updateUserById(
          foundUser.id,
          { password: new_password }
        )

      if (updateError2) {
        console.error('Password update after link error:', updateError2)
        return errorResponse(
          `Auth account was linked but password could not be set: ${updateError2.message}`,
          500
        )
      }
    } else {
      // No existing auth account — create one
      const { data: newAuthUser, error: createError } =
        await supabaseAdmin.auth.admin.createUser({
          email,
          password: new_password,
          email_confirm: true,
        })

      if (createError || !newAuthUser?.user) {
        console.error('Failed to create auth account:', createError)
        return errorResponse(
          `Failed to create login account: ${createError?.message ?? 'unknown error'}`,
          400
        )
      }

      // Link the new auth user to the profile
      const { error: linkError2 } = await supabaseAdmin
        .from('profiles')
        .update({ user_id: newAuthUser.user.id })
        .eq('id', targetProfile.id)

      if (linkError2) {
        console.error('Failed to link auth account:', linkError2)
        return errorResponse(
          `Auth account created but could not be linked to profile: ${linkError2.message}`,
          500
        )
      }
    }

    try {
      await supabaseAdmin.from('audit_logs').insert({
        org_id: callerProfile.org_id,
        user_id: caller.id,
        action: 'admin.account_created_and_password_set',
        entity_type: 'profile',
        entity_id: targetProfile.id,
        details: {
          target_name: targetProfile.full_name,
          target_role: targetProfile.role,
          created_by: callerProfile.role,
        }
      })
    } catch (e) {
      console.error('Audit log error:', e)
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Login account created and password set for ${targetProfile.full_name ?? 'user'}`
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
