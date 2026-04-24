-- Run this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

-- Add discount-related columns to the orders table
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS discount_amount numeric(12, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_label text DEFAULT 'None',
ADD COLUMN IF NOT EXISTS discount_name text DEFAULT '',
ADD COLUMN IF NOT EXISTS discount_address text DEFAULT '';

-- Optional: Update total_amount comments to clarify it is the final price after discount
COMMENT ON COLUMN public.orders.total_amount IS 'The final amount paid after any discounts.';
