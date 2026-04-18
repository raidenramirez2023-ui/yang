# OTP Template with {{ .Token }} - Complete Fix

## The Problem:
Supabase needs {{ .Token }} to send OTP codes. Without it, no code will be generated.

## Complete Template Fix:

### Step 1: Update Supabase Email Template
1. **Supabase Dashboard** -> **Authentication** -> **Email Templates**
2. **"Reset password"** template
3. **DELETE ALL CONTENT**
4. **Paste this EXACT content**:

**Subject:**
```
Password Reset Code - Yang Chow Restaurant
```

**HTML Body:**
```html
<h2>Password Reset Code</h2>
<p>Hello,</p>
<p>You have requested to reset your password for your account at Yang Chow Restaurant.</p>
<p>Your 6-digit verification code is:</p>
<div style="background-color: #f0f0f0; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
  <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #E81E0D;">{{ .Token }}</span>
</div>
<p>This code will expire in 10 minutes.</p>
<p><strong>How to use:</strong></p>
<ol>
  <li>Open the Yang Chow Restaurant app</li>
  <li>Enter this 6-digit code in the verification field</li>
  <li>Set your new password</li>
</ol>
<p>If you did not request a password reset, please ignore this email.</p>
<p>Thank you!<br>Yang Chow Restaurant Team</p>
<hr>
<p style="color: #666; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
```

## Why {{ .Token }} is Critical:

### What {{ .Token }} Does:
- **Generates 6-digit code** automatically
- **Sends unique code** to user's email
- **Allows OTP verification** in your app
- **Expires after set time** (10 minutes)

### Without {{ .Token }}:
- No code generated
- No email sent
- OTP system fails

### With {{ .Token }}:
- 6-digit code generated
- Email sent with code
- OTP verification works
- Password reset successful

## Step 2: Test the Complete Flow

### Test 1: Send Code
1. **Go to**: `/forgot-password`
2. **Enter email**: Your Gmail address
3. **Click "Send Reset Email"**
4. **Check Gmail**: Should show 6-digit code

### Test 2: Verify Code
1. **Copy 6-digit code** from email
2. **Go to OTP page** (automatic)
3. **Enter code** in verification field
4. **Click "Verify Code"**

### Test 3: Reset Password
1. **Enter new password**
2. **Confirm password**
3. **Click "Reset Password"**
4. **Success!** Login with new password

## Expected Email Result:
- **Subject**: "Password Reset Code - Yang Chow Restaurant"
- **6-digit code**: Large, red, bold text
- **Instructions**: How to use the code
- **No reset links**: Only code-based reset

## Critical Points:
- {{ .Token }} is REQUIRED for OTP
- Delete ALL old content first
- Use EXACT template provided
- Wait 2 minutes after saving
- Test complete flow

## Troubleshooting:
If still no code:
1. Check if {{ .Token }} is present
2. Verify template was saved
3. Check email service (SendGrid)
4. Try different email address
