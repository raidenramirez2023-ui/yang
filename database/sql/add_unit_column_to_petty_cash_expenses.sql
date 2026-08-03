-- Add unit column to petty_cash_expenses for inventory purchases
-- This stores the unit of measurement for purchased items (e.g., pcs, kilo, pack)

ALTER TABLE petty_cash_expenses
ADD COLUMN unit VARCHAR(20);

-- Add comment
COMMENT ON COLUMN petty_cash_expenses.unit IS 'Unit of measurement for inventory purchases (e.g., pcs, kilo, pack, bot)';
