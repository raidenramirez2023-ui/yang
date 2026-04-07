-- Stock Transactions Table Setup
-- This table tracks all incoming and outgoing stock movements

-- Create stock_transactions table
CREATE TABLE IF NOT EXISTS stock_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_name VARCHAR(255) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('incoming', 'outgoing')),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit VARCHAR(50),
    supplier VARCHAR(255), -- For incoming transactions
    purpose VARCHAR(255), -- For outgoing transactions
    requested_by VARCHAR(255), -- For outgoing transactions
    processed_by VARCHAR(255), -- User who processed the transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Add constraint to ensure either supplier or purpose is provided based on transaction type
    CONSTRAINT check_supplier_or_purpose CHECK (
        (transaction_type = 'incoming' AND supplier IS NOT NULL) OR
        (transaction_type = 'outgoing' AND purpose IS NOT NULL AND requested_by IS NOT NULL)
    )
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stock_transactions_type ON stock_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_item_name ON stock_transactions(item_name);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_created_at ON stock_transactions(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE stock_transactions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Allow authenticated users to read stock transactions
CREATE POLICY "Allow authenticated users to read stock transactions"
    ON stock_transactions FOR SELECT
    USING (auth.role() = 'authenticated');

-- Allow authenticated users to insert stock transactions
CREATE POLICY "Allow authenticated users to insert stock transactions"
    ON stock_transactions FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Allow users to update their own transactions (if needed in the future)
CREATE POLICY "Allow users to update their own stock transactions"
    ON stock_transactions FOR UPDATE
    USING (auth.email() = processed_by);

-- Allow admins to delete any transactions
CREATE POLICY "Allow admins to delete any stock transactions"
    ON stock_transactions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.email = auth.email() 
            AND (users.role = 'admin' OR users.role = 'adm')
        )
    );

-- Add comments for documentation
COMMENT ON TABLE stock_transactions IS 'Tracks all incoming and outgoing stock movements for inventory management';
COMMENT ON COLUMN stock_transactions.transaction_type IS 'Type of transaction: incoming (replenishment) or outgoing (usage)';
COMMENT ON COLUMN stock_transactions.supplier IS 'Supplier name for incoming stock deliveries';
COMMENT ON COLUMN stock_transactions.purpose IS 'Purpose of outgoing stock (e.g., cooking, preparation)';
COMMENT ON COLUMN stock_transactions.requested_by IS 'Person who requested the outgoing stock';
COMMENT ON COLUMN stock_transactions.processed_by IS 'User who processed the transaction';
