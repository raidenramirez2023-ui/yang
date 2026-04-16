-- =========================================================
-- FIX ADMIN CHAT CONVERSATIONS: Table Conversion & Robust RLS
-- =========================================================

-- 1. Ensure columns exist in chat_sessions for streaming
ALTER TABLE chat_sessions 
ADD COLUMN IF NOT EXISTS unread_customer_count BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS unread_admin_count BIGINT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_message_text TEXT;

-- 2. Drop the old view if it exists (we'll stream the table instead)
DROP VIEW IF EXISTS admin_chat_conversations;
DROP VIEW IF EXISTS secure_admin_chat_conversations;

-- 3. Create a more robust function to check for admin role
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Update RLS Policies for chat_messages
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable all for authenticated users on messages" ON chat_messages;
DROP POLICY IF EXISTS "Customers can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Customers can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can update messages" ON chat_messages;

-- Policy: Anyone can view their own messages or if they are admin
CREATE POLICY "View messages policy" ON chat_messages
    FOR SELECT USING (
        customer_email = auth.email() OR is_admin()
    );

-- Policy: Anyone can insert their own messages OR if they are admin (sending to a customer)
CREATE POLICY "Insert messages policy" ON chat_messages
    FOR INSERT WITH CHECK (
        (customer_email = auth.email() AND is_from_customer = true) OR is_admin()
    );

-- Policy: Admins or the customer can mark messages as read
CREATE POLICY "Update messages policy" ON chat_messages
    FOR UPDATE USING (
        customer_email = auth.email() OR is_admin()
    );

-- 5. Update RLS Policies for chat_sessions
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable all for authenticated users on sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Customers can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Customers can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can view all sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can update sessions" ON chat_sessions;

CREATE POLICY "View sessions policy" ON chat_sessions
    FOR SELECT USING (
        customer_email = auth.email() OR is_admin()
    );

CREATE POLICY "Insert sessions policy" ON chat_sessions
    FOR INSERT WITH CHECK (
        customer_email = auth.email() OR is_admin()
    );

CREATE POLICY "Update sessions policy" ON chat_sessions
    FOR UPDATE USING (
        customer_email = auth.email() OR is_admin()
    );

-- 6. Trigger Function to sync unread counts and last message in chat_sessions
CREATE OR REPLACE FUNCTION sync_chat_session_on_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or Insert session info
    INSERT INTO chat_sessions (customer_email, customer_name, last_message_at, last_message_text, updated_at)
    VALUES (NEW.customer_email, NEW.customer_name, NEW.created_at, NEW.message, NOW())
    ON CONFLICT (customer_email) DO UPDATE 
    SET 
        last_message_at = NEW.created_at,
        last_message_text = NEW.message,
        updated_at = NOW(),
        -- Only update customer_name if not null
        customer_name = COALESCE(NEW.customer_name, chat_sessions.customer_name);

    -- Calculate current unread counts for this specific customer
    -- We do a full count to ensure accuracy, though an increment pattern is possible
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

-- 7. Trigger Function to sync when a message is UPDATED (e.g. marked as read or unsent)
CREATE OR REPLACE FUNCTION sync_chat_session_on_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Update unread counts
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
        ),
        -- Update last message text if it was changed (e.g. unsent)
        last_message_text = CASE 
            WHEN NEW.created_at >= (SELECT MAX(created_at) FROM chat_messages WHERE customer_email = NEW.customer_email)
            THEN NEW.message 
            ELSE last_message_text 
        END,
        updated_at = NOW()
    WHERE customer_email = NEW.customer_email;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Bind Triggers
DROP TRIGGER IF EXISTS tr_sync_session_on_insert ON chat_messages;
CREATE TRIGGER tr_sync_session_on_insert
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION sync_chat_session_on_message();

DROP TRIGGER IF EXISTS tr_sync_session_on_update ON chat_messages;
CREATE TRIGGER tr_sync_session_on_update
    AFTER UPDATE ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION sync_chat_session_on_update();

-- 9. Initial data sync: Populate unread counts and last message for existing data
UPDATE chat_sessions cs
SET 
    unread_customer_count = (
        SELECT COUNT(*) FROM chat_messages cm 
        WHERE cm.customer_email = cs.customer_email 
        AND cm.is_from_customer = true 
        AND cm.is_read = false
    ),
    unread_admin_count = (
        SELECT COUNT(*) FROM chat_messages cm 
        WHERE cm.customer_email = cs.customer_email 
        AND cm.is_from_customer = false 
        AND cm.is_read = false
    ),
    last_message_at = (
        SELECT MAX(created_at) FROM chat_messages cm 
        WHERE cm.customer_email = cs.customer_email
    ),
    last_message_text = (
        SELECT message FROM chat_messages cm 
        WHERE cm.customer_email = cs.customer_email
        ORDER BY created_at DESC LIMIT 1
    );

-- 10. Enable Realtime for the table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_sessions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_sessions;
    END IF;
END $$;

-- 11. Optional: Ensure the specific admin email has the admin role
INSERT INTO users (email, role) 
VALUES ('admn.pagsanjan@gmail.com', 'admin')
ON CONFLICT (email) DO UPDATE SET role = 'admin';

-- 12. Final Grants
GRANT SELECT, INSERT, UPDATE ON chat_sessions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO authenticated;

SELECT 'Admin chat fix applied successfully!' as result;
