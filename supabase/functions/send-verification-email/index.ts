import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import nodemailer from 'npm:nodemailer'

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

    // Get Hostinger SMTP credentials from environment variables
    const smtpHost = Deno.env.get('SMTP_HOST') || 'smtp.hostinger.com'
    const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '465')
    const smtpUser = Deno.env.get('SMTP_USER')
    const smtpPass = Deno.env.get('SMTP_PASS')
    const senderName = Deno.env.get('SENDER_NAME') || 'Yang Chow Restaurant'

    if (!smtpUser || !smtpPass) {
      console.error('SMTP credentials (SMTP_USER/SMTP_PASS) not found in environment variables')
      return new Response(
        JSON.stringify({ error: 'Email service not configured. Please set SMTP credentials.' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Create transporter using Hostinger SMTP settings
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465, // true for 465, false for 587
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    })

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

    // Send email using SMTP
    await transporter.sendMail({
      from: `"${senderName}" <${smtpUser}>`,
      to: email,
      subject: 'Your Verification Code - Yang Chow Restaurant',
      html: htmlContent,
    })

    console.log(`Verification email sent via SMTP to: ${email}`)

    return new Response(
      JSON.stringify({ success: true, message: 'Email sent successfully via SMTP' }),
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
