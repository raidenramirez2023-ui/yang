-- Drop all SQL functions created for Featured Dishes feature
-- Run this in Supabase SQL Editor

-- Drop the get_top_selling_dishes function
DROP FUNCTION IF EXISTS public.get_top_selling_dishes(integer);

-- Note: This does not drop the orders, order_items, advance_orders, or reservations tables
-- Only drops the RPC function that was created for the Featured Dishes feature
