-- ============================================================
-- IT Access Request System
-- Allows Admin to formally request elevated IT support access
-- from the Developer account, with time-limited approval.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.it_access_requests (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by_email  TEXT NOT NULL,
  requested_by_name   TEXT NOT NULL DEFAULT '',
  developer_email     TEXT NOT NULL DEFAULT 'yangchowit@gmail.com',
  issue_description   TEXT NOT NULL,
  access_scope        TEXT NOT NULL DEFAULT 'Full Access',
  duration_hours      INT  NOT NULL DEFAULT 2,
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'accepted', 'declined', 'expired', 'revoked')),
  requested_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at         TIMESTAMPTZ,
  expires_at          TIMESTAMPTZ,
  resolved_at         TIMESTAMPTZ,
  admin_notes         TEXT,
  developer_notes     TEXT
);

CREATE INDEX IF NOT EXISTS idx_it_access_requests_status
  ON public.it_access_requests (status, developer_email);

CREATE INDEX IF NOT EXISTS idx_it_access_requests_requested_at
  ON public.it_access_requests (requested_at DESC);

ALTER TABLE public.it_access_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='it_access_requests' AND policyname='it_access_insert') THEN
    CREATE POLICY it_access_insert ON public.it_access_requests FOR INSERT TO authenticated WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='it_access_requests' AND policyname='it_access_select') THEN
    CREATE POLICY it_access_select ON public.it_access_requests FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='it_access_requests' AND policyname='it_access_update') THEN
    CREATE POLICY it_access_update ON public.it_access_requests FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;
