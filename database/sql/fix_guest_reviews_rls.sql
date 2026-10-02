-- ============================================================================
-- Fix Reviews Table for Guest Reviews & Feedback (Yang Chow RMS)
-- ============================================================================

-- 1. Allow reservation_id to be NULL (para sa mga walk-in o guest na walang reservation record)
ALTER TABLE public.reviews ALTER COLUMN reservation_id DROP NOT NULL;

-- 2. Siguraduhing may columns para sa guest details kung wala pa
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS dish TEXT;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS is_guest BOOLEAN DEFAULT false;

-- 3. Enable RLS on reviews table (if not yet enabled)
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- 4. Drop restrictive insert policy if exists
DROP POLICY IF EXISTS "Allow authenticated insert for reviews" ON public.reviews;
DROP POLICY IF EXISTS "Allow guest and authenticated insert for reviews" ON public.reviews;
DROP POLICY IF EXISTS "Allow public insert for reviews" ON public.reviews;

-- 5. Create permissive INSERT policy for public (guests + registered customers)
CREATE POLICY "Allow public insert for reviews" ON public.reviews
    FOR INSERT TO public
    WITH CHECK (
        rating >= 1 AND rating <= 5
    );

-- 6. Ensure public read access
DROP POLICY IF EXISTS "Allow public read access for reviews" ON public.reviews;
CREATE POLICY "Allow public read access for reviews" ON public.reviews
    FOR SELECT TO public
    USING (true);
