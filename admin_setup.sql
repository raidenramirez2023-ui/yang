-- Admin Authentication Setup for Yang Chow Restaurant
-- Copy and paste this in Supabase SQL Editor

-- Create users table
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can manage their profile" ON users
  FOR ALL USING (auth.email() = email);

-- Create admin accounts
INSERT INTO users (email, role) VALUES 
  ('adm.pagsanjan@gmail.com', 'admin'),
  ('admin@yangchow.com', 'admin'),
  ('manager@yangchow.com', 'admin');

-- Create staff accounts
INSERT INTO users (email, role) VALUES 
  ('staff1@yangchow.com', 'staff'),
  ('staff2@yangchow.com', 'staff'),
  ('kitchen@yangchow.com', 'staff');

-- Create indexes
CREATE INDEX users_email_idx ON users(email);
CREATE INDEX users_role_idx ON users(role);

-- Verify users
SELECT * FROM users ORDER BY created_at;
