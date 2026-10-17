-- ============================================================================
-- ENABLE REALTIME REPLICATION FOR INVENTORY AND KITCHEN_INVENTORY
-- ============================================================================
-- This ensures that when stock levels change in kitchen_inventory or inventory,
-- Supabase broadcasts WebSocket events live to all open POS and Inventory screens.

-- 1. Ensure Full row replication is enabled
ALTER TABLE IF EXISTS public.kitchen_inventory REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.inventory REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS public.recipe_ingredients REPLICA IDENTITY FULL;

-- 2. Add tables to supabase_realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'kitchen_inventory'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.kitchen_inventory;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'inventory'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'recipe_ingredients'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.recipe_ingredients;
    END IF;
END $$;
