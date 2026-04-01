-- =========================================
-- COMPLETE STAFF USER SETUP
-- Email: staffycp@gmail.com
-- Password: staffycp
-- =========================================

-- STEP 1: Create or update the staff account in users table
INSERT INTO users (email, role) 
VALUES ('staffycp@gmail.com', 'staff')
ON CONFLICT (email) 
DO UPDATE SET 
  role = 'staff',
  updated_at = NOW();

-- STEP 2: Verify the staff account setup
SELECT 
  'USERS TABLE' as table_name,
  email,
  role,
  created_at,
  updated_at
FROM users 
WHERE email = 'staffycp@gmail.com'

UNION ALL

SELECT 
  'AUTH USERS' as table_name,
  email,
  raw_user_meta_data->>'role' as role,
  created_at,
  last_sign_in_at
FROM auth.users 
WHERE email = 'staffycp@gmail.com';

-- =========================================
-- INSTRUCTIONS:
-- =========================================
-- 1. First, create the auth user in Supabase Dashboard:
--    - Go to Authentication -> Users
--    - Click "Add user"
--    - Email: staffycp@gmail.com
--    - Password: staffycp
--    - User metadata: {"role": "staff", "name": "Staff User"}
--    - Click "Save"
--
-- 2. Then run this SQL script to set up the users table
--
-- 3. Test login at: http://localhost:50709/#/staff
--    Email: staffycp@gmail.com
--    Password: staffycp
