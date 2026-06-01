-- Fix RLS policies for reviews table
-- Allow authenticated users to insert and update their own reviews

-- Enable RLS on reviews table (if not already enabled)
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow public read access for reviews" ON reviews;
DROP POLICY IF EXISTS "Allow authenticated insert for reviews" ON reviews;
DROP POLICY IF EXISTS "Allow authenticated update for reviews" ON reviews;

-- Policy: Allow public read access to reviews
CREATE POLICY "Allow public read access for reviews" ON reviews
    FOR SELECT TO public USING (true);

-- Policy: Allow authenticated users to insert their own reviews
CREATE POLICY "Allow authenticated insert for reviews" ON reviews
    FOR INSERT TO authenticated
    WITH CHECK (customer_email = auth.email());

-- Policy: Allow authenticated users to update their own reviews
CREATE POLICY "Allow authenticated update for reviews" ON reviews
    FOR UPDATE TO authenticated
    USING (customer_email = auth.email())
    WITH CHECK (customer_email = auth.email());
