-- Fix for PayMongo Integration - Add Payment Columns to Reservations Table
-- Run this in your Supabase SQL Editor

-- Add payment-related columns to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS payment_method TEXT,
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS payment_amount DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS transaction_id TEXT,
ADD COLUMN IF NOT EXISTS payment_date TIMESTAMP;

-- Optional: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reservations_payment_status ON reservations(payment_status);
CREATE INDEX IF NOT EXISTS idx_reservations_payment_method ON reservations(payment_method);

-- Verify columns were added
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'reservations' 
AND column_name IN ('payment_method', 'payment_status', 'payment_amount', 'transaction_id', 'payment_date')
ORDER BY column_name;
