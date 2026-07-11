-- Allow super-admin / executive-admin to SELECT any organization.
-- Mirrors existing org_update_admin / org_delete_admin policies which already
-- bypass RLS by role. Without this, a platform admin viewing another org fails
-- both org_select conditions ((id = get_user_org_id()) OR (created_by = auth.uid()))
-- and the org detail page silently returns NULL -> "Organization not found".
DROP POLICY IF EXISTS org_select ON public.organizations;
CREATE POLICY org_select ON public.organizations
  FOR SELECT
  USING (
    (id = get_user_org_id())
    OR (created_by = auth.uid())
    OR (get_user_role() = ANY (ARRAY['executiveAdmin'::text, 'superAdmin'::text]))
  );
