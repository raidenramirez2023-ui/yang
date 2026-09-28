-- ==============================================================================
-- PHASE 2: Secure Admin Continuity & App Settings RLS Policies
-- Yang Chow Palace Restaurant Management System (YCPRMS)
-- ==============================================================================
--
-- SAFETY & COMPLIANCE VERIFICATION:
-- 1. NON-BREAKING: Preserves public SELECT on app_settings so customers can still
--    view operating hours, min/max guests, and reservation rules seamlessly.
-- 2. ZERO DATA LOSS: Does not drop, alter, or modify any existing tables or records.
-- 3. ACCESS RESTRICTION: Ensures only Admins, Backup Admins, and Developers can
--    UPDATE or INSERT continuity configurations, preventing customer tampering.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SECURE app_settings TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Clean up overly permissive or legacy manage policies
DROP POLICY IF EXISTS "Allow authenticated to manage app settings" ON public.app_settings;
DROP POLICY IF EXISTS "Developers and Admins manage app settings" ON public.app_settings;
DROP POLICY IF EXISTS "Staff and Admin all access app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Public read app_settings" ON public.app_settings;
DROP POLICY IF EXISTS "Allow public read app settings" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_public_read" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_admin_manage" ON public.app_settings;

-- 1.A. PUBLIC READ: Anyone can read app settings (needed for landing page & customer booking)
CREATE POLICY "app_settings_public_read"
ON public.app_settings
FOR SELECT
TO public
USING (true);

-- 1.B. AUTHORIZED WRITE: Only Admins, Backup Admins, and Developers can insert/update/delete
CREATE POLICY "app_settings_admin_manage"
ON public.app_settings
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE public.users.email = auth.email() 
        AND (
            public.users.role IN ('admin', 'developer') 
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE public.users.email = auth.email() 
        AND (
            public.users.role IN ('admin', 'developer') 
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
);

-- ------------------------------------------------------------------------------
-- 2. SECURE admin_continuity_records TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.admin_continuity_records ENABLE ROW LEVEL SECURITY;

-- Drop permissive check(true) policies
DROP POLICY IF EXISTS "admin_continuity_select" ON public.admin_continuity_records;
DROP POLICY IF EXISTS "admin_continuity_insert" ON public.admin_continuity_records;
DROP POLICY IF EXISTS "admin_continuity_update" ON public.admin_continuity_records;
DROP POLICY IF EXISTS "admin_continuity_secure_select" ON public.admin_continuity_records;
DROP POLICY IF EXISTS "admin_continuity_secure_insert" ON public.admin_continuity_records;
DROP POLICY IF EXISTS "admin_continuity_secure_update" ON public.admin_continuity_records;

-- 2.A. READ POLICY: Only Admins, Backup Admins, and Developers can view continuity records
CREATE POLICY "admin_continuity_secure_select"
ON public.admin_continuity_records
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE public.users.email = auth.email()
        AND (
            public.users.role IN ('admin', 'developer')
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
);

-- 2.B. INSERT POLICY: Only authorized governance actors can record designations or successions
CREATE POLICY "admin_continuity_secure_insert"
ON public.admin_continuity_records
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE public.users.email = auth.email()
        AND (
            public.users.role IN ('admin', 'developer')
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
);

-- 2.C. UPDATE POLICY: Only authorized administrators can update records
CREATE POLICY "admin_continuity_secure_update"
ON public.admin_continuity_records
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE public.users.email = auth.email()
        AND (
            public.users.role IN ('admin', 'developer')
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE public.users.email = auth.email()
        AND (
            public.users.role IN ('admin', 'developer')
            OR public.users.admin_tier IN ('primary', 'backup', 'co_admin')
        )
    )
);

-- ------------------------------------------------------------------------------
-- 3. REFRESH SUPABASE SCHEMA CACHE
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

-- Verification output
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    roles, 
    cmd 
FROM pg_policies 
WHERE tablename IN ('app_settings', 'admin_continuity_records')
ORDER BY tablename, policyname;
