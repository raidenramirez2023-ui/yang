-- Migration: Add balance payment link tracking columns to reservations and advance_orders
-- Run this in your Supabase SQL Editor

ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS balance_link_id TEXT,
ADD COLUMN IF NOT EXISTS balance_link_url TEXT;

ALTER TABLE advance_orders 
ADD COLUMN IF NOT EXISTS balance_link_id TEXT,
ADD COLUMN IF NOT EXISTS balance_link_url TEXT;
