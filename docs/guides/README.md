# Yang Chow - Documentation Guides

This folder contains comprehensive guides for setting up, configuring, and deploying the Yang Chow Restaurant Management System.

## 📑 Guide Index

### **00-COMPLETE_SETUP_GUIDE.md** ⭐ START HERE
The complete end-to-end setup guide for getting Yang Chow running from scratch.

**Covers:**
- Project overview and structure
- Prerequisites and installation
- Supabase setup and configuration
- Database deployment
- Authentication setup (Email, Google Sign-In)
- Payment integration (PayMongo)
- Running the application on web/Android/iOS
- Troubleshooting common issues
- Security checklist

**Who should read this:** Everyone setting up Yang Chow for the first time.

**Time to complete:** ~45-60 minutes (depending on experience)

---

### **QUICK_START_DEPLOYMENT.md**
Quick reference for deploying database changes and customer improvements.

**Covers:**
- Database schema deployment using Supabase
- Verification of table creation
- Configuration of app settings
- Quick validation steps

**Who should read this:** Developers deploying database updates or migrating existing installations.

**Time to complete:** ~5-10 minutes

---

### **GOOGLE_SIGNIN_SETUP.md**
Complete guide for implementing Google Sign-In authentication.

**Covers:**
- Google Cloud Console setup
- OAuth 2.0 credentials creation
- Supabase configuration
- Client ID updates in code
- Platform-specific setup (Android, iOS, Web)
- Testing Google Sign-In

**Who should read this:** Implementing or troubleshooting Google authentication.

**Time to complete:** ~20-30 minutes

---

### **PAYMONGO_SETUP_GUIDE.md**
Complete guide for PayMongo payment integration.

**Covers:**
- PayMongo account creation
- API key management
- Environment variable configuration (security best practice)
- Database schema updates
- Deep linking configuration
- Test payment cards
- Webhook setup (optional)
- Troubleshooting

**Who should read this:** Setting up payment processing or testing payments.

**Time to complete:** ~30-45 minutes

---

### **test_payment_guide.md**
Testing guide for PayMongo integration.

**Covers:**
- Test payment card details
- Step-by-step testing procedure
- Deep link verification
- Common testing issues
- Production checklist

**Who should read this:** QA team or developers testing payment functionality.

**Time to complete:** ~10-15 minutes

---

### **paymongo_integration_complete.md**
Summary of completed PayMongo integration work.

**Covers:**
- Security fixes implemented
- UI improvements
- Deep link configuration
- Testing setup
- Files modified and created

**Who should read this:** Understanding what's been implemented and what's left to do.

**Time to complete:** ~5 minutes (reference doc)

---

### **generate_production_keystore.md**
Guide for creating production signing certificates for Android.

**Covers:**
- Generating production keystore
- Extracting SHA-1 fingerprint
- Updating build configuration
- Adding to Google Cloud Console
- Building signed APK for release

**Who should read this:** Building Android app for Google Play Store.

**Time to complete:** ~15-20 minutes

---

### **CUSTOMER_IMPROVEMENTS_IMPLEMENTATION.md**
Detailed documentation of customer-side improvements.

**Covers:**
- Database schema enhancements
- New services created (AppSettings, Reservation, EmailNotification)
- Review and rating system
- Reservation management (cancel, reschedule)
- Customer operation features
- Implementation status and completion percentage

**Who should read this:** Understanding the customer feature set or maintaining customer-related code.

**Time to complete:** ~15-20 minutes (reference doc)

---

## 🚀 Getting Started Checklist

- [ ] Read **00-COMPLETE_SETUP_GUIDE.md** from start to finish
- [ ] Set up Supabase project and get API keys
- [ ] Update `lib/main.dart` with Supabase credentials
- [ ] Deploy database schema using **QUICK_START_DEPLOYMENT.md**
- [ ] Run `flutter pub get` to install dependencies
- [ ] Test app on web: `flutter run -d chrome`
- [ ] (Optional) Set up Google Sign-In using **GOOGLE_SIGNIN_SETUP.md**
- [ ] (Optional) Set up PayMongo using **PAYMONGO_SETUP_GUIDE.md**
- [ ] Create test data and verify functionality
- [ ] Deploy to production when ready

