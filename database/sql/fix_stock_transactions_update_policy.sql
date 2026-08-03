-- Fix RLS policy to allow users to update petty cash transactions
-- This is needed for petty cash transfers to update the purpose field

-- Drop the existing restrictive update policy
DROP POLICY IF EXISTS "Allow users to update their own stock_transactions" ON stock_transactions;

-- Add a more flexible update policy that allows:
-- - Users to update transactions they processed
-- - Users to update petty cash transactions (for transfer to storage)
CREATE POLICY "Allow users to update their own and petty cash stock_transactions"
    ON stock_transactions FOR UPDATE
    USING (
        auth.email() = processed_by OR
        purpose = 'Petty Cash Purchase'
    )
    WITH CHECK (
        auth.email() = processed_by OR
        purpose = 'Petty Cash Purchase' OR
        purpose = 'Transferred to Storage'
    );
