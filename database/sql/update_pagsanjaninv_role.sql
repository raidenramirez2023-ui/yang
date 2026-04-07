-- Update pagsanjaninv@gmail.com role to inventory staff
-- Run this in Supabase SQL Editor

-- Update existing user role
UPDATE users 
SET role = 'inventory staff' 
WHERE email = 'pagsanjaninv@gmail.com';

-- Verify the user was updated
SELECT * FROM users WHERE email = 'pagsanjaninv@gmail.com';

-- Show all inventory staff users
SELECT * FROM users WHERE role = 'inventory staff' ORDER BY created_at;

-- Show all users to verify roles
SELECT email, role, created_at FROM users ORDER BY created_at;
