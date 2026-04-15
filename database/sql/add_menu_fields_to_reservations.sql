-- =========================================
-- ADD MENU-BASED RESERVATION FIELDS
-- =========================================

-- 1. Add menu-based reservation fields to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS is_menu_based BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS pricing_type TEXT DEFAULT 'traditional',
ADD COLUMN IF NOT EXISTS selected_menu_items JSONB DEFAULT '{}';

-- 2. Add constraints for pricing_type
ALTER TABLE reservations ADD CONSTRAINT reservations_pricing_type_check 
CHECK (pricing_type IN ('traditional', 'menu_based'));

-- 3. Update existing rows to have default values
UPDATE reservations 
SET 
  is_menu_based = FALSE,
  pricing_type = 'traditional',
  selected_menu_items = '{}'
WHERE is_menu_based IS NULL OR pricing_type IS NULL OR selected_menu_items IS NULL;

-- 4. Verify the updated table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'reservations' 
  AND column_name IN ('is_menu_based', 'pricing_type', 'selected_menu_items')
ORDER BY ordinal_position;

-- 5. Test query to verify the new fields
SELECT 
  id, 
  customer_email, 
  event_type, 
  event_date,
  total_price,
  deposit_amount,
  is_menu_based,
  pricing_type,
  selected_menu_items,
  status,
  created_at
FROM reservations 
WHERE is_menu_based = TRUE
ORDER BY created_at DESC
LIMIT 5;
