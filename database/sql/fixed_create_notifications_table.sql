-- =========================================
-- FIXED NOTIFICATIONS TABLE SETUP
-- =========================================

-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'customer_approval', 'account_approved', 'account_rejected', etc.
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable Row Level Security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 3. Drop existing policies
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Admin can manage notifications" ON notifications;

-- 4. Create policies
-- Users can view their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.email() = user_email);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.email() = user_email);

-- Admin can manage all notifications
CREATE POLICY "Admin can manage notifications" ON notifications
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE email = auth.email() AND role = 'admin'
    )
  );

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS notifications_user_email_idx ON notifications(user_email);
CREATE INDEX IF NOT EXISTS notifications_type_idx ON notifications(type);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON notifications(created_at);
CREATE INDEX IF NOT EXISTS notifications_is_read_idx ON notifications(is_read);

-- 6. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Create trigger for updated_at
DROP TRIGGER IF EXISTS notifications_updated_at_trigger ON notifications;
CREATE TRIGGER notifications_updated_at_trigger
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

-- 8. FIXED: Create notification trigger for admin
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
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. Create trigger for new customer notifications
DROP TRIGGER IF EXISTS customer_approval_trigger ON users;
CREATE TRIGGER customer_approval_trigger
  AFTER INSERT ON users
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_approval();

-- 10. Verify table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
ORDER BY ordinal_position;

-- 11. Test query
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 5;
