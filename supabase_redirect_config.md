# Supabase Redirect URL Configuration for Password Reset

## Problem:
Email reset link needs proper redirect URL to work with your app

## Solution:

### Step 1: Update Supabase Authentication Settings
1. **Supabase Dashboard** -> **Authentication** -> **Settings**
2. **Site URL**: Set to `http://localhost:3000` (for local testing)
3. **Redirect URLs**: Add these EXACT URLs:

#### Required Redirect URLs:
```
http://localhost:3000/*
http://localhost:3000/#/*
http://localhost:3000/auth/callback
http://localhost:3000/#/auth/callback
http://localhost:3000/reset-password
http://localhost:3000/#/reset-password
```

#### For Production (when ready):
```
https://your-domain.com/*
https://your-domain.com/#/*
https://your-domain.com/auth/callback
https://your-domain.com/#/auth/callback
https://your-domain.com/reset-password
https://your-domain.com/#/reset-password
```

### Step 2: Update Email Template with Redirect
In the email template, the {{ .ConfirmationURL }} should redirect to your app:

```html
<!-- This should work with proper redirect URLs -->
<a href="{{ .ConfirmationURL }}">Reset Password</a>
```

### Step 3: Test the Redirect Flow

#### Method 1: Direct URL Test
1. **Open browser**: `http://localhost:3000/#/reset-password`
2. **Should show**: Password reset page
3. **Working**: App handles the route correctly

#### Method 2: Email Link Test
1. **Send reset email** from `/forgot-password`
2. **Click link** in email
3. **Should redirect** to `http://localhost:3000/#/reset-password`
4. **Should show**: Password reset form

### Step 4: Common Redirect Issues

#### Issue 1: "Refuses to connect"
**Fix**: Add wildcard redirect `http://localhost:3000/*`

#### Issue 2: Goes to wrong page
**Fix**: Check if `/reset-password` route exists in main.dart

#### Issue 3: Shows 404 error
**Fix**: Ensure app is running on port 3000

#### Issue 4: Link expires immediately
**Fix**: Check if redirect URLs match exactly

### Step 5: Verify Configuration
1. **Check Supabase settings** for redirect URLs
2. **Check main.dart** for `/reset-password` route
3. **Check app** is running on correct port
4. **Test email** contains correct link format

### Step 6: Debug Redirect
Check browser console for:
- URL being accessed
- Any redirect errors
- Network requests to Supabase

### Expected Flow:
1. **User clicks** reset link in email
2. **Browser redirects** to `http://localhost:3000/#/reset-password`
3. **App handles** the route
4. **Password reset page** appears
5. **User enters** new password
6. **Password updated** successfully

### Quick Test:
```bash
flutter run
# Test 1: Direct access
http://localhost:3000/#/reset-password

# Test 2: Email flow
# Go to /forgot-password -> Send email -> Click link
```

## Critical Points:
- Redirect URLs must match exactly
- App must be running when clicking link
- Route `/reset-password` must exist in main.dart
- Email template must use {{ .ConfirmationURL }}
