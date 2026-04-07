-- ========================================================
-- REPAIR SCRIPT FOR CHEF DASHBOARD
-- Run this in your Supabase SQL Editor to fix 
-- the 'kitchen_order_status' not found error.
-- ========================================================

-- 1. Ensure kitchen_requests exists
CREATE TABLE IF NOT EXISTS public.kitchen_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  item_name TEXT NOT NULL,
  quantity_needed INTEGER NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  priority TEXT NOT NULL DEFAULT 'Normal'
    CHECK (priority IN ('Low', 'Normal', 'High', 'Urgent')),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending', 'Approved', 'Rejected')),
  requested_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Ensure kitchen_order_status exists
-- We use TEXT for order_id to be compatible with both UUID and INT id types
CREATE TABLE IF NOT EXISTS public.kitchen_order_status (
  order_id TEXT PRIMARY KEY, 
  status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending', 'Preparing', 'Ready', 'Done')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS for both
ALTER TABLE public.kitchen_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_order_status ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies (ignore if they already exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'kitchen_requests' AND policyname = 'Allow all for authenticated'
    ) THEN
        CREATE POLICY "Allow all for authenticated" ON public.kitchen_requests
        FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'kitchen_order_status' AND policyname = 'Allow all for authenticated'
    ) THEN
        CREATE POLICY "Allow all for authenticated" ON public.kitchen_order_status
        FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
    END IF;
END
$$;

-- 5. Add indexes
CREATE INDEX IF NOT EXISTS kitchen_requests_status_idx ON public.kitchen_requests(status);
CREATE INDEX IF NOT EXISTS kitchen_order_status_status_idx ON public.kitchen_order_status(status);
