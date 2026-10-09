-- ============================================================================
-- Fix RLS Policies for PagsanjanINV & Chef Portals (Yang Chow RMS)
-- ============================================================================
-- Problem:
-- When users log in as pagsanjaninv@gmail.com (role: 'inventory staff') or
-- chefycp2026@gmail.com (role: 'chef'), the database RLS policies on
-- 'stock_transactions', 'kitchen_requests', 'petty_cash_fund', and 'reservations'
-- were restricting access to only users with role = 'admin'.
--
-- As a result:
-- 1. PagsanjanINV saw 0 stock transactions, 0 kitchen requests, 0 petty cash.
-- 2. Chef saw "No Upcoming Events" in the Events tab and no event cooking tickets,
--    even though event reservations (e.g. Sir Jaime Rabi Birthday Party) exist in DB!
--
-- Solution:
-- Update RLS policies to allow all authenticated portal roles (inventory staff,
-- chef, staff, admin, developer) full read and write access to operations tables.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. STOCK TRANSACTIONS (PagsanjanINV Dashboard, Inventory Room, Wastage Logs)
-- ----------------------------------------------------------------------------
ALTER TABLE public.stock_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow authenticated users to insert stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow users to update their own stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow users to update their own and petty cash stock_transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow admins to delete any stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow all authenticated users to read stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow all authenticated users to insert stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow all authenticated users to update stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow all authenticated users to delete stock transactions" ON public.stock_transactions;
DROP POLICY IF EXISTS "Allow all for authenticated" ON public.stock_transactions;

CREATE POLICY "Allow all authenticated users to read stock transactions"
    ON public.stock_transactions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow all authenticated users to insert stock transactions"
    ON public.stock_transactions FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow all authenticated users to update stock transactions"
    ON public.stock_transactions FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all authenticated users to delete stock transactions"
    ON public.stock_transactions FOR DELETE
    TO authenticated
    USING (true);

-- ----------------------------------------------------------------------------
-- 2. KITCHEN REQUESTS (Chef Ingredient Requests & PagsanjanINV Approval)
-- ----------------------------------------------------------------------------
ALTER TABLE public.kitchen_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can manage kitchen_requests" ON public.kitchen_requests;
DROP POLICY IF EXISTS "Allow all for authenticated" ON public.kitchen_requests;
DROP POLICY IF EXISTS "Allow all authenticated users to read kitchen_requests" ON public.kitchen_requests;
DROP POLICY IF EXISTS "Allow all authenticated users to insert kitchen_requests" ON public.kitchen_requests;
DROP POLICY IF EXISTS "Allow all authenticated users to update kitchen_requests" ON public.kitchen_requests;
DROP POLICY IF EXISTS "Allow all authenticated users to delete kitchen_requests" ON public.kitchen_requests;

CREATE POLICY "Allow all authenticated users to read kitchen_requests"
    ON public.kitchen_requests FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow all authenticated users to insert kitchen_requests"
    ON public.kitchen_requests FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow all authenticated users to update kitchen_requests"
    ON public.kitchen_requests FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow all authenticated users to delete kitchen_requests"
    ON public.kitchen_requests FOR DELETE
    TO authenticated
    USING (true);

-- ----------------------------------------------------------------------------
-- 3. KITCHEN ORDER STATUS (Chef Order Progress: Preparing, Ready, Done)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'kitchen_order_status') THEN
        ALTER TABLE public.kitchen_order_status ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Authenticated users can manage kitchen_order_status" ON public.kitchen_order_status;
        DROP POLICY IF EXISTS "Allow all for authenticated" ON public.kitchen_order_status;
        DROP POLICY IF EXISTS "Allow all authenticated users to manage kitchen_order_status" ON public.kitchen_order_status;
        
        CREATE POLICY "Allow all authenticated users to manage kitchen_order_status"
            ON public.kitchen_order_status FOR ALL
            TO authenticated
            USING (true)
            WITH CHECK (true);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 4. PETTY CASH FUND & EXPENSES (PagsanjanINV & Admin Management)
