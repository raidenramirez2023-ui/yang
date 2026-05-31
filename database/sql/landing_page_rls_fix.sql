-- =========================================================================
-- LANDING PAGE RLS POLICIES FIX
-- This script configures public read access (SELECT) for all tables
-- and storage assets used on the landing page so visitors can see them.
-- Run this in your Supabase SQL Editor (https://supabase.com dashboard).
-- =========================================================================

-- ---------------------------------------------------------
-- 1. MENU ITEMS
-- Allow anyone (public/anonymous) to browse the food menu
-- ---------------------------------------------------------
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access for menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "Allow public select for menu_items" ON public.menu_items;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.menu_items;

CREATE POLICY "Allow public read access for menu_items" ON public.menu_items
    FOR SELECT TO public USING (true);


-- ---------------------------------------------------------
-- 2. RECIPE INGREDIENTS
-- Allow anyone to view details/ingredients of menu items
-- ---------------------------------------------------------
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access for recipe_ingredients" ON public.recipe_ingredients;
DROP POLICY IF EXISTS "Allow public select for recipe_ingredients" ON public.recipe_ingredients;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.recipe_ingredients;

CREATE POLICY "Allow public read access for recipe_ingredients" ON public.recipe_ingredients
    FOR SELECT TO public USING (true);


-- ---------------------------------------------------------
-- 3. REVIEWS
-- Allow anyone to see reviews/ratings on the landing page
-- ---------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access for reviews" ON public.reviews;
DROP POLICY IF EXISTS "Allow public select for reviews" ON public.reviews;

CREATE POLICY "Allow public read access for reviews" ON public.reviews
    FOR SELECT TO public USING (true);


-- ---------------------------------------------------------
-- 4. STORAGE BUCKET (RESTAURANT ASSETS)
-- Allow anyone to download/view the menu images stored in
-- the 'restaurant-assets' storage bucket.
-- ---------------------------------------------------------
DROP POLICY IF EXISTS "Allow public read access to restaurant_assets" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access to restaurant-assets" ON storage.objects;

CREATE POLICY "Allow public read access to restaurant-assets" ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'restaurant-assets');

-- ---------------------------------------------------------
-- Verification Query
-- ---------------------------------------------------------
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('menu_items', 'recipe_ingredients', 'reviews')
ORDER BY tablename, policyname;
