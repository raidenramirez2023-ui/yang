-- ==============================================================================
-- Audit Logs Table & Indexes for YCPRMS (Yang Chow Palace Restaurant Management)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    user_email TEXT NOT NULL,
    user_name TEXT,
    user_role TEXT DEFAULT 'staff',
    action TEXT NOT NULL, -- e.g., 'CREATE', 'UPDATE', 'DELETE', 'APPROVE', 'REJECT', 'LOGIN', 'STATUS_CHANGE', 'EXPORT'
    module TEXT NOT NULL, -- e.g., 'Reservations', 'Payments', 'Refunds', 'Petty Cash', 'Inventory', 'Menu', 'Users', 'Announcements'
    description TEXT NOT NULL,
    entity_id TEXT, -- e.g., reservation_id, payment_id, menu_item_id
    metadata JSONB DEFAULT '{}'::jsonb, -- dynamic details, old/new changes, amounts, ip/device
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Add comments for schema documentation
COMMENT ON TABLE public.audit_logs IS 'Activity logs tracking administrative and critical staff operations in the system.';

-- Create indexes for ultra-fast filtering and sorting
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON public.audit_logs(module);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_email ON public.audit_logs(user_email);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_id ON public.audit_logs(entity_id);

-- Enable Row Level Security (RLS)
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to prevent conflicts on rerun
DROP POLICY IF EXISTS "Allow authenticated users to insert audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow admins to read audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow users to read their own audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow all authenticated users to read audit logs" ON public.audit_logs;

-- Policy 1: Allow anon and authenticated users to insert audit logs
CREATE POLICY "Allow anon or authenticated users to insert audit logs"
ON public.audit_logs
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Policy 2: Allow all users to read audit logs
CREATE POLICY "Allow all users to read audit logs"
ON public.audit_logs
FOR SELECT
TO anon, authenticated
USING (true);

-- Optional: Initial system initialization log entry
INSERT INTO public.audit_logs (
    user_email,
    user_name,
    user_role,
    action,
    module,
    description,
    metadata
) VALUES (
    'system@yangchow.com',
    'System Engine',
    'admin',
    'CREATE',
    'System',
    'Audit Trail & Activity Logging system initialized successfully.',
    '{"version": "1.0.0", "status": "active"}'::jsonb
);
