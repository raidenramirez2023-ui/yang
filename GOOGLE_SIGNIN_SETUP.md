# Google Sign-In Setup Instructions

## Overview
Your Yang Chow app now supports Google Sign-In for customer registration and login. This allows customers to create accounts and sign in using their Google account instead of manually creating credentials.

## What's Been Added

### 1. Dependencies
- `google_sign_in: ^6.2.0` added to `pubspec.yaml`

### 2. UI Components
- Google Sign-In button added to both login and registration pages
- Loading states and error handling implemented
- Clean "OR" divider between traditional and Google sign-in options

### 3. Authentication Logic
- Google OAuth integration with Supabase
- Automatic user creation in the `users` table
- Default role assignment as "customer" for Google users
- Seamless navigation to appropriate dashboard

## Required Setup Steps

### Step 1: Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials:
   - Application type: "Web application"
   - Add your app's redirect URI (for development: `http://localhost:3000`)
   - Note down your **Client ID** and **Client Secret**

### Step 2: Supabase Configuration
1. Go to your Supabase project dashboard
2. Navigate to **Authentication > Providers**
3. Enable **Google** provider
4. Enter your Google **Client ID** and **Client Secret**
5. Add your app's redirect URL to the allowed URLs
6. Save configuration

### Step 3: Update Client ID in Code
Replace the placeholder client ID in both files:
- `lib/pages/login_page.dart` (line 19)
- `lib/pages/customer_registration_page.dart` (line 22)

Change:
```dart
clientId: 'your-web-client-id.apps.googleusercontent.com',
```

To:
```dart
clientId: 'YOUR-ACTUAL-CLIENT-ID.apps.googleusercontent.com',
```

### Step 4: Platform-Specific Setup

#### For Android:
1. Add your SHA-1 fingerprint to Google Console
2. Update `android/app/build.gradle` with your Google sign-in configuration
3. Add Google Services JSON file to `android/app/`

#### For iOS:
1. Add your iOS bundle ID to Google Console
2. Update `ios/Runner/Info.plist` with URL scheme
3. Add Google Services plist file to `ios/Runner/`

#### For Web:
1. Add your web client ID to Google Console
2. Update `web/index.html` with Google Sign-In script

## How It Works

### Login Flow:
1. User clicks "Sign in with Google"
2. Google authentication popup opens
3. User authenticates with Google
4. App receives Google tokens
5. Supabase creates/updates user session
6. User is redirected to appropriate dashboard

### Registration Flow:
1. User clicks "Sign up with Google" on registration page
2. Same authentication process as login
3. If user doesn't exist in database, new customer record is created
4. User is automatically logged in and redirected to customer dashboard

## User Experience Benefits

✅ **Faster Registration**: No need to manually enter email/password  
✅ **Reduced Friction**: One-click sign-in process  
✅ **Secure Authentication**: Google's secure OAuth flow  
✅ **Profile Auto-fill**: Name and email automatically populated  
✅ **Consistent Experience**: Works across all platforms  

## Testing

1. Run `flutter pub get` to install new dependencies
2. Update the client ID placeholder
3. Test on your preferred platform (web recommended for initial testing)
4. Verify that Google users are created in your `users` table with "customer" role

## Troubleshooting

**Common Issues:**
- "Invalid client_id": Update the placeholder client ID
- "Redirect URI mismatch": Ensure your redirect URI is configured in Google Console
- "Network error": Check internet connection and API enablement
- "User not created": Verify Supabase Google provider is enabled

For detailed troubleshooting, check the debug logs in your console.

## Security Notes

- Google Sign-In users automatically get "customer" role
- Admin and staff roles still require manual account creation
- All authentication is handled through Supabase's secure OAuth flow
- No passwords are stored for Google users
