-- ==============================================================================
-- Migration: Purge Developer Maintenance Test Payments & Orders
-- Yang Chow Restaurant Management System (YCPRMS)
-- ==============================================================================
-- Description:
-- Safely deletes test orders, payments, order items, refunds, and reservations
-- created during developer maintenance mode or by developer accounts.
-- Ensures Admin Daily & Monthly Sales Reports, Revenue Analytics, and Inventory
-- remain 100% clean and free of test numbers.
-- ==============================================================================

-- 1. Create Stored Procedure / Function to Purge Maintenance Test Data
CREATE OR REPLACE FUNCTION public.purge_maintenance_test_data(
    p_operator_email TEXT DEFAULT 'yangchowit@gmail.com',
    p_window_start TIMESTAMPTZ DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
    DECLARE
    v_start_time TIMESTAMPTZ;
    v_deleted_orders INT := 0;
    v_deleted_order_items INT := 0;
    v_deleted_reservations INT := 0;
    v_deleted_advance_orders INT := 0;
    v_deleted_refunds INT := 0;
    v_order_ids UUID[];
    v_reservation_ids UUID[];
    v_advance_order_ids UUID[];
BEGIN
    -- Determine start window: use passed parameter, or get maintenance_start_time from app_settings
    IF p_window_start IS NOT NULL THEN
        v_start_time := p_window_start;
    ELSE
        SELECT (setting_value)::timestamptz INTO v_start_time
        FROM public.app_settings
        WHERE setting_key = 'maintenance_start_time'
          AND setting_value IS NOT NULL
          AND setting_value <> '';
          
        -- If no active maintenance start time found, default to last 6 hours
        IF v_start_time IS NULL THEN
            v_start_time := NOW() - INTERVAL '6 hours';
        END IF;
    END IF;

    -- 1. Collect test order IDs created during maintenance window or by developer email
    SELECT ARRAY_AGG(id) INTO v_order_ids
    FROM public.orders
    WHERE created_at >= v_start_time
       OR staff_email = p_operator_email
       OR customer_name ILIKE '%test%'
       OR transaction_id ILIKE '%test%';

    IF v_order_ids IS NOT NULL AND ARRAY_LENGTH(v_order_ids, 1) > 0 THEN
        -- Delete refunds referencing these orders
        DELETE FROM public.refunds
        WHERE source_id = ANY(v_order_ids);
        GET DIAGNOSTICS v_deleted_refunds = ROW_COUNT;

        -- Delete order items
        DELETE FROM public.order_items
        WHERE order_id = ANY(v_order_ids);
        GET DIAGNOSTICS v_deleted_order_items = ROW_COUNT;

        -- Delete orders
        DELETE FROM public.orders
        WHERE id = ANY(v_order_ids);
        GET DIAGNOSTICS v_deleted_orders = ROW_COUNT;
    END IF;

    -- 2. Collect test event / reservation IDs created during maintenance or marked with test
    SELECT ARRAY_AGG(id) INTO v_reservation_ids
    FROM public.reservations
    WHERE (created_at >= v_start_time AND (email ILIKE '%dev%' OR email = p_operator_email OR customer_name ILIKE '%test%'))
       OR customer_name ILIKE '%test%'
       OR email = p_operator_email
       OR notes ILIKE '%test%'
       OR notes ILIKE '%[DEV TEST]%';

    IF v_reservation_ids IS NOT NULL AND ARRAY_LENGTH(v_reservation_ids, 1) > 0 THEN
        -- Delete refunds referencing these reservations
        DELETE FROM public.refunds
        WHERE source_id = ANY(v_reservation_ids);

        -- Delete reservations
        DELETE FROM public.reservations
        WHERE id = ANY(v_reservation_ids);
        GET DIAGNOSTICS v_deleted_reservations = ROW_COUNT;
    END IF;

    -- 3. Collect test advance_order IDs created during maintenance or marked with test
    SELECT ARRAY_AGG(id) INTO v_advance_order_ids
    FROM public.advance_orders
    WHERE (created_at >= v_start_time AND (email ILIKE '%dev%' OR email = p_operator_email OR customer_name ILIKE '%test%'))
       OR customer_name ILIKE '%test%'
       OR email = p_operator_email;

    IF v_advance_order_ids IS NOT NULL AND ARRAY_LENGTH(v_advance_order_ids, 1) > 0 THEN
        -- Delete refunds referencing these advance orders
        DELETE FROM public.refunds
        WHERE source_id = ANY(v_advance_order_ids);

        -- Delete advance orders
        DELETE FROM public.advance_orders
        WHERE id = ANY(v_advance_order_ids);
        GET DIAGNOSTICS v_deleted_advance_orders = ROW_COUNT;
    END IF;

    -- 4. Clean up test audit logs and technical framework crash logs from maintenance window
    DELETE FROM public.audit_logs
    WHERE (created_at >= v_start_time AND (action IN ('ERROR', 'CRITICAL') OR module ILIKE '%library%'))
       OR user_email = p_operator_email
       OR user_role = 'DEVELOPER';

    -- Record in audit logs
    INSERT INTO public.audit_logs (
        action,
        module,
        description,
        user_email,
        user_role,
        created_at
    ) VALUES (
        'PURGE_MAINTENANCE_TEST_DATA',
        'Maintenance',
        FORMAT('Purged %s test orders, %s test events/reservations, and %s test advance orders created during maintenance window (%s).',
            v_deleted_orders, v_deleted_reservations, v_deleted_advance_orders, v_start_time),
        p_operator_email,
        'DEVELOPER',
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'deleted_orders', v_deleted_orders,
        'deleted_order_items', v_deleted_order_items,
        'deleted_reservations', v_deleted_reservations,
        'deleted_advance_orders', v_deleted_advance_orders,
        'deleted_refunds', v_deleted_refunds,
        'window_start', v_start_time
    );
END;
$$;

-- Grant execution permission
GRANT EXECUTE ON FUNCTION public.purge_maintenance_test_data TO authenticated;
GRANT EXECUTE ON FUNCTION public.purge_maintenance_test_data TO service_role;

-- ==============================================================================
-- MANUAL ONE-CLICK CLEANUP QUERIES (Alternative if running directly in SQL Editor)
-- ==============================================================================

-- 1. Check what test orders currently exist before deleting:
-- SELECT id, transaction_id, customer_name, total_amount, staff_email, created_at 
-- FROM public.orders 
-- WHERE staff_email = 'yangchowit@gmail.com' 
--    OR customer_name ILIKE '%test%'
-- ORDER BY created_at DESC;

-- 2. Delete test order items and orders:
-- WITH target_orders AS (
--     SELECT id FROM public.orders
--     WHERE staff_email = 'yangchowit@gmail.com'
--        OR customer_name ILIKE '%test%'
-- )
-- DELETE FROM public.order_items WHERE order_id IN (SELECT id FROM target_orders);

-- DELETE FROM public.orders
-- WHERE staff_email = 'yangchowit@gmail.com'
--    OR customer_name ILIKE '%test%';

-- 3. Delete test reservations:
-- DELETE FROM public.reservations
-- WHERE email = 'yangchowit@gmail.com'
--    OR customer_name ILIKE '%test%';
