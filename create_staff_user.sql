-- =========================================
-- CREATE STAFF USER WITH PASSWORD staffycp
-- =========================================

-- Create the staff user in Supabase auth system
-- This will create user with email: staffycp@gmail.com and password: staffycp

-- Note: This needs to be run in Supabase SQL Editor
-- The password will be: staffycp

SELECT auth.signup(
  email := 'staffycp@gmail.com',
  password := 'staffycp',
  data := '{"role": "staff", "name": "Staff User"}'
);

-- Alternative method if auth.signup doesn't work:
-- Use this in Supabase Dashboard -> Authentication -> Users -> Add User
-- Email: staffycp@gmail.com
-- Password: staffycp

-- After creating the auth user, run the staff_setup.sql to ensure role is set correctly

-- Verify the user exists in auth system
SELECT 
  id,
  email,
  created_at,
  last_sign_in_at,
  raw_user_meta_data
FROM auth.users 
WHERE email = 'staffycp@gmail.com';
