-- =========================================================
-- FINAL FIX: INFINITE RECURSION IN USERS TABLE
-- =========================================================

-- 1. CLEAN UP: Drop all conflicting policies on the users table
-- This clears the "Infinite Loop" immediately
DROP POLICY IF EXISTS "Admin can view all customers" ON users;
DROP POLICY IF EXISTS "Admin can view all users" ON users;
DROP POLICY IF EXISTS "Allow user registration" ON users;
DROP POLICY IF EXISTS "allow_public_read_only" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "users_insert_own" ON users;
DROP POLICY IF EXISTS "users_select_own" ON users;
DROP POLICY IF EXISTS "users_select_own_row" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "Users can manage their profile" ON users;
DROP POLICY IF EXISTS "users_read_policy" ON users;
DROP POLICY IF EXISTS "users_insert_policy" ON users;
DROP POLICY IF EXISTS "users_update_policy" ON users;
DROP POLICY IF EXISTS "users_delete_policy" ON users;

-- 2. BETTER ROLE SYNC: Ensure role is in JWT (Prevents Database Recursion)
CREATE OR REPLACE FUNCTION sync_user_role_to_auth()
RETURNS TRIGGER AS $$
BEGIN
  -- This updates the auth metadata which is included in the JWT
  -- This allows us to check role without querying the users table
  UPDATE auth.users 
  SET raw_app_meta_data = 
    raw_app_meta_data || 
    jsonb_build_object('role', NEW.role)
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind the trigger
DROP TRIGGER IF EXISTS tr_sync_user_role ON users;
CREATE TRIGGER tr_sync_user_role
AFTER INSERT OR UPDATE OF role ON users
FOR EACH ROW EXECUTE FUNCTION sync_user_role_to_auth();

-- 3. UPDATED is_admin() function: Non-recursive
CREATE OR REPLACE FUNCTION is_admin() 
RETURNS BOOLEAN AS $$
BEGIN
  -- FIRST: Check JWT (Fastest, No recursion)
  IF (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' THEN
    RETURN TRUE;
  END IF;

  -- SECOND: Hardcoded emergency check for your admin email
  IF auth.email() = 'admn.pagsanjan@gmail.com' THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. NEW CLEAN POLICIES for 'users' table
-- Use auth.uid() directly to avoid recursion

-- SELECT: Users see themselves OR Admin sees all
CREATE POLICY "users_read_policy" ON users
FOR SELECT USING (
  id = auth.uid() OR email = auth.email() OR is_admin()
);

-- INSERT: Anyone can register (Public)
CREATE POLICY "users_insert_policy" ON users
FOR INSERT WITH CHECK (true);

-- UPDATE: Users can edit themselves OR Admin can edit all
CREATE POLICY "users_update_policy" ON users
FOR UPDATE USING (
  id = auth.uid() OR email = auth.email() OR is_admin()
) WITH CHECK (
  id = auth.uid() OR email = auth.email() OR is_admin()
);

-- DELETE: Only Admin
CREATE POLICY "users_delete_policy" ON users
FOR DELETE USING (is_admin());

-- 5. Force sync the current admin account to be safe
UPDATE users SET role = 'admin' WHERE email = 'admn.pagsanjan@gmail.com';

-- 6. Grant basic access
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
GRANT ALL ON users TO authenticated;
GRANT ALL ON users TO anon;
GRANT ALL ON users TO service_role;

SELECT 'RLS Recursion Fixed! Please log out and log back in.' as status;
