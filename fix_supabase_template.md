# Fix Supabase Email Template - Remove 8-Digit Code

## Current Problem:
Email still shows 8-digit code instead of direct reset link

## Solution:

### Step 1: Go to Supabase Dashboard
1. Login to [supabase.com](https://supabase.com)
2. Select your Yang Chow project
3. Go to **Authentication** → **Email Templates**

### Step 2: Update "Reset password" Template

#### Click on "Reset password" template
- Delete ALL existing content
- Replace with this EXACT content:

**Subject:**
```
Reset Your Password - Yang Chow Restaurant
```

**HTML Body:**
```html
<h2>Reset Your Password</h2>
<p>Hello,</p>
<p>You have requested to reset your password for your account at Yang Chow Restaurant.</p>
<p>Please click the link below to reset your password:</p>
<p><a href="{{ .ConfirmationURL }}" style="background-color: #E81E0D; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Reset Password</a></p>
<p>Or copy and paste this link in your browser:</p>
<p>{{ .ConfirmationURL }}</p>
<p>If you did not request a password reset, please ignore this email.</p>
<p>Thank you!<br>Yang Chow Restaurant Team</p>
<hr>
<p style="color: #666; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
```

### Step 3: CRITICAL - Remove OTP References
Make sure the template does NOT contain:
- ❌ `{{ .Token }}`
- ❌ "8-digit code"
- ❌ "verification code"
- ❌ "OTP"

### Step 4: Test the Template
1. Save the template
2. Go to your app: `/forgot-password`
3. Enter your email
4. Click "Send Reset Email"
5. Check your Gmail

## Expected Result:
✅ Email should show:
- Red "Reset Password" button
- Direct reset link (no code)
- Yang Chow Restaurant branding

❌ Email should NOT show:
- 8-digit code
- OTP field
- Verification code

## Why This Happens:
Supabase sometimes keeps old template cache. You need to:
1. **Delete old content completely**
2. **Paste new content**
3. **Save template**
4. **Wait 1-2 minutes** for cache to clear
5. **Test again**

## Alternative: Use Different Template
If still shows 8-digit code:
1. **Delete the entire template**
2. **Create new template** with different name
3. **Update settings** to use new template

## Quick Test:
After updating template, test immediately:
```
1. Go to /forgot-password
2. Enter email
3. Send reset email
4. Check Gmail content
5. Verify no 8-digit code appears
```
