-- ============================================
-- REFUNDS SYSTEM - DATABASE SETUP
-- Run this in your Supabase SQL Editor
-- ============================================

-- 1. Create refunds table
CREATE TABLE IF NOT EXISTS public.refunds (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Source identification (which transaction is being refunded)
  source_table TEXT NOT NULL,              -- 'orders', 'reservations', 'advance_orders'
  source_id UUID NOT NULL,                 -- ID from the source table
  transaction_id TEXT,                     -- POS transaction_id ('001', '002', etc.)
  
  -- Customer info
  customer_email TEXT,
  customer_name TEXT NOT NULL,
  
  -- Refund details
  refund_type TEXT NOT NULL,               -- 'full', 'partial', 'item'
  refund_method TEXT NOT NULL DEFAULT 'cash', -- 'cash', 'paymongo'
  refund_reason TEXT NOT NULL,
  refund_amount DECIMAL(12,2) NOT NULL,
  original_amount DECIMAL(12,2) NOT NULL,
  
  -- For item-level POS refunds
  refunded_items JSONB,                    -- [{item_name, quantity, unit_price, subtotal}]
  
  -- For PayMongo refunds
  paymongo_payment_id TEXT,                -- Original payment ID (pay_xxx)
  paymongo_refund_id TEXT,                 -- PayMongo refund ID after processing
  
  -- Workflow
  status TEXT DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'completed', 'rejected')),
  requested_by TEXT NOT NULL,              -- email of who initiated
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_by TEXT,                        -- admin email who approved/rejected
  reviewed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  admin_notes TEXT,                        -- admin remarks on approval/rejection
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Add refund_status to orders table
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS refund_status TEXT DEFAULT 'none';
-- Values: 'none', 'partial_refund', 'full_refund'

-- 3. Add paymongo_payment_id to reservations & advance_orders
-- (needed to call PayMongo Refund API with the original payment_id)
ALTER TABLE public.reservations
ADD COLUMN IF NOT EXISTS paymongo_payment_id TEXT;

ALTER TABLE public.reservations
ADD COLUMN IF NOT EXISTS payment_option TEXT DEFAULT 'half';

ALTER TABLE public.advance_orders
ADD COLUMN IF NOT EXISTS paymongo_payment_id TEXT;

-- 4. Add refund passcode to app_settings
INSERT INTO app_settings (setting_key, setting_value, setting_type, description)
VALUES ('refund_passcode', '1234', 'string', 'Admin passcode required to confirm POS refunds')
ON CONFLICT (setting_key) DO NOTHING;

-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_refunds_source ON public.refunds(source_table, source_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON public.refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_customer ON public.refunds(customer_email);
CREATE INDEX IF NOT EXISTS idx_refunds_created ON public.refunds(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refunds_completed ON public.refunds(completed_at);
CREATE INDEX IF NOT EXISTS idx_orders_refund_status ON public.orders(refund_status);

-- 6. Enable Row Level Security
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

-- Allow all operations (matching existing pattern used by orders/reservations)
CREATE POLICY "Allow all on refunds" ON public.refunds
  FOR ALL USING (true) WITH CHECK (true);

-- 7. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_refunds_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_refunds_updated_at
  BEFORE UPDATE ON public.refunds
  FOR EACH ROW
  EXECUTE FUNCTION update_refunds_updated_at();

-- 8. Create PayMongo refund RPC function (server-side, uses secret key)
-- NOTE: Requires the http extension. If not enabled, run:
--   CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;
CREATE OR REPLACE FUNCTION process_paymongo_refund(
  p_payment_id TEXT,
  p_amount INTEGER,           -- amount in centavos (e.g., 10000 = PHP 100.00)
  p_reason TEXT DEFAULT 'others',
  p_notes TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  secret_key TEXT;
  response extensions.http_response;
  result JSONB;
BEGIN
  -- Get PayMongo secret key from Supabase vault/config
  secret_key := current_setting('app.paymongo_secret_key', true);
  
  IF secret_key IS NULL OR secret_key = '' THEN
    RAISE EXCEPTION 'PayMongo secret key not configured. Set it via: ALTER DATABASE postgres SET app.paymongo_secret_key = ''sk_test_xxx'';';
  END IF;

  -- Call PayMongo Refunds API
  SELECT * INTO response
  FROM extensions.http((
    'POST',
    'https://api.paymongo.com/v1/refunds',
    ARRAY[
      extensions.http_header('Content-Type', 'application/json'),
      extensions.http_header('Authorization', 'Basic ' || encode(convert_to(secret_key || ':', 'UTF8'), 'base64'))
    ],
    'application/json',
    jsonb_build_object(
      'data', jsonb_build_object(
        'attributes', jsonb_build_object(
          'amount', p_amount,
          'payment_id', p_payment_id,
          'reason', p_reason,
          'notes', p_notes
        )
      )
    )::text
  ));

  -- Parse the response
  result := response.content::jsonb;
  
  -- Check for errors in the response
  IF result ? 'errors' THEN
    RAISE EXCEPTION 'PayMongo refund failed: %', result->'errors'->0->>'detail';
  END IF;

  RETURN result;
END;
$$;

-- 9. Verify setup
SELECT 'Refunds table created successfully' AS status;
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'refunds' AND table_schema = 'public'
ORDER BY ordinal_position;
