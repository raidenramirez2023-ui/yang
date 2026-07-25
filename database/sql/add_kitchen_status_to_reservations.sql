-- Migration: Add kitchen_status column to reservations table
-- Execute this script in your Supabase SQL Editor.

ALTER TABLE public.reservations 
ADD COLUMN IF NOT EXISTS kitchen_status TEXT DEFAULT 'Pending';

-- Create an index to optimize queries for active dashboard items
CREATE INDEX IF NOT EXISTS idx_reservations_kitchen_status 
ON public.reservations(kitchen_status);
