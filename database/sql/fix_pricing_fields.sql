-- =========================================
-- FIXED: ADD PRICING FIELDS TO RESERVATIONS TABLE
-- =========================================

-- 1. Drop existing check constraints if they exist
ALTER TABLE reservations DROP CONSTRAINT IF EXISTS reservations_status_check;
ALTER TABLE reservations DROP CONSTRAINT IF EXISTS reservations_payment_status_check;

-- 2. Add pricing fields to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS total_price DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS deposit_amount DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS payment_amount DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'unpaid',
ADD COLUMN IF NOT EXISTS payment_reference TEXT,
ADD COLUMN IF NOT EXISTS price_quotation_sent BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS price_quotation_sent_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS admin_set_price BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS special_requests TEXT,
ADD COLUMN IF NOT EXISTS customer_phone TEXT,
ADD COLUMN IF NOT EXISTS customer_address TEXT,
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- 3. Update existing rows to have valid values BEFORE adding constraints
UPDATE reservations 
SET payment_status = 'unpaid' 
WHERE payment_status IS NULL OR payment_status NOT IN ('unpaid', 'deposit_paid', 'fully_paid', 'refunded', 'rejected');

UPDATE reservations 
SET status = 'pending' 
WHERE status IS NULL OR status NOT IN ('pending', 'confirmed', 'cancelled', 'pending_admin_approval', 'payment_rejected');

-- 4. Add new check constraints (now safe because all rows have valid values)
ALTER TABLE reservations ADD CONSTRAINT reservations_payment_status_check 
CHECK (payment_status IN ('unpaid', 'deposit_paid', 'fully_paid', 'refunded', 'rejected'));

ALTER TABLE reservations ADD CONSTRAINT reservations_status_check 
CHECK (status IN ('pending', 'confirmed', 'cancelled', 'pending_admin_approval', 'payment_rejected'));

-- 5. Update existing reservations to have default values for new fields
UPDATE reservations 
SET 
  payment_status = 'unpaid',
  price_quotation_sent = FALSE,
  admin_set_price = FALSE,
  is_archived = FALSE
WHERE payment_status IS NULL OR price_quotation_sent IS NULL OR admin_set_price IS NULL OR is_archived IS NULL;

-- 6. Add indexes for new fields
CREATE INDEX IF NOT EXISTS reservations_payment_status_idx ON reservations(payment_status);
CREATE INDEX IF NOT EXISTS reservations_price_quotation_sent_idx ON reservations(price_quotation_sent);
CREATE INDEX IF NOT EXISTS reservations_admin_set_price_idx ON reservations(admin_set_price);

-- 7. Verify the updated table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'reservations' 
ORDER BY ordinal_position;

-- 8. Test query to verify the new fields
SELECT 
  id, 
  customer_email, 
  event_type, 
  event_date,
  total_price,
  deposit_amount,
  payment_amount,
  payment_status,
  payment_reference,
  price_quotation_sent,
  admin_set_price,
  status,
  created_at
FROM reservations 
ORDER BY created_at DESC
LIMIT 5;

-- =========================================
-- SUCCESS: All pricing fields added with proper constraints!
-- =========================================
