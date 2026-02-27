-- =========================================
-- CUSTOMER REGISTRATION SETUP
-- =========================================

-- 1. Update users table to support customer registration
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT;

-- 2. Enable Row Level Security (if not already enabled)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 3. Drop all existing policies first
DROP POLICY IF EXISTS "Users can manage their profile" ON users;
DROP POLICY IF EXISTS "Allow user registration" ON users;
DROP POLICY IF EXISTS "Users can view profiles" ON users;

-- 4. Create policies for customer registration
-- Allow users to insert their own record during registration
CREATE POLICY "Allow user registration" ON users
  FOR INSERT WITH CHECK (auth.email() = email);

-- Allow users to view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.email() = email);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.email() = email);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS users_name_idx ON users(name);

-- 6. Verify the updated table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- 7. Test query to verify customer records
SELECT 
  id, 
  email, 
  name, 
  phone,
  role, 
  created_at
FROM users 
WHERE role = 'customer'
ORDER BY created_at DESC;
