-- Fix visit_logs RLS: drop ALL existing policies (from multiple conflicting migration files)
-- Then recreate with simple org_id check (works for all roles including collection agents)

DROP POLICY IF EXISTS staff_select ON public.visit_logs;
DROP POLICY IF EXISTS staff_insert ON public.visit_logs;
DROP POLICY IF EXISTS staff_update ON public.visit_logs;
DROP POLICY IF EXISTS visit_logs_select ON public.visit_logs;
DROP POLICY IF EXISTS visit_logs_insert ON public.visit_logs;
DROP POLICY IF EXISTS visit_logs_update ON public.visit_logs;

CREATE POLICY visit_logs_select ON public.visit_logs FOR SELECT
    USING (org_id = public.get_user_org_id());

CREATE POLICY visit_logs_insert ON public.visit_logs FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY visit_logs_update ON public.visit_logs FOR UPDATE
    USING (org_id = public.get_user_org_id());
