-- EMERGENCY FIX: Admin Chat Visibility
-- Run this if the admin still sees "No conversations yet"

-- 1. Fix the is_admin() function to check by email (more reliable)
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE email = auth.email() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Force sync the admin email role just in case
UPDATE users SET role = 'admin' WHERE email = 'admn.pagsanjan@gmail.com';

-- 3. Ensure the chat_sessions are populated from existing messages
INSERT INTO chat_sessions (customer_email, customer_name, last_message_at, updated_at)
SELECT DISTINCT ON (customer_email) 
    customer_email, 
    customer_name, 
    MAX(created_at) OVER (PARTITION BY customer_email),
    NOW()
FROM chat_messages
ON CONFLICT (customer_email) DO UPDATE SET
    last_message_at = EXCLUDED.last_message_at,
    updated_at = NOW();

-- 4. Double check RLS policies for chat_sessions
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View sessions policy" ON chat_sessions;
CREATE POLICY "View sessions policy" ON chat_sessions
    FOR SELECT USING (
        customer_email = auth.email() OR is_admin()
    );

DROP POLICY IF EXISTS "Update sessions policy" ON chat_sessions;
CREATE POLICY "Update sessions policy" ON chat_sessions
    FOR UPDATE USING (
        customer_email = auth.email() OR is_admin()
    );

-- 5. Double check RLS policies for chat_messages
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "View messages policy" ON chat_messages;
CREATE POLICY "View messages policy" ON chat_messages
    FOR SELECT USING (
        customer_email = auth.email() OR is_admin()
    );

-- 6. Trigger update: ensure unread counts are synced
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
    last_message_text = (
        SELECT message FROM chat_messages cm 
        WHERE cm.customer_email = cs.customer_email
        ORDER BY created_at DESC LIMIT 1
    );

-- 7. Grant access for realtime
GRANT SELECT ON chat_sessions TO authenticated;
GRANT SELECT ON chat_messages TO authenticated;

SELECT 'Emergency fix applied!' as status, 
       (SELECT COUNT(*) FROM chat_sessions) as total_sessions,
       is_admin() as current_user_is_admin;
