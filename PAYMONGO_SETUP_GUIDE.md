# PayMongo Integration Setup Guide

## Overview
This guide will help you set up PayMongo payment integration for your Yang Chow Restaurant Flutter app.

## Step 1: PayMongo Account Setup

### 1.1 Create PayMongo Account
1. Go to [PayMongo Dashboard](https://dashboard.paymongo.com/)
2. Sign up for a new account or login if you already have one
3. Complete the verification process

### 1.2 Get API Keys
1. Navigate to **Settings** > **Developers** > **API Keys**
2. You'll find two sets of keys:
   - **Test Keys** (for development)
   - **Live Keys** (for production)

### 1.3 Important Keys
- **Public Key**: Starts with `pk_test_` or `pk_live_`
- **Secret Key**: Starts with `sk_test_` or `sk_live_`

⚠️ **Important**: Never expose your secret key in client-side code!

## Step 2: Update Configuration

### 2.1 Update PayMongo Service
Edit `lib/services/paymongo_service.dart`:

```dart
class PayMongoService {
  // Replace with your actual PayMongo API keys
  static const String _baseUrl = 'https://api.paymongo.com/v1';
  static const String _publicKey = 'pk_test_YOUR_PUBLIC_KEY_HERE'; // Test Public Key
  static const String _secretKey = 'sk_test_YOUR_SECRET_KEY_HERE'; // Test Secret Key
  
  // For production, use:
  // static const String _publicKey = 'pk_live_YOUR_PUBLIC_KEY_HERE';
  // static const String _secretKey = 'sk_live_YOUR_SECRET_KEY_HERE';
}
```

### 2.2 Add Payment Logos (Optional)
Add payment method logos to `assets/images/`:
- `gcash_logo.png`
- `paymaya_logo.png`
- `card_logo.png`
- `bank_logo.png`

## Step 3: Database Schema Updates

Add payment-related columns to your `reservations` table:

```sql
ALTER TABLE reservations 
ADD COLUMN payment_method VARCHAR(50),
ADD COLUMN payment_status VARCHAR(20) DEFAULT 'pending',
ADD COLUMN payment_amount DECIMAL(10,2),
ADD COLUMN transaction_id VARCHAR(100),
ADD COLUMN payment_date TIMESTAMP;
```

## Step 4: Install Dependencies

Run the following command to install new dependencies:

```bash
flutter pub get
```

## Step 5: Configure App Links (For Deep Linking)

### 5.1 Android Configuration
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- Existing intent filters -->
    
    <!-- PayMongo return URLs -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yangchow" />
    </intent-filter>
</activity>
```

### 5.2 iOS Configuration
Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>yangchow</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yangchow</string>
        </array>
    </dict>
</array>
```

## Step 6: Test Payment Integration

### 6.1 Test Cards for Development
PayMongo provides test cards for testing:

| Card Type | Card Number | Expiry | CVC |
|-----------|-------------|---------|-----|
| Visa (Successful) | 4343434343434343 | 12/25 | 123 |
| Mastercard (Successful) | 5555555555554444 | 12/25 | 123 |
| Visa (Declined) | 4000000000000002 | 12/25 | 123 |

### 6.2 Testing E-Wallets
For GCash and Maya testing:
1. Use the PayMongo test environment
2. Follow the test e-wallet flow provided by PayMongo

## Step 7: Payment Flow

### 7.1 Reservation Creation Flow
1. User fills reservation form
2. System calculates reservation fee
3. Payment dialog shows fee breakdown
4. User proceeds to payment
5. Payment page shows payment methods
6. User selects method and pays
7. On successful payment, reservation is confirmed

### 7.2 Fee Calculation Example
```dart
// Base reservation fee: ₱500
// Per-guest fee: ₱50
// Total = 500 + (50 × number_of_guests)

double reservationFee = 500.0 + (50.0 * numberOfGuests);
```

## Step 8: Error Handling

The integration includes comprehensive error handling for:
- Network issues
- Payment failures
- Invalid API keys
- Timeout scenarios
- User cancellation

## Step 9: Security Considerations

### 9.1 API Key Security
- Never commit secret keys to version control
- Use environment variables for production
- Consider using a backend proxy for sensitive operations

### 9.2 Payment Data
- All payment data is handled securely through PayMongo
- No credit card details are stored on your servers
- PCI compliance is handled by PayMongo

## Step 10: Production Deployment

### 10.1 Switch to Live Keys
1. Update `paymongo_service.dart` with live keys
2. Test thoroughly in staging environment
3. Deploy to production

### 10.2 Monitor Transactions
- Set up webhooks for payment notifications
- Monitor failed payments
- Set up alerts for unusual activity

## Step 11: Webhook Configuration (Optional but Recommended)

### 11.1 Set Up Webhooks
1. In PayMongo Dashboard, go to **Settings** > **Webhooks**
2. Add your webhook endpoint URL
3. Select events to listen for:
   - `payment.paid`
   - `payment.failed`
   - `payment.refunded`

### 11.2 Webhook Endpoint Example
```dart
// Example webhook endpoint
// POST /api/payments/webhook
{
  "data": {
    "id": "pay_xxxx",
    "type": "payment.paid",
    "attributes": {
      "amount": 50000,
      "currency": "PHP",
      "status": "paid"
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **API Key Errors**
   - Verify keys are correct
   - Check if test/live keys match environment

2. **Payment Failures**
   - Check network connectivity
   - Verify payment method availability
   - Check PayMongo service status

3. **WebView Issues**
   - Ensure `webview_flutter` is properly configured
   - Check Android/iOS permissions

4. **Deep Link Issues**
   - Verify app links configuration
   - Test deep link functionality

### Debug Mode
Enable debug mode in PayMongo service:
```dart
// In PayMongoService, add debug logging
debugPrint('PayMongo Request: $requestBody');
debugPrint('PayMongo Response: ${response.body}');
```

## Support

For PayMongo-specific issues:
- PayMongo Documentation: https://developers.paymongo.com/
- PayMongo Support: support@paymongo.com

For Flutter integration issues:
- Check Flutter logs
- Review API responses
- Verify network permissions

## Next Steps

1. Complete the setup using this guide
2. Test thoroughly in development environment
3. Set up monitoring and analytics
4. Consider adding refund functionality
5. Implement recurring payments if needed

---

**Note**: This integration uses PayMongo's payment links method for simplicity and security. For more advanced use cases, consider implementing direct payment method handling with proper PCI compliance.
