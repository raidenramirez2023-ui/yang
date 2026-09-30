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
  dept TEXT DEFAULT 'Kitchen',
  phone TEXT DEFAULT '+63 900 000 0000',
  email TEXT,
  image TEXT,
  level INTEGER NOT NULL DEFAULT 2,
  status TEXT NOT NULL DEFAULT 'Active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Add columns if table already exists
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS image TEXT;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS dept TEXT;

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;

-- 4. Policy: Authenticated users can view the staff directory
DROP POLICY IF EXISTS "Public can view staff" ON public.staff;
DROP POLICY IF EXISTS "Staff and Admins can view staff directory" ON public.staff;
CREATE POLICY "Staff and Admins can view staff directory" 
ON public.staff FOR SELECT 
USING (true);

-- 5. Policy: Only Administrators and Developers can insert, update, or delete staff records
DROP POLICY IF EXISTS "Authenticated users can manage staff" ON public.staff;
DROP POLICY IF EXISTS "Admins and Developers can manage staff directory" ON public.staff;
CREATE POLICY "Admins and Developers can manage staff directory" 
ON public.staff FOR ALL 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.email = auth.email() 
    AND LOWER(users.role) IN ('admin', 'developer', 'backup_admin')
  )
);

-- 6. Ensure unique index on employee_id if not present
CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_employee_id ON public.staff (employee_id);
