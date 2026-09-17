-- ==============================================================================
-- Migration: Add Booking Validation, Quotation Expiration & Account Restrictions
-- Yang Chow Restaurant Management System (YCPRMS)
-- ==============================================================================

-- 1. Add quotation_expires_at to reservations table
ALTER TABLE public.reservations 
ADD COLUMN IF NOT EXISTS quotation_expires_at TIMESTAMPTZ;

-- Drop restrictive status check constraint so all valid statuses (including 'expired') are supported
ALTER TABLE public.reservations DROP CONSTRAINT IF EXISTS reservations_status_check;

CREATE INDEX IF NOT EXISTS idx_reservations_quotation_expires_at ON public.reservations(quotation_expires_at);

-- 2. Add customer account restriction fields to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS restriction_status VARCHAR(50) DEFAULT 'active',
ADD COLUMN IF NOT EXISTS warning_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS restriction_reason TEXT,
ADD COLUMN IF NOT EXISTS restriction_start TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS restriction_end TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS restricted_by TEXT;

-- Add check constraint for restriction_status
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_restriction_status_check;
ALTER TABLE public.users ADD CONSTRAINT users_restriction_status_check 
CHECK (restriction_status IS NULL OR restriction_status IN ('active', 'warning', 'temporarily_restricted', 'blocked', 'suspended'));

CREATE INDEX IF NOT EXISTS idx_users_restriction_status ON public.users(restriction_status);

-- 3. Create customer_restrictions table for audit trail
CREATE TABLE IF NOT EXISTS public.customer_restrictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT,
    customer_email TEXT NOT NULL,
    customer_name TEXT,
    action_type TEXT NOT NULL, -- 'warning', 'temporary_restriction', 'unrestrict', 'block', 'suspend'
    previous_status TEXT,
    new_status TEXT NOT NULL,
    reason TEXT NOT NULL,
    duration_days INTEGER,
    duration_hours INTEGER,
    starts_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.customer_restrictions IS 'Audit trail of all warnings, temporary restrictions, blocks, suspensions, and unrestrictions applied to customer accounts.';

CREATE INDEX IF NOT EXISTS idx_customer_restrictions_email ON public.customer_restrictions(customer_email);
CREATE INDEX IF NOT EXISTS idx_customer_restrictions_created_at ON public.customer_restrictions(created_at DESC);

-- Enable RLS
ALTER TABLE public.customer_restrictions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated to read customer restrictions" ON public.customer_restrictions;
CREATE POLICY "Allow authenticated to read customer restrictions"
ON public.customer_restrictions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow authenticated to insert customer restrictions" ON public.customer_restrictions;
CREATE POLICY "Allow authenticated to insert customer restrictions"
ON public.customer_restrictions FOR INSERT TO authenticated WITH CHECK (true);

-- 4. Seed default app_settings for booking validation & limits
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS setting_type TEXT DEFAULT 'string',
ADD COLUMN IF NOT EXISTS description TEXT;

INSERT INTO public.app_settings (setting_key, setting_value, setting_type, description) VALUES
('max_active_reservations_per_customer', '3', 'number', 'Maximum concurrent pending/unconfirmed reservations allowed per customer awaiting review'),
('default_quotation_grace_period_hours', '24', 'number', 'Default grace period in hours for customer to confirm/pay a price quotation'),
('booking_spam_window_minutes', '10', 'number', 'Cooldown window in minutes to prevent rapid identical reservation submissions')
ON CONFLICT (setting_key) DO UPDATE SET
    setting_type = EXCLUDED.setting_type,
    description = EXCLUDED.description;

