import { serve } from "https://deno.land/std@0.190.0/http/server.js"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabaseUrl = Deno.env.get('SUPABASE_URL')
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const resendApiKey = Deno.env.get('RESEND_API_KEY')

// Initialize Supabase client with service role for full access
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

// Resend API endpoint
const RESEND_API_URL = 'https://api.resend.com/emails'
const FROM_EMAIL = 'MicroFlow Pro <noreply@microflowpro.com>'

serve(async (req) => {
  // Handle CORS for preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: getCorsHeaders() })
  }

  try {
    // Parse the request body (should contain the user email and org name)
    const { email, orgName, userId } = await req.json()

    // Validate required fields
    if (!email || !orgName || !userId) {
      throw new Error('Missing required fields: email, orgName, or userId')
    }

    // Send welcome email via Resend
    const resendResponse = await fetch(RESEND_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [email],
        subject: 'Welcome to MicroFlow Pro!',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #2563eb;">Welcome to MicroFlow Pro!</h2>
            <p>Thank you for joining MicroFlow Pro. Your organization <strong>${orgName}</strong> is now ready to use.</p>
            <p>You can log in to your dashboard at:</p>
            <a href="https://app.microflowpro.com" style="display: inline-block; background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; margin: 16px 0;">Go to Dashboard</a>
            <p>If you have any questions, please don't hesitate to reach out to our support team.</p>
            <p>Best regards,<br>The MicroFlow Pro Team</p>
          </div>
        `,
      }),
    })

    if (!resendResponse.ok) {
      const errorData = await resendResponse.json()
      throw new Error(`Resend API error: ${errorData.message}`)
    }

    // Log successful email send (optional)
    console.log(`Welcome email sent to ${email} for organization ${orgName}`)

    return new Response(
      JSON.stringify({ success: true, message: 'Welcome email sent successfully' }),
      { 
        headers: { ...getCorsHeaders(), 'Content-Type': 'application/json' },
        status: 200 
      }
    )
  } catch (error) {
    console.error('Error sending welcome email:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: error.message || 'Failed to send welcome email' 
      }),
      { 
        headers: { ...getCorsHeaders(), 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})

function getCorsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  }
}