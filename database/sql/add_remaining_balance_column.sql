-- =========================================
-- ADD REMAINING BALANCE COLUMN TO RESERVATIONS
-- =========================================

-- Add remaining_balance column to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS remaining_balance DECIMAL(10,2) DEFAULT 0.00;

-- Update existing reservations with remaining balance calculation
-- For deposit_paid: remaining_balance = total_price - deposit_amount
-- For fully_paid: remaining_balance = 0
-- For unpaid: remaining_balance = total_price
UPDATE reservations 
SET remaining_balance = 
  CASE 
    WHEN payment_status = 'fully_paid' OR payment_status = 'paid' THEN 0
    WHEN payment_status = 'deposit_paid' THEN 
      GREATEST(0, COALESCE(total_price, 0) - COALESCE(deposit_amount, 0))
    ELSE COALESCE(total_price, 0)
  END
WHERE remaining_balance IS NULL OR remaining_balance = 0;

-- Create index for faster queries on remaining balance
CREATE INDEX IF NOT EXISTS reservations_remaining_balance_idx ON reservations(remaining_balance);

-- Verification query
SELECT 
  id, 
  customer_name, 
  total_price, 
  deposit_amount, 
  payment_amount, 
  payment_status, 
  remaining_balance,
  status
FROM reservations 
WHERE payment_status = 'deposit_paid'
ORDER BY created_at DESC
LIMIT 5;
