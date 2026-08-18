-- ============================================
-- RESCHEDULE REQUESTS SYSTEM - DATABASE SETUP
-- Run this in your Supabase SQL Editor
-- ============================================

-- 1. Create reschedule_requests table
CREATE TABLE IF NOT EXISTS public.reschedule_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Reference to the reservation
  reservation_id UUID NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  
  -- Customer info
  customer_id TEXT,
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  
  -- Current / Old schedule
  old_date TEXT NOT NULL,
  old_time TEXT NOT NULL,
  old_duration INTEGER,
  old_guests INTEGER,
  
  -- Requested new schedule
  new_date TEXT NOT NULL,
  new_time TEXT NOT NULL,
  new_duration INTEGER,
  new_guests INTEGER,
  
  -- Request details
  reason TEXT,
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  
  -- Admin review details
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  admin_notes TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add reschedule_status to reservations table if not existing
ALTER TABLE public.reservations
ADD COLUMN IF NOT EXISTS reschedule_status TEXT DEFAULT 'none';
-- Possible values: 'none', 'pending_approval', 'rescheduled', 'reschedule_rejected'

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_reschedule_reservation ON public.reschedule_requests(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reschedule_status ON public.reschedule_requests(status);
CREATE INDEX IF NOT EXISTS idx_reschedule_customer_email ON public.reschedule_requests(customer_email);
CREATE INDEX IF NOT EXISTS idx_reschedule_created ON public.reschedule_requests(created_at DESC);

-- 4. Enable Row Level Security
ALTER TABLE public.reschedule_requests ENABLE ROW LEVEL SECURITY;

-- Allow all operations (matching existing pattern used by orders/reservations/refunds)
CREATE POLICY "Allow all on reschedule_requests" ON public.reschedule_requests
  FOR ALL USING (true) WITH CHECK (true);

-- 5. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_reschedule_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reschedule_requests_updated_at
  BEFORE UPDATE ON public.reschedule_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_reschedule_requests_updated_at();
