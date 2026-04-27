-- Add payment_status column to orders table
-- Run this in your Supabase SQL Editor to fix POS connection to chef dashboard

-- Add payment_status column if it doesn't exist
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'paid';

-- Add other missing columns that POS system uses
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS kitchen_status TEXT DEFAULT 'Pending',
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'CASH',
ADD COLUMN IF NOT EXISTS amount_paid DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS change_due DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS note TEXT,
ADD COLUMN IF NOT EXISTS table_number TEXT,
ADD COLUMN IF NOT EXISTS number_of_guests INTEGER,
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_label TEXT DEFAULT 'None',
ADD COLUMN IF NOT EXISTS discount_name TEXT,
ADD COLUMN IF NOT EXISTS discount_address TEXT;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_kitchen_status ON public.orders(kitchen_status);

-- Verify columns were added
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
ORDER BY column_name;
