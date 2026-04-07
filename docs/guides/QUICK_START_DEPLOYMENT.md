# QUICK START: Deploying Customer Improvements

## 🏗️ Project Structure Overview

After recent reorganization, the Yang Chow project has the following structure:

```
lib/pages/
├── admin/              # Admin pages (8 files)
├── staff/              # Staff pages (7 files)
├── customer/           # Customer pages (6 files)
└── *.dart              # Shared auth pages (4 files)
```

All customer-facing features are in `lib/pages/customer/` while database operations are in `lib/services/`.

---

## 🚀 Step 1: Deploy Database Changes (5 minutes)

### Option A: Using Supabase Dashboard (Easiest)
1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your Yang Chow project
3. Click **SQL Editor** (left sidebar)
4. Click **New Query**
5. Open file: `reservations_enhancements.sql` (in project root)
6. Copy ALL content
7. Paste into Supabase SQL editor
8. Click **Run** button (⚡)
9. Wait for "Success" message
10. Verify tables created (see checklist below)

### Option B: Using Supabase CLI
```bash
# If you have Supabase CLI installed
cd your-project-folder
supabase db push  # Uses your migrations

# Or manually:
cat reservations_enhancements.sql | supabase db execute
```

---

## ✅ Verification Checklist

After running SQL, verify in Supabase:

1. **In SQL Editor**, run this to check:
```sql
-- Check new tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

Should include: `reviews`, `cancellation_requests`, `email_logs`, `app_settings`

2. **Check reservations table has new columns**:
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'reservations' 
ORDER BY ordinal_position;
```

Should include: `special_requests`, `customer_phone`, `customer_address`, `cancelled_at`, `refund_amount`, `refund_status`

3. **Check app_settings is populated**:
```sql
SELECT * FROM app_settings;
```

Should show 13 rows with default configuration

4. **Check RLS policies**:
   - Go to **Authentication** → **Policies** in Supabase dashboard
   - Should see policies for: `reviews`, `cancellation_requests`

---

## 🔧 Step 2: Configure App Settings (Optional)

If you want to customize operating hours, guest limits, etc.:

```sql
-- EXAMPLE: Change operating hours to 11 AM - 11 PM
UPDATE app_settings 
SET setting_value = '11' 
WHERE setting_key = 'operating_hours_start';

UPDATE app_settings 
SET setting_value = '23' 
WHERE setting_key = 'operating_hours_end';

-- EXAMPLE: Set minimum 1 guest (for couples, etc)
UPDATE app_settings 
SET setting_value = '1' 
WHERE setting_key = 'min_guest_count';

-- EXAMPLE: Disable special requests field
UPDATE app_settings 
SET setting_value = 'false' 
WHERE setting_key = 'enable_special_requests';

-- View changes
SELECT setting_key, setting_value FROM app_settings ORDER BY setting_key;
```

**Available Settings to Configure**:
```
min_guest_count                  → Minimum guests (default: 2)
max_guest_count                  → Maximum guests (default: 500)
operating_hours_start            → Opening hour (default: 10)
operating_hours_end              → Closing hour (default: 22)
min_reservation_days_ahead       → Earliest booking (default: 4 days)
max_reservation_days_ahead       → Latest booking (default: 365 days)
refund_policy_days               → Days for 100% refund (default: 7)
refund_percentage_within_window  → Partial refund % (default: 50%)
enable_special_requests          → Show special requests field (default: true)
enable_email_notifications       → Send emails (default: true)
smtp_from_email                  → Email sender address
```

---

## 📦 Step 3: Update Flutter App Code (2 minutes)

1. **Replace these files** with updated versions:
   - ✅ `lib/pages/customer_dashboard.dart` - UPDATED
   - ✅ `lib/main.dart` - UPDATED
   - ✅ `lib/utils/app_constants.dart` - UPDATED

2. **Create these NEW files**:
   - ✅ `lib/services/app_settings_service.dart` - NEW
   - ✅ `lib/services/reservation_service.dart` - NEW
   - ✅ `lib/services/email_notification_service.dart` - NEW
   - ✅ `lib/pages/customer_reviews_page.dart` - NEW

3. **Copy & paste the code** from the implementation files into your project

4. **Verify no errors**:
```bash
flutter pub get
flutter analyze  # Should show 0 errors related to our changes
```

---

## 🧪 Step 4: Test the New Features (10 minutes)

### Test 1: Configurable Guest Count
- Open app as customer
- Go to Reservations tab
- Try booking with 1 guest (should work now, was blocked before)
- Try booking with 2, 3, 5 guests (all should work)
- ✅ **Pass**: Can book with <10 guests

### Test 2: Configurable Operating Hours
- Try selecting time before/after configured hours
- Should show error message with your hours
- ✅ **Pass**: Time picker respects configured hours

### Test 3: Special Requests Field
- See new "Special Requests" text area in reservation form
- Type in a dietary restriction
- Submit reservation
- In Supabase SQL Editor, check:
```sql
SELECT customer_email, special_requests, event_type 
FROM reservations 
WHERE special_requests IS NOT NULL 
LIMIT 1;
```
- ✅ **Pass**: Special requests saved to database

