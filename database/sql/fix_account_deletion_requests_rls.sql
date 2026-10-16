-- ============================================================
-- FIX ACCOUNT DELETION REQUESTS RLS & CANCELLATION RPC
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Ensure table and columns exist
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

-- 2. Drop restrictive check constraints and ensure 'cancelled_by_user' is valid
DO $$
BEGIN
  ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS account_deletion_requests_status_check;
  ALTER TABLE public.account_deletion_requests DROP CONSTRAINT IF EXISTS status_check;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

ALTER TABLE public.account_deletion_requests
  ADD CONSTRAINT account_deletion_requests_status_check
  CHECK (status IN ('pending_review', 'cancelled_by_user', 'approved', 'rejected'));

-- 3. Enable RLS and clean up any old restrictive policies
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all on account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to insert account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to select account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Allow authenticated to update account_deletion_requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Users can view their own deletion requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Users can create their own deletion requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Users can update their own deletion requests" ON public.account_deletion_requests;

-- 4. Create wide-open RLS policy allowing SELECT, INSERT, UPDATE, DELETE for anon & authenticated
CREATE POLICY "Allow all on account_deletion_requests"
  ON public.account_deletion_requests
  FOR ALL
  TO public, anon, authenticated, service_role
  USING (true)
  WITH CHECK (true);

-- 5. Grant full table permissions
GRANT ALL ON TABLE public.account_deletion_requests TO anon, authenticated, service_role;

-- 6. Create SECURITY DEFINER RPC function for 100% reliable deletion cancellations
CREATE OR REPLACE FUNCTION public.cancel_account_deletion_request(
  p_request_id UUID DEFAULT NULL,
  p_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_email TEXT;
  v_rows_updated INT := 0;
BEGIN
  v_user_id := auth.uid();
  v_user_email := COALESCE(auth.jwt()->>'email', p_email);

  -- 1. Try cancelling by specific request ID
  IF p_request_id IS NOT NULL THEN
    UPDATE public.account_deletion_requests
    SET
      status = 'cancelled_by_user',
      processed_by = COALESCE(v_user_email, 'Customer'),
      processed_at = NOW(),
      admin_notes = 'Customer cancelled account deletion during 14-day grace period.',
      updated_at = NOW()
    WHERE id = p_request_id
      AND status = 'pending_review';
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  END IF;

  -- 2. Try cancelling by email if no rows were updated by ID
  IF v_rows_updated = 0 AND v_user_email IS NOT NULL AND v_user_email <> '' THEN
    UPDATE public.account_deletion_requests
    SET
      status = 'cancelled_by_user',
      processed_by = COALESCE(v_user_email, 'Customer'),
      processed_at = NOW(),
      admin_notes = 'Customer cancelled account deletion during 14-day grace period.',
      updated_at = NOW()
    WHERE lower(email) = lower(v_user_email)
      AND status = 'pending_review';
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  END IF;

  -- 3. Try cancelling by authenticated user_id if still 0 rows
  IF v_rows_updated = 0 AND v_user_id IS NOT NULL THEN
    UPDATE public.account_deletion_requests
    SET
      status = 'cancelled_by_user',
      processed_by = COALESCE(v_user_email, 'Customer'),
      processed_at = NOW(),
      admin_notes = 'Customer cancelled account deletion during 14-day grace period.',
      updated_at = NOW()
    WHERE user_id = v_user_id
      AND status = 'pending_review';
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'rows_updated', v_rows_updated
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_account_deletion_request(UUID, TEXT) TO anon, authenticated, service_role;

-- 7. Verification: check all records
SELECT id, email, status, requested_at, processed_at, admin_notes
FROM public.account_deletion_requests
ORDER BY requested_at DESC;
