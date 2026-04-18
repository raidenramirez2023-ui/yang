# Fix Supabase Redirect URLs for Password Reset

## Problem:
Email reset link "refuses to connect" - doesn't open password reset page

## Solution:

### Step 1: Update Supabase Authentication Settings
1. **Supabase Dashboard** -> **Authentication** -> **Settings**
2. **Site URL**: Set to `http://localhost:3000` (for local testing)
3. **Redirect URLs**: Add these URLs:
   - `http://localhost:3000/*`
   - `http://localhost:3000/#/*`
   - `http://localhost:3000/reset-password`
   - `http://localhost:3000/#/reset-password`
   - `http://localhost:3000/auth/callback`
   - `io.supabase.flutter://reset-callback/*`

### Step 2: Update Email Template Redirect
In the email template, make sure the link format works:
```html
<!-- Use this format in email template -->
<a href="{{ .ConfirmationURL }}">Reset Password</a>
```

### Step 3: Test the Complete Flow

#### Method 1: Direct URL Test
1. **Open browser**: `http://localhost:3000/#/reset-password`
2. **Should show**: Password reset form
3. **Test**: Enter password + confirm

#### Method 2: Email Link Test
1. **Go to**: `/forgot-password`
2. **Enter email**: Your email address
3. **Send reset email**
4. **Check email**: Click reset link
5. **Should open**: Password reset page

#### Method 3: Debug Test
1. **Run app**: `flutter run`
2. **Check console**: Look for debug messages
3. **Test link**: See what URL is generated

### Step 4: Common Issues & Fixes

#### Issue 1: "Refuses to connect"
**Fix**: Add wildcard redirect URL `http://localhost:3000/*`

#### Issue 2: Goes to landing page
**Fix**: Check if app is running on correct port (3000)

#### Issue 3: Shows 404 error
**Fix**: Ensure `/reset-password` route exists in main.dart

#### Issue 4: Link expires immediately
**Fix**: Check email template - don't modify the {{ .ConfirmationURL }}

### Step 5: Expected Behavior
1. **Email sends** with reset link
2. **Click link** opens password reset page
3. **Page shows**: "Reset Your Password" form
4. **Enter password** + confirm
5. **Click "Reset Password"**
6. **Success message** appears
7. **Redirect to login**

### Step 6: Debug Information
Check browser console for:
- URL being accessed
- Any JavaScript errors
- Network requests

### Quick Test Commands:
```bash
# Test direct access
flutter run
# Open: http://localhost:3000/#/reset-password

# Test email flow
# Go to: http://localhost:3000/#/forgot-password
# Send test email
# Click link in email
```

## Expected Result:
- Email link works
- Password reset page opens
- No 8-digit code required
- Direct password reset works
