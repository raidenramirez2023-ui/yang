-- FINAL CHAT SETUP - Complete Working System
-- Run this entire script after deleting old chat tables

-- First, drop everything to start fresh
DROP TABLE IF EXISTS admin_chat_conversations;
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_sessions;
DROP VIEW IF EXISTS admin_chat_conversations;

-- Drop all functions and triggers
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_session_last_message() CASCADE;
DROP FUNCTION IF EXISTS get_or_create_chat_session(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS update_admin_conversation() CASCADE;
DROP FUNCTION IF EXISTS update_conversation_unread_count() CASCADE;

-- Create chat messages table
CREATE TABLE chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_email TEXT NOT NULL,
    customer_name TEXT,
    message TEXT NOT NULL,
    is_from_customer BOOLEAN DEFAULT true,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create chat sessions table
CREATE TABLE chat_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_email TEXT NOT NULL,
    customer_name TEXT,
    session_status TEXT DEFAULT 'active' CHECK (session_status IN ('active', 'closed', 'archived')),
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    UNIQUE(customer_email)
);

-- Create indexes
CREATE INDEX idx_chat_messages_customer_email ON chat_messages(customer_email);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_chat_messages_is_read ON chat_messages(is_read);
CREATE INDEX idx_chat_sessions_customer_email ON chat_sessions(customer_email);
CREATE INDEX idx_chat_sessions_status ON chat_sessions(session_status);

-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- SIMPLE RLS POLICIES - Allow all authenticated users
CREATE POLICY "Enable all for authenticated users on messages" ON chat_messages
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Enable all for authenticated users on sessions" ON chat_sessions
    FOR ALL USING (auth.role() = 'authenticated');

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for timestamps
CREATE TRIGGER update_chat_messages_updated_at 
    BEFORE UPDATE ON chat_messages 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_chat_sessions_updated_at 
    BEFORE UPDATE ON chat_sessions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update session when message is sent
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

-- Create trigger for session updates
CREATE TRIGGER update_session_on_message
    AFTER INSERT ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION update_session_last_message();

-- Create function to get or create chat session
CREATE OR REPLACE FUNCTION get_or_create_chat_session(p_customer_email TEXT, p_customer_name TEXT DEFAULT NULL)
RETURNS UUID AS $$
DECLARE
    session_id UUID;
BEGIN
    SELECT id INTO session_id 
    FROM chat_sessions 
    WHERE customer_email = p_customer_email AND session_status = 'active'
    LIMIT 1;
    
    IF session_id IS NULL THEN
        INSERT INTO chat_sessions (customer_email, customer_name)
        VALUES (p_customer_email, p_customer_name)
        RETURNING id INTO session_id;
    END IF;
    
    RETURN session_id;
END;
$$ LANGUAGE plpgsql;

-- Create admin conversations view
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

-- Grant access to view
GRANT SELECT ON admin_chat_conversations TO authenticated;

-- Enable Realtime for chat tables
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_sessions;

-- Test the system
SELECT 'Chat system setup complete!' as status;

-- Check current user
SELECT 
    'Current user' as info,
    auth.uid() as user_id,
    auth.email() as email,
    auth.role() as role;