### Test 4: Cancellation Workflow
- Create a confirmed reservation (have admin confirm it)
- Go to Reservation History
- Click the menu button (⋮) on confirmed reservation
- Click "Cancel Reservation"
- Select cancellation reason
- See refund amount calculation
- Confirm cancellation
- Check Supabase: reservation status should be 'cancelled'
- ✅ **Pass**: Can cancel confirmed reservations

### Test 5: Rescheduling
- Create a confirmed reservation
- Click menu (⋮) and select "Reschedule"
- Select new date and time
- Confirm
- Check Supabase: reservation event_date/start_time should be updated
- ✅ **Pass**: Reservation rescheduled successfully

### Test 6: Reviews & Ratings
- Go to Reservation History
- Look for "Leave a Review" button/option (need to implement UI link first)
- Or navigate to CustomerReviewsPage directly
- Select a past reservation
- Leave a 5-star review with comments
- Check Supabase:
```sql
SELECT * FROM reviews ORDER BY created_at DESC LIMIT 1;
```
- ✅ **Pass**: Review saved with ratings

### Test 7: Email Notifications
- Create a reservation
- Check Supabase email_logs table:
```sql
SELECT recipient_email, email_type, subject, sent_at 
FROM email_logs 
ORDER BY sent_at DESC 
LIMIT 5;
```
- ✅ **Pass**: Confirmation email logged

---

## 🐛 Troubleshooting

### "Table does not exist" Error
- ❌ **Problem**: SQL migration didn't run completely
- ✅ **Solution**: 
  1. Check for errors in SQL output
  2. Run SQL query again
  3. Look for specific table and check for typos

### Guest count still limited to 10
- ❌ **Problem**: App is using old code
- ✅ **Solution**:
  1. Verify you updated `customer_dashboard.dart`
  2. Run `flutter clean`
  3. Run `flutter pub get`
  4. Rebuild app: `flutter run`

### Operating hours still showing 10 AM - 4 PM
- ❌ **Problem**: App loaded before app_settings were created
- ✅ **Solution**:
  1. Verify `app_settings` table is populated
  2. Run: `flutter clean && flutter pub get`
  3. Close and reopen app

### Special requests field not showing
- ❌ **Problem**: `enable_special_requests` is false in app_settings
- ✅ **Solution**:
```sql
UPDATE app_settings 
SET setting_value = 'true' 
WHERE setting_key = 'enable_special_requests';
```
Then restart app.

### Email notifications not appearing in logs
- ❌ **Problem**: App code isn't hitting the new service
- ✅ **Solution**:
  1. Check `main.dart` initializes AppSettingsService
  2. Check `customer_dashboard.dart` imports are correct
  3. Check console for error messages

---

## 🎯 Integration Checklist

- [ ] SQL migration executed successfully
- [ ] All new tables created in Supabase
- [ ] App settings table populated with defaults
- [ ] Flutter files updated/created
- [ ] App builds without errors (`flutter analyze`)
- [ ] Guest count minimum changed to 2
- [ ] Operating hours configurable
- [ ] Special requests field visible in form
- [ ] Can cancel confirmed reservations
- [ ] Can reschedule reservations
- [ ] Can see and submit reviews
- [ ] Email notifications logged to database

---

## 📞 Support

If you encounter issues:

1. **Check the migration status**:
```sql
SELECT * FROM information_schema.tables 
WHERE table_name IN ('reviews', 'app_settings', 'cancellation_requests', 'email_logs');
```

2. **Check app_settings values**:
```sql
SELECT * FROM app_settings;
```

3. **Monitor email logs**:
```sql
SELECT * FROM email_logs ORDER BY sent_at DESC LIMIT 10;
```

4. **Check reservation details**:
```sql
SELECT customer_email, event_type, status, special_requests, created_at 
FROM reservations 
ORDER BY created_at DESC 
LIMIT 5;
```

5. **Review migration file for errors**:
   - Look for any SQL errors in the migration output
   - Check for constraint violations
   - Ensure all dependencies exist

---

## ✨ What's Next?

After successfully deploying:

1. **Add email provider** (SendGrid, AWS SES, Mailgun)
   - File: `lib/services/email_notification_service.dart`
   - Method: `_logEmailNotification()`
   - Takes ~30 minutes to connect

2. **Create admin settings UI page**
   - Let admins adjust app_settings without SQL
   - Takes ~2 hours

3. **Add phone/address to profile**
   - Update `lib/pages/edit_profile_page.dart`
   - Takes ~1 hour

4. **Add "Leave Review" button to dashboard**
   - Link to `CustomerReviewsPage`
   - Show review count and average rating
   - Takes ~30 minutes

---

## 🎉 Congratulations!

Your customer-facing improvements are live! 🚀

Key improvements delivered:
- ✅ Customers can cancel confirmed reservations
- ✅ Customers can reschedule reservations
- ✅ Customers can add special requests
- ✅ Customers can leave reviews and ratings
- ✅ Configurable guest count limits (no more hard-coded 10)
- ✅ Configurable operating hours (no more hard-coded 10 AM-4 PM)
- ✅ Email notification system ready
- ✅ Refund policy system in place
- ✅ Clean, extensible architecture

Enjoy the improved user experience! 🎊
