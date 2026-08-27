-- Migration: Add receipt_url column to reservations table
-- Run this in Supabase SQL Editor

ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS receipt_url TEXT;

COMMENT ON COLUMN reservations.receipt_url
  IS 'Public Supabase Storage URL of the official PDF receipt generated upon cash settlement by admin';
