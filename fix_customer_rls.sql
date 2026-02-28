-- =========================================
-- FIX CUSTOMER REGISTRATION RLS POLICY
-- =========================================

-- 1. Drop existing registration policy
DROP POLICY IF EXISTS "Allow user registration" ON users;

-- 2. Create better policy that allows insertion during registration
-- This policy allows users to insert their own record and handles duplicates
CREATE POLICY "Allow user registration" ON users
  FOR INSERT WITH CHECK (
    auth.email() = email OR 
    (auth.role() = 'anon' AND email = current_setting('request.headers', true)::json->>'x-user-email')
  );

-- 3. Add policy to handle duplicate prevention
CREATE POLICY "Prevent duplicate user records" ON users
  FOR INSERT WITH CHECK (NOT EXISTS (
    SELECT 1 FROM users WHERE users.email = email
  ));

-- 4. Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.email() = email);

-- 5. Allow users to view their own profile  
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.email() = email);

-- 6. Test the policy by checking existing customer records
SELECT 
  id, 
  email, 
  name, 
  role, 
  created_at
FROM users 
WHERE role = 'customer'
ORDER BY created_at DESC;
