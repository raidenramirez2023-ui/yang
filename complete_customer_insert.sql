-- =========================================
-- COMPLETE CUSTOMER INSERT QUERY
-- =========================================

-- 1. Make sure all required columns exist
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- 2. Disable RLS temporarily to insert customer record
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 3. Insert test customer record with all columns
INSERT INTO users (id, email, role, created_at, updated_at, firebase_uid, name, phone) 
VALUES (
  gen_random_uuid(),
  'test.customer@example.com',
  'customer',
  NOW(),
  NOW(),
  NULL,
  'Test Customer',
  NULL
)
ON CONFLICT (email) DO NOTHING;

-- 4. Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 5. Create simple policy for customer registration
DROP POLICY IF EXISTS "Allow customer registration" ON users;
CREATE POLICY "Allow customer registration" ON users
  FOR INSERT WITH CHECK (auth.email() = email);

-- 6. Verify customer was added
SELECT 
  id, 
  email, 
  role, 
  created_at,
  updated_at,
  firebase_uid,
  name,
  phone
FROM users 
WHERE role = 'customer'
ORDER BY created_at DESC;
