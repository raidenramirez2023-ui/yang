-- ============================================================
-- ACCOUNT DELETION REQUESTS & 14-DAY GRACE PERIOD SETUP
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Create table if not existing
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  email TEXT NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'pending_review',
  admin_notes TEXT,
  processed_by TEXT,
  processed_at TIMESTAMPTZ,
  grace_period_expires_at TIMESTAMPTZ,
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. If table already exists, ensure all required columns exist
ALTER TABLE public.account_deletion_requests
  ADD COLUMN IF NOT EXISTS user_id UUID,
  ADD COLUMN IF NOT EXISTS reason TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending_review',
  ADD COLUMN IF NOT EXISTS admin_notes TEXT,
  ADD COLUMN IF NOT EXISTS processed_by TEXT,
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS grace_period_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS requested_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. Drop any old/restrictive check constraint on status so 'cancelled_by_user' is accepted
DO $$
BEGIN
  ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS account_deletion_requests_status_check;
  ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS status_check;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Add updated check constraint that permits 'cancelled_by_user'
ALTER TABLE public.account_deletion_requests
  ADD CONSTRAINT account_deletion_requests_status_check
  CHECK (status IN ('pending_review', 'cancelled_by_user', 'approved', 'rejected'));

-- 4. Enable Row Level Security (RLS) & Grant Full Access Policies
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all on account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to insert account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to select account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to update account_deletion_requests" ON public.account_deletion_requests;

-- Allow SELECT, INSERT, UPDATE, DELETE for all roles
CREATE POLICY "Allow all on account_deletion_requests" ON public.account_deletion_requests
  FOR ALL USING (true) WITH CHECK (true);

-- 5. Grant permissions to anon & authenticated roles
GRANT ALL ON TABLE public.account_deletion_requests TO anon, authenticated, service_role;

-- 6. Add performance indexes
CREATE INDEX IF NOT EXISTS idx_account_deletion_email ON public.account_deletion_requests(email);
CREATE INDEX IF NOT EXISTS idx_account_deletion_status ON public.account_deletion_requests(status);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requested_at ON public.account_deletion_requests(requested_at DESC);
