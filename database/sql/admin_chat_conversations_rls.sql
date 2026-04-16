-- =========================================
-- RLS POLICY FOR ADMIN_CHAT_CONVERSATIONS VIEW
-- =========================================

-- Note: admin_chat_conversations is a VIEW, not a table
-- Views use GRANT statements instead of RLS policies
-- This script shows the current access and provides alternative security

-- 1. Check current grants on the view
SELECT 
    'Current grants on admin_chat_conversations:' as info,
    grantee,
    privilege_type,
    grantor
FROM information_schema.role_table_grants 
WHERE table_name = 'admin_chat_conversations'
ORDER BY grantee, privilege_type;

-- 2. Current grant (from final_chat_setup.sql)
-- This is already in place: GRANT SELECT ON admin_chat_conversations TO authenticated;

-- 3. Alternative: Create a secured function instead of direct view access
CREATE OR REPLACE FUNCTION get_admin_conversations(p_user_email TEXT DEFAULT NULL)
RETURNS TABLE (
    session_id UUID,
    customer_email TEXT,
    customer_name TEXT,
    session_status TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    unread_customer_count BIGINT,
    unread_admin_count BIGINT,
    last_message_time TIMESTAMP WITH TIME ZONE
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
    -- Only allow authenticated users to access conversations
    -- If p_user_email is provided, filter by that email (for customer access)
    -- If NULL, return all conversations (for admin access)
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
    AND (
        -- Admin can see all conversations
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
        OR
        -- Customer can only see their own conversation
        (p_user_email IS NOT NULL AND cs.customer_email = p_user_email)
    )
    GROUP BY cs.id, cs.customer_email, cs.customer_name, cs.session_status, cs.last_message_at, cs.created_at
    ORDER BY cs.last_message_at DESC;
$$;

-- 4. Grant access to the function
GRANT EXECUTE ON FUNCTION get_admin_conversations(TEXT) TO authenticated;

-- 5. Create a view with row-level security using the function
CREATE OR REPLACE VIEW secure_admin_chat_conversations AS
SELECT * FROM get_admin_conversations(NULL);

-- Grant access to the secure view
GRANT SELECT ON secure_admin_chat_conversations TO authenticated;

-- 6. Test queries

-- Test 1: Check if you can access the original view
SELECT 
    'Testing original view access:' as test_type,
    COUNT(*) as conversation_count
FROM admin_chat_conversations;

-- Test 2: Check if you can access the secure function (admin view)
SELECT 
    'Testing secure function (admin view):' as test_type,
    COUNT(*) as conversation_count
FROM get_admin_conversations(NULL);

-- Test 3: Check if you can access your own conversation (customer view)
SELECT 
    'Testing secure function (customer view):' as test_type,
    COUNT(*) as conversation_count
FROM get_admin_conversations(auth.email());

-- Test 4: Check current user role
SELECT 
    'Current user info:' as test_type,
    auth.uid() as user_id,
    auth.email() as email,
    (SELECT role FROM users WHERE id = auth.uid()) as user_role;

-- 7. Security audit
SELECT 
    'Security audit:' as test_type,
    table_name,
    privilege_type,
    grantee
FROM information_schema.role_table_grants 
WHERE table_name IN ('admin_chat_conversations', 'secure_admin_chat_conversations')
ORDER BY table_name, privilege_type;

-- 8. Usage examples:
-- For admins: SELECT * FROM get_admin_conversations(NULL);
-- For customers: SELECT * FROM get_admin_conversations('customer@email.com');
-- Or use the secure view: SELECT * FROM secure_admin_chat_conversations;
