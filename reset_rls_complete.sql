-- =========================================
-- COMPLETE RLS POLICY RESET
-- =========================================

-- 1. Disable RLS temporarily
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL policies for users table
DROP POLICY IF EXISTS "Allow user registration" ON users;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can manage their profile" ON users;
DROP POLICY IF EXISTS "Allow customer registration" ON users;
DROP POLICY IF EXISTS "Users can view profiles" ON users;

-- 3. Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 4. Create simple policy for registration
CREATE POLICY "Allow registration" ON users
  FOR INSERT WITH CHECK (true);

-- 5. Create policy for viewing own profile
CREATE POLICY "View own profile" ON users
  FOR SELECT USING (auth.email() = email);

-- 6. Verify policies
SELECT 
  policyname,
  cmd,
  roles,
  with_check
FROM pg_policies 
WHERE tablename = 'users';
