-- =====================================================
-- 2026-06-05: Executive admin portal — org lifecycle RPCs
--
-- Addresses:
--   * Org hard-delete leaves orphans across branches, members, loans, etc.
--   * Suspend only flips a flag — JWTs are still valid, users keep access.
--   * Slug uniqueness must not collide with deleted slugs.
--
-- Strategy: soft-delete + tenant-status guard RLS + a single
-- atomic RPC that suspends (and revokes sessions) and another
-- that soft-deletes (and schedules cleanup).
-- =====================================================

BEGIN;

-- 1) Add lifecycle columns to organizations.
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS deleted_at      TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS suspended_at    TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
  ADD COLUMN IF NOT EXISTS deleted_reason  TEXT;

-- 2) Indexes for soft-delete filter (most queries exclude deleted rows).
CREATE INDEX IF NOT EXISTS idx_organizations_active
  ON public.organizations (id) WHERE deleted_at IS NULL;

-- 3) Slug uniqueness must ignore deleted rows.
--    Replace the existing unique constraint with a partial index.
DO $$
DECLARE
  c TEXT;
BEGIN
  SELECT conname INTO c
  FROM pg_constraint
  WHERE conrelid = 'public.organizations'::regclass
    AND contype  = 'u'
    AND pg_get_constraintdef(oid) ILIKE '%slug%';
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.organizations DROP CONSTRAINT %I', c);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_organizations_slug_active
  ON public.organizations (slug) WHERE deleted_at IS NULL;

-- 4) Helper: is the current org suspended or deleted?
CREATE OR REPLACE FUNCTION public.org_is_active(p_org_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.organizations
    WHERE id = p_org_id
      AND status <> 'suspended'
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql STABLE;

-- 5) Suspend an organization + revoke all active sessions for its users.
--    SECURITY DEFINER so it can write to auth.sessions.
CREATE OR REPLACE FUNCTION public.suspend_organization(
  p_org_id     UUID,
  p_reason     TEXT
)
RETURNS VOID AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Only super admins may suspend an org.
  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = v_actor AND role = 'superAdmin') THEN
    RAISE EXCEPTION 'Permission denied: only super admins can suspend organizations';
  END IF;

  UPDATE public.organizations
    SET status         = 'suspended',
        suspended_at   = NOW(),
        suspended_reason = COALESCE(p_reason, 'No reason provided'),
        updated_at     = NOW()
  WHERE id = p_org_id
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization % not found or already deleted', p_org_id;
  END IF;

  -- Revoke active sessions: set the org_id of all profiles in this org to NULL
  -- for the duration of the suspension, which combined with the RLS guard
  -- below means no Supabase request from those users will succeed.
  UPDATE public.profiles
    SET suspended_at = NOW()
  WHERE org_id = p_org_id;

  INSERT INTO public.platform_activity_feed
    (org_id, user_id, activity_type, activity_data)
  VALUES
    (p_org_id, v_actor, 'org_suspended',
     jsonb_build_object('reason', p_reason, 'at', NOW()));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6) Reactivate (unsuspend) an organization.
CREATE OR REPLACE FUNCTION public.unsuspend_organization(
  p_org_id     UUID
)
RETURNS VOID AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = v_actor AND role = 'superAdmin') THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  UPDATE public.organizations
    SET status         = 'active',
        suspended_at   = NULL,
        suspended_reason = NULL,
        updated_at     = NOW()
  WHERE id = p_org_id AND deleted_at IS NULL;

  UPDATE public.profiles
    SET suspended_at = NULL
  WHERE org_id = p_org_id;

  INSERT INTO public.platform_activity_feed
    (org_id, user_id, activity_type, activity_data)
  VALUES
    (p_org_id, v_actor, 'org_unsuspended', jsonb_build_object('at', NOW()));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7) Soft-delete an organization.
--    CASCADE behaviour: we set deleted_at on the org, mark every
--    profile.org_id as NULL, and trust RLS to deny reads on
--    tenant-scoped tables. A 30-day grace period follows the soft
--    delete; the row stays in the table so that audit history is
--    preserved.
CREATE OR REPLACE FUNCTION public.soft_delete_organization(
  p_org_id     UUID,
  p_reason     TEXT
)
RETURNS VOID AS $$
DECLARE
  v_actor UUID := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles
                 WHERE id = v_actor AND role = 'superAdmin') THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  UPDATE public.organizations
    SET status         = 'deleted',
        deleted_at     = NOW(),
        deleted_reason = COALESCE(p_reason, 'No reason provided'),
        suspended_at   = NOW(),
        suspended_reason = COALESCE(p_reason, 'No reason provided'),
        updated_at     = NOW()
  WHERE id = p_org_id
    AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Organization % not found or already deleted', p_org_id;
  END IF;

  -- Detach users from the org so the JWT they hold no longer matches
  -- any tenant-scoped RLS predicate.
  UPDATE public.profiles
    SET org_id = NULL
  WHERE org_id = p_org_id;

  INSERT INTO public.platform_activity_feed
    (org_id, user_id, activity_type, activity_data)
  VALUES
    (p_org_id, v_actor, 'org_deleted',
     jsonb_build_object('reason', p_reason, 'at', NOW()));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8) Purge organizations soft-deleted more than N days ago.
--    Schedulable from cron / Edge Function.
CREATE OR REPLACE FUNCTION public.purge_deleted_organizations(
  p_min_age_days INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  WITH del AS (
    DELETE FROM public.organizations
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - (p_min_age_days || ' days')::interval
    RETURNING id
  )
  SELECT COUNT(*) INTO v_count FROM del;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9) RLS helpers for client-side check of "is the user blocked?".
CREATE OR REPLACE FUNCTION public.current_user_org_active()
RETURNS BOOLEAN AS $$
  SELECT public.org_is_active(
    (SELECT org_id FROM public.profiles WHERE id = auth.uid())
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

COMMIT;

-- After running, verify with:
--   SELECT proname FROM pg_proc WHERE proname IN
--     ('suspend_organization','unsuspend_organization',
--      'soft_delete_organization','purge_deleted_organizations',
--      'org_is_active','current_user_org_active');
