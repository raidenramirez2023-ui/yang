# OTP Email Template for Password Reset

## Email Template Configuration:

### Step 1: Update Supabase Email Template
1. **Supabase Dashboard** -> **Authentication** -> **Email Templates**
2. **Select "Reset password"**
3. **Update with this content**:

**Subject:**
```
Reset Your Password - Yang Chow Restaurant
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
<p>If you did not request a password reset, please ignore this email.</p>
<p>Thank you!<br>Yang Chow Restaurant Team</p>
<hr>
<p style="color: #666; font-size: 12px;">This is an automated message. Please do not reply to this email.</p>
```

## How It Works:

### Step 1: User Requests Reset
1. **Forgot Password** -> Enter email
2. **Send Code** -> Supabase sends 6-digit code
3. **Navigate** -> OTP verification page

### Step 2: User Enters Code
1. **Check Gmail** for 6-digit code
2. **Enter code** in app
3. **Verify** -> Code validation
4. **Set Password** -> Enter new password

### Step 3: Password Updated
1. **Success** -> Password reset complete
2. **Login** -> Use new password

## Expected Email Content:
- **Subject**: "Reset Your Password - Yang Chow Restaurant"
- **6-digit code**: Large, bold, red text
- **Expiration**: 10 minutes
- **Instructions**: Clear and simple

## Test the Complete Flow:
1. **Run app**: `flutter run`
2. **Go to**: `/forgot-password`
3. **Enter email**: Your Gmail address
4. **Send code** -> Check Gmail
5. **Enter 6-digit code** in app
6. **Set new password** -> Success!

## Features:
- 6-digit OTP code (not 8)
- Email verification
- Code expiration
- Resend code option
- Secure password reset
