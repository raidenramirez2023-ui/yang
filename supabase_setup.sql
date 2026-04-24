-- Create necessary tables for Yang Chow Restaurant

-- Reservations table
CREATE TABLE IF NOT EXISTS reservations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_email TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  event_type TEXT NOT NULL,
  event_date DATE NOT NULL,
  start_time TIME NOT NULL,
  duration_hours INTEGER NOT NULL,
  number_of_guests INTEGER NOT NULL,
  status TEXT DEFAULT 'pending',
  payment_status TEXT DEFAULT 'unpaid',
  deposit_amount DECIMAL(10,2),
  payment_amount DECIMAL(10,2),
  payment_reference TEXT,
  special_requests TEXT,
  customer_phone TEXT,
  customer_address TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- App settings table
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Chat messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_email TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  message TEXT NOT NULL,
  is_from_customer BOOLEAN DEFAULT true,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Admin chat conversations table
CREATE TABLE IF NOT EXISTS admin_chat_conversations (
  session_id TEXT PRIMARY KEY,
  customer_email TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  session_status TEXT DEFAULT 'active',
  last_message_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insert default app settings
INSERT INTO app_settings (setting_key, setting_value) VALUES
  ('operating_hours_start', '10:00'),
  ('operating_hours_end', '20:00'),
  ('base_durations', '[2, 3, 4]'),
  ('min_reservation_days_ahead', '2'),
  ('max_reservation_days_ahead', '30'),
  ('refund_policy_days', '7'),
  ('refund_percentage_within_window', '100')
ON CONFLICT (setting_key) DO NOTHING;
