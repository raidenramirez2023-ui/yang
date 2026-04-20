# Email Verification Setup Guide

This guide will help you set up the email verification system for customer registration using SendGrid and Supabase Edge Functions.

## Overview

The email verification system allows customers to verify their email address before registration by:
1. User enters their email address in the registration form
2. User clicks the "Verify" button
3. A modal appears showing "Loading" and "Waiting for verification"
4. A magic link is sent to the user's email via SendGrid
5. User clicks the magic link in their email
6. The app redirects back to the registration page
7. The modal updates to show "Verified Email Address"

## Prerequisites

- SendGrid account with API key
- Supabase project with Edge Functions enabled
- Your `email_verifications` table in Supabase database

## Step 1: Configure SendGrid Environment Variables

### 1.1 Get Your SendGrid API Key

1. Log in to your [SendGrid account](https://app.sendgrid.com/)
2. Navigate to Settings > API Keys
3. Click "Create API Key"
4. Give it a name (e.g., "Yang Chow Email Verification")
5. Select permissions: "Mail Send" > "Full Access"
6. Copy the generated API key

### 1.2 Set Environment Variables in Supabase

You need to add the following environment variables to your Supabase Edge Functions:

**Via Supabase Dashboard:**
1. Go to your Supabase project dashboard
2. Navigate to Edge Functions > Settings
3. Add the following environment variables:

```
SENDGRID_API_KEY=your_sendgrid_api_key_here
SENDER_EMAIL=chowyang783@gmail.com
SENDER_NAME=Yang Chow Restaurant
```

**Via CLI (if using Supabase CLI):**
```bash
supabase secrets set SENDGRID_API_KEY=your_sendgrid_api_key_here
supabase secrets set SENDER_EMAIL=chowyang783@gmail.com
supabase secrets set SENDER_NAME=Yang Chow Restaurant
```

## Step 2: Deploy the Supabase Edge Function

### 2.1 Using Supabase CLI

1. Install the Supabase CLI if you haven't already:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link to your project:
```bash
supabase link --project-ref your-project-ref
```

4. Deploy the Edge Function:
```bash
supabase functions deploy send-verification-email
```

### 2.2 Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to Edge Functions
3. Click "New Function"
4. Name it: `send-verification-email`
5. Copy the contents from `supabase/functions/send-verification-email/index.ts`
6. Paste it into the function editor
7. Click "Deploy"

## Step 3: Install Flutter Dependencies

Run the following command to install the required dependencies:

```bash
flutter pub get
```

This will install:
- `uuid` - for generating unique verification tokens
- `app_links` - already in your pubspec.yaml for deep linking

## Step 4: Deep Link Configuration

The deep linking is already configured in your project:

### Android
- Deep link scheme: `yangchow`
- Configured in: `android/app/src/main/AndroidManifest.xml`
- Already includes the `yangchow` scheme intent filter

### iOS
- Deep link scheme: `yangchow`
- Configured in: `ios/Runner/Info.plist`
- Already includes the `yangchow` URL scheme

No additional configuration needed!

## Step 5: Test the Email Verification

### 5.1 Test in Development

1. Run your Flutter app:
```bash
flutter run
```

2. Navigate to the Customer Registration page

3. Enter an email address

4. Click the "Verify" button

5. A modal should appear showing "Loading" and "Waiting for verification"

6. Check your email inbox for the verification email

7. Click the "Verify Email" button in the email

8. The app should redirect back to the registration page

9. The modal should update to show "Verified Email Address"

10. A green checkmark should appear next to the email field

### 5.2 Verify Database Records

Check your `email_verifications` table in Supabase:
- A new record should be created when the verification email is sent
- The record should contain:
  - `email`: The user's email address
  - `verification_code`: The unique token
  - `created_at`: Timestamp when created
  - `expires_at`: 24 hours after creation
  - `is_used`: false initially, true after verification
  - `verified`: false initially, true after verification
  - `verified_at`: Timestamp when verified (null until verified)

## Step 6: Troubleshooting

### Email not being sent

1. Check Supabase Edge Function logs for errors
2. Verify your SendGrid API key is correct
3. Check SendGrid dashboard for email delivery status
4. Ensure the sender email is verified in SendGrid

### Deep link not working

1. Ensure you're testing on a real device (not simulator)
2. For Android: Make sure the app is installed
3. For iOS: Make sure Associated Domains are configured if using universal links
4. Check that the deep link scheme matches in both the email and app configuration

### Verification token invalid/expired

1. Check the `expires_at` timestamp in the database
2. Tokens expire after 24 hours
3. Generate a new verification email if expired

### TypeScript errors in Edge Function

The TypeScript errors shown in your IDE are normal because:
- The IDE doesn't have Deno type definitions
- Edge Functions run in the Deno runtime
- These errors won't affect deployment to Supabase

## Step 7: Production Considerations

### SendGrid Sender Authentication

1. In SendGrid, verify your sender email domain
2. Set up SPF, DKIM, and DMARC records
3. This improves email deliverability and prevents spam classification

### Rate Limiting

Consider adding rate limiting to prevent abuse:
- Limit verification emails per email address per hour
- Limit verification emails per IP address
- Implement CAPTCHA if needed

### Security

- Never commit your SendGrid API key to version control
- Rotate API keys regularly
- Use environment variables for all sensitive data
- Implement proper Row-Level Security (RLS) on the `email_verifications` table

## Files Modified/Created

### Created Files:
- `lib/services/email_verification_service.dart` - Email verification logic
- `supabase/functions/send-verification-email/index.ts` - Edge Function for sending emails
- `EMAIL_VERIFICATION_SETUP_GUIDE.md` - This guide

### Modified Files:
- `lib/pages/customer/customer_registration_page.dart` - Added verification UI and logic
- `pubspec.yaml` - Added uuid dependency

### Already Configured (No Changes Needed):
- `android/app/src/main/AndroidManifest.xml` - Deep linking for Android
- `ios/Runner/Info.plist` - Deep linking for iOS

## Summary

The email verification system is now fully implemented with:
- ✅ Verify button in registration form
- ✅ Loading modal with "Waiting for verification"
- ✅ Magic link email sent via SendGrid
- ✅ Deep link redirect handling
- ✅ Email verification status display
- ✅ Database tracking of verifications
- ✅ 24-hour token expiration

Users cannot register without verifying their email address first, ensuring only valid email addresses are used for account creation.
