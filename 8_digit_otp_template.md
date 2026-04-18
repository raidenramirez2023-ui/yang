# 8-Digit OTP Email Template

## Update Supabase Email Template for 8-Digit Code:

### Step 1: Update Template
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
<p>Your 8-digit verification code is:</p>
<div style="background-color: #f0f0f0; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
  <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #E81E0D;">{{ .Token }}</span>
</div>
<p>This code will expire in 10 minutes.</p>
<p><strong>How to use:</strong></p>
<ol>
  <li>Open the Yang Chow Restaurant app</li>
  <li>Enter this 8-digit code in the verification field</li>
  <li>Set your new password</li>
</ol>
<p>If you did not request a password reset, please ignore this email.</p>
<p>Thank you!<br>Yang Chow Restaurant Team</p>
<hr>
<p style="color: #666; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
```

## Key Changes for 8-Digit Code:

### Updated Text:
- **"8-digit verification code"** (not 6-digit)
- **"Enter this 8-digit code"** in instructions
- **Letter spacing adjusted** for 8 digits

### Visual Changes:
- **Letter spacing: 6px** (good for 8 digits)
- **Same large, bold, red text**
- **Clear centered display**

## Expected Email:
- **Subject**: "Password Reset Code - Yang Chow Restaurant"
- **8-digit code**: Large, red, bold text
- **Instructions**: How to use 8-digit code
- **No reset links**: Only code-based reset

## Test the 8-Digit Flow:
1. **Forgot Password** -> Enter email
2. **Send Code** -> Check Gmail
3. **8-digit code** appears in email
4. **Enter code** in app (8 digits required)
5. **Verify** -> Set new password
6. **Success** -> Login with new password

## Critical Points:
- {{ .Token }} generates 8-digit code automatically
- App validates for exactly 8 digits
- Email shows "8-digit" instructions
- No 6-digit references anywhere