---

## 📋 Project Structure Reference

```
yang_chow/
├── lib/
│   ├── pages/
│   │   ├── admin/              # Admin pages (8 files)
│   │   ├── staff/              # Staff pages (7 files)
│   │   ├── customer/           # Customer pages (6 files)
│   │   ├── login_page.dart     # Shared customer login
│   │   ├── forgot_password_page.dart
│   │   ├── landing_page.dart
│   │   └── update_password_page.dart
│   ├── services/               # Business logic
│   ├── widgets/                # Reusable UI components
│   ├── utils/                  # Helpers and constants
│   ├── models/                 # Data models
│   └── main.dart               # App entry point
├── android/                    # Android platform code
├── ios/                        # iOS platform code
├── web/                        # Web platform code
├── docs/
│   ├── guides/                 # Setup guides (this folder)
│   └── PAGES_CODE_EXPLANATION.md
├── pubspec.yaml                # Dependencies
├── .env.example                # Environment variables template
└── README.md                   # Project README
```

---

## 🔧 Common Setup Tasks

### I want to add Google Sign-In
→ Read: **GOOGLE_SIGNIN_SETUP.md**

### I want to enable payments
→ Read: **PAYMONGO_SETUP_GUIDE.md** then **test_payment_guide.md**

### I'm setting up the database for the first time
→ Read: **QUICK_START_DEPLOYMENT.md**

### I'm deploying to Android
→ Read: **generate_production_keystore.md**

### I want to understand the customer features
→ Read: **CUSTOMER_IMPROVEMENTS_IMPLEMENTATION.md**

### Everything isn't working - where do I start?
→ Read: **00-COMPLETE_SETUP_GUIDE.md** → Verify all steps

---

## ⚠️ Important Security Notes

1. **Never hardcode API keys** - Use environment variables in `.env` file
2. **Keep `.env` out of version control** - Add to `.gitignore`
3. **Use different keys for development and production**
4. **Rotate API keys regularly**
5. **Enable Row-Level Security (RLS)** on all sensitive Supabase tables
6. **Use HTTPS** for all external API calls

See **00-COMPLETE_SETUP_GUIDE.md** → Security Checklist for details.

---

## 📞 Need Help?

- **Flutter Issues**: https://flutter.dev/docs
- **Supabase Issues**: https://supabase.com/docs
- **PayMongo Issues**: https://developers.paymongo.com/
- **Google Cloud Issues**: https://cloud.google.com/docs

---

## 📝 Document Versions

| Guide | Version | Last Updated | Status |
|-------|---------|-------------|--------|
| 00-COMPLETE_SETUP_GUIDE.md | 1.0 | 2026-04-07 | ✅ Complete |
| QUICK_START_DEPLOYMENT.md | 1.0 | 2026-04-07 | ✅ Complete |
| GOOGLE_SIGNIN_SETUP.md | 1.0 | 2026-04-07 | ✅ Complete |
| PAYMONGO_SETUP_GUIDE.md | 1.1 | 2026-04-07 | ✅ updated |
| test_payment_guide.md | 1.0 | 2026-04-07 | ✅ Complete |
| paymongo_integration_complete.md | 1.0 | 2026-04-07 | 📝 Reference |
| generate_production_keystore.md | 1.0 | 2026-04-07 | ✅ Complete |
| CUSTOMER_IMPROVEMENTS_IMPLEMENTATION.md | 1.1 | 2026-04-07 | ✅ Updated |

---

**Last Updated**: April 7, 2026  
**Status**: All guides reviewed and updated for new project structure ✅
