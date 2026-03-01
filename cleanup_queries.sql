-- Database Cleanup Queries
-- Use these to clean up any test data or tables created during development

-- 1. Delete all customer records (if you want to clean up customer table)
-- DELETE FROM customer WHERE 1=1;

-- 2. Delete all test reservations (if you want to clean up reservations)
-- DELETE FROM reservations WHERE 1=1;

-- 3. Delete specific test users (replace with actual emails)
-- DELETE FROM users WHERE email IN ('test@example.com', 'customer@test.com');

-- 4. Drop customer table (if you want to remove it completely)
-- DROP TABLE IF EXISTS customer;

-- 5. Drop any test tables you might have created
-- DROP TABLE IF EXISTS test_table;
-- DROP TABLE IF EXISTS temp_table;

-- 6. Reset sequences (if you used auto-increment IDs)
-- ALTER SEQUENCE IF EXISTS customer_id_seq RESTART WITH 1;
-- ALTER SEQUENCE IF EXISTS reservations_id_seq RESTART WITH 1;
-- ALTER SEQUENCE IF EXISTS users_id_seq RESTART WITH 1;

-- 7. Clean up RLS policies (if you want to remove them)
-- DROP POLICY IF EXISTS "Customers can insert profile" ON customer;
-- DROP POLICY IF EXISTS "Customers can view own profile" ON customer;
-- DROP POLICY IF EXISTS "Customers can update own profile" ON customer;
-- DROP POLICY IF EXISTS "Admin can view all customers" ON customer;

-- 8. Disable RLS on customer table (if you want to remove it)
-- ALTER TABLE customer DISABLE ROW LEVEL SECURITY;

-- 9. Remove any test functions or triggers
-- DROP FUNCTION IF EXISTS update_updated_at_column();
-- DROP TRIGGER IF EXISTS update_customer_updated_at ON customer;

-- 10. Clean up indexes (if you want to remove them)
-- DROP INDEX IF EXISTS idx_customer_email;
-- DROP INDEX IF EXISTS idx_customer_created_at;

-- 11. View all tables to see what exists
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- 12. View all records in each table to see what data exists
-- SELECT * FROM users LIMIT 10;
-- SELECT * FROM reservations LIMIT 10;
-- SELECT * FROM customer LIMIT 10;

-- 13. Count records in each table
-- SELECT COUNT(*) as user_count FROM users;
-- SELECT COUNT(*) as reservation_count FROM reservations;
-- SELECT COUNT(*) as customer_count FROM customer;

-- 14. Check for any orphaned records (records that might not have proper references)
-- SELECT * FROM customer WHERE id NOT IN (SELECT id FROM auth.users);

-- 15. Clean up any specific test data by date range
-- DELETE FROM reservations WHERE created_at < '2026-01-01';

-- USAGE INSTRUCTIONS:
-- 1. Uncomment the queries you want to run (remove the -- at the beginning)
-- 2. Replace placeholder values with actual values if needed
-- 3. Run each query individually in Supabase SQL Editor
-- 4. Always backup your data before running delete operations

-- SAFETY CHECKS:
-- Always run these SELECT queries first to see what will be deleted:
-- SELECT * FROM customer; -- See all customer records
-- SELECT * FROM reservations; -- See all reservations
-- SELECT * FROM users; -- See all users

-- Then run the DELETE queries if you're sure:
-- DELETE FROM customer; -- Delete all customers
-- DELETE FROM reservations; -- Delete all reservations
-- DELETE FROM users WHERE role = 'customer'; -- Delete only customer users
