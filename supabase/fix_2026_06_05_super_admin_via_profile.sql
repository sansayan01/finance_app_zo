-- =====================================================
-- 2026-06-05: Replace hardcoded super-admin email check
--             with a profile.role-based grant.
--
-- The Flutter client used to perform
--     if (email == 'msayan9733@gmail.com') role = superAdmin
-- inside auth_repository._parseRole. That client-side privilege
-- escalation has been removed. From now on, super-admin is granted
-- ONLY by setting profiles.role = 'superAdmin' for the user.
--
-- This migration promotes the original owner account (if it exists
-- in auth.users) to superAdmin so they keep the same level of
-- access. Run it once on production.
-- =====================================================

BEGIN;

-- 1) Promote the owner account by email (case-insensitive).
--    If the profile row does not exist yet, create it.
DO $$
DECLARE
  v_user_id UUID;
  v_email   TEXT := 'msayan9733@gmail.com';
BEGIN
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(v_email)
  LIMIT 1;

  IF v_user_id IS NOT NULL THEN
    -- upsert profile row
    INSERT INTO public.profiles (id, user_id, email, role, created_at, updated_at)
    VALUES (v_user_id, v_user_id, v_email, 'superAdmin', NOW(), NOW())
    ON CONFLICT (id) DO UPDATE
      SET role      = 'superAdmin',
          updated_at = NOW();
  END IF;
END $$;

-- 2) Make sure the role column accepts 'superAdmin' (it should already).
--    Belt-and-braces guard:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'profiles'
      AND column_name  = 'role'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN role TEXT NOT NULL DEFAULT 'customer';
  END IF;
END $$;

-- 3) Add a helper RPC for client-side admin role checks.
--    is_super_admin() already exists in super_admin_schema.sql,
--    but we add a simpler boolean function for the auth_repository
--    to call on demand so the client never has to embed emails.
CREATE OR REPLACE FUNCTION public.current_user_is_super_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'superAdmin'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

COMMIT;

-- After running this migration you can verify with:
--   SELECT id, email, role FROM public.profiles WHERE role = 'superAdmin';
