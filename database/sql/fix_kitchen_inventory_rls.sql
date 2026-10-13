-- ============================================================================
-- FIX RLS POLICIES & REALTIME FOR KITCHEN_INVENTORY (Yang Chow RMS)
-- ============================================================================
-- Problem:
-- When requests are approved in the PagsanjanINV Dashboard, the request status
-- changes to "Approved" in kitchen_requests, but the stock in kitchen_inventory
-- remains 0 on the Chef Kitchen Display (/chef/stock).
--
-- Root Cause:
-- 1. kitchen_inventory only had legacy RLS policies ("Allow authenticated users to update kitchen_inventory")
--    which used USING (auth.role() = 'authenticated') without WITH CHECK (true) and without
--    TO authenticated. Under PostgreSQL RLS, if an UPDATE does not pass the USING condition,
--    it silently updates 0 rows without throwing an error. PostgREST returns 200/204,
--    so Dart thinks it succeeded and marks kitchen_requests as "Approved", but
--    kitchen_inventory was never actually updated!
-- 2. fix_pagsanjaninv_and_chef_rls.sql previously fixed kitchen_requests and
--    stock_transactions, but missed kitchen_inventory.
-- 3. kitchen_inventory was not guaranteed to be in the supabase_realtime publication.
-- ============================================================================

-- 1. Ensure table has RLS enabled
ALTER TABLE public.kitchen_inventory ENABLE ROW LEVEL SECURITY;

-- 2. Drop all legacy/restrictive policies
DROP POLICY IF EXISTS "Allow authenticated users to read kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow authenticated users to insert kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow authenticated users to update kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to manage kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to read kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to insert kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to update kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to delete kitchen_inventory" ON public.kitchen_inventory;
DROP POLICY IF EXISTS "Allow public read access for kitchen_inventory" ON public.kitchen_inventory;

-- 3. Grant full access to all authenticated users (chef, pagsanjaninv, inventory staff, admin)
CREATE POLICY "Allow all authenticated users to manage kitchen_inventory"
    ON public.kitchen_inventory FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- 4. Allow public read access (for anon users / customer menu checks if needed)
CREATE POLICY "Allow public read access for kitchen_inventory"
    ON public.kitchen_inventory FOR SELECT
    TO anon
    USING (true);

-- 5. Enable Realtime Replication for kitchen_inventory so the Chef Display updates live
ALTER TABLE public.kitchen_inventory REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'kitchen_inventory'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen_inventory;
    END IF;
END $$;

-- 6. Verification
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'kitchen_inventory';
