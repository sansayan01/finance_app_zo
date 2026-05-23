-- RPC: get_latest_staff_locations
-- Returns the most recent location row per staff for an org, joined with
-- staff_profiles (full_name, employee_id as staff_code) and branches (name).
-- Consumed by lib/features/staff/data/repositories/live_tracking_repository.dart

CREATE OR REPLACE FUNCTION public.get_latest_staff_locations(p_org_id UUID)
RETURNS TABLE (
    staff_id UUID,
    full_name TEXT,
    staff_code TEXT,
    branch_id UUID,
    branch_name TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    accuracy DECIMAL(8, 2),
    speed DECIMAL,
    heading DECIMAL,
    activity_type TEXT,
    battery_level INTEGER,
    is_charging BOOLEAN,
    is_active BOOLEAN,
    recorded_at TIMESTAMP WITH TIME ZONE
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT DISTINCT ON (sl.staff_id)
        sl.staff_id,
        sp.full_name,
        sp.employee_id  AS staff_code,
        sp.branch_id,
        b.name          AS branch_name,
        sl.latitude,
        sl.longitude,
        sl.accuracy,
        sl.speed,
        sl.heading,
        sl.activity_type,
        sl.battery_level,
        sl.is_charging,
        sl.is_active,
        sl.recorded_at
    FROM public.staff_locations sl
    LEFT JOIN public.staff_profiles sp ON sp.id = sl.staff_id
    LEFT JOIN public.branches b       ON b.id = sp.branch_id
    WHERE sl.org_id = p_org_id
    ORDER BY sl.staff_id, sl.recorded_at DESC;
$$;
