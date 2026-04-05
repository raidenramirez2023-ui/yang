-- Fix RLS policies for chat system
-- Run this to fix the permission issues

-- First, let's see current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('chat_messages', 'chat_sessions');

-- Drop existing policies that might be causing issues
DROP POLICY IF EXISTS "Customers can view own messages" ON chat_messages;
DROP POLICY IF EXISTS "Customers can insert own messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON chat_messages;
DROP POLICY IF EXISTS "Admins can update messages" ON chat_messages;

DROP POLICY IF EXISTS "Customers can view own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Customers can insert own sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can view all sessions" ON chat_sessions;
DROP POLICY IF EXISTS "Admins can update sessions" ON chat_sessions;

-- Create new, simpler policies for chat_messages
CREATE POLICY "Enable insert for authenticated users" ON chat_messages
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable read for own messages" ON chat_messages
    FOR SELECT USING (
        auth.role() = 'authenticated' AND (
            customer_email = auth.email() OR 
            EXISTS (
                SELECT 1 FROM users 
                WHERE users.id = auth.uid() AND users.role = 'admin'
            )
        )
    );

CREATE POLICY "Enable update for admins" ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() AND users.role = 'admin'
        )
    );

-- Create new, simpler policies for chat_sessions
CREATE POLICY "Enable insert for authenticated users" ON chat_sessions
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable read for own sessions" ON chat_sessions
    FOR SELECT USING (
        auth.role() = 'authenticated' AND (
            customer_email = auth.email() OR 
            EXISTS (
                SELECT 1 FROM users 
                WHERE users.id = auth.uid() AND users.role = 'admin'
            )
        )
    );

CREATE POLICY "Enable update for admins" ON chat_sessions
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() AND users.role = 'admin'
        )
    );

-- Also, let's disable RLS temporarily to test
-- ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE chat_sessions DISABLE ROW LEVEL SECURITY;
