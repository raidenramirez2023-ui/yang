-- Simple fix for chat system - disable RLS temporarily for testing
ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions DISABLE ROW LEVEL SECURITY;

-- Check if user is authenticated and what email they have
SELECT 
    'Current User Info' as info,
    auth.uid() as user_id,
    auth.email() as email,
    auth.role() as role;

-- Test inserting a message manually
INSERT INTO chat_messages (customer_email, customer_name, message, is_from_customer, is_read)
VALUES ('test@example.com', 'Test User', 'Test message from SQL', true, false)
RETURNING *;

-- Check if message was inserted
SELECT * FROM chat_messages ORDER BY created_at DESC LIMIT 5;

-- If this works, the issue is with RLS policies
-- Let's create very simple RLS policies
CREATE POLICY "Allow all authenticated users" ON chat_messages
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all authenticated users" ON chat_sessions
    FOR ALL USING (auth.role() = 'authenticated');

-- Re-enable RLS with simple policies
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
