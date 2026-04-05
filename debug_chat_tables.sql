-- Debug chat tables - check if they exist and have data
SELECT 'chat_messages' as table_name, 
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_messages') as exists,
       (SELECT COUNT(*) FROM chat_messages) as row_count
UNION ALL
SELECT 'chat_sessions' as table_name,
       EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'chat_sessions') as exists,
       (SELECT COUNT(*) FROM chat_sessions) as row_count;

-- Check table structure
\d chat_messages
\d chat_sessions

-- Check if user is authenticated
SELECT auth.uid(), auth.email(), auth.role();

-- Try a simple insert test
INSERT INTO chat_messages (customer_email, customer_name, message, is_from_customer, is_read)
VALUES ('test@example.com', 'Test User', 'Test message', true, false)
RETURNING *;
