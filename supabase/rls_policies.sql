-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- MicroFlow Pro - Multi-Tenant SaaS
-- =====================================================
-- These policies ensure each organization sees ONLY its own data.
-- Run AFTER migration_multi_tenant.sql
-- =====================================================

-- Helper functions (SECURITY DEFINER to bypass RLS and avoid recursion)
CREATE OR REPLACE FUNCTION public.get_user_org_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(profiles.org_id, '00000000-0000-0000-0000-000000000001'::uuid)
  FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- Organizations (users can only read their own org)
CREATE POLICY org_select ON public.organizations FOR SELECT
  USING (id = public.get_user_org_id());

-- Profiles
CREATE POLICY org_select_own ON public.profiles FOR SELECT
  USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert_own ON public.profiles FOR INSERT
  WITH CHECK (user_id = auth.uid() AND org_id = public.get_user_org_id());
CREATE POLICY org_update_own ON public.profiles FOR UPDATE
  USING (user_id = auth.uid() OR public.get_user_role() IN ('executiveAdmin', 'manager'))
  WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_delete_admin ON public.profiles FOR DELETE
  USING (public.get_user_role() = 'executiveAdmin');

-- Members
CREATE POLICY org_select ON public.members FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.members FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.members FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.members FOR DELETE USING (org_id = public.get_user_org_id());

-- Loans
CREATE POLICY org_select ON public.loans FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.loans FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.loans FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.loans FOR DELETE USING (org_id = public.get_user_org_id());

-- EMI Schedule
CREATE POLICY org_select ON public.emi_schedule FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.emi_schedule FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.emi_schedule FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.emi_schedule FOR DELETE USING (org_id = public.get_user_org_id());

-- Savings
CREATE POLICY org_select ON public.savings FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.savings FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.savings FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.savings FOR DELETE USING (org_id = public.get_user_org_id());

-- Savings Plans
CREATE POLICY org_select ON public.savings_plans FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.savings_plans FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.savings_plans FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.savings_plans FOR DELETE USING (org_id = public.get_user_org_id());

-- Transactions
CREATE POLICY org_select ON public.transactions FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.transactions FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.transactions FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.transactions FOR DELETE USING (org_id = public.get_user_org_id());

-- Activity Logs
CREATE POLICY org_select ON public.activity_logs FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.activity_logs FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Branches (admin/manager can insert, all can select within org)
CREATE POLICY org_select ON public.branches FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.branches FOR INSERT
  WITH CHECK (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
CREATE POLICY org_update ON public.branches FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.branches FOR DELETE USING (org_id = public.get_user_org_id());

-- Staff Profiles
CREATE POLICY org_select ON public.staff_profiles FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.staff_profiles FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY org_update ON public.staff_profiles FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY org_delete ON public.staff_profiles FOR DELETE USING (org_id = public.get_user_org_id());

-- Collections (staff see own, admin/supervisor see all in org)
CREATE POLICY staff_select ON public.collections FOR SELECT
  USING (org_id = public.get_user_org_id() AND
    (staff_id = auth.uid() OR public.get_user_role() IN ('executiveAdmin', 'manager', 'supervisor')));
CREATE POLICY staff_insert ON public.collections FOR INSERT
  WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY staff_update ON public.collections FOR UPDATE
  USING (org_id = public.get_user_org_id());

-- Savings Collections
CREATE POLICY org_select ON public.savings_collections FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY org_insert ON public.savings_collections FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Staff Locations (staff insert own, supervisors/admin see branch)
CREATE POLICY staff_insert ON public.staff_locations FOR INSERT
  WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
CREATE POLICY staff_select ON public.staff_locations FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

-- Wallet (staff see own)
CREATE POLICY staff_select ON public.staff_wallet FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

-- Wallet Transactions (staff see own)
CREATE POLICY staff_select ON public.wallet_transactions FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

-- Collection Targets (staff see own)
CREATE POLICY staff_select ON public.collection_targets FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
CREATE POLICY staff_insert ON public.collection_targets FOR INSERT
  WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

-- Visit Logs
CREATE POLICY staff_select ON public.visit_logs FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
CREATE POLICY staff_insert ON public.visit_logs FOR INSERT
  WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- Offline Sync Queue
CREATE POLICY staff_select ON public.offline_sync_queue FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
CREATE POLICY staff_insert ON public.offline_sync_queue FOR INSERT
  WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- Staff Streaks
CREATE POLICY staff_select ON public.staff_streaks FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

-- Staff Notifications
CREATE POLICY staff_select ON public.staff_notifications FOR SELECT
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
CREATE POLICY staff_update ON public.staff_notifications FOR UPDATE
  USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
