-- ============================================
-- RESERVATIONS ENHANCEMENTS SQL MIGRATIONS
-- ============================================

-- 1. Add columns to reservations table
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS special_requests TEXT,
ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS customer_address TEXT,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS refund_amount DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS refund_status VARCHAR(50) DEFAULT 'none'; -- none, pending, completed, failed

-- 2. Create reviews table for customer ratings
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  customer_email VARCHAR(255) NOT NULL,
  rating INT CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  food_quality INT CHECK (food_quality >= 1 AND food_quality <= 5),
  service_quality INT CHECK (service_quality >= 1 AND service_quality <= 5),
  ambiance INT CHECK (ambiance >= 1 AND ambiance <= 5),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create app_settings table for admin configuration
CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key VARCHAR(100) NOT NULL UNIQUE,
  setting_value TEXT NOT NULL,
  setting_type VARCHAR(50), -- string, number, boolean, json
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_by VARCHAR(255)
);

-- 4. Insert default app settings
INSERT INTO app_settings (setting_key, setting_value, setting_type, description) VALUES
('min_guest_count', '2', 'number', 'Minimum number of guests for a reservation'),
('max_guest_count', '500', 'number', 'Maximum number of guests for a reservation'),
('operating_hours_start', '10', 'number', 'Restaurant opening hour (24-hour format)'),
('operating_hours_end', '22', 'number', 'Restaurant closing hour (24-hour format)'),
('base_durations', '["2 Hours", "3 Hours"]', 'json', 'Available base duration options'),
('extra_time_options', '["30 Minutes", "1 Hour", "1 Hour 30 Minutes", "2 Hours"]', 'json', 'Available extra time options'),
('min_reservation_days_ahead', '4', 'number', 'Minimum days ahead to allow reservation booking'),
('max_reservation_days_ahead', '365', 'number', 'Maximum days ahead to allow reservation booking'),
('refund_policy_days', '7', 'number', 'Days before event for 100% refund'),
('refund_percentage_within_window', '50', 'number', 'Refund percentage if cancelled within refund_policy_days'),
('enable_special_requests', 'true', 'boolean', 'Enable special requests field in reservation form'),
('enable_email_notifications', 'true', 'boolean', 'Send email notifications to customers'),
('smtp_from_email', 'noreply@yangchow.com', 'string', 'Email address to send notifications from')
ON CONFLICT (setting_key) DO NOTHING;

-- 5. Create cancellation requests table (for tracking cancellations)
CREATE TABLE IF NOT EXISTS cancellation_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  customer_email VARCHAR(255) NOT NULL,
  cancellation_reason TEXT,
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  approved_at TIMESTAMP,
  refund_amount DECIMAL(10, 2),
  status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
  processed_by VARCHAR(255),
  notes TEXT
);

-- 6. Create email_logs table to track notification emails
CREATE TABLE IF NOT EXISTS email_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email VARCHAR(255) NOT NULL,
  subject TEXT NOT NULL,
  email_type VARCHAR(50), -- confirmation, reminder, cancellation, review_request, etc
  reservation_id UUID REFERENCES reservations(id) ON DELETE SET NULL,
  sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(50) DEFAULT 'sent', -- sent, failed, bounced
  error_message TEXT
);

-- 7. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_reviews_reservation_id ON reviews(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_email ON reviews(customer_email);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_reservation_id ON cancellation_requests(reservation_id);
CREATE INDEX IF NOT EXISTS idx_cancellation_requests_status ON cancellation_requests(status);
CREATE INDEX IF NOT EXISTS idx_email_logs_recipient ON email_logs(recipient_email);
CREATE INDEX IF NOT EXISTS idx_email_logs_type ON email_logs(email_type);

-- 8. Add RLS policies for reviews table
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view all reviews" ON reviews
  FOR SELECT USING (true);

CREATE POLICY "Customers can insert their own reviews" ON reviews
  FOR INSERT WITH CHECK (
    customer_email = auth.jwt() ->> 'email'
  );

-- 9. Add RLS policies for cancellation_requests table
ALTER TABLE cancellation_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own cancellation requests" ON cancellation_requests
  FOR SELECT USING (
    customer_email = auth.jwt() ->> 'email'
  );

CREATE POLICY "Customers can create cancellation requests" ON cancellation_requests
  FOR INSERT WITH CHECK (
    customer_email = auth.jwt() ->> 'email'
  );

CREATE POLICY "Admins can view all cancellation requests" ON cancellation_requests
  FOR SELECT USING (
    auth.jwt() ->> 'email' IN ('adm.pagsanjan@gmail.com', 'admin@yangchow.com', 'manager@yangchow.com')
  );

-- 10. Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 11. Create trigger for reviews updated_at
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 12. Create trigger for app_settings updated_at
CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON app_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 13. Add COMMENT documentation
COMMENT ON TABLE reviews IS 'Customer reviews and ratings for completed reservations';
COMMENT ON TABLE app_settings IS 'Configurable application settings managed by admins';
COMMENT ON TABLE cancellation_requests IS 'Track reservation cancellation requests and refund processing';
COMMENT ON TABLE email_logs IS 'Track all email notifications sent to customers';

COMMENT ON COLUMN reviews.reservation_id IS 'Reference to the reservation being reviewed';
COMMENT ON COLUMN reviews.rating IS 'Overall rating 1-5';
COMMENT ON COLUMN reviews.food_quality IS 'Food quality rating 1-5';
COMMENT ON COLUMN reviews.service_quality IS 'Service quality rating 1-5';
COMMENT ON COLUMN reviews.ambiance IS 'Ambiance/atmosphere rating 1-5';

COMMENT ON COLUMN app_settings.setting_key IS 'Unique identifier for the setting (e.g., min_guest_count)';
COMMENT ON COLUMN app_settings.setting_value IS 'Value of the setting';
COMMENT ON COLUMN app_settings.setting_type IS 'Data type: string, number, boolean, or json';

COMMENT ON COLUMN cancellation_requests.status IS 'Status of the cancellation request: pending, approved, rejected';
COMMENT ON COLUMN cancellation_requests.refund_amount IS 'Amount to be refunded to customer';

COMMENT ON COLUMN reservations.special_requests IS 'Special requests from customer (dietary, accessibility, etc)';
COMMENT ON COLUMN reservations.refund_status IS 'Status of refund processing: none, pending, completed, failed';
