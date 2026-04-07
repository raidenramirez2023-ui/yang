-- =========================================
-- COMPLETE USER CLEANUP (FIXED)
-- =========================================

-- 1. Delete from auth.users (main authentication table)
DELETE FROM auth.users WHERE email = 'customeryangchow@gmail.com';

-- 2. Delete from public.users (profile table)
DELETE FROM users WHERE email = 'customeryangchow@gmail.com';

-- 3. Delete from any sessions or tokens
DELETE FROM auth.sessions WHERE user_id IN (
    SELECT id FROM auth.users WHERE email = 'customeryangchow@gmail.com'
);

-- 4. Verify deletion from auth.users
SELECT 
    'auth.users' as table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM auth.users WHERE email = 'customeryangchow@gmail.com') 
        THEN 'User still exists' 
        ELSE 'User deleted successfully' 
    END as status;

-- 5. Verify deletion from public.users
SELECT 
    'public.users' as table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM users WHERE email = 'customeryangchow@gmail.com') 
        THEN 'User still exists' 
        ELSE 'User deleted successfully' 
    END as status;

-- 6. Show all remaining gmail users
SELECT email, created_at, 'auth.users' as source
FROM auth.users 
WHERE email LIKE '%@gmail.com' 
ORDER BY created_at DESC;
