-- =========================================
-- COMPLETE STAFF ACCOUNT SETUP
-- =========================================

-- 1. Create users table (if not exists)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 3. Create policies (if not exists)
DROP POLICY IF EXISTS "Users can manage their profile" ON users;
CREATE POLICY "Users can manage their profile" ON users
  FOR ALL USING (auth.email() = email);

-- 4. Insert staff account with proper error handling
DO $$
BEGIN
    -- Check if user already exists
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE email = 'staffycp@gmail.com'
    ) THEN
        -- Insert new staff account
        INSERT INTO users (email, role) VALUES 
          ('staffycp@gmail.com', 'staff');
        RAISE NOTICE 'Staff account staffycp@gmail.com created successfully';
    ELSE
        -- Update existing account to ensure it has staff role
        UPDATE users 
        SET role = 'staff', updated_at = NOW() 
        WHERE email = 'staffycp@gmail.com';
        RAISE NOTICE 'Staff account staffycp@gmail.com updated to staff role';
    END IF;
END $$;

-- 5. Verify staff account was added
SELECT 
  id,
  email,
  role,
  created_at,
  updated_at
FROM users 
WHERE email = 'staffycp@gmail.com';
