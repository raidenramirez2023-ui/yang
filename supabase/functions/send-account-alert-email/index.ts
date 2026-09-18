import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import nodemailer from 'npm:nodemailer'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AlertEmailRequest {
  type: 'account_warning' | 'account_restriction' | 'account_unrestricted' | 'custom_alert'
  recipientEmail: string
  customerName?: string
  warningNumber?: number
  restrictionType?: string
  reason?: string
  expiresAt?: string
  adminName?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: AlertEmailRequest = await req.json()
    const {
      type,
      recipientEmail,
      customerName = 'Valued Customer',
      warningNumber = 1,
      restrictionType = 'Temporary Restriction',
      reason = 'Booking policy compliance notice.',
      expiresAt,
    } = body

    if (!recipientEmail) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: recipientEmail' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // SMTP Credentials
    const smtpHost = Deno.env.get('SMTP_HOST') || 'smtp.hostinger.com'
    const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '465')
    const smtpUser = Deno.env.get('SMTP_USER')
    const smtpPass = Deno.env.get('SMTP_PASS')
    const senderName = Deno.env.get('SENDER_NAME') || 'Yang Chow Restaurant'

    if (!smtpUser || !smtpPass) {
      console.error('SMTP credentials (SMTP_USER/SMTP_PASS) not configured')
      return new Response(
        JSON.stringify({ error: 'SMTP not configured on server' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase Client for logging
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    let supabase: any = null
    if (supabaseUrl && supabaseServiceKey) {
      supabase = createClient(supabaseUrl, supabaseServiceKey)
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    })

    let subject = ''
    let htmlContent = ''

    if (type === 'account_warning') {
      subject = `⚠️ Important Notice: Official Account Warning (#${warningNumber}) - Yang Chow Restaurant`
      htmlContent = buildWarningHtml(customerName, warningNumber, reason)
    } else if (type === 'account_restriction') {
      subject = `🚫 Notice: Your Account Has Been Placed on Restriction - Yang Chow Restaurant`
      htmlContent = buildRestrictionHtml(customerName, restrictionType, reason, expiresAt)
    } else if (type === 'account_unrestricted') {
      subject = `✅ Good News: Account Restriction Has Been Lifted - Yang Chow Restaurant`
      htmlContent = buildUnrestrictedHtml(customerName, reason)
    } else {
      subject = `Notice Regarding Your Account - Yang Chow Restaurant`
      htmlContent = buildWarningHtml(customerName, 1, reason)
    }

    // Send Mail
    await transporter.sendMail({
      from: `"${senderName}" <${smtpUser}>`,
      to: recipientEmail,
      subject,
      html: htmlContent,
    })

    console.log(`Alert email [${type}] sent to: ${recipientEmail}`)

    // Log to email_logs if supabase is available
    if (supabase) {
      try {
        await supabase.from('email_logs').insert({
          recipient_email: recipientEmail,
          subject,
          email_type: type,
          status: 'sent',
          sent_at: new Date().toISOString(),
        })
      } catch (logErr) {
        console.error('Error recording in email_logs:', logErr)
      }
    }

    return new Response(
      JSON.stringify({ success: true, message: `Email sent successfully to ${recipientEmail}` }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: any) {
    console.error('Error in send-account-alert-email function:', error)
    return new Response(
      JSON.stringify({ error: error.message || 'Failed to send alert email' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ── HTML Email Templates ──

function buildWarningHtml(customerName: string, warningNumber: number, reason: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account Warning Notice</title>
</head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc;">
  <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e2e8f0;">
    
    <!-- Header Banner -->
    <div style="background: linear-gradient(135deg, #D97706 0%, #B45309 100%); padding: 30px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">Yang Chow Pagsanjan</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 6px 0 0 0; font-size: 13px; font-weight: 500;">Official Account Policy Notice</p>
    </div>

    <!-- Main Content -->
    <div style="padding: 32px 28px;">
      <div style="display: inline-block; background-color: #FEF3C7; border: 1px solid #FCD34D; color: #92400E; font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 20px; text-transform: uppercase; margin-bottom: 16px;">
        ⚠️ Warning #${warningNumber} Issued
      </div>

      <h2 style="color: #0F172A; margin: 0 0 12px 0; font-size: 20px;">Dear ${customerName},</h2>
      <p style="color: #475569; line-height: 1.6; font-size: 14.5px; margin: 0 0 20px 0;">
        We are writing to inform you that an official warning has been recorded on your customer account due to non-compliance with our reservation policies.
      </p>

      <!-- Reason Card -->
      <div style="background: #FFFBEB; border-left: 4px solid #D97706; border-radius: 8px; padding: 18px; margin: 20px 0;">
        <h3 style="color: #92400E; margin: 0 0 8px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Reason for Warning</h3>
        <p style="color: #78350F; margin: 0; font-size: 14px; line-height: 1.5; font-weight: 500;">
          "${reason}"
        </p>
      </div>

      <!-- Policy Guidelines -->
      <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 18px; margin: 20px 0;">
        <h4 style="color: #1E293B; margin: 0 0 10px 0; font-size: 13px;">📌 Why is this policy in place?</h4>
        <ul style="color: #64748B; font-size: 13px; line-height: 1.6; margin: 0; padding-left: 20px;">
          <li>Submitting speculative bookings or failing to pay quotations holds dates away from other guests.</li>
          <li>Repeated unconfirmed bookings incur prep costs and disrupt restaurant schedule management.</li>
          <li>Accounts that incur multiple warnings may be placed on temporary booking restriction.</li>
        </ul>
      </div>

      <p style="color: #475569; line-height: 1.6; font-size: 13.5px; margin: 20px 0 0 0;">
        You can continue to view and manage your reservations inside the app. If you believe this notice was issued by mistake, please contact our management team or reply to this message.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #F8FAFC; padding: 20px 28px; border-top: 1px solid #E2E8F0; text-align: center;">
      <p style="color: #0F172A; font-weight: 700; font-size: 14px; margin: 0 0 4px 0;">Yang Chow Pagsanjan</p>
      <p style="color: #94A3B8; font-size: 12px; margin: 0;">Pagsanjan, Laguna • Contact: bsit-ycprms@yc-pagsanjan.site</p>
    </div>
  </div>
</body>
</html>
  `.trim()
}

function buildRestrictionHtml(customerName: string, restrictionType: string, reason: string, expiresAt?: string): string {
  const expiryText = expiresAt ? expiresAt : 'Pending Administrative Review'

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account Restriction Notice</title>
</head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc;">
  <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e2e8f0;">
    
    <!-- Header Banner -->
    <div style="background: linear-gradient(135deg, #DC2626 0%, #991B1B 100%); padding: 30px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">Yang Chow Pagsanjan</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 6px 0 0 0; font-size: 13px; font-weight: 500;">Account Restriction Notification</p>
    </div>

    <!-- Main Content -->
    <div style="padding: 32px 28px;">
      <div style="display: inline-block; background-color: #FEE2E2; border: 1px solid #FCA5A5; color: #991B1B; font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 20px; text-transform: uppercase; margin-bottom: 16px;">
        🚫 ${restrictionType.toUpperCase()}
      </div>

      <h2 style="color: #0F172A; margin: 0 0 12px 0; font-size: 20px;">Dear ${customerName},</h2>
      <p style="color: #475569; line-height: 1.6; font-size: 14.5px; margin: 0 0 20px 0;">
        Your customer account has been placed under temporary restriction from submitting new reservation requests and advance orders.
      </p>

      <!-- Details Card -->
      <div style="background: #FEF2F2; border-left: 4px solid #DC2626; border-radius: 8px; padding: 18px; margin: 20px 0;">
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 4px 0; color: #7F1D1D; font-size: 13px; width: 120px; font-weight: 600;">Status:</td>
            <td style="padding: 4px 0; color: #991B1B; font-size: 13px; font-weight: 700;">${restrictionType}</td>
          </tr>
          <tr>
            <td style="padding: 4px 0; color: #7F1D1D; font-size: 13px; font-weight: 600;">Reason:</td>
            <td style="padding: 4px 0; color: #7F1D1D; font-size: 13px;">${reason}</td>
          </tr>
          <tr>
            <td style="padding: 4px 0; color: #7F1D1D; font-size: 13px; font-weight: 600;">Effective Until:</td>
            <td style="padding: 4px 0; color: #991B1B; font-size: 13px; font-weight: 700;">${expiryText}</td>
          </tr>
        </table>
      </div>

      <!-- Impact Details -->
      <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 18px; margin: 20px 0;">
        <h4 style="color: #1E293B; margin: 0 0 10px 0; font-size: 13px;">Account Access Guidelines:</h4>
        <ul style="color: #64748B; font-size: 13px; line-height: 1.6; margin: 0; padding-left: 20px;">
          <li>You will temporarily not be able to submit new reservations or advance orders.</li>
          <li>Any existing confirmed reservations remain scheduled unless specifically cancelled.</li>
          <li>Restrictions are automatically lifted upon expiration or through administrative review.</li>
        </ul>
      </div>

      <p style="color: #475569; line-height: 1.6; font-size: 13.5px; margin: 20px 0 0 0;">
        If you need to appeal this decision or have inquiries regarding your account standing, please contact our restaurant management directly.
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #F8FAFC; padding: 20px 28px; border-top: 1px solid #E2E8F0; text-align: center;">
      <p style="color: #0F172A; font-weight: 700; font-size: 14px; margin: 0 0 4px 0;">Yang Chow Pagsanjan</p>
      <p style="color: #94A3B8; font-size: 12px; margin: 0;">Pagsanjan, Laguna • Contact: bsit-ycprms@yc-pagsanjan.site</p>
    </div>
  </div>
</body>
</html>
  `.trim()
}

function buildUnrestrictedHtml(customerName: string, reason: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Account Restored</title>
</head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background-color: #f8fafc;">
  <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); border: 1px solid #e2e8f0;">
    
    <!-- Header Banner -->
    <div style="background: linear-gradient(135deg, #16A34A 0%, #15803D 100%); padding: 30px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">Yang Chow Pagsanjan</h1>
      <p style="color: rgba(255,255,255,0.9); margin: 6px 0 0 0; font-size: 13px; font-weight: 500;">Account Status Update</p>
    </div>

    <!-- Main Content -->
    <div style="padding: 32px 28px;">
      <div style="display: inline-block; background-color: #DCFCE7; border: 1px solid #86EFAC; color: #15803D; font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 20px; text-transform: uppercase; margin-bottom: 16px;">
        ✅ Account Active & In Good Standing
      </div>

      <h2 style="color: #0F172A; margin: 0 0 12px 0; font-size: 20px;">Hello ${customerName},</h2>
      <p style="color: #475569; line-height: 1.6; font-size: 14.5px; margin: 0 0 20px 0;">
        We are happy to let you know that your account restrictions and warning history have been cleared. You now have full access to book reservations and order from Yang Chow Restaurant.
      </p>

      <div style="background: #F0FDF4; border-left: 4px solid #16A34A; border-radius: 8px; padding: 18px; margin: 20px 0;">
        <h3 style="color: #166534; margin: 0 0 8px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px;">Admin Note</h3>
        <p style="color: #14532D; margin: 0; font-size: 14px; line-height: 1.5; font-weight: 500;">
          "${reason}"
        </p>
      </div>

      <p style="color: #475569; line-height: 1.6; font-size: 13.5px; margin: 20px 0 0 0;">
        Thank you for your cooperation and for choosing Yang Chow!
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #F8FAFC; padding: 20px 28px; border-top: 1px solid #E2E8F0; text-align: center;">
      <p style="color: #0F172A; font-weight: 700; font-size: 14px; margin: 0 0 4px 0;">Yang Chow Pagsanjan</p>
      <p style="color: #94A3B8; font-size: 12px; margin: 0;">Pagsanjan, Laguna • Contact: bsit-ycprms@yc-pagsanjan.site</p>
    </div>
  </div>
</body>
</html>
  `.trim()
}
