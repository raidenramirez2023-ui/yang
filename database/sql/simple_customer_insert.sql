-- =========================================
-- SIMPLE CUSTOMER INSERT QUERY
-- =========================================

-- 1. First, make sure name column exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS name TEXT;

-- 2. Disable RLS temporarily to insert customer record
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 3. Insert test customer record directly
INSERT INTO users (id, email, name, role, created_at) 
VALUES (
  gen_random_uuid(),
  'test.customer@example.com',
  'Test Customer',
  'customer',
  NOW()
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
  name, 
  role, 
  created_at
FROM users 
WHERE role = 'customer'
ORDER BY created_at DESC;
