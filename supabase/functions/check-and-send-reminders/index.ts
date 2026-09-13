import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import nodemailer from 'npm:nodemailer'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
}

interface ReminderRequest {
  source: 'cron' | 'manual'
  reservationId?: string   // For manual resend of event reservation
  advanceOrderId?: string  // For manual resend of advance order
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify cron secret for automated calls (skip for manual calls with valid auth)
    const cronSecret = req.headers.get('x-cron-secret')
    const authHeader = req.headers.get('authorization')
    const expectedCronSecret = Deno.env.get('CRON_SECRET')

    // Accept either: valid cron secret OR valid Supabase auth token
    if (cronSecret !== expectedCronSecret && !authHeader) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const body: ReminderRequest = await req.json()

    // Initialize Supabase client with service role key for full DB access
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get SMTP credentials
    const smtpHost = Deno.env.get('SMTP_HOST') || 'smtp.hostinger.com'
    const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '465')
    const smtpUser = Deno.env.get('SMTP_USER')
    const smtpPass = Deno.env.get('SMTP_PASS')
    const senderEmail = 'bsit-ycprms@yc-pagsanjan.site'
    const senderName = 'Yang Chow Pagsanjan'

    if (!smtpUser || !smtpPass) {
      console.error('SMTP credentials not found')
      return new Response(
        JSON.stringify({ error: 'SMTP not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create SMTP transporter
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: { user: smtpUser, pass: smtpPass },
    })

    let totalSent = 0
    let errors: string[] = []

    // ================================================================
    // MANUAL RESEND — specific reservation or advance order
    // ================================================================
    if (body.source === 'manual') {
      if (body.reservationId) {
        const { data: reservation, error } = await supabase
          .from('reservations')
          .select('*')
          .eq('id', body.reservationId)
          .single()

        if (error || !reservation) {
          return new Response(
            JSON.stringify({ error: 'Reservation not found' }),
            { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        const result = await sendEventReminder(transporter, supabase, reservation, senderName, senderEmail, true)
        if (result.success) totalSent++
        else errors.push(result.error!)
      }

      if (body.advanceOrderId) {
        const { data: order, error } = await supabase
          .from('advance_orders')
          .select('*')
          .eq('id', body.advanceOrderId)
          .single()

        if (error || !order) {
          return new Response(
            JSON.stringify({ error: 'Advance order not found' }),
            { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          )
        }

        const result = await sendAdvanceOrderReminder(transporter, supabase, order, senderName, senderEmail, true)
        if (result.success) totalSent++
        else errors.push(result.error!)
      }

      return new Response(
        JSON.stringify({ success: true, sent: totalSent, errors }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ================================================================
    // AUTOMATED CRON — find and send all due reminders
    // ================================================================

    // Get current time in Philippine timezone (UTC+8)
    const now = new Date()
    const phOffset = 8 * 60 // UTC+8 in minutes
    const utcMs = now.getTime() + (now.getTimezoneOffset() * 60000)
    const phNow = new Date(utcMs + (phOffset * 60000))

    console.log(`[Cron] Running reminder check at PH time: ${phNow.toISOString()}`)

    // --- EVENT RESERVATIONS: 2 days before event_date ---
    // Calculate the target date (2 days from now in PH timezone)
    const twoDaysFromNow = new Date(phNow)
    twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2)
    const targetEventDate = twoDaysFromNow.toISOString().split('T')[0] // YYYY-MM-DD

    console.log(`[Cron] Looking for event reservations on date: ${targetEventDate}`)

    const { data: dueReservations, error: resError } = await supabase
      .from('reservations')
      .select('*')
      .eq('event_date', targetEventDate)
      .eq('reminder_sent', false)
      .in('status', ['confirmed', 'approved', 'pending'])

    if (resError) {
      console.error('[Cron] Error fetching reservations:', resError)
    } else if (dueReservations && dueReservations.length > 0) {
      console.log(`[Cron] Found ${dueReservations.length} event reservations to remind`)
      for (const reservation of dueReservations) {
        const result = await sendEventReminder(transporter, supabase, reservation, senderName, senderEmail, false)
        if (result.success) totalSent++
        else errors.push(result.error!)
      }
    } else {
      console.log('[Cron] No event reservations need reminders today')
    }

    // --- ADVANCE ORDERS: 5 hours before order_date + order_time ---
    // We need to find orders where the order datetime minus 5 hours is now or past,
    // but the order datetime itself is still in the future
    const fiveHoursFromNow = new Date(phNow)
    fiveHoursFromNow.setHours(fiveHoursFromNow.getHours() + 5)
    const fiveHoursDate = fiveHoursFromNow.toISOString().split('T')[0]
    
    // Also check today's date for orders happening later today
    const todayDate = phNow.toISOString().split('T')[0]

    console.log(`[Cron] Looking for advance orders on dates: ${todayDate} to ${fiveHoursDate}`)

    const { data: dueOrders, error: ordError } = await supabase
      .from('advance_orders')
      .select('*')
      .eq('reminder_sent', false)
      .in('status', ['confirmed', 'approved', 'pending', 'paid'])
      .or(`order_date.eq.${todayDate},order_date.eq.${fiveHoursDate}`)

    if (ordError) {
      console.error('[Cron] Error fetching advance orders:', ordError)
    } else if (dueOrders && dueOrders.length > 0) {
      console.log(`[Cron] Found ${dueOrders.length} potential advance orders to check`)
      
      for (const order of dueOrders) {
        // Parse the order's datetime and check if it's within 5 hours
        const orderDateStr = order.order_date
        const orderTimeStr = order.order_time || '12:00'
        
        // Build the full datetime
        const orderDateTime = new Date(`${orderDateStr}T${orderTimeStr}:00+08:00`)
        const reminderTime = new Date(orderDateTime.getTime() - (5 * 60 * 60 * 1000)) // 5 hours before
        
        // Send reminder if current time is at or past the reminder time, but before the order time
        if (now >= reminderTime && now < orderDateTime) {
          console.log(`[Cron] Sending reminder for advance order ${order.id} (${order.order_type} at ${orderTimeStr})`)
          const result = await sendAdvanceOrderReminder(transporter, supabase, order, senderName, senderEmail, false)
          if (result.success) totalSent++
          else errors.push(result.error!)
        }
      }
    } else {
      console.log('[Cron] No advance orders need reminders')
    }

    console.log(`[Cron] Reminder check complete. Sent: ${totalSent}, Errors: ${errors.length}`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: totalSent,
        errors,
        checkedAt: phNow.toISOString(),
        targetEventDate,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error in check-and-send-reminders:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ================================================================
// SEND EVENT RESERVATION REMINDER
// ================================================================
async function sendEventReminder(
  transporter: any,
  supabase: any,
  reservation: any,
  senderName: string,
  senderEmail: string,
  isManual: boolean,
): Promise<{ success: boolean; error?: string }> {
  try {
    const customerEmail = reservation.customer_email
    const customerName = reservation.customer_name || 'Valued Customer'
    const eventType = reservation.event_type || 'Event'
    const eventDate = reservation.event_date
    const startTime = reservation.start_time || ''
    const guests = reservation.number_of_guests || 0

    // Format the date nicely
    const dateObj = new Date(eventDate + 'T00:00:00')
    const formattedDate = dateObj.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })

    // Format time
    let formattedTime = startTime
    if (startTime) {
      try {
        const [h, m] = startTime.split(':').map(Number)
        const ampm = h >= 12 ? 'PM' : 'AM'
        const hour12 = h % 12 || 12
        formattedTime = `${hour12}:${m.toString().padStart(2, '0')} ${ampm}`
      } catch (_) { /* keep original */ }
    }

    // Dynamic relative timing (e.g. today, tomorrow, in 2 days, in 3 weeks, in 1 month)
    const timing = getEventTimingDetails(eventDate, eventType, formattedDate)
    const subject = timing.subject
    const htmlContent = buildEventReminderHtml(customerName, eventType, formattedDate, formattedTime, guests, timing.introPhrase)

    await transporter.sendMail({
      from: `"${senderName}" <${senderEmail}>`,
      to: customerEmail,
      subject,
      html: htmlContent,
    })

    // Mark as sent
    await supabase
      .from('reservations')
      .update({
        reminder_sent: true,
        reminder_sent_at: new Date().toISOString(),
      })
      .eq('id', reservation.id)

    // Log to email_logs
    await supabase.from('email_logs').insert({
      recipient_email: customerEmail,
      subject,
      email_type: 'event_reminder',
      reservation_id: reservation.id,
      status: 'sent',
    })

    console.log(`✅ Event reminder sent to ${customerEmail} for ${eventType} on ${eventDate}`)
    return { success: true }
  } catch (error) {
    console.error(`❌ Failed to send event reminder for ${reservation.id}:`, error)
    
    // Log failure
    try {
      await supabase.from('email_logs').insert({
        recipient_email: reservation.customer_email,
        subject: `Reminder: ${reservation.event_type}`,
        email_type: 'event_reminder',
        reservation_id: reservation.id,
        status: 'failed',
        error_message: error.message,
      })
    } catch (_) { /* ignore logging errors */ }

    return { success: false, error: `${reservation.id}: ${error.message}` }
  }
}

// ================================================================
// SEND ADVANCE ORDER REMINDER
// ================================================================
async function sendAdvanceOrderReminder(
  transporter: any,
  supabase: any,
  order: any,
  senderName: string,
  senderEmail: string,
  isManual: boolean,
): Promise<{ success: boolean; error?: string }> {
  try {
    const customerEmail = order.customer_email
    const customerName = order.customer_name || 'Valued Customer'
    const orderType = order.order_type || 'Order' // 'Dine-in' or 'Pick-up'
    const orderDate = order.order_date
    const orderTime = order.order_time || '12:00'
    const guests = order.number_of_guests || 0
    const orderTypeLabel = orderType.toLowerCase().includes('dine') ? 'Dine-in' : 'Pick-up'

    // Format the date nicely
    const dateObj = new Date(orderDate + 'T00:00:00')
    const formattedDate = dateObj.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    })

    // Format time
    let formattedTime = orderTime
    try {
      const [h, m] = orderTime.split(':').map(Number)
      const ampm = h >= 12 ? 'PM' : 'AM'
      const hour12 = h % 12 || 12
      formattedTime = `${hour12}:${m.toString().padStart(2, '0')} ${ampm}`
    } catch (_) { /* keep original */ }

    // Dynamic relative timing for advance orders
    const timing = getAdvanceOrderTimingDetails(orderDate, orderTime, orderTypeLabel, formattedDate, formattedTime)
    const subject = timing.subject
    const htmlContent = buildAdvanceOrderReminderHtml(customerName, orderType, formattedDate, formattedTime, guests, timing.introPhrase)

    await transporter.sendMail({
      from: `"${senderName}" <${senderEmail}>`,
      to: customerEmail,
      subject,
      html: htmlContent,
    })

    // Mark as sent
    await supabase
      .from('advance_orders')
      .update({
        reminder_sent: true,
        reminder_sent_at: new Date().toISOString(),
      })
      .eq('id', order.id)

    // Log to email_logs
    await supabase.from('email_logs').insert({
      recipient_email: customerEmail,
      subject,
      email_type: 'advance_order_reminder',
      status: 'sent',
    })

    console.log(`✅ Advance order reminder sent to ${customerEmail} for ${orderType} on ${orderDate} at ${orderTime}`)
    return { success: true }
  } catch (error) {
    console.error(`❌ Failed to send advance order reminder for ${order.id}:`, error)
    
    try {
      await supabase.from('email_logs').insert({
        recipient_email: order.customer_email,
        subject: `Reminder: ${order.order_type} Order`,
        email_type: 'advance_order_reminder',
        status: 'failed',
        error_message: error.message,
      })
    } catch (_) { /* ignore logging errors */ }

    return { success: false, error: `${order.id}: ${error.message}` }
  }
}

// ================================================================
// DYNAMIC TIMING CALCULATORS
// ================================================================

function getEventTimingDetails(eventDateStr: string, eventType: string, formattedDate: string): {
  subject: string
  introPhrase: string
} {
  // Get current PH date string YYYY-MM-DD
  const now = new Date()
  const phOffset = 8 * 60 // UTC+8 in minutes
  const utcMs = now.getTime() + (now.getTimezoneOffset() * 60000)
  const phNow = new Date(utcMs + (phOffset * 60000))
  const todayStr = phNow.toISOString().split('T')[0]

  const d1 = new Date(todayStr + 'T00:00:00Z').getTime()
  const d2 = new Date(eventDateStr + 'T00:00:00Z').getTime()
  const diffDays = Math.round((d2 - d1) / (1000 * 60 * 60 * 24))

  if (diffDays <= 0) {
    return {
      subject: `Reminder: Your ${eventType} at Yang Chow Pagsanjan is Today! 🎉`,
      introPhrase: `is happening <strong>today</strong>!`,
    }
  } else if (diffDays === 1) {
    return {
      subject: `Reminder: Your ${eventType} at Yang Chow Pagsanjan is Tomorrow! 🎉`,
      introPhrase: `is coming up <strong>tomorrow</strong>!`,
    }
  } else if (diffDays === 2) {
    return {
      subject: `Reminder: Your ${eventType} at Yang Chow Pagsanjan is in 2 Days! 🎉`,
      introPhrase: `is coming up in <strong>2 days</strong>!`,
    }
  } else if (diffDays >= 3 && diffDays <= 6) {
    return {
      subject: `Reminder: Your ${eventType} at Yang Chow Pagsanjan is in ${diffDays} Days! 🎉`,
      introPhrase: `is coming up in <strong>${diffDays} days</strong>!`,
    }
  } else if (diffDays >= 7 && diffDays < 30) {
    const weeks = Math.floor(diffDays / 7)
    const weekText = weeks === 1 ? '1 week' : `${weeks} weeks`
    const daysRemainder = diffDays % 7
    const timeDetail = daysRemainder === 0 ? `${weekText} (${diffDays} days)` : `${diffDays} days (about ${weekText})`
    return {
      subject: `Reminder: Your ${eventType} at Yang Chow Pagsanjan is in ${diffDays} Days! 🎉`,
      introPhrase: `is coming up in <strong>${timeDetail}</strong>!`,
    }
  } else {
    // 30 days or more
    const months = Math.floor(diffDays / 30)
    const monthText = months === 1 ? '1 month' : `${months} months`
    return {
      subject: `Reminder: Your Upcoming ${eventType} at Yang Chow Pagsanjan (${formattedDate}) 🎉`,
      introPhrase: `is scheduled for <strong>${formattedDate}</strong> (in <strong>${diffDays} days / about ${monthText}</strong>)!`,
    }
  }
}

function getAdvanceOrderTimingDetails(
  orderDateStr: string,
  orderTimeStr: string,
  orderTypeLabel: string,
  formattedDate: string,
  formattedTime: string,
): {
  subject: string
  introPhrase: string
} {
  const now = new Date()
  const phOffset = 8 * 60
  const utcMs = now.getTime() + (now.getTimezoneOffset() * 60000)
  const phNow = new Date(utcMs + (phOffset * 60000))

  const targetDateTime = new Date(`${orderDateStr}T${orderTimeStr || '12:00'}:00+08:00`)
  const diffMs = targetDateTime.getTime() - phNow.getTime()
  const diffMinutes = Math.round(diffMs / (1000 * 60))
  const diffHours = Math.round(diffMs / (1000 * 60 * 60))

  const todayStr = phNow.toISOString().split('T')[0]
  const d1 = new Date(todayStr + 'T00:00:00Z').getTime()
  const d2 = new Date(orderDateStr + 'T00:00:00Z').getTime()
  const diffDays = Math.round((d2 - d1) / (1000 * 60 * 60 * 24))

  if (diffDays === 0) {
    if (diffMinutes <= 60 && diffMinutes > 0) {
      return {
        subject: `Reminder: Your ${orderTypeLabel} Order at Yang Chow is in ${diffMinutes} Minutes! 🍽️`,
        introPhrase: `is coming up in <strong>${diffMinutes} minutes</strong>!`,
      }
    } else if (diffHours > 0) {
      return {
        subject: `Reminder: Your ${orderTypeLabel} Order at Yang Chow is Today at ${formattedTime}! 🍽️`,
        introPhrase: `is coming up in <strong>${diffHours} hour${diffHours > 1 ? 's' : ''}</strong>!`,
      }
    } else {
      return {
        subject: `Reminder: Your ${orderTypeLabel} Order at Yang Chow is Today! 🍽️`,
        introPhrase: `is scheduled for <strong>today at ${formattedTime}</strong>!`,
      }
    }
  } else if (diffDays === 1) {
    return {
      subject: `Reminder: Your ${orderTypeLabel} Order at Yang Chow is Tomorrow! 🍽️`,
      introPhrase: `is scheduled for <strong>tomorrow (${formattedDate}) at ${formattedTime}</strong>!`,
    }
  } else {
    return {
      subject: `Reminder: Your Upcoming ${orderTypeLabel} Order at Yang Chow (${formattedDate}) 🍽️`,
      introPhrase: `is scheduled for <strong>${formattedDate} at ${formattedTime} (in ${diffDays} days)</strong>!`,
    }
  }
}

// ================================================================
// HTML EMAIL TEMPLATES
// ================================================================

function buildEventReminderHtml(
  customerName: string,
  eventType: string,
  formattedDate: string,
  formattedTime: string,
  guests: number,
  introPhrase: string,
): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reservation Reminder</title>
</head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background-color: #f8f9fa;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #E81E0D 0%, #C41810 100%); padding: 30px; border-radius: 16px 16px 0 0; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: 0.5px;">Yang Chow Pagsanjan</h1>
      <p style="color: rgba(255,255,255,0.85); margin: 8px 0 0 0; font-size: 14px;">Reservation Reminder</p>
    </div>

    <!-- Body -->
    <div style="background-color: #ffffff; padding: 35px 30px; border-left: 1px solid #e8e8e8; border-right: 1px solid #e8e8e8;">
      
      <!-- Greeting -->
      <h2 style="color: #1a1a1a; margin: 0 0 8px 0; font-size: 20px;">Hello ${customerName}! 👋</h2>
      <p style="color: #555; line-height: 1.7; font-size: 15px; margin: 0 0 25px 0;">
        This is a friendly reminder that your <strong style="color: #E81E0D;">${eventType}</strong> at Yang Chow Pagsanjan ${introPhrase}
      </p>

      <!-- Event Details Card -->
      <div style="background: linear-gradient(135deg, #FFF5F5 0%, #FFF0F0 100%); border: 1px solid #FFD7D5; border-radius: 12px; padding: 25px; margin: 20px 0;">
        <h3 style="color: #E81E0D; margin: 0 0 18px 0; font-size: 16px; text-transform: uppercase; letter-spacing: 1px;">📋 Reservation Details</h3>
        
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px; width: 140px;">Event Type</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">${eventType}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Date</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">📅 ${formattedDate}</td>
          </tr>
          ${formattedTime ? `
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Start Time</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">🕐 ${formattedTime}</td>
          </tr>` : ''}
          ${guests > 0 ? `
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Number of Guests</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">👥 ${guests} guests</td>
          </tr>` : ''}
        </table>
      </div>

      <!-- Preparation Tips -->
      <div style="background-color: #F0FFF4; border: 1px solid #C6F6D5; border-radius: 12px; padding: 20px; margin: 20px 0;">
        <h3 style="color: #276749; margin: 0 0 12px 0; font-size: 15px;">💡 Preparation Tips</h3>
        <ul style="color: #555; line-height: 1.8; font-size: 14px; margin: 0; padding-left: 20px;">
          <li>Please arrive <strong>30 minutes early</strong> to ensure a smooth start</li>
          <li>If you need to adjust your reservation, apply for <strong>Reschedule</strong> in application in your reservation. Just make sure it is <strong>4 days ahead</strong> of the current date.</li>
          <li>Inform us of any dietary restrictions or special requests ahead of time</li>
        </ul>
      </div>

      <!-- CTA -->
      <p style="color: #555; line-height: 1.7; font-size: 14px; margin: 25px 0 10px 0;">
        If you have any questions or need to make changes, don't hesitate to reach out to us. We look forward to making your <strong>${eventType}</strong> a memorable experience!
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 25px 30px; border-radius: 0 0 16px 16px; border: 1px solid #e8e8e8; border-top: 2px solid #E81E0D; text-align: center;">
      <p style="color: #E81E0D; font-weight: 700; font-size: 15px; margin: 0 0 8px 0;">Yang Chow Pagsanjan</p>
      <p style="color: #999; font-size: 12px; margin: 0 0 4px 0;">Thank you for choosing us for your special occasion!</p>
      <p style="color: #bbb; font-size: 11px; margin: 8px 0 0 0;">This is an automated reminder. Please do not reply to this email.</p>
    </div>

  </div>
</body>
</html>
  `.trim()
}

function buildAdvanceOrderReminderHtml(
  customerName: string,
  orderType: string,
  formattedDate: string,
  formattedTime: string,
  guests: number,
  introPhrase: string,
): string {
  const orderTypeEmoji = orderType.toLowerCase().includes('dine') ? '🍽️' : '📦'
  const orderTypeLabel = orderType.toLowerCase().includes('dine') ? 'Dine-in' : 'Pick-up'

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Order Reminder</title>
</head>
<body style="font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 0; background-color: #f8f9fa;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #E81E0D 0%, #C41810 100%); padding: 30px; border-radius: 16px 16px 0 0; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: 0.5px;">Yang Chow Pagsanjan</h1>
      <p style="color: rgba(255,255,255,0.85); margin: 8px 0 0 0; font-size: 14px;">Advance Order Reminder</p>
    </div>

    <!-- Body -->
    <div style="background-color: #ffffff; padding: 35px 30px; border-left: 1px solid #e8e8e8; border-right: 1px solid #e8e8e8;">
      
      <!-- Greeting -->
      <h2 style="color: #1a1a1a; margin: 0 0 8px 0; font-size: 20px;">Hello ${customerName}! 👋</h2>
      <p style="color: #555; line-height: 1.7; font-size: 15px; margin: 0 0 25px 0;">
        Just a heads up! Your <strong style="color: #E81E0D;">${orderTypeLabel}</strong> order at Yang Chow Pagsanjan ${introPhrase} ${orderTypeEmoji}
      </p>

      <!-- Order Details Card -->
      <div style="background: linear-gradient(135deg, #FFF5F5 0%, #FFF0F0 100%); border: 1px solid #FFD7D5; border-radius: 12px; padding: 25px; margin: 20px 0;">
        <h3 style="color: #E81E0D; margin: 0 0 18px 0; font-size: 16px; text-transform: uppercase; letter-spacing: 1px;">📋 Order Details</h3>
        
        <table style="width: 100%; border-collapse: collapse;">
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px; width: 140px;">Order Type</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">${orderTypeEmoji} ${orderTypeLabel}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Date</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">📅 ${formattedDate}</td>
          </tr>
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Time</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">🕐 ${formattedTime}</td>
          </tr>
          ${guests > 0 ? `
          <tr>
            <td style="padding: 8px 0; color: #777; font-size: 14px;">Guests</td>
            <td style="padding: 8px 0; color: #1a1a1a; font-size: 14px; font-weight: 600;">👥 ${guests} guests</td>
          </tr>` : ''}
        </table>
      </div>

      <!-- Important Notice -->
      <div style="background-color: #FFFBEB; border: 1px solid #FDE68A; border-radius: 12px; padding: 20px; margin: 20px 0;">
        <h3 style="color: #92400E; margin: 0 0 12px 0; font-size: 15px;">⏰ Important Reminder</h3>
        <ul style="color: #555; line-height: 1.8; font-size: 14px; margin: 0; padding-left: 20px;">
          ${orderType.toLowerCase().includes('dine') ? `
          <li>Please arrive <strong>on time</strong> at your scheduled time slot</li>
          <li>Your table and food will be prepared for your arrival</li>
          ` : `
          <li>Your order will be ready for <strong>pick-up at ${formattedTime}</strong></li>
          <li>Please bring a valid ID or your order reference for verification</li>
          `}
          <li>Contact us immediately if you need to reschedule or cancel</li>
        </ul>
      </div>

      <!-- CTA -->
      <p style="color: #555; line-height: 1.7; font-size: 14px; margin: 25px 0 10px 0;">
        We're preparing everything for your order. See you soon! 😊
      </p>
    </div>

    <!-- Footer -->
    <div style="background-color: #f8f9fa; padding: 25px 30px; border-radius: 0 0 16px 16px; border: 1px solid #e8e8e8; border-top: 2px solid #E81E0D; text-align: center;">
      <p style="color: #E81E0D; font-weight: 700; font-size: 15px; margin: 0 0 8px 0;">Yang Chow Pagsanjan</p>
      <p style="color: #999; font-size: 12px; margin: 0 0 4px 0;">Thank you for choosing Yang Chow!</p>
      <p style="color: #bbb; font-size: 11px; margin: 8px 0 0 0;">This is an automated reminder. Please do not reply to this email.</p>
    </div>

  </div>
</body>
</html>
  `.trim()
}
