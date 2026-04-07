-- =========================================
-- FIX ADMIN RLS POLICIES FOR RESERVATIONS
-- =========================================

-- 1. Drop existing policies
DROP POLICY IF EXISTS "Admin can view all reservations" ON reservations;
DROP POLICY IF EXISTS "Admin can update all reservations" ON reservations;
DROP POLICY IF EXISTS "Customers can view own reservations" ON reservations;
DROP POLICY IF EXISTS "Customers can create reservations" ON reservations;
DROP POLICY IF EXISTS "Customers can update own reservations" ON reservations;

-- 2. Create simplified policies that work
-- Allow authenticated users to view all reservations (for admin)
CREATE POLICY "Allow authenticated users to view reservations" ON reservations
  FOR SELECT USING (auth.role() = 'authenticated');

-- Allow authenticated users to insert reservations (for customers)
CREATE POLICY "Allow authenticated users to create reservations" ON reservations
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update reservations (for admin)
CREATE POLICY "Allow authenticated users to update reservations" ON reservations
  FOR UPDATE USING (auth.role() = 'authenticated');

-- 3. Test query to check if admin can see reservations
SELECT 
  id,
  customer_email,
  customer_name,
  event_type,
  event_date,
  start_time,
  duration_hours,
  number_of_guests,
  status,
  created_at
FROM reservations 
ORDER BY created_at DESC;
