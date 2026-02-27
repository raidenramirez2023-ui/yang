-- =========================================
-- FIX DELETE POLICIES FOR RESERVATIONS
-- =========================================

-- 1. Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated users to view reservations" ON reservations;
DROP POLICY IF EXISTS "Allow authenticated users to create reservations" ON reservations;
DROP POLICY IF EXISTS "Allow authenticated users to update reservations" ON reservations;

-- 2. Create policies that include DELETE operations
-- Allow authenticated users to view reservations
CREATE POLICY "Allow authenticated users to view reservations" ON reservations
  FOR SELECT USING (auth.role() = 'authenticated');

-- Allow authenticated users to create reservations
CREATE POLICY "Allow authenticated users to create reservations" ON reservations
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow authenticated users to update reservations
CREATE POLICY "Allow authenticated users to update reservations" ON reservations
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Allow authenticated users to delete reservations
CREATE POLICY "Allow authenticated users to delete reservations" ON reservations
  FOR DELETE USING (auth.role() = 'authenticated');

-- 3. Test delete permission
SELECT 
  'RLS Policies for Reservations:' as info,
  policy_name,
  command,
  qual
FROM pg_policies 
WHERE tablename = 'reservations';

-- 4. Verify table still exists and has data
SELECT COUNT(*) as total_reservations FROM reservations;
