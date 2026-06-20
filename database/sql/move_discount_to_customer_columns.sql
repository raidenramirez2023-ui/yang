-- Fix customer data: Move regular customer details from discount columns to customer columns
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/tvzbsvqaikjkxrqykrhw/sql/new

-- Update orders with no discount: move discount_name to customer_name, discount_address to customer_address
-- Only moves data if customer_name/customer_address are NULL or empty (to avoid overwriting existing data)
UPDATE public.orders
SET 
    customer_name = CASE 
        WHEN discount_amount = 0 
            AND discount_name IS NOT NULL 
            AND discount_name != '' 
            AND (customer_name IS NULL OR customer_name = '')
        THEN discount_name 
        ELSE customer_name 
    END,
    customer_address = CASE 
        WHEN discount_amount = 0 
            AND discount_address IS NOT NULL 
            AND discount_address != '' 
            AND (customer_address IS NULL OR customer_address = '')
        THEN discount_address 
        ELSE customer_address 
    END
WHERE discount_amount = 0
    AND (
        (discount_name IS NOT NULL AND discount_name != '' AND (customer_name IS NULL OR customer_name = ''))
        OR
        (discount_address IS NOT NULL AND discount_address != '' AND (customer_address IS NULL OR customer_address = ''))
    );

-- Clear discount_name and discount_address for orders with no discount (after moving to customer columns)
UPDATE public.orders
SET 
    discount_name = NULL,
    discount_address = NULL
WHERE discount_amount = 0
    AND (customer_name IS NOT NULL AND customer_name != '')
    AND (customer_address IS NOT NULL AND customer_address != '');

-- Verify the changes
SELECT 
    transaction_id,
    customer_name,
    customer_address,
    discount_amount,
    discount_label,
    discount_name,
    discount_address
FROM public.orders
ORDER BY created_at DESC
LIMIT 10;
