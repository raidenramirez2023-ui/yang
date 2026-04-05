-- Drop All Chat RLS Policies
-- This removes all problematic policies to start fresh

-- Drop all chat message policies
DROP POLICY IF EXISTS "Customers can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Customers can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can update messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can insert messages" ON chat_messages;
DROP POLICY IF EXISTS "Enable customer access" ON chat_messages;
DROP POLICY IF EXISTS "Enable admin access" ON chat_messages;

-- Drop all chat session policies
DROP POLICY IF EXISTS "Customers can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Customers can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can view all sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can update sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Enable customer session access" ON chat_sessions;
DROP POLICY IF EXISTS "Enable admin session access" ON chat_sessions;

-- Drop admin conversations policies
DROP POLICY IF EXISTS "Admin can access conversations" ON admin_chat_conversations;
DROP POLICY IF EXISTS "Admin can manage conversations" ON admin_chat_conversations;

-- Show result
SELECT 
    'All chat policies dropped' as status,
    COUNT(*) as policies_dropped
FROM pg_policies 
WHERE tablename IN ('chat_messages', 'chat_sessions', 'admin_chat_conversations');

-- Show remaining tables
SELECT 
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('chat_messages', 'chat_sessions', 'admin_chat_conversations')
ORDER BY tablename;
