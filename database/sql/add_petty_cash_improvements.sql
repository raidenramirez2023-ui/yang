-- Add low balance threshold to petty_cash_fund
ALTER TABLE petty_cash_fund ADD COLUMN IF NOT EXISTS low_balance_threshold DECIMAL(10, 2) DEFAULT 2000.00;

-- Add cash reconciliation tracking
CREATE TABLE IF NOT EXISTS petty_cash_reconciliation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_id UUID REFERENCES petty_cash_fund(id),
  reconciled_by TEXT NOT NULL, -- email of admin who reconciled
  system_balance DECIMAL(10, 2) NOT NULL,
  actual_cash_count DECIMAL(10, 2) NOT NULL,
  discrepancy DECIMAL(10, 2) GENERATED ALWAYS AS (actual_cash_count - system_balance) STORED,
  notes TEXT,
  reconciled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add category budgets
CREATE TABLE IF NOT EXISTS petty_cash_category_budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL, -- 'inventory_purchase', 'supplies', 'transportation', 'other'
  budget_limit DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  current_spent DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  period_start TIMESTAMP WITH TIME ZONE DEFAULT DATE_TRUNC('month', NOW()),
  period_end TIMESTAMP WITH TIME ZONE DEFAULT DATE_TRUNC('month', NOW()) + INTERVAL '1 month' - INTERVAL '1 second',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(category, period_start)
);

-- Enable RLS on reconciliation table
ALTER TABLE petty_cash_reconciliation ENABLE ROW LEVEL SECURITY;

-- Enable RLS on category budgets table
ALTER TABLE petty_cash_category_budgets ENABLE ROW LEVEL SECURITY;

-- RLS policies for reconciliation
CREATE POLICY "Allow authenticated users to view reconciliation"
ON petty_cash_reconciliation FOR SELECT
TO authenticated
USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert reconciliation"
ON petty_cash_reconciliation FOR INSERT
TO authenticated
WITH CHECK (
  auth.role() = 'authenticated'
);

-- RLS policies for category budgets
CREATE POLICY "Allow authenticated users to view category budgets"
ON petty_cash_category_budgets FOR SELECT
TO authenticated
USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to manage category budgets"
ON petty_cash_category_budgets FOR ALL
TO authenticated
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');
