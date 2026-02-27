-- =========================================
-- COMPLETE USER CLEANUP
-- =========================================

-- 1. Delete from auth.users (main authentication table)
DELETE FROM auth.users WHERE email = 'customeryangchow@gmail.com';

-- 2. Delete from public.users (profile table)
DELETE FROM users WHERE email = 'customeryangchow@gmail.com';

-- 3. Check for user in other possible tables
-- Delete from any sessions or tokens
DELETE FROM auth.sessions WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'customeryangchow@gmail.com');

-- 4. Force cleanup - check if user still exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'customeryangchow@gmail.com') THEN
        RAISE EXCEPTION 'User still exists in auth.users';
    ELSE
        RAISE NOTICE 'User successfully deleted from auth.users';
    END IF;
    
    IF EXISTS (SELECT 1 FROM users WHERE email = 'customeryangchow@gmail.com') THEN
        RAISE EXCEPTION 'User still exists in public.users';
    ELSE
        RAISE NOTICE 'User successfully deleted from public.users';
    END IF;
END $$;

-- 5. Show all remaining users to verify
SELECT 
    email, 
    created_at,
    'auth.users' as table_name
FROM auth.users 
WHERE email LIKE '%@gmail.com' 
ORDER BY created_at DESC

UNION ALL

SELECT 
    email, 
    created_at,
    'public.users' as table_name
FROM users 
WHERE email LIKE '%@gmail.com' 
ORDER BY created_at DESC;
