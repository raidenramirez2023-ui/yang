-- Add pagsanjaninv@gmail.com as inventory staff user
-- Run this in Supabase SQL Editor

-- Insert the new inventory staff user
INSERT INTO users (email, role) VALUES 
  ('pagsanjaninv@gmail.com', 'inventory staff');

-- Verify the user was added
SELECT * FROM users WHERE email = 'pagsanjaninv@gmail.com';

-- Show all inventory staff users
SELECT * FROM users WHERE role = 'inventory staff' ORDER BY created_at;
