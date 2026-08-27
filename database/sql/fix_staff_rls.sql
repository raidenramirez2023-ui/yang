-- =======================================================
-- YANG CHOW RESTAURANT - FIX STAFF TABLE RLS POLICIES
-- Run this in Supabase SQL Editor to allow saving staff
-- =======================================================

-- 1. Ensure staff table exists with proper schema
CREATE TABLE IF NOT EXISTS public.staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  role TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 2,
  status TEXT NOT NULL DEFAULT 'Active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing restrictive policies on staff table
DROP POLICY IF EXISTS "Public can view staff" ON public.staff;
DROP POLICY IF EXISTS "Allow read staff" ON public.staff;
DROP POLICY IF EXISTS "Allow insert staff" ON public.staff;
DROP POLICY IF EXISTS "Allow update staff" ON public.staff;
DROP POLICY IF EXISTS "Allow delete staff" ON public.staff;
DROP POLICY IF EXISTS "Staff all access" ON public.staff;

-- 4. Create open/permissive policies so Admin can save, update, delete staff
CREATE POLICY "Staff all access" 
ON public.staff 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- 5. Also fix app_settings RLS policy if needed
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all app_settings" ON public.app_settings;
CREATE POLICY "Allow all app_settings" 
ON public.app_settings 
FOR ALL 
USING (true) 
WITH CHECK (true);
