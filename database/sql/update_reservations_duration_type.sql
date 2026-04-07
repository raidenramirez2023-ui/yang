-- Run this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

-- Change duration_hours from INTEGER to NUMERIC to support 30-minute increments (e.g., 2.5 hours)
ALTER TABLE public.reservations 
ALTER COLUMN duration_hours TYPE numeric(4, 2);

-- Update existing records (if any)
-- (No conversion needed as INTEGER is compatible with NUMERIC)
