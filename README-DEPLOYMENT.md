# Yang Chow Restaurant - Deployment Guide

## Domain: yc-pagsanjan.site

### Prerequisites
- Flutter SDK installed
- Hostinger hosting account
- Supabase project
- PayMongo account (for payments)

### Environment Setup

1. Copy environment file:
```bash
cp .env.example .env
```

2. Update `.env` with your actual keys:
```env
# Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# PayMongo API Keys
PAYMONGO_PUBLIC_KEY=pk_live_your_public_key_here
PAYMONGO_SECRET_KEY=sk_live_your_secret_key_here

# App Configuration
APP_NAME=Yang Chow Restaurant
APP_SCHEME=yangchow
DOMAIN=yc-pagsanjan.site
```

### Local Development

1. Install dependencies:
```bash
flutter pub get
```

2. Run locally:
```bash
flutter run -d web-server --web-port 8080
```

### Production Deployment

#### Option 1: PowerShell (Windows)
```powershell
.\deploy.ps1
```

#### Option 2: Bash (Linux/Mac)
```bash
chmod +x hostinger-deploy.sh
./hostinger-deploy.sh
```

#### Option 3: Manual Build
```bash
flutter clean
flutter pub get
flutter build web --release --web-renderer canvaskit --base-href=/
```

### Hostinger Setup

1. **Upload Files:**
   - Upload the contents of `build/web/` to your Hostinger `public_html` directory
   - Or upload the generated deployment package (`.zip` or `.tar.gz`)

2. **Domain Configuration:**
   - Ensure your domain `yc-pagsanjan.site` points to the correct directory
   - Set up SSL certificate (Hostinger usually provides free SSL)

3. **Environment Variables:**
   - In Hostinger control panel, set up environment variables if supported
   - Or hardcode values in production build (not recommended for sensitive data)

### Important Notes

- **Supabase:** Make sure your Supabase project allows your domain in the authentication settings
- **Google Sign-In:** Update the authorized origins in Google Console to include `https://yc-pagsanjan.site`
- **Firebase:** Update the Firebase configuration if using Firebase services
- **Payments:** Ensure PayMongo webhook URLs are configured for `https://yc-pagsanjan.site`

### Troubleshooting

- **404 Errors:** Check that `base-href` is set correctly in the build
- **CORS Issues:** Configure Supabase and other APIs to allow `yc-pagsanjan.site`
- **Authentication Failures:** Verify redirect URLs in Google Sign-In and other auth providers

### Build Optimization

The build is optimized for production with:
- CanvasKit renderer for better performance
- Proper caching headers
- Minified assets
- Base href configured for root domain

### Support

For issues related to:
- **Hostinger:** Contact Hostinger support
- **Flutter App:** Check Flutter documentation
- **Supabase:** Check Supabase dashboard
- **PayMongo:** Check PayMongo documentation
