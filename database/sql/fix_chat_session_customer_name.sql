-- =========================================================================
-- FIX CHAT SESSION CUSTOMER NAME & PREVENT CONCIERGE BOT OVERWRITE
-- =========================================================================

-- 1. Update the trigger function so that bot/concierge/admin replies NEVER
--    overwrite the customer's name in chat_sessions.
CREATE OR REPLACE FUNCTION sync_chat_session_on_message()
RETURNS TRIGGER AS $$
DECLARE
    v_actual_customer_name TEXT;
BEGIN
    -- Look up the actual customer name from public.users first
    SELECT COALESCE(
        NULLIF(TRIM(CONCAT(firstname, ' ', lastname)), ''),
        name,
        split_part(NEW.customer_email, '@', 1)
    ) INTO v_actual_customer_name
    FROM users 
    WHERE email = NEW.customer_email 
    LIMIT 1;

    -- If not found in users, fall back to NEW.customer_name only if it's really the customer
    IF v_actual_customer_name IS NULL OR v_actual_customer_name = '' THEN
        IF NEW.is_from_customer = true 
           AND NEW.customer_name IS NOT NULL 
           AND NEW.customer_name NOT ILIKE '%concierge%' 
           AND NEW.customer_name NOT ILIKE '%bot%' THEN
            v_actual_customer_name := NEW.customer_name;
        ELSE
            v_actual_customer_name := split_part(NEW.customer_email, '@', 1);
        END IF;
    END IF;

    -- Update or Insert session info
    INSERT INTO chat_sessions (
        customer_email, 
        customer_name, 
        last_message_at, 
        last_message_text, 
        updated_at
    )
    VALUES (
        NEW.customer_email, 
        v_actual_customer_name, 
        NEW.created_at, 
        NEW.message, 
        NOW()
    )
    ON CONFLICT (customer_email) DO UPDATE 
    SET 
        last_message_at = NEW.created_at,
        last_message_text = NEW.message,
        updated_at = NOW(),
        -- Only overwrite customer_name if:
        -- 1. The existing customer_name was wrongly set to bot/concierge/customer/null
        -- 2. OR the new incoming message is directly from the real customer
        customer_name = CASE 
            WHEN chat_sessions.customer_name IS NULL 
                 OR chat_sessions.customer_name ILIKE '%concierge%' 
                 OR chat_sessions.customer_name ILIKE '%bot%' 
                 OR chat_sessions.customer_name = 'Customer' THEN v_actual_customer_name
            WHEN NEW.is_from_customer = true 
                 AND NEW.customer_name IS NOT NULL 
                 AND NEW.customer_name NOT ILIKE '%concierge%' 
                 AND NEW.customer_name NOT ILIKE '%bot%' THEN NEW.customer_name
            ELSE chat_sessions.customer_name
        END;

    -- Recalculate unread count for the customer
    UPDATE chat_sessions 
    SET 
        unread_customer_count = (
            SELECT COUNT(*) FROM chat_messages 
            WHERE customer_email = NEW.customer_email 
            AND is_from_customer = true 
            AND is_read = false
        ),
        unread_admin_count = (
            SELECT COUNT(*) FROM chat_messages 
            WHERE customer_email = NEW.customer_email 
            AND is_from_customer = false 
            AND is_read = false
        )
    WHERE customer_email = NEW.customer_email;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger if needed
DROP TRIGGER IF EXISTS trg_sync_chat_session ON chat_messages;
CREATE TRIGGER trg_sync_chat_session
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION sync_chat_session_on_message();

-- 2. Fix all existing chat_sessions rows that currently have "Yang Chow Concierge" or "Customer"
UPDATE chat_sessions cs
SET customer_name = COALESCE(
    (
        SELECT NULLIF(TRIM(CONCAT(u.firstname, ' ', u.lastname)), '') 
        FROM users u 
        WHERE u.email = cs.customer_email 
        LIMIT 1
    ),
    (
        SELECT u.name 
        FROM users u 
        WHERE u.email = cs.customer_email 
        LIMIT 1
    ),
    split_part(cs.customer_email, '@', 1)
)
WHERE cs.customer_name ILIKE '%concierge%' 
   OR cs.customer_name ILIKE '%bot%' 
   OR cs.customer_name IS NULL 
   OR cs.customer_name = 'Customer';

-- 3. Verify updated chat_sessions
SELECT id, customer_email, customer_name, last_message_at, updated_at 
FROM chat_sessions 
ORDER BY last_message_at DESC 
LIMIT 20;
