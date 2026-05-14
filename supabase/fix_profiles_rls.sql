-- =====================================================
-- FIX: PROFILES RLS PERMISSIONS
-- MicroFlow Pro - Multi-Tenant Admin Fix
-- =====================================================
-- Run this in your Supabase SQL Editor to fix the 
-- "Permission Denied" error during user creation.
-- =====================================================

-- 1. Ensure helper functions are robust and secure
CREATE OR REPLACE FUNCTION public.get_user_org_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT org_id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- 2. Drop existing restrictive policies to start fresh
DROP POLICY IF EXISTS org_insert_own ON public.profiles;
DROP POLICY IF EXISTS profiles_insert ON public.profiles;
DROP POLICY IF EXISTS org_update_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update ON public.profiles;
DROP POLICY IF EXISTS org_delete_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_delete ON public.profiles;
DROP POLICY IF EXISTS org_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_select ON public.profiles;

-- 3. SELECT: Users can see their own profile OR others in their organization
CREATE POLICY profiles_select_policy ON public.profiles
FOR SELECT USING (
  user_id = auth.uid() 
  OR 
  org_id = public.get_user_org_id()
);

-- 4. INSERT: Users can create their own profile (signup) 
-- OR Admins/Managers can create staff/customer profiles in their org
CREATE POLICY profiles_insert_policy ON public.profiles
FOR INSERT WITH CHECK (
  user_id = auth.uid() -- Allow self-creation
  OR
  (
    public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager') 
    AND 
    org_id = public.get_user_org_id()
  ) -- Allow admin-led creation
);

-- 5. UPDATE: Users can update their own profile 
-- OR Admins/Managers can update profiles in their org
CREATE POLICY profiles_update_policy ON public.profiles
FOR UPDATE USING (
  user_id = auth.uid()
  OR
  (
    public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager') 
    AND 
    org_id = public.get_user_org_id()
  )
)
WITH CHECK (
  user_id = auth.uid()
  OR
  (
    public.get_user_role() IN ('superAdmin', 'executiveAdmin', 'manager') 
    AND 
    org_id = public.get_user_org_id()
  )
);

-- 6. DELETE: Only admins can delete profiles within their org
CREATE POLICY profiles_delete_policy ON public.profiles
FOR DELETE USING (
  public.get_user_role() IN ('superAdmin', 'executiveAdmin') 
  AND 
  org_id = public.get_user_org_id()
);

-- 7. Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 8. Verify the role check constraint covers all current roles
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('superAdmin', 'executiveAdmin', 'manager', 'collectionAgent', 'customer'));

-- =====================================================
-- END OF FIX
-- =====================================================
