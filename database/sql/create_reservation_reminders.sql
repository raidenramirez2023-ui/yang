-- ============================================
-- RESERVATION REMINDERS MIGRATION
-- ============================================
-- Adds columns to track whether a reminder email has been sent
-- for upcoming reservations and advance orders.
-- Run this in your Supabase SQL Editor.

-- 1. Add reminder tracking columns to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS reminder_sent BOOLEAN DEFAULT FALSE;

ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ;

-- 2. Add reminder tracking columns to advance_orders table
ALTER TABLE advance_orders 
ADD COLUMN IF NOT EXISTS reminder_sent BOOLEAN DEFAULT FALSE;

ALTER TABLE advance_orders 
ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ;

-- 3. Create indexes for fast reminder queries
-- These indexes help the cron job quickly find reservations that need reminders
CREATE INDEX IF NOT EXISTS idx_reservations_reminder_pending 
ON reservations(reminder_sent, event_date, status) 
WHERE reminder_sent = FALSE;

CREATE INDEX IF NOT EXISTS idx_advance_orders_reminder_pending 
ON advance_orders(reminder_sent, order_date, status) 
WHERE reminder_sent = FALSE;

-- 4. Verify columns were added
SELECT column_name, data_type, column_default
FROM information_schema.columns 
WHERE table_name = 'reservations' 
AND column_name IN ('reminder_sent', 'reminder_sent_at')
ORDER BY column_name;

SELECT column_name, data_type, column_default
FROM information_schema.columns 
WHERE table_name = 'advance_orders' 
AND column_name IN ('reminder_sent', 'reminder_sent_at')
ORDER BY column_name;
