-- Create petty_cash_fund table to track the main fund balance
CREATE TABLE IF NOT EXISTS petty_cash_fund (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_name TEXT NOT NULL DEFAULT 'Main Petty Cash',
  current_balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  initial_balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  last_replenished_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create petty_cash_expenses table to track individual expenses
CREATE TABLE IF NOT EXISTS petty_cash_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  category TEXT NOT NULL, -- 'inventory_purchase', 'supplies', 'transportation', 'other'
  purchased_by TEXT NOT NULL, -- email of staff who made the purchase
  inventory_item_id UUID, -- link to inventory item if applicable
  inventory_item_name TEXT, -- name of inventory item purchased
  quantity_purchased INTEGER,
  supplier TEXT,
  receipt_image_url TEXT, -- URL to receipt image
  receipt_number TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'reimbursed'
  approved_by TEXT, -- email of admin who approved
  approved_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on petty_cash_fund
ALTER TABLE petty_cash_fund ENABLE ROW LEVEL SECURITY;

-- Enable RLS on petty_cash_expenses
ALTER TABLE petty_cash_expenses ENABLE ROW LEVEL SECURITY;

-- Policies for petty_cash_fund
CREATE POLICY "Allow authenticated users to read petty_cash_fund"
  ON petty_cash_fund FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow admins to insert petty_cash_fund"
  ON petty_cash_fund FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.email()
      AND (users.role = 'admin' OR users.email = 'pagsanjaninv@gmail.com')
    )
  );

CREATE POLICY "Allow admins to update petty_cash_fund"
  ON petty_cash_fund FOR UPDATE
  USING (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.email()
      AND (users.role = 'admin' OR users.email = 'pagsanjaninv@gmail.com')
    )
  );

-- Policies for petty_cash_expenses
CREATE POLICY "Allow authenticated users to read petty_cash_expenses"
  ON petty_cash_expenses FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert petty_cash_expenses"
  ON petty_cash_expenses FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own expenses"
  ON petty_cash_expenses FOR UPDATE
  USING (
    auth.role() = 'authenticated' AND
    purchased_by = auth.email()
  );

CREATE POLICY "Allow admins to approve expenses"
  ON petty_cash_expenses FOR UPDATE
  USING (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.email()
      AND (users.role = 'admin' OR users.email = 'pagsanjaninv@gmail.com')
    )
  );

CREATE POLICY "Allow admins to delete expenses"
  ON petty_cash_expenses FOR DELETE
  USING (
    auth.role() = 'authenticated' AND
    EXISTS (
      SELECT 1 FROM users
      WHERE users.email = auth.email()
      AND (users.role = 'admin' OR users.email = 'pagsanjaninv@gmail.com')
    )
  );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_petty_cash_expenses_date ON petty_cash_expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_petty_cash_expenses_status ON petty_cash_expenses(status);
CREATE INDEX IF NOT EXISTS idx_petty_cash_expenses_purchased_by ON petty_cash_expenses(purchased_by);
CREATE INDEX IF NOT EXISTS idx_petty_cash_expenses_category ON petty_cash_expenses(category);

-- Add comments
COMMENT ON TABLE petty_cash_fund IS 'Tracks the main petty cash fund balance for inventory purchases';
COMMENT ON TABLE petty_cash_expenses IS 'Tracks individual petty cash expenses with proof of purchase';
COMMENT ON COLUMN petty_cash_expenses.status IS 'Expense status: pending, approved, rejected, reimbursed';
COMMENT ON COLUMN petty_cash_expenses.category IS 'Expense category: inventory_purchase, supplies, transportation, other';

-- Initialize with default petty cash fund if it doesn't exist
INSERT INTO petty_cash_fund (fund_name, current_balance, initial_balance)
SELECT 'Main Petty Cash', 0.00, 0.00
WHERE NOT EXISTS (SELECT 1 FROM petty_cash_fund WHERE fund_name = 'Main Petty Cash');
