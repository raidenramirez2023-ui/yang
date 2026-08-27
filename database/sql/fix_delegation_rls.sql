-- ============================================================
-- YANG CHOW RESTAURANT - Fix app_settings for Staff Delegation
-- Run this in Supabase Dashboard -> SQL Editor -> Run
-- ============================================================

-- 1. Ensure app_settings table exists
CREATE TABLE IF NOT EXISTS public.app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  setting_type TEXT DEFAULT 'string',
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 3. Drop any conflicting old policies on app_settings
DROP POLICY IF EXISTS "Allow all app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow read app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_all" ON public.app_settings;
DROP POLICY IF EXISTS "Authenticated users can read settings" ON public.app_settings;
DROP POLICY IF EXISTS "Authenticated users can write settings" ON public.app_settings;
DROP POLICY IF EXISTS "Staff and Admin all access app_settings" ON public.app_settings;

-- 4. Create open/permissive policy for authenticated users (Staff & Admin)
--    so Staff can READ and Admin can UPDATE settings without RLS blocking
CREATE POLICY "Staff and Admin all access app_settings"
ON public.app_settings
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. Also allow public read (anon key fallback)
CREATE POLICY "Public read app_settings"
ON public.app_settings
FOR SELECT
TO anon
USING (true);

-- 6. Insert the default staff_delegation_mode row if not present
INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description)
VALUES (
  'staff_delegation_mode',
  'false',
  'boolean',
  'Enable staff POS to process and approve reservations, payment slips, and balances during Admin rest days'
)
ON CONFLICT (setting_key) DO UPDATE
SET updated_at = NOW();

-- 7. Check current values in app_settings
SELECT setting_key, setting_value, setting_type, updated_at
FROM public.app_settings
WHERE setting_key = 'staff_delegation_mode';
