-- =====================================================
-- ADD MISSING PROFILES DELETE POLICY
-- MicroFlow Pro
-- =====================================================
-- The database_comprehensive_fix.sql defines SELECT,
-- INSERT, UPDATE policies for profiles but OMITS the
-- DELETE policy. With RLS enabled, all DELETE operations
-- are silently rejected (0 rows affected, no error).
-- =====================================================
-- Run this in Supabase SQL Editor.
-- =====================================================

DROP POLICY IF EXISTS profiles_delete ON public.profiles;
DROP POLICY IF EXISTS profiles_delete_policy ON public.profiles;

CREATE POLICY profiles_delete ON public.profiles
FOR DELETE USING (
  org_id = public.get_user_org_id()
  AND public.get_user_role() IN (
    'superAdmin', 'superadmin',
    'executiveAdmin', 'executiveadmin',
    'manager'
  )
);

-- Verify
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles' AND cmd = 'DELETE';
