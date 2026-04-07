-- Add table number field to orders table
-- Run this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS table_number text DEFAULT '';

-- Add guest number field to orders table
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS number_of_guests integer DEFAULT 1;
