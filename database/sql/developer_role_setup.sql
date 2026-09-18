-- ==============================================================================
-- Developer / IT Role Setup & RLS Policy Guide
-- Yang Chow Palace Restaurant Management System (YCPRMS)
-- ==============================================================================
--
-- ARCHITECTURAL SEPARATION:
-- Business Operations: Admin, Staff, Chef, Inventory
-- Technical Maintenance: Developer / IT
--
-- This script contains minimal, non-breaking SQL statements for configuring
-- developer accounts and verifying technical maintenance access.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ASSIGN DEVELOPER ROLE TO AN IT ACCOUNT
-- Replace 'your_developer_email@example.com' with the actual developer email.
-- ------------------------------------------------------------------------------

-- Example: Update an existing account to developer role
UPDATE public.users 
SET role = 'developer', updated_at = NOW() 
WHERE email = 'your_developer_email@example.com';

-- Or create a developer user record if not yet existing
INSERT INTO public.users (email, role, firstname, lastname, created_at, updated_at)
VALUES (
    'your_developer_email@example.com', 
    'developer', 
    'IT', 
    'Engineer', 
    NOW(), 
    NOW()
)
ON CONFLICT (email) DO UPDATE 
SET role = 'developer', updated_at = NOW();


-- ------------------------------------------------------------------------------
-- 2. VERIFY DEVELOPER ACCOUNTS
-- ------------------------------------------------------------------------------
SELECT id, email, role, firstname, lastname, created_at, updated_at 
FROM public.users 
WHERE role = 'developer'
ORDER BY created_at DESC;


-- ------------------------------------------------------------------------------
-- 3. ENSURE DEVELOPER CAN MANAGE APP_SETTINGS (MAINTENANCE MODE)
-- (Run this if app_settings RLS restricts non-admin roles)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    -- Allow Developers and Admins to manage app_settings
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' AND tablename = 'app_settings'
    ) THEN
        DROP POLICY IF EXISTS "Developers and Admins manage app settings" ON public.app_settings;
        CREATE POLICY "Developers and Admins manage app settings"
        ON public.app_settings
        FOR ALL
        TO authenticated
        USING (
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE public.users.email = auth.email() 
                AND public.users.role IN ('admin', 'developer')
            )
        )
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.users 
                WHERE public.users.email = auth.email() 
                AND public.users.role IN ('admin', 'developer')
            )
        );
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 4. VERIFY APP SETTINGS POLICIES
-- ------------------------------------------------------------------------------
SELECT policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'app_settings';
