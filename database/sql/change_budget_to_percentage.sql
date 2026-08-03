-- Change category budgets from fixed amounts to percentage-based allocation
-- This allows categories to be allocated as percentages of the current petty cash balance

-- Drop the old table and recreate with percentage column
DROP TABLE IF EXISTS petty_cash_category_budgets;

CREATE TABLE petty_cash_category_budgets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category VARCHAR(50) NOT NULL UNIQUE,
  percentage NUMERIC(5, 2) NOT NULL DEFAULT 0, -- Percentage of total balance (0-100)
  current_spent NUMERIC(10, 2) NOT NULL DEFAULT 0,
  period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_percentage CHECK (percentage >= 0 AND percentage <= 100)
);

-- Enable RLS
ALTER TABLE petty_cash_category_budgets ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Allow authenticated users to view budgets"
  ON petty_cash_category_budgets FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow authenticated users to insert budgets"
  ON petty_cash_category_budgets FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update budgets"
  ON petty_cash_category_budgets FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Create default budget allocations (total 100%)
INSERT INTO petty_cash_category_budgets (category, percentage, current_spent, period_start, period_end)
VALUES 
  ('inventory_purchase', 50.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('supplies', 20.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('transportation', 20.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('other', 10.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second');

-- Add comment
COMMENT ON COLUMN petty_cash_category_budgets.percentage IS 'Percentage of total petty cash balance allocated to this category (0-100)';
