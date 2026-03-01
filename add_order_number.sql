-- Run this in your Supabase SQL Editor if you haven't already
-- This adds the auto-incrementing order_number column to your orders table.

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_number SERIAL;
