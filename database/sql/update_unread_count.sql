-- Update unread count when admin reads messages
-- This will automatically update the unread_customer_count in admin_chat_conversations view

-- Function to update unread count for all conversations
CREATE OR REPLACE FUNCTION update_all_unread_counts()
RETURNS void AS $$
BEGIN
    -- Update admin_chat_conversations view to reflect current unread counts
    REFRESH MATERIALIZED VIEW admin_chat_conversations;
END;
$$ LANGUAGE plpgsql;

-- Function to mark specific conversation messages as read and update count
CREATE OR REPLACE FUNCTION mark_conversation_as_read(p_customer_email TEXT)
RETURNS void AS $$
BEGIN
    -- Mark all customer messages as read for this conversation
    UPDATE chat_messages 
    SET is_read = true 
    WHERE customer_email = p_customer_email 
    AND is_from_customer = true 
    AND is_read = false;
    
    -- Update the session's last_message_at to trigger view refresh
    UPDATE chat_sessions 
    SET updated_at = NOW() 
    WHERE customer_email = p_customer_email;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update unread counts when messages change
CREATE OR REPLACE FUNCTION update_conversation_unread_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- When a message is marked as read, update the session
    IF TG_OP = 'UPDATE' AND OLD.is_read = false AND NEW.is_read = true THEN
        UPDATE chat_sessions 
        SET updated_at = NOW() 
        WHERE customer_email = NEW.customer_email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_unread_trigger ON chat_messages;

-- Create trigger for automatic unread count updates
CREATE TRIGGER update_unread_trigger
    AFTER UPDATE ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION update_conversation_unread_trigger();

-- Test the functions
-- Mark a specific conversation as read (example)
-- SELECT mark_conversation_as_read('customer@example.com');

-- Update all unread counts
-- SELECT update_all_unread_counts();

-- Check current unread counts
SELECT 
    cs.customer_email,
    COUNT(cm.id) FILTER (WHERE cm.is_from_customer = true AND cm.is_read = false) as unread_customer_count,
    COUNT(cm.id) FILTER (WHERE cm.is_from_customer = false AND cm.is_read = false) as unread_admin_count,
    MAX(cm.created_at) as last_message_time
FROM chat_sessions cs
LEFT JOIN chat_messages cm ON cs.customer_email = cm.customer_email
WHERE cs.session_status = 'active'
GROUP BY cs.customer_email
ORDER BY MAX(cm.created_at) DESC;
