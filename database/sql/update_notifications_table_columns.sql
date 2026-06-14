-- =========================================================================
-- DATABASE MIGRATION: UPDATE NOTIFICATIONS TABLE SCHEMA (UPDATED)
-- Run this script in the Supabase SQL Editor to add the required columns,
-- update RLS policies, and adjust trigger functions.
-- =========================================================================

-- 1. Drop NOT NULL constraints on columns that do not have defaults in the live table
ALTER TABLE notifications ALTER COLUMN target_role DROP NOT NULL;
ALTER TABLE notifications ALTER COLUMN title DROP NOT NULL;
ALTER TABLE notifications ALTER COLUMN message DROP NOT NULL;
ALTER TABLE notifications ALTER COLUMN type DROP NOT NULL;

-- 2. Add missing columns required by the new Dart codebase
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS recipient_email TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS is_for_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_name TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS reservation_id TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS event_date TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS customer_email TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS start_time TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS guest_count INTEGER;

-- 3. Create indexes to improve query performance for real-time streams
CREATE INDEX IF NOT EXISTS notifications_recipient_email_idx ON notifications(recipient_email);
CREATE INDEX IF NOT EXISTS notifications_is_for_admin_idx ON notifications(is_for_admin);
CREATE INDEX IF NOT EXISTS notifications_action_type_idx ON notifications(action_type);

-- 4. Recreate RLS policies to support the new fields, employee roles, and insertions
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "Admin can manage notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can view admin notifications" ON notifications;
DROP POLICY IF EXISTS "Staff can update admin notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;

-- Allow all authenticated users to insert/send notifications
CREATE POLICY "Authenticated users can insert notifications" ON notifications
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Customers can view their own notifications (either via target_email or recipient_email)
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (
    auth.email() = target_email OR 
    auth.email() = recipient_email
  );

-- Customers can update/mark as read their own notifications
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (
    auth.email() = target_email OR 
    auth.email() = recipient_email
  );

-- Admins and staff (roles other than 'customer') can view admin-targeted notifications
CREATE POLICY "Staff can view admin notifications" ON notifications
  FOR SELECT USING (
    is_for_admin = true AND 
    EXISTS (
      SELECT 1 FROM users 
      WHERE email = auth.email() AND role != 'customer'
    )
  );

-- Admins and staff can update admin-targeted notifications (e.g., mark as read)
CREATE POLICY "Staff can update admin notifications" ON notifications
  FOR UPDATE USING (
    is_for_admin = true AND 
    EXISTS (
      SELECT 1 FROM users 
      WHERE email = auth.email() AND role != 'customer'
    )
  );

-- Admins retain full administrative control
CREATE POLICY "Admin can manage notifications" ON notifications
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE email = auth.email() AND role = 'admin'
    )
  );

-- 5. Update the registration trigger to populate both old and new columns correctly
CREATE OR REPLACE FUNCTION notify_admin_approval()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify for new customer registrations
    IF NEW.role = 'customer' AND NEW.is_approved = FALSE THEN
        -- Insert notification for admin setting both old and new fields
        INSERT INTO notifications (
            target_email, 
            recipient_email,
            is_for_admin, 
            actor_name, 
            action_type, 
            reservation_id, 
            event_type, 
            title, 
            message, 
            type, 
            target_role,
            created_at
        )
        VALUES (
            'pagsanjan@gmail.com',
            'pagsanjan@gmail.com',
            TRUE,
            'System',
            'customer_approval',
            'Admin',
            'New Customer Registration',
            'New Customer Registration',
            format('New customer %s %s (%s) is waiting for approval.', 
                   NEW.firstname, NEW.lastname, NEW.email),
            'customer_approval',
            'admin',
            NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
