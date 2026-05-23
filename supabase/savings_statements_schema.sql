-- Savings Statements archive table
CREATE TABLE IF NOT EXISTS public.savings_statements (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  member_id     UUID NOT NULL,
  statement_ref TEXT NOT NULL,
  period_start  DATE NOT NULL,
  period_end    DATE NOT NULL,
  format        TEXT NOT NULL CHECK (format IN ('pdf', 'excel', 'csv')),
  file_path     TEXT NOT NULL,
  file_size_bytes INTEGER,
  sha256_hash   TEXT NOT NULL,
  generated_by  UUID,
  generated_by_name TEXT,
  generated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.savings_statements ENABLE ROW LEVEL SECURITY;

-- Super Admin: full access across all orgs
CREATE POLICY "super_admin_select_savings_statements"
  ON public.savings_statements FOR SELECT
  USING (auth.jwt() ->> 'role' IN ('superAdmin', 'superadmin'));

CREATE POLICY "super_admin_insert_savings_statements"
  ON public.savings_statements FOR INSERT
  WITH CHECK (auth.jwt() ->> 'role' IN ('superAdmin', 'superadmin'));

CREATE POLICY "super_admin_delete_savings_statements"
  ON public.savings_statements FOR DELETE
  USING (auth.jwt() ->> 'role' IN ('superAdmin', 'superadmin'));

-- Org-level access
CREATE POLICY "org_select_savings_statements"
  ON public.savings_statements FOR SELECT
  USING (org_id IN (
    SELECT id FROM public.organizations
    WHERE id = org_id
  ));

CREATE POLICY "org_insert_savings_statements"
  ON public.savings_statements FOR INSERT
  WITH CHECK (org_id IN (
    SELECT org_id FROM public.profiles
    WHERE id = auth.uid()
  ));

CREATE POLICY "org_delete_savings_statements"
  ON public.savings_statements FOR DELETE
  USING (org_id IN (
    SELECT org_id FROM public.profiles
    WHERE id = auth.uid()
  ));

-- Indexes
CREATE INDEX IF NOT EXISTS idx_savings_statements_org
  ON public.savings_statements (org_id);
CREATE INDEX IF NOT EXISTS idx_savings_statements_member
  ON public.savings_statements (member_id);
CREATE INDEX IF NOT EXISTS idx_savings_statements_generated
  ON public.savings_statements (generated_at DESC);
