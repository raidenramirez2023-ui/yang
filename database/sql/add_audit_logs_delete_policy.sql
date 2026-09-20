-- ============================================================================
-- Migration: Add DELETE Policy for Error Logs & System Telemetry in audit_logs
-- Purpose: Allows developers/admins to purge technical error and crash logs
--          without affecting business operations and audit trails.
-- ============================================================================

-- Ensure Row Level Security is enabled
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing delete policy if present to avoid conflicts
DROP POLICY IF EXISTS "Allow authenticated users to delete error audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow anon or authenticated to delete error audit logs" ON public.audit_logs;

-- Allow deleting only error and crash telemetry records
CREATE POLICY "Allow anon or authenticated to delete error audit logs"
ON public.audit_logs
FOR DELETE
TO anon, authenticated
USING (
    action IN ('CRITICAL', 'ERROR', 'FAILED', 'SYSTEM_ERROR')
    OR (metadata->>'is_system_telemetry')::boolean = true
);
