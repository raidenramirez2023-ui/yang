-- =========================================
-- CUSTOMER APPROVAL SYSTEM SETUP
-- =========================================

-- 1. Add approval status column to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS approved_by TEXT,
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Create index for better performance
CREATE INDEX IF NOT EXISTS users_approval_idx ON users(is_approved, role);

-- 3. Update existing customers to be approved by default (for existing data)
UPDATE users 
SET is_approved = TRUE, 
    approved_by = 'system@yangchow.com',
    approved_at = NOW()
WHERE role = 'customer' AND is_approved IS NULL;

-- 4. Create function to check if user can login
CREATE OR REPLACE FUNCTION can_user_login(user_email TEXT, user_role TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    approval_status BOOLEAN;
BEGIN
    -- Admin and staff can always login
    IF user_role IN ('admin', 'staff') THEN
        RETURN TRUE;
    END IF;
    
    -- Check if customer is approved
    SELECT is_approved INTO approval_status
    FROM users
    WHERE email = user_email AND role = user_role;
    
    RETURN COALESCE(approval_status, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create policy for customer login based on approval
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (
    auth.email() = email AND 
    (role IN ('admin', 'staff') OR (role = 'customer' AND is_approved = TRUE))
  );

-- 6. Create notification function for admin approval
CREATE OR REPLACE FUNCTION notify_admin_approval()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify for new customer registrations
    IF NEW.role = 'customer' AND NEW.is_approved = FALSE THEN
        -- Insert notification for admin
        INSERT INTO notifications (user_email, title, message, type, created_at)
        VALUES (
            'pagsanjan@gmail.com',
            'New Customer Registration',
            format('New customer %s %s (%s) is waiting for approval.', 
                   NEW.firstname, NEW.lastname, NEW.email),
            'customer_approval',
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger for automatic admin notification
DROP TRIGGER IF EXISTS customer_approval_trigger ON users;
CREATE TRIGGER customer_approval_trigger
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_approval();

-- 8. Verify the setup
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
  AND column_name IN ('is_approved', 'approved_by', 'approved_at', 'rejection_reason')
ORDER BY ordinal_position;

-- 9. Test query to check pending approvals
SELECT 
    id,
    firstname,
    lastname, 
    email,
    phone,
    created_at,
    is_approved,
    approved_by,
    approved_at
FROM users 
WHERE role = 'customer' 
  AND is_approved = FALSE
ORDER BY created_at DESC;
