-- Fix: Live map showing no agents because the RPC filtered only "today"
--
-- get_latest_staff_locations had:
--   AND sl.recorded_at >= (CURRENT_DATE AT TIME ZONE 'utc')
-- Old data in staff_locations is from May 2026 (weeks ago), so it was all
-- discarded — map always returned 0 agents for every org.
--
-- Changed to a 90-day window so historical test / pilot data shows up
-- on the map. Production agents sending live locations will appear instantly
-- regardless of this window because their recorded_at is always recent.

DO $$
BEGIN
  -- Only create/replace if the function exists
  IF EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'get_latest_staff_locations'
      AND pg_function_is_visible(p.oid)
  ) THEN
    EXECUTE $sql$
      CREATE OR REPLACE FUNCTION public.get_latest_staff_locations(p_org_id UUID)
      RETURNS TABLE(
        staff_id UUID,
        full_name TEXT,
        staff_code TEXT,
        branch_name TEXT,
        latitude NUMERIC,
        longitude NUMERIC,
        accuracy NUMERIC,
        speed NUMERIC,
        heading NUMERIC,
        activity_type TEXT,
        battery_level NUMERIC,
        is_charging BOOLEAN,
        is_active BOOLEAN,
        recorded_at TIMESTAMPTZ
      )
      LANGUAGE sql
      SECURITY DEFINER
      AS $$
       SELECT DISTINCT ON (sl.staff_id)
        sl.staff_id,
        COALESCE(sp.full_name, p.full_name)        AS full_name,
        COALESCE(sp.staff_code, p.staff_code, '')  AS staff_code,
        b.name                                      AS branch_name,
        sl.latitude, sl.longitude, sl.accuracy, sl.speed, sl.heading,
        sl.activity_type, sl.battery_level, sl.is_charging, sl.is_active,
        sl.recorded_at
       FROM public.staff_locations sl
       LEFT JOIN public.staff_profiles sp ON sp.id = sl.staff_id
       LEFT JOIN public.profiles        p  ON p.id  = sl.staff_id
       LEFT JOIN public.branches        b  ON b.id  = COALESCE(sp.branch_id, p.branch_id)
       WHERE sl.org_id = p_org_id
         AND sl.recorded_at >= (CURRENT_DATE AT TIME ZONE 'utc' - INTERVAL '90 days')
       ORDER BY sl.staff_id, sl.recorded_at DESC;
      $$;
    $sql$;

    RAISE NOTICE 'get_latest_staff_locations updated with 90-day window';
  ELSE
    RAISE NOTICE 'get_latest_staff_locations not found — skipping (may not exist in this environment)';
  END IF;
END $$;

-- Re-grant to ensure permissions
GRANT EXECUTE ON FUNCTION public.get_latest_staff_locations(UUID) TO anon;
GRANT EXECUTE ON FUNCTION public.get_latest_staff_locations(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_latest_staff_locations(UUID) TO service_role;
