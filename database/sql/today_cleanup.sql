-- Today's Cleanup Queries
-- Clean up only the queries run today (March 1, 2026)

-- 1. Drop customer table if you created it today
DROP TABLE IF EXISTS customer;

-- 2. Delete any customer records that were added to users table today
DELETE FROM users 
WHERE role = 'customer' 
AND created_at >= '2026-03-01';

-- 3. Delete any test reservations created today
DELETE FROM reservations 
WHERE created_at >= '2026-03-01';

-- 4. Clean up any RLS policies for customer table
DROP POLICY IF EXISTS "Customers can insert profile" ON customer;
DROP POLICY IF EXISTS "Customers can view own profile" ON customer;
DROP POLICY IF EXISTS "Customers can update own profile" ON customer;
DROP POLICY IF EXISTS "Admin can view all customers" ON customer;

-- 5. Drop customer-related functions and triggers
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP TRIGGER IF EXISTS update_customer_updated_at ON customer;

-- 6. Drop customer-related indexes
DROP INDEX IF EXISTS idx_customer_email;
DROP INDEX IF EXISTS idx_customer_created_at;

-- 7. Check what was deleted (run these first to see what will be removed)
SELECT * FROM users WHERE role = 'customer' AND created_at >= '2026-03-01';
SELECT * FROM reservations WHERE created_at >= '2026-03-01';
SELECT * FROM customer; -- This should show nothing if table exists

-- USAGE:
-- 1. Run the SELECT queries first to see what will be deleted
-- 2. Then run the DELETE and DROP queries
-- 3. Make sure to backup if needed before running
