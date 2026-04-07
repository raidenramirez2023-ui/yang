-- Complete Chat System Setup
-- Run this entire script in Supabase SQL Editor

-- First, create the tables if they don't exist
CREATE TABLE IF NOT EXISTS chat_messages (
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

CREATE TABLE IF NOT EXISTS chat_sessions (
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
CREATE INDEX IF NOT EXISTS idx_chat_messages_customer_email ON chat_messages(customer_email);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_is_read ON chat_messages(is_read);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_customer_email ON chat_sessions(customer_email);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_status ON chat_sessions(session_status);

-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;

-- Create or replace the view (this will work even if view doesn't exist)
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

-- Create function for updating timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers
DROP TRIGGER IF EXISTS update_chat_messages_updated_at ON chat_messages;
CREATE TRIGGER update_chat_messages_updated_at 
    BEFORE UPDATE ON chat_messages 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_sessions_updated_at ON chat_sessions;
CREATE TRIGGER update_chat_sessions_updated_at 
    BEFORE UPDATE ON chat_sessions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to update session last message time
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
DROP TRIGGER IF EXISTS update_session_on_message ON chat_messages;
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

-- Create RLS Policies
DROP POLICY IF EXISTS "Customers can view own messages" ON chat_messages;
CREATE POLICY "Customers can view own messages" ON chat_messages
    FOR SELECT USING (
        customer_email = auth.email()
    );

DROP POLICY IF EXISTS "Customers can insert own messages" ON chat_messages;
CREATE POLICY "Customers can insert own messages" ON chat_messages
    FOR INSERT WITH CHECK (
        customer_email = auth.email()
    );

DROP POLICY IF EXISTS "Admins can view all messages" ON chat_messages;
CREATE POLICY "Admins can view all messages" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Admins can update messages" ON chat_messages;
CREATE POLICY "Admins can update messages" ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

-- Similar policies for chat_sessions
DROP POLICY IF EXISTS "Customers can view own sessions" ON chat_sessions;
CREATE POLICY "Customers can view own sessions" ON chat_sessions
    FOR SELECT USING (
        customer_email = auth.email()
    );

DROP POLICY IF EXISTS "Customers can insert own sessions" ON chat_sessions;
CREATE POLICY "Customers can insert own sessions" ON chat_sessions
    FOR INSERT WITH CHECK (
        customer_email = auth.email()
    );

DROP POLICY IF EXISTS "Admins can view all sessions" ON chat_sessions;
CREATE POLICY "Admins can view all sessions" ON chat_sessions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

DROP POLICY IF EXISTS "Admins can update sessions" ON chat_sessions;
CREATE POLICY "Admins can update sessions" ON chat_sessions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );
