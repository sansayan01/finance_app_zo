-- =====================================================
-- FIX: Organizations RLS and Circular Dependency
-- =====================================================

-- 1. Add tracking column
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- 2. Update existing organizations (optional)
-- UPDATE public.organizations SET created_by = (SELECT user_id FROM public.profiles WHERE org_id = organizations.id LIMIT 1) WHERE created_by IS NULL;

-- 3. Securely update RLS policies
DROP POLICY IF EXISTS org_select ON public.organizations;
DROP POLICY IF EXISTS org_insert ON public.organizations;

CREATE POLICY org_select ON public.organizations 
FOR SELECT USING (id = public.get_user_org_id() OR created_by = auth.uid());

CREATE POLICY org_insert ON public.organizations 
FOR INSERT WITH CHECK (created_by = auth.uid());

-- 4. Loosen profile RLS for setup wizard
DROP POLICY IF EXISTS org_insert_own ON public.profiles;
DROP POLICY IF EXISTS org_update_own ON public.profiles;
DROP POLICY IF EXISTS org_select_own ON public.profiles;

CREATE POLICY org_select_own ON public.profiles FOR SELECT
  USING (org_id = public.get_user_org_id() OR user_id = auth.uid());

CREATE POLICY org_insert_own ON public.profiles FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY org_update_own ON public.profiles FOR UPDATE
  USING (user_id = auth.uid() OR public.get_user_role() IN ('executiveAdmin', 'manager'))
  WITH CHECK (user_id = auth.uid() OR org_id = public.get_user_org_id());
