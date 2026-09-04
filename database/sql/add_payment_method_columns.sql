-- Migration: Ensure payment_method and payment_option columns exist in reservations and advance_orders
-- Run this in your Supabase SQL Editor if columns are not yet present.

-- 1. Ensure columns exist on reservations table
ALTER TABLE public.reservations 
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'paymongo',
ADD COLUMN IF NOT EXISTS payment_option TEXT DEFAULT 'half';

-- 2. Ensure payment_method exists on advance_orders table
ALTER TABLE public.advance_orders 
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'paymongo';

-- 3. Optional indices for optimized query performance
CREATE INDEX IF NOT EXISTS idx_reservations_payment_method ON public.reservations(payment_method);
CREATE INDEX IF NOT EXISTS idx_reservations_payment_option ON public.reservations(payment_option);
CREATE INDEX IF NOT EXISTS idx_advance_orders_payment_method ON public.advance_orders(payment_method);
