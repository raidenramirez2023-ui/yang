# GCash QR Code Payment Setup Instructions

## How to Add Your Actual GCash QR Code

### Step 1: Prepare Your QR Code Image
- Save your GCash QR code image as `gcash_qr.png`
- Make sure the image is clear and high quality
- Recommended size: 200x200 pixels or larger

### Step 2: Add Your QR Code Image
1. Copy your actual GCash QR code image (gcash_qr.png)
2. Navigate to: `c:\Users\Raiden\yang\assets\images\`
3. Place your `gcash_qr.png` file in this folder

### Step 3: Update Account Information (Optional)
If you want to update the account details shown in the payment page, edit:
- File: `lib/pages/customer/gcash_qr_payment_page.dart`
- Look for the "Account Info" section around line 190
- Update the name and mobile number to match your GCash account

### Current Account Information in Code:
- Account Name: LO*D RA***N R.
- Mobile: +63 906 865 ....

### Step 4: Test the Payment Flow
1. Run your Flutter app
2. Go to Customer Dashboard
3. Create a reservation
4. Click "Pay Deposit" 
5. Select "Pay with GCash QR"
6. Verify your QR code appears correctly

## Features Implemented:
- **Secure GCash QR Payment**: Customers scan QR code with GCash app
- **Automatic Payment Confirmation**: Updates reservation status when customer confirms payment
- **Email Notifications**: Sends payment confirmation emails
- **Mobile & Web Compatible**: Works on all platforms
- **Error Handling**: Proper error messages and fallbacks

## Payment Flow:
1. Customer clicks "Pay Deposit"
2. Selects "Pay with GCash QR"
3. Scans QR code with GCash app
4. Enters exact amount
5. Completes payment in GCash
6. Returns to app and clicks "I Paid"
7. System updates reservation status
8. Admin receives notification for verification

## Notes:
- PayMongo integration has been disabled/commented out
- All payment processing now goes through GCash QR
- You can re-enable PayMongo later if needed by uncommenting the relevant code
