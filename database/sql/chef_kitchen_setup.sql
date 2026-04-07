-- =========================================
-- CHEF KITCHEN SETUP
-- =========================================

-- 1. kitchen_requests: chef sends ingredient requests to inventory staff
CREATE TABLE IF NOT EXISTS kitchen_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  item_name TEXT NOT NULL,
  quantity_needed INTEGER NOT NULL,
  unit TEXT NOT NULL DEFAULT 'pcs',
  priority TEXT NOT NULL DEFAULT 'Normal'
    CHECK (priority IN ('Low', 'Normal', 'High', 'Urgent')),
  note TEXT,
  status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending', 'Approved', 'Rejected')),
  requested_by TEXT,   -- chef's email
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE kitchen_requests ENABLE ROW LEVEL SECURITY;

-- 3. Policy: any authenticated user can read/write (chef and inventory staff)
CREATE POLICY "Authenticated users can manage kitchen_requests"
  ON kitchen_requests
  FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- 4. kitchen_order_status: track chef's status for each order
--    (Pending, Preparing, Ready, Done)
--    NOTE: orders are already stored in the 'orders' table.
--    We add a separate column by creating a companion table so we
--    don't alter the existing orders schema.
CREATE TABLE IF NOT EXISTS kitchen_order_status (
  order_id UUID PRIMARY KEY,           -- references orders.id
  status TEXT NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending', 'Preparing', 'Ready', 'Done')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE kitchen_order_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage kitchen_order_status"
  ON kitchen_order_status
  FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS kitchen_requests_status_idx ON kitchen_requests(status);
CREATE INDEX IF NOT EXISTS kitchen_requests_created_at_idx ON kitchen_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS kitchen_order_status_status_idx ON kitchen_order_status(status);
