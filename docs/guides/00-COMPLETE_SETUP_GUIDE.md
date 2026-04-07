# Yang Chow Restaurant System - Complete Setup Guide

This comprehensive guide walks you through everything needed to get Yang Chow running from scratch.

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Clone & Install](#step-1-clone--install)
4. [Step 2: Supabase Setup](#step-2-supabase-setup)
5. [Step 3: Database Configuration](#step-3-database-configuration)
6. [Step 4: Authentication Setup](#step-4-authentication-setup)
7. [Step 5: Payment Integration](#step-5-payment-integration)
8. [Step 6: Running the Application](#step-6-running-the-application)
9. [Troubleshooting](#troubleshooting)

---

## Project Overview

Yang Chow is a comprehensive restaurant management system built with Flutter and Supabase, featuring:

- **Customer Module**: Reservations, payments, reviews, chat support
- **Staff Module**: Order management, kitchen display, inventory tracking
- **Admin Module**: Dashboard, analytics, user management, announcements
- **Payment Integration**: PayMongo for secure card and e-wallet payments
- **Real-Time Features**: Live order updates, chat system, inventory tracking

### Project Structure

```
yang_chow/
├── lib/
│   ├── pages/
│   │   ├── admin/              # Admin dashboard pages
│   │   ├── staff/              # Staff operations pages
│   │   ├── customer/           # Customer-facing pages
│   │   └── *.dart              # Shared auth pages (login, forgot_password, etc.)
│   ├── services/               # Business logic & API integration
│   ├── widgets/                # Reusable UI components
│   ├── utils/                  # Helper functions & constants
│   ├── models/                 # Data models
│   └── main.dart               # App entry point
├── android/                    # Android platform code
├── ios/                        # iOS platform code
├── web/                        # Web platform code
├── docs/guides/                # Setup and integration guides
└── pubspec.yaml                # Flutter dependencies
```

---

## Prerequisites

Before starting, ensure you have:

- **Flutter**: Version 3.10+ ([Install](https://flutter.dev/docs/get-started/install))
- **Git**: For cloning the repository
- **Supabase Account**: Free tier at [supabase.com](https://supabase.com)
- **Google Cloud Account**: For Google Sign-In (optional, can be skipped initially)
- **PayMongo Account**: For payment processing (optional, can be skipped initially)
- **IDE**: VS Code, Android Studio, or IntelliJ IDEA

### Verify Installation

```bash
# Check Flutter version
flutter --version

# Check Dart version
dart --version

# Get Flutter doctor report
flutter doctor
```

---

## Step 1: Clone & Install

### 1.1 Clone the Repository

```bash
cd ~/Projects
git clone https://github.com/your-org/yang-chow.git
cd yang-chow
```

### 1.2 Install Flutter Dependencies

```bash
# Get all Dart/Flutter packages
flutter pub get

# (Optional) Upgrade to latest compatible versions
flutter pub upgrade
```

### 1.3 Verify Build

```bash
# Analyze the project for errors
flutter analyze

# This should show: "No issues found!" or only pre-existing warnings
```

---

## Step 2: Supabase Setup

### 2.1 Create a Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Click **New Project**
3. Fill in project details:
   - **Project Name**: `yang-chow`
   - **Database Password**: Generate secure password (save it!)
   - **Region**: Select region closest to your users
4. Click **Create new project** and wait 2-3 minutes for setup

### 2.2 Get Connection Details

1. Go to **Project Settings** → **Database**
2. Note these credentials (you'll need them):
   - `Host`: `db.xxxxx.supabase.co`
   - `Port`: `5432`
   - `Database`: `postgres`
   - `User`: `postgres`
   - `Password`: (the one you created above)

### 2.3 Get Supabase API Keys

1. Go to **Project Settings** → **API**
2. Under **Project API Keys**, find:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon key**: (public key for client)
   - **service_role key**: (secret key for server operations)

### 2.4 Update Flutter App Configuration

Edit `lib/main.dart` and update the Supabase initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_URL.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );

  runApp(const MyApp());
}
```

**Where to find these values:**
- Go to Supabase Dashboard
- Click your project
- Settings → API
- Copy `Project URL` and `anon key`

---

## Step 3: Database Configuration

### 3.1 Deploy Database Schema

The database schema creates all necessary tables and configurations.

**File Location**: `reservations_enhancements.sql` (in project root)

#### Method A: Using Supabase Dashboard (Recommended)

1. Open [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Click **SQL Editor** (left sidebar)
4. Click **New Query**
5. Open `reservations_enhancements.sql` in your editor
6. Copy the entire content
7. Paste into the SQL Editor
8. Click **Run** (⚡ button)
9. Wait for success message

#### Method B: Using CLI

```bash
# If you have Supabase CLI
supabase db push

# Or using psql directly
psql postgresql://postgres:PASSWORD@db.xxxxx.supabase.co:5432/postgres < reservations_enhancements.sql
```

### 3.2 Verify Database Setup

Run these queries in Supabase SQL Editor to verify:

```sql
-- Check all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Should include: users, reservations, reviews, cancellation_requests, 
-- email_logs, app_settings, orders, chat_messages, announcements, etc.

-- Check app_settings configuration
SELECT setting_key, setting_value FROM app_settings 
ORDER BY setting_key;

-- Should show 13+ rows with default values
```

### 3.3 Enable Row-Level Security (RLS)

RLS policies protect data from unauthorized access:

1. Go to **Authentication** → **Policies** in Supabase
2. For each table (`reviews`, `chat_messages`, `orders`, etc.):
   - Click the table name
   - Ensure **Enable RLS** is toggled ON
   - Verify policies are created (should happen automatically from SQL)

---

## Step 4: Authentication Setup

### 4.1 Enable Email/Password Authentication

1. Go to Supabase Dashboard
2. Click **Authentication** (left sidebar)
3. Go to **Providers** tab
4. Enable **Email** provider
5. Configure email settings:
   - Enable **Confirm email** (recommended)
   - Set SMTP settings for custom domain (optional)

### 4.2 Google Sign-In Setup (Optional but Recommended)

Follow the detailed guide: `docs/guides/GOOGLE_SIGNIN_SETUP.md`

**Quick Summary:**
1. Create OAuth app in [Google Cloud Console](https://console.cloud.google.com)
2. Get Client ID and Client Secret
3. Add to Supabase → Authentication → Providers → Google
4. Update client ID in `lib/pages/customer/customer_registration_page.dart`

### 4.3 Set Up Email Templates (Optional)

1. Go to **Authentication** → **Email Templates**
2. Customize templates for:
   - Confirmation emails
   - Password reset emails
   - Change email notifications

---

## Step 5: Payment Integration

### 5.1 PayMongo Account Setup

1. Create account at [PayMongo Dashboard](https://dashboard.paymongo.com)
2. Complete verification process
3. Get API keys from **Settings** → **Developers** → **API Keys**

### 5.2 Configure Environment Variables

Create `.env` file in project root:

```env
# Copy from PayMongo Settings > API Keys
PAYMONGO_PUBLIC_KEY=pk_test_xxxxxxxxx
PAYMONGO_SECRET_KEY=sk_test_xxxxxxxxx
```

**WARNING**: Never commit `.env` file to version control. Add to `.gitignore`:

```
.env
.env.local
```

### 5.3 Update PayMongo Service

Edit `lib/services/paymongo_service.dart` to load keys from environment:

```dart
// Already configured to use environment variables
// See lib/main.dart for dotenv initialization
```

### 5.4 Configure Deep Links for Payment

Payment callbacks need to redirect back to the app. Already configured in:
- `android/app/src/main/AndroidManifest.xml` - `yangchow://` scheme
- `ios/Runner/Info.plist` - URL schemes

### 5.5 Test Payment Integration

Use PayMongo test cards:

| Card Type | Number | Expiry | CVC | Result |
|-----------|---------|---------|-----|---------|
| Visa | 4343434343434343 | 12/25 | 123 | ✅ Success |
| Mastercard | 5555555555554444 | 12/25 | 123 | ✅ Success |
| Visa | 4000000000000002 | 12/25 | 123 | ❌ Declined |

See full guide: `docs/guides/test_payment_guide.md`

---

## Step 6: Running the Application

### 6.1 Web (Recommended for Initial Testing)

```bash
# Run on Chrome (fastest for development)
flutter run -d chrome

# Or specify device
flutter run -d web-server
```

**Default URL**: http://localhost:45835

### 6.2 Android

```bash
# List available devices
flutter devices

# Run on specific device/emulator
flutter run -d <device-id>

# Or build APK
flutter build apk --release
```

### 6.3 iOS

```bash
# Requires Mac with Xcode
flutter run -d ios

# Or build iOS app
flutter build ios --release
```

### 6.4 First Run Setup

1. **Create Staff/Admin Account**:
   ```sql
   -- Run in Supabase SQL Editor
   INSERT INTO users (email, role, full_name, status, approved)
   VALUES ('admin@yangchow.com', 'admin', 'Admin User', 'active', true);
   ```

2. **Test Login Flow**:
   - Go to Login page
   - Use a test email (or Google Sign-In)
   - Create account or login
   - Verify redirect to correct dashboard

3. **Test Each Role**:
   - **Customer**: Reservations, payments, chat
   - **Staff**: Order management, inventory
   - **Chef**: Kitchen display system
   - **Admin**: Dashboard, user management, reports

---

## Troubleshooting

### Common Issues & Solutions

#### 1. "MissingPluginException"

**Problem**: Plugin not found when running app

**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

#### 2. "Invalid authentication credentials"

**Problem**: Supabase connection failing

**Solution**:
- Verify Supabase URL and anon key in `main.dart`
- Check that Supabase project is running
- Verify network connectivity

#### 3. "Tables don't exist"

**Problem**: Database tables not found

**Solution**:
- Re-run `reservations_enhancements.sql` in Supabase
- Check for SQL errors in Supabase SQL Editor
- Verify you're in correct database (`postgres`)

#### 4. "Google Sign-In not working"

**Problem**: Google sign-in button shows error

**Solution**:
- Update Client ID in code
- Check Google Cloud Console credentials
- Verify URL scheme in Android/iOS config
- See: `docs/guides/GOOGLE_SIGNIN_SETUP.md`

#### 5. "Payment not processing"

**Problem**: PayMongo integration failing

**Solution**:
- Verify `.env` file has correct API keys
- Check API keys are not expired (rotate if needed)
- Test with PayMongo test cards
- Enable payment logging for debugging

#### 6. Flutter App Won't Build

**Problem**: Build errors or compilation failures

**Solution**:
```bash
# Full clean rebuild
flutter clean
flutter pub get
flutter pub upgrade flutter_test --pre
flutter analyze

# Then try again
flutter run
```

### Getting Help

1. **Check Flutter Logs**:
   ```bash
   flutter run -v  # Verbose output
   ```

2. **Check Supabase Logs**:
   - Supabase Dashboard → Logs
   - Check for database errors or auth issues

3. **Read Guides**:
   - `docs/guides/GOOGLE_SIGNIN_SETUP.md` - For auth issues
   - `docs/guides/PAYMONGO_SETUP_GUIDE.md` - For payment issues
   - `docs/guides/test_payment_guide.md` - For testing

4. **Check Project Status**:
   ```bash
   flutter doctor
   flutter doctor -v
   ```

---

## Security Checklist

Before deploying to production:

- [ ] Update Supabase URL and keys from environment variables (not hardcoded)
- [ ] Enable HTTPS for all external API calls
- [ ] Switch PayMongo to live keys
- [ ] Enable RLS policies on all sensitive tables
- [ ] Set up rate limiting on API endpoints
- [ ] Configure CORS properly in Supabase
- [ ] Use strong database passwords
- [ ] Rotate API keys regularly
- [ ] Set up monitoring and alerts
- [ ] Enable backups in Supabase

---

## Performance Optimization

### For Better Performance

1. **Enable LazyLoad for Large Lists**:
   ```dart
   ListView.builder(
     cacheExtent: 1000,
     addAutomaticKeepAlives: true,
   )
   ```

2. **Optimize Images**:
   - Store in Firebase Storage or Supabase
   - Use cached_network_image package

3. **Use Real-Time Streams Wisely**:
   - Only listen when needed
   - Unsubscribe when not in use

4. **Database Indexing**:
   ```sql
   CREATE INDEX idx_user_email ON users(email);
   CREATE INDEX idx_reservation_date ON reservations(date);
   ```

---

## Next Steps

1. ✅ Complete all setup steps above
2. ✅ Run the app and test each role
3. ✅ Create test data (reservations, orders)
4. ✅ Test payment flow with test cards
5. ✅ Review `PROJECT_ORGANIZATION.md` for code structure
6. ✅ Share app with beta testers
7. ✅ Gather feedback and iterate
8. ✅ Deploy to production when ready

---

## Support & Documentation

- **Flutter Docs**: https://flutter.dev/docs
- **Supabase Docs**: https://supabase.com/docs
- **PayMongo API**: https://developers.paymongo.com/
- **Google Cloud**: https://cloud.google.com/docs

---

**Last Updated**: April 7, 2026  
**Version**: 1.0  
**Status**: ✅ Complete
