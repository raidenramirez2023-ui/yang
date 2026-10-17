-- ============================================================================
-- Migration: Add prep_started_at column to orders table
-- Tracks when kitchen cook clicks "START PREP" for 15-20 min target preparation
-- ============================================================================

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS prep_started_at TIMESTAMPTZ;

COMMENT ON COLUMN public.orders.prep_started_at IS 
'Timestamp when the kitchen chef started preparation (START PREP) for measuring the 15-20 minute target food preparation turnaround time.';

-- Index for querying orders by preparation start time
CREATE INDEX IF NOT EXISTS idx_orders_prep_started_at ON public.orders(prep_started_at);
