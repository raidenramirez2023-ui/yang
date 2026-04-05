-- Fix Chat RLS Policies
-- This script fixes the RLS policies to allow admin access

-- First, drop all existing policies
DROP POLICY IF EXISTS "Customers can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Customers can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can update messages" ON chat_messages;

DROP POLICY IF EXISTS "Customers can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Customers can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can view all sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can update sessions" ON chat_sessions;

-- Create new RLS policies with simpler admin check

-- Chat Messages Policies
-- Customers can view their own messages
CREATE POLICY "Customers can view own messages" ON chat_messages
    FOR SELECT USING (
        customer_email = auth.email()
    );

-- Customers can insert their own messages
CREATE POLICY "Customers can insert own messages" ON chat_messages
    FOR INSERT WITH CHECK (
        customer_email = auth.email()
    );

-- Admins can view all messages (check by email)
CREATE POLICY "Admins can view all messages" ON chat_messages
    FOR SELECT USING (
        auth.email() = 'admn.pagsanjan@gmail.com'
    );

-- Admins can insert messages (check by email)
CREATE POLICY "Admins can insert messages" ON chat_messages
    FOR INSERT WITH CHECK (
        auth.email() = 'admn.pagsanjan@gmail.com'
    );

-- Admins can update messages (check by email)
CREATE POLICY "Admins can update messages" ON chat_messages
    FOR UPDATE USING (
        auth.email() = 'admn.pagsanjan@gmail.com'
    );

-- Chat Sessions Policies
-- Customers can view their own sessions
CREATE POLICY "Customers can view own sessions" ON chat_sessions
    FOR SELECT USING (
        customer_email = auth.email()
    );

-- Customers can insert their own sessions
CREATE POLICY "Customers can insert own sessions" ON chat_sessions
    FOR INSERT WITH CHECK (
        customer_email = auth.email()
    );

-- Admins can view all sessions (check by email)
CREATE POLICY "Admins can view all sessions" ON chat_sessions
    FOR SELECT USING (
        auth.email() = 'admn.pagsanjan@gmail.com'
    );

-- Admins can update sessions (check by email)
CREATE POLICY "Admins can update sessions" ON chat_sessions
    FOR UPDATE USING (
        auth.email() = 'admn.pagsanjan@gmail.com'
    );

-- Also fix the admin_chat_conversations view
DROP VIEW IF EXISTS admin_chat_conversations;

CREATE OR REPLACE VIEW admin_chat_conversations AS
SELECT 
    cs.id as session_id,
    cs.customer_email,
    cs.customer_name,
    cs.session_status,
    cs.last_message_at,
    cs.created_at,
    COUNT(cm.id) FILTER (WHERE cm.is_from_customer = true AND cm.is_read = false) as unread_count,
    MAX(cm.created_at) as last_message_time
FROM chat_sessions cs
LEFT JOIN chat_messages cm ON cs.customer_email = cm.customer_email
WHERE cs.session_status = 'active'
GROUP BY cs.id, cs.customer_email, cs.customer_name, cs.session_status, cs.last_message_at, cs.created_at
ORDER BY cs.last_message_at DESC;

-- Grant access to the view for admins
GRANT SELECT ON admin_chat_conversations TO authenticated;

-- Test query to verify admin can see messages
SELECT 
    'Testing admin access to messages' as test_type,
    COUNT(*) as total_messages,
    auth.email() as current_user
FROM chat_messages
WHERE auth.email() = 'admn.pagsanjan@gmail.com';

-- Test query to verify customer can see their own messages
SELECT 
    'Testing customer access to own messages' as test_type,
    COUNT(*) as own_messages,
    auth.email() as current_user
FROM chat_messages
WHERE customer_email = auth.email();

-- Show current user info for debugging
SELECT 
    'Current user info' as info_type,
    auth.email() as email,
    auth.uid() as uid,
    'Authenticated' as status;

-- Enable Realtime for chat tables
-- This allows Supabase to push real-time updates
-- Handle cases where tables might already be in the publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_sessions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chat_sessions;
    END IF;
END $$;

-- Create triggers to update session timestamps
CREATE OR REPLACE FUNCTION update_session_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_sessions 
    SET last_message_at = NEW.created_at,
        updated_at = NOW()
    WHERE customer_email = NEW.customer_email;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_session_on_message ON chat_messages;

-- Create trigger to automatically update session when message is sent
CREATE TRIGGER update_session_on_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION update_session_last_message();

-- Function to create or get chat session for a customer
CREATE OR REPLACE FUNCTION get_or_create_chat_session(p_customer_email TEXT, p_customer_name TEXT DEFAULT NULL)
RETURNS UUID AS $$
DECLARE
    session_id UUID;
BEGIN
    -- Try to get existing session
    SELECT id INTO session_id 
    FROM chat_sessions 
    WHERE customer_email = p_customer_email AND session_status = 'active'
    LIMIT 1;
    
    -- If no session exists, create one
    IF session_id IS NULL THEN
        INSERT INTO chat_sessions (customer_email, customer_name)
        VALUES (p_customer_email, p_customer_name)
        RETURNING id INTO session_id;
    END IF;
    
    RETURN session_id;
END;
$$ LANGUAGE plpgsql;

-- Test the complete system
-- This should show all messages for admins and only own messages for customers
SELECT 
    'Final test - All messages (admin only)' as test_type,
    COUNT(*) as count,
    auth.email() as current_user
FROM chat_messages
WHERE auth.email() = 'admn.pagsanjan@gmail.com';

SELECT 
    'Final test - Customer messages only' as test_type,
    COUNT(*) as count,
    auth.email() as current_user
FROM chat_messages
WHERE customer_email = auth.email();
