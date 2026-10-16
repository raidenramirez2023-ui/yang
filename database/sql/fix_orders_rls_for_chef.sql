-- ============================================================================
-- Fix RLS Policies for Orders & Order Items (Chef Kitchen Display & POS)
-- ============================================================================
-- Problem:
-- When Chef clicks "START PREP" or "MARK READY" on POS orders, the kitchen_status
-- update on public.orders was silently blocked by Row Level Security (RLS).
-- Because RLS blocked the update, the status remained 'Pending' in the database.
-- As soon as a new order (#247) was inserted, the realtime stream reloaded all orders
-- from Supabase and reverted order #246 back to 'START PREP'.
--
-- Solution:
-- Enable full read, insert, and update policies for orders and order_items.
-- ============================================================================

-- 1. Ensure RLS is enabled
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- 2. Drop any previous conflicting / restrictive policies on orders
DROP POLICY IF EXISTS "Allow all on orders" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated to view orders" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated to update orders" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated to insert orders" ON public.orders;
DROP POLICY IF EXISTS "Allow authenticated to manage orders" ON public.orders;
DROP POLICY IF EXISTS "Allow public to read orders" ON public.orders;
DROP POLICY IF EXISTS "Staff all access orders" ON public.orders;

-- 3. Create comprehensive open policies on orders for authenticated & anon portal roles
CREATE POLICY "Allow all on orders"
    ON public.orders FOR ALL
    TO public
    USING (true)
    WITH CHECK (true);

-- 4. Drop and recreate policies on order_items
DROP POLICY IF EXISTS "Allow all on order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated to view order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated to update order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated to insert order_items" ON public.order_items;
DROP POLICY IF EXISTS "Allow authenticated to manage order_items" ON public.order_items;

CREATE POLICY "Allow all on order_items"
    ON public.order_items FOR ALL
    TO public
    USING (true)
    WITH CHECK (true);

-- 5. Verify the active policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename IN ('orders', 'order_items');
