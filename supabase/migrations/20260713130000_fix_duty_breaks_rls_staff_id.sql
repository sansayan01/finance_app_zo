-- Fix RLS on duty_sessions + staff_breaks.
--
-- BUG: policies used `staff_id = auth.uid()`, but the app stores the PROFILE
-- id (profiles.id / staff_profiles.id) in the `staff_id` column, while
-- auth.uid() is the Supabase AUTH user id. They are DIFFERENT uuids for the
-- same person, so RLS silently rejected every INSERT/SELECT/UPDATE — staff
-- could never go ON DUTY, so live-location tracking never started and the
-- manager map showed no agents.
--
-- FIX: mirror the proven pattern already used by staff_locations_insert_v2 /
-- offline_sync_queue_insert — translate auth.uid() -> profile id via a subquery.

-- ─── duty_sessions ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS duty_sessions_insert ON public.duty_sessions;
DROP POLICY IF EXISTS duty_sessions_select ON public.duty_sessions;
DROP POLICY IF EXISTS duty_sessions_update ON public.duty_sessions;

CREATE POLICY duty_sessions_insert ON public.duty_sessions
  FOR INSERT TO authenticated
  WITH CHECK (
    (org_id = get_user_org_id()) AND
    (staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    ))
  );

CREATE POLICY duty_sessions_select ON public.duty_sessions
  FOR SELECT TO authenticated
  USING (
    (staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    ))
    OR (org_id IN (
      SELECT prof.org_id FROM public.profiles prof
      WHERE prof.id = auth.uid()
        AND prof.role = ANY (ARRAY['executiveAdmin','manager','superAdmin'])
    ))
  );

CREATE POLICY duty_sessions_update ON public.duty_sessions
  FOR UPDATE TO authenticated
  USING (
    (staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    ))
    OR (org_id IN (
      SELECT prof.org_id FROM public.profiles prof
      WHERE prof.id = auth.uid()
        AND prof.role = ANY (ARRAY['executiveAdmin','manager','superAdmin'])
    ))
  );

-- ─── staff_breaks (table has no org_id column) ───────────────────────────────
DROP POLICY IF EXISTS staff_breaks_insert ON public.staff_breaks;
DROP POLICY IF EXISTS staff_breaks_select ON public.staff_breaks;
DROP POLICY IF EXISTS staff_breaks_update ON public.staff_breaks;

CREATE POLICY staff_breaks_insert ON public.staff_breaks
  FOR INSERT TO authenticated
  WITH CHECK (
    staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    )
  );

CREATE POLICY staff_breaks_select ON public.staff_breaks
  FOR SELECT TO authenticated
  USING (
    (staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    ))
    OR (EXISTS (
      SELECT 1 FROM public.profiles prof
      WHERE prof.id = auth.uid()
        AND prof.role = ANY (ARRAY['executiveAdmin','manager','superAdmin'])
    ))
  );

CREATE POLICY staff_breaks_update ON public.staff_breaks
  FOR UPDATE TO authenticated
  USING (
    staff_id IN (
      SELECT p.id FROM public.profiles p WHERE p.user_id = auth.uid()
      UNION ALL
      SELECT sp.id FROM public.staff_profiles sp WHERE sp.user_id = auth.uid()
    )
  );
