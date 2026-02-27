-- =========================================
-- FIX RLS POLICY FOR CUSTOMER REGISTRATION
-- =========================================

-- 1. Drop existing policies
DROP POLICY IF EXISTS "Allow customer registration" ON users;
DROP POLICY IF EXISTS "Users can manage their profile" ON users;

-- 2. Create proper RLS policy for registration
CREATE POLICY "Allow user registration" ON users
  FOR INSERT WITH CHECK (true);

-- 3. Create policy for viewing own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.email() = email);

-- 4. Create policy for updating own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.email() = email);

-- 5. Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'users';
