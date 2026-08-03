-- Fix petty_cash_expenses records where inventory_item_id and inventory_item_name are null
-- This script extracts data from the inventory_items JSON array and populates the legacy fields

-- First, let's check what records have NULL values and why
SELECT 
  id,
  description,
  category,
  inventory_item_id,
  inventory_item_name,
  quantity_purchased,
  inventory_items,
  CASE 
    WHEN inventory_items IS NULL THEN 'inventory_items is NULL'
    WHEN jsonb_array_length(inventory_items) = 0 THEN 'inventory_items is empty array'
    ELSE 'Has inventory_items data'
  END as status
FROM petty_cash_expenses
WHERE category = 'inventory_purchase'
  AND (inventory_item_id IS NULL OR inventory_item_name IS NULL OR quantity_purchased IS NULL)
ORDER BY created_at DESC;

-- Update records that have inventory_items but null legacy fields
-- For single-item expenses, populate the legacy fields from the first item in the array
UPDATE petty_cash_expenses
SET 
  inventory_item_id = (inventory_items->0->>'item_id')::uuid,
  inventory_item_name = (inventory_items->0->>'item_name')::text,
  quantity_purchased = (inventory_items->0->>'quantity')::int
WHERE 
  inventory_items IS NOT NULL 
  AND jsonb_array_length(inventory_items) = 1
  AND (inventory_item_id IS NULL OR inventory_item_name IS NULL OR quantity_purchased IS NULL);

-- For multi-item expenses, we only populate the legacy fields with the first item
-- This maintains some backward compatibility while indicating it's a multi-item expense
UPDATE petty_cash_expenses
SET 
  inventory_item_id = (inventory_items->0->>'item_id')::uuid,
  inventory_item_name = (inventory_items->0->>'item_name')::text,
  quantity_purchased = (inventory_items->0->>'quantity')::int
WHERE 
  inventory_items IS NOT NULL 
  AND jsonb_array_length(inventory_items) > 1
  AND (inventory_item_id IS NULL OR inventory_item_name IS NULL OR quantity_purchased IS NULL);

-- Verify the updates - check remaining NULL records
SELECT 
  id,
  description,
  category,
  inventory_item_id,
  inventory_item_name,
  quantity_purchased,
  inventory_items,
  CASE 
    WHEN inventory_items IS NULL THEN 'inventory_items is NULL - CANNOT AUTO FIX'
    WHEN jsonb_array_length(inventory_items) = 0 THEN 'inventory_items is empty array'
    ELSE 'Has inventory_items data'
  END as status
FROM petty_cash_expenses
WHERE category = 'inventory_purchase'
  AND (inventory_item_id IS NULL OR inventory_item_name IS NULL OR quantity_purchased IS NULL)
ORDER BY created_at DESC;

-- Identify records that CANNOT be automatically fixed (both legacy fields AND inventory_items are NULL)
-- These need manual intervention - either update manually or delete and recreate through the app
SELECT 
  id,
  description,
  amount,
  status,
  created_at
FROM petty_cash_expenses
WHERE category = 'inventory_purchase'
  AND inventory_items IS NULL
  AND (inventory_item_id IS NULL OR inventory_item_name IS NULL OR quantity_purchased IS NULL)
ORDER BY created_at DESC;
