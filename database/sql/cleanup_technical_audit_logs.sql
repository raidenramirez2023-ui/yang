-- ==============================================================================
-- CLEANUP TECHNICAL AUDIT LOGS & DEVELOPER TELEMETRY
-- ==============================================================================
-- Purpose:
-- Purges non-operational records (Flutter system errors, developer test accounts,
-- emergency succession security test logs, IT access requests) from the audit_logs table
-- so that the Audit Trail displays strictly authentic restaurant business operations
-- (Reservations, Reschedule, Payments, Refunds, Petty Cash, Inventory, Menu, Users, Announcements, Spoilage, Auth).
-- ==============================================================================

-- 1. Remove developer testing logs
DELETE FROM public.audit_logs
WHERE user_email ILIKE '%yangchowit%'
   OR user_role IN ('DEVELOPER', 'IT');

-- 2. Remove technical error logs and Flutter runtime telemetry
DELETE FROM public.audit_logs
WHERE action IN ('CRITICAL', 'ERROR', 'FAILED', 'SYSTEM_ERROR', 'WARNING')
   OR module ILIKE '%library%'
   OR module ILIKE '%flutter%'
   OR module ILIKE '%platformdispatcher%'
   OR module ILIKE '%framework%'
   OR module ILIKE '%zoned%';

-- 3. Remove non-operational background governance and IT access logs
DELETE FROM public.audit_logs
WHERE module ILIKE '%admin governance%'
   OR module ILIKE '%it access%'
   OR action LIKE 'IT_ACCESS%'
   OR action LIKE 'CONTINUITY%'
   OR action LIKE 'SUCCESSION%';

-- 4. Verify clean operational audit trail summary
SELECT 
    module, 
    COUNT(*) AS total_operational_records,
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE) AS today_records
FROM public.audit_logs
GROUP BY module
ORDER BY total_operational_records DESC;
