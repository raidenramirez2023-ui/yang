-- Check what admin_chat_conversations actually is
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_name = 'admin_chat_conversations';

-- If it's a table, drop it and create as view
DROP TABLE IF EXISTS admin_chat_conversations;

-- Now create the view
CREATE VIEW admin_chat_conversations AS
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
