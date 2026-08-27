-- Sync/Backfill remaining_balance for ALL existing reservations
-- For deposit_paid: remaining_balance = total_price - deposit_amount
-- For fully_paid/paid: remaining_balance = 0

-- 1. First, add the column if it doesn't exist yet
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS remaining_balance NUMERIC DEFAULT 0;

-- 2. Sync deposit_paid reservations: set remaining_balance = total_price - deposit_amount
UPDATE reservations
SET remaining_balance = COALESCE(total_price, 0) - COALESCE(deposit_amount, 0),
    updated_at = NOW()
WHERE payment_status = 'deposit_paid'
  AND (remaining_balance IS NULL OR remaining_balance = 0)
  AND total_price IS NOT NULL
  AND deposit_amount IS NOT NULL
  AND total_price > deposit_amount;

-- 3. Sync fully_paid/paid reservations: set remaining_balance = 0
UPDATE reservations
SET remaining_balance = 0,
    updated_at = NOW()
WHERE payment_status IN ('fully_paid', 'paid')
  AND (remaining_balance IS NULL OR remaining_balance != 0);

-- 4. Sync unpaid reservations: set remaining_balance = total_price (full amount is due)
UPDATE reservations
SET remaining_balance = COALESCE(total_price, 0),
    updated_at = NOW()
WHERE payment_status = 'unpaid'
  AND remaining_balance IS NULL
  AND total_price IS NOT NULL;
