-- Simple fix for chat view creation
-- Run this first, then run your update_chat_view.sql

-- Step 1: Create the view (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'admin_chat_conversations') THEN
        EXECUTE '
        CREATE VIEW admin_chat_conversations AS
        SELECT 
            cs.id as session_id,
            cs.customer_email,
            cs.customer_name,
            cs.session_status,
            cs.last_message_at,
            cs.created_at,
            0 as unread_customer_count,
            0 as unread_admin_count,
            cs.last_message_at as last_message_time
        FROM chat_sessions cs
        WHERE cs.session_status = ''active''
        ORDER BY cs.last_message_at DESC';
    END IF;
END $$;

-- Step 2: Now update the view with proper counts
CREATE OR REPLACE VIEW admin_chat_conversations AS
SELECT 
    cs.id as session_id,
    cs.customer_email,
    cs.customer_name,
    cs.session_status,
    cs.last_message_at,
    cs.created_at,
    COUNT(cm.id) FILTER (WHERE cm.is_from_customer = true AND cm.is_read = false) as unread_customer_count,
    COUNT(cm.id) FILTER (WHERE cm.is_from_customer = false AND cm.is_read = false) as unread_admin_count,
    MAX(cm.created_at) as last_message_time
FROM chat_sessions cs
LEFT JOIN chat_messages cm ON cs.customer_email = cm.customer_email
WHERE cs.session_status = 'active'
GROUP BY cs.id, cs.customer_email, cs.customer_name, cs.session_status, cs.last_message_at, cs.created_at
ORDER BY cs.last_message_at DESC;
