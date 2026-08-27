-- =======================================================
-- YANG CHOW RESTAURANT - STAFF TABLE SETUP (SUPABASE)
-- =======================================================

-- 1. Create staff table matching live database schema
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

-- 3. Policy: Public & Authenticated users can read staff
DROP POLICY IF EXISTS "Public can view staff" ON public.staff;
CREATE POLICY "Public can view staff" 
ON public.staff FOR SELECT USING (true);

-- 4. Policy: Authenticated users can insert/update/delete staff
DROP POLICY IF EXISTS "Authenticated users can manage staff" ON public.staff;
CREATE POLICY "Authenticated users can manage staff" 
ON public.staff FOR ALL USING (true);

-- 5. Ensure unique index on employee_id if not present
CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_employee_id ON public.staff (employee_id);
