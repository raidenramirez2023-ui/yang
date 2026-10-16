-- =====================================================
-- 1. ADD PHONE VERIFICATION STATUS TO USERS TABLE
-- =====================================================
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_phone_verified BOOLEAN DEFAULT FALSE;

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS users_phone_verified_idx ON users(id, is_phone_verified);


-- =====================================================
-- 2. CREATE PHONE_VERIFICATIONS TABLE (FOR OTP TRACKING)
-- =====================================================
CREATE TABLE IF NOT EXISTS phone_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  verification_code VARCHAR(10) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_used BOOLEAN DEFAULT FALSE,
  attempts INT DEFAULT 0
);

-- Enable Row Level Security (RLS)
ALTER TABLE phone_verifications ENABLE ROW LEVEL SECURITY;

-- Allow insert/select for verification
DROP POLICY IF EXISTS "Allow phone_verifications access" ON phone_verifications;
CREATE POLICY "Allow phone_verifications access" 
ON phone_verifications 
FOR ALL 
USING (true) 
WITH CHECK (true);


-- =====================================================
-- 3. STORE PHIL_SMS CONFIG IN APP_SETTINGS
-- =====================================================
INSERT INTO app_settings (setting_key, setting_value, setting_type)
VALUES 
  ('philsms_api_token', 'YOUR_PHIL_SMS_API_TOKEN_HERE', 'string'),
  ('philsms_sender_id', 'PhilSMS', 'string'),
  ('philsms_enabled', 'true', 'boolean')
ON CONFLICT (setting_key) 
DO UPDATE SET 
  setting_value = EXCLUDED.setting_value,
  setting_type = EXCLUDED.setting_type;
