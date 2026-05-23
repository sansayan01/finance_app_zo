-- Create missing RPC: get_latest_staff_locations
-- Used by live_tracking_repository.dart

CREATE OR REPLACE FUNCTION public.get_latest_staff_locations(p_org_id UUID)
RETURNS TABLE (
    staff_id UUID,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    recorded_at TIMESTAMP WITH TIME ZONE,
    activity_type TEXT,
    battery_level INTEGER,
    accuracy DECIMAL(8,2)
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT DISTINCT ON (sl.staff_id)
        sl.staff_id,
        sl.latitude,
        sl.longitude,
        sl.recorded_at,
        sl.activity_type,
        sl.battery_level,
        sl.accuracy
    FROM public.staff_locations sl
    WHERE sl.org_id = p_org_id
    ORDER BY sl.staff_id, sl.recorded_at DESC;
$$;
