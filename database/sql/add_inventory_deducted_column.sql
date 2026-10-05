-- Add inventory_deducted flag to advance_orders and reservations
-- This prevents double deduction when cooking status changes.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'advance_orders' AND column_name = 'inventory_deducted'
  ) THEN
    ALTER TABLE advance_orders ADD COLUMN inventory_deducted BOOLEAN DEFAULT FALSE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'reservations' AND column_name = 'inventory_deducted'
  ) THEN
    ALTER TABLE reservations ADD COLUMN inventory_deducted BOOLEAN DEFAULT FALSE;
  END IF;
END $$;