-- ----------------------------------------------------------------------------
ALTER TABLE public.petty_cash_fund ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read petty_cash_fund" ON public.petty_cash_fund;
DROP POLICY IF EXISTS "Allow admins to insert petty_cash_fund" ON public.petty_cash_fund;
DROP POLICY IF EXISTS "Allow admins to update petty_cash_fund" ON public.petty_cash_fund;
DROP POLICY IF EXISTS "Allow all authenticated to read petty_cash_fund" ON public.petty_cash_fund;
DROP POLICY IF EXISTS "Allow all authenticated to manage petty_cash_fund" ON public.petty_cash_fund;

CREATE POLICY "Allow all authenticated to read petty_cash_fund"
    ON public.petty_cash_fund FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow all authenticated to manage petty_cash_fund"
    ON public.petty_cash_fund FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

ALTER TABLE public.petty_cash_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read petty_cash_expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow authenticated users to insert petty_cash_expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow users to update their own expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow admins to approve expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow admins to delete expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow all authenticated to read petty_cash_expenses" ON public.petty_cash_expenses;
DROP POLICY IF EXISTS "Allow all authenticated to manage petty_cash_expenses" ON public.petty_cash_expenses;

CREATE POLICY "Allow all authenticated to read petty_cash_expenses"
    ON public.petty_cash_expenses FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow all authenticated to manage petty_cash_expenses"
    ON public.petty_cash_expenses FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 5. INVENTORY TABLE (Ensure all authenticated can read & manage)
-- ----------------------------------------------------------------------------
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated users to read inventory" ON public.inventory;
DROP POLICY IF EXISTS "Allow authenticated users to manage inventory" ON public.inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to read inventory" ON public.inventory;
DROP POLICY IF EXISTS "Allow all authenticated users to manage inventory" ON public.inventory;
DROP POLICY IF EXISTS "Allow public read access for inventory" ON public.inventory;

CREATE POLICY "Allow all authenticated users to read inventory"
    ON public.inventory FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow all authenticated users to manage inventory"
    ON public.inventory FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow public read so landing page / menu can access basic ingredient info if needed
CREATE POLICY "Allow public read access for inventory"
    ON public.inventory FOR SELECT
    TO anon
    USING (true);

-- ----------------------------------------------------------------------------
-- 6. RESERVATIONS (Chef Kitchen Events & Staff/Admin Operations)
-- ----------------------------------------------------------------------------
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin can view all reservations" ON public.reservations;
DROP POLICY IF EXISTS "Admin can update all reservations" ON public.reservations;
DROP POLICY IF EXISTS "Allow authenticated to view reservations" ON public.reservations;
DROP POLICY IF EXISTS "Allow authenticated to update reservations" ON public.reservations;
DROP POLICY IF EXISTS "Allow staff and chef to view reservations" ON public.reservations;
DROP POLICY IF EXISTS "Allow staff and chef to update reservations" ON public.reservations;

-- Allow all authenticated portal users (Chef, Staff, Admin) to view reservations
CREATE POLICY "Allow authenticated to view reservations"
    ON public.reservations FOR SELECT
    TO authenticated
    USING (true);

-- Allow all authenticated portal users to update reservations (e.g. kitchen_status by Chef)
CREATE POLICY "Allow authenticated to update reservations"
    ON public.reservations FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Allow all authenticated portal users to insert reservations
CREATE POLICY "Allow authenticated to insert reservations"
    ON public.reservations FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 7. ADVANCE ORDERS TABLE (Chef Kitchen Display Orders)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'advance_orders') THEN
        ALTER TABLE public.advance_orders ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Allow authenticated to view advance_orders" ON public.advance_orders;
        DROP POLICY IF EXISTS "Allow authenticated to manage advance_orders" ON public.advance_orders;
        
        CREATE POLICY "Allow authenticated to view advance_orders"
            ON public.advance_orders FOR SELECT
            TO authenticated
            USING (true);
            
        CREATE POLICY "Allow authenticated to manage advance_orders"
            ON public.advance_orders FOR ALL
            TO authenticated
            USING (true)
            WITH CHECK (true);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 8. VERIFICATION
-- ----------------------------------------------------------------------------
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd 
FROM pg_policies 
WHERE tablename IN (
    'stock_transactions', 
    'kitchen_requests', 
    'petty_cash_fund', 
    'petty_cash_expenses', 
    'inventory', 
    'reservations',
    'advance_orders'
)
ORDER BY tablename, cmd;
