-- Fix the petty_cash_category_budgets table schema to support monthly budgets
-- The current UNIQUE constraint on category alone prevents having multiple records for the same category across different months

-- Drop the old table and recreate with proper unique constraint
DROP TABLE IF EXISTS petty_cash_category_budgets;

CREATE TABLE petty_cash_category_budgets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category VARCHAR(50) NOT NULL,
  percentage NUMERIC(5, 2) NOT NULL DEFAULT 0, -- Percentage of total balance (0-100)
  current_spent NUMERIC(10, 2) NOT NULL DEFAULT 0,
  period_start TIMESTAMP WITH TIME ZONE NOT NULL,
  period_end TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT valid_percentage CHECK (percentage >= 0 AND percentage <= 100),
  CONSTRAINT unique_category_period UNIQUE (category, period_start)
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

-- Create default budget allocations for current month (total 100%)
INSERT INTO petty_cash_category_budgets (category, percentage, current_spent, period_start, period_end)
VALUES 
  ('inventory_purchase', 50.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('supplies', 20.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('transportation', 20.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second'),
  ('other', 10.0, 0, DATE_TRUNC('month', NOW()), DATE_TRUNC('month', NOW() + INTERVAL '1 month') - INTERVAL '1 second');

-- Add comment
COMMENT ON COLUMN petty_cash_category_budgets.percentage IS 'Percentage of total petty cash balance allocated to this category (0-100)';
