# PayMongo Integration Test Guide

## Test Payment Cards
Use these test cards for PayMongo testing:

| Card Type | Card Number | Expiry | CVC | Result |
|-----------|-------------|---------|-----|---------|
| Visa (Success) | 4343434343434343 | 12/25 | 123 | ✅ Successful |
| Mastercard (Success) | 5555555555554444 | 12/25 | 123 | ✅ Successful |
| Visa (Declined) | 4000000000000002 | 12/25 | 123 | ❌ Declined |

## Testing Steps

### 1. Environment Setup
```bash
# Install dependencies
flutter pub get

# Verify .env file exists
cat .env
```

### 2. Test Payment Flow
1. Navigate to reservation page
2. Fill reservation details
3. Proceed to payment
4. Select payment method
5. Use test card details
6. Complete payment

### 3. Verify Deep Links
- Android: `adb shell am start -W -a android.intent.action.VIEW -d "yangchow://payment/success" com.example.yang_chow`
- iOS: Test in Safari using `yangchow://payment/success`

### 4. Common Issues
- **API Key Error**: Check `.env` file
- **WebView Issues**: Verify `webview_flutter` dependency
- **Deep Link Issues**: Check manifest configurations

### 5. Production Checklist
- [ ] Replace test keys with live keys
- [ ] Set up webhooks
- [ ] Test with real payment methods
- [ ] Monitor transaction logs
