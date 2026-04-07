-- =========================================
-- FIX TIME FORMAT IN RESERVATIONS TABLE
-- =========================================
-- Problem: start_time is stored as TIME (HH:MM:SS) but app expects HH:MM
-- Solution: Convert to TEXT format HH:MM for consistency
-- 
-- Run this in Supabase SQL Editor
-- =========================================

-- Step 1: Add new column with TEXT type
ALTER TABLE reservations 
ADD COLUMN start_time_new TEXT;

-- Step 2: Copy data, converting from TIME to HH:MM text format
UPDATE reservations 
SET start_time_new = TO_CHAR(start_time, 'HH24:MI')
WHERE start_time IS NOT NULL;

-- Step 3: Make sure all values were converted
SELECT COUNT(*) as total_rows,
       COUNT(start_time_new) as converted_rows,
       CASE WHEN COUNT(*) = COUNT(start_time_new) THEN 'SUCCESS' ELSE 'ERROR' END as status
FROM reservations;

-- Step 4: Drop old column (ONLY AFTER VERIFYING STEP 3)
ALTER TABLE reservations 
DROP COLUMN start_time;

-- Step 5: Rename new column
ALTER TABLE reservations 
RENAME COLUMN start_time_new TO start_time;

-- Step 6: Add NOT NULL constraint
ALTER TABLE reservations 
ALTER COLUMN start_time SET NOT NULL;

-- Step 7: Verify the fix
SELECT id, event_date, start_time, duration_hours FROM reservations LIMIT 5;

-- Expected output: start_time should be in HH:MM format (e.g., "14:30", "08:15")
