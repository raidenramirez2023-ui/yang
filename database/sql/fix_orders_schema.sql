-- Run this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

-- Add missing columns to orders table to support notes and kitchen status
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS note text DEFAULT '',
ADD COLUMN IF NOT EXISTS kitchen_status text DEFAULT 'Pending',
ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'CASH',
ADD COLUMN IF NOT EXISTS amount_paid numeric(12, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS change_due numeric(12, 2) DEFAULT 0;

-- Optional: Update existing orders to have a status if they were null
UPDATE public.orders SET kitchen_status = 'Pending' WHERE kitchen_status IS NULL;
