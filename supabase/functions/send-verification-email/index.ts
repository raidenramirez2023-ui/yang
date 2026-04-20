import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface EmailRequest {
  email: string
  otpCode: string
  appName: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, otpCode, appName }: EmailRequest = await req.json()

    if (!email || !otpCode) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get SendGrid credentials from environment variables
    const sendgridApiKey = Deno.env.get('SENDGRID_API_KEY')
    const senderEmail = Deno.env.get('SENDER_EMAIL') || 'chowyang783@gmail.com'
    const senderName = Deno.env.get('SENDER_NAME') || 'Yang Chow Restaurant'

    if (!sendgridApiKey) {
      console.error('SENDGRID_API_KEY not found in environment variables')
      return new Response(
        JSON.stringify({ error: 'Email service not configured' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Build the HTML email template with 6-digit OTP code
    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Verification</title>
</head>
<body style="font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f4f4f4;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
    <div style="text-align: center; padding-bottom: 20px; border-bottom: 2px solid #E81E0D;">
      <h1 style="color: #E81E0D; margin: 0; font-size: 28px;">Yang Chow Restaurant</h1>
    </div>
    
    <div style="padding: 30px 0;">
      <h2 style="color: #333; margin-top: 0;">Verify Your Email Address</h2>
      <p style="color: #666; line-height: 1.6; font-size: 16px;">
        Thank you for signing up at Yang Chow Restaurant! To complete your registration, please use the following 6-digit verification code:
      </p>
      
      <div style="text-align: center; margin: 30px 0; background-color: #f8f8f8; padding: 20px; border-radius: 5px;">
        <span style="font-size: 36px; font-weight: bold; color: #E81E0D; letter-spacing: 10px;">${otpCode}</span>
      </div>
      
      <p style="color: #999; font-size: 14px; line-height: 1.6;">
        This code will expire in 10 minutes. If you didn't create an account with Yang Chow Restaurant, please ignore this email.
      </p>
    </div>
    
    <div style="padding-top: 20px; border-top: 1px solid #e0e0e0; text-align: center; color: #999; font-size: 12px;">
      <p style="margin: 5px 0;">Yang Chow Restaurant</p>
      <p style="margin: 5px 0;">This is an automated message. Please do not reply.</p>
    </div>
  </div>
</body>
</html>
    `.trim()

    // Send email using SendGrid API
    const sendgridResponse = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${sendgridApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [
          {
            to: [{ email: email }],
            subject: 'Your Verification Code - Yang Chow Restaurant',
          },
        ],
        from: {
          email: senderEmail,
          name: senderName,
        },
        content: [
          {
            type: 'text/html',
            value: htmlContent,
          },
        ],
      }),
    })

    if (!sendgridResponse.ok) {
      const errorText = await sendgridResponse.text()
      console.error('SendGrid API error:', errorText)
      return new Response(
        JSON.stringify({ error: 'Failed to send email via SendGrid' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`Verification email sent to: ${email}`)

    return new Response(
      JSON.stringify({ success: true, message: 'Email sent successfully' }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in send-verification-email function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
