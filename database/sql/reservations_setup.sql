-- =========================================
-- RESERVATIONS TABLE SETUP
-- =========================================

-- 1. Create reservations table
CREATE TABLE IF NOT EXISTS reservations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_email TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_date DATE NOT NULL,
  start_time TIME NOT NULL,
  duration_hours INTEGER NOT NULL,
  number_of_guests INTEGER NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE reservations ENABLE ROW LEVEL SECURITY;

-- 3. Create policies
-- Customers can view their own reservations
CREATE POLICY "Customers can view own reservations" ON reservations
  FOR SELECT USING (auth.email() = customer_email);

-- Customers can insert their own reservations
CREATE POLICY "Customers can create reservations" ON reservations
  FOR INSERT WITH CHECK (auth.email() = customer_email);

-- Customers can update their own reservations
CREATE POLICY "Customers can update own reservations" ON reservations
  FOR UPDATE USING (auth.email() = customer_email);

-- Admin can view all reservations
CREATE POLICY "Admin can view all reservations" ON reservations
  FOR SELECT USING (auth.jwt() ->> 'role' = 'admin');

-- Admin can update all reservations
CREATE POLICY "Admin can update all reservations" ON reservations
  FOR UPDATE USING (auth.jwt() ->> 'role' = 'admin');

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS reservations_customer_email_idx ON reservations(customer_email);
CREATE INDEX IF NOT EXISTS reservations_event_date_idx ON reservations(event_date);
CREATE INDEX IF NOT EXISTS reservations_status_idx ON reservations(status);

-- 5. Verify table structure
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'reservations' 
ORDER BY ordinal_position;

-- 6. Test query to verify table
SELECT 
  id, 
  customer_email, 
  event_type, 
  event_date, 
  status,
  created_at
FROM reservations 
ORDER BY created_at DESC;
