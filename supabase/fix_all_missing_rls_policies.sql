-- =====================================================
-- COMPREHENSIVE RLS POLICIES FOR UNCONFIGURED TABLES
-- =====================================================

-- 1. achievements
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS achievements_select ON public.achievements;
CREATE POLICY achievements_select ON public.achievements FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS achievements_insert ON public.achievements;
CREATE POLICY achievements_insert ON public.achievements FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS achievements_update ON public.achievements;
CREATE POLICY achievements_update ON public.achievements FOR UPDATE
    USING (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS achievements_delete ON public.achievements;
CREATE POLICY achievements_delete ON public.achievements FOR DELETE
    USING (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));

-- 2. savings_plans
ALTER TABLE public.savings_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS savings_plans_select ON public.savings_plans;
CREATE POLICY savings_plans_select ON public.savings_plans FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS savings_plans_insert ON public.savings_plans;
CREATE POLICY savings_plans_insert ON public.savings_plans FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS savings_plans_update ON public.savings_plans;
CREATE POLICY savings_plans_update ON public.savings_plans FOR UPDATE
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS savings_plans_delete ON public.savings_plans;
CREATE POLICY savings_plans_delete ON public.savings_plans FOR DELETE
    USING (org_id = public.get_user_org_id());

-- 3. savings_collections
ALTER TABLE public.savings_collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS savings_collections_select ON public.savings_collections;
CREATE POLICY savings_collections_select ON public.savings_collections FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS savings_collections_insert ON public.savings_collections;
CREATE POLICY savings_collections_insert ON public.savings_collections FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

-- 4. activity_logs
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS activity_logs_select ON public.activity_logs;
CREATE POLICY activity_logs_select ON public.activity_logs FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS activity_logs_insert ON public.activity_logs;
CREATE POLICY activity_logs_insert ON public.activity_logs FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

-- 5. cash_deposits
ALTER TABLE public.cash_deposits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cash_deposits_select ON public.cash_deposits;
CREATE POLICY cash_deposits_select ON public.cash_deposits FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS cash_deposits_insert ON public.cash_deposits;
CREATE POLICY cash_deposits_insert ON public.cash_deposits FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS cash_deposits_update ON public.cash_deposits;
CREATE POLICY cash_deposits_update ON public.cash_deposits FOR UPDATE
    USING (org_id = public.get_user_org_id());

-- 6. collection_targets
ALTER TABLE public.collection_targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS collection_targets_select ON public.collection_targets;
CREATE POLICY collection_targets_select ON public.collection_targets FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS collection_targets_insert ON public.collection_targets;
CREATE POLICY collection_targets_insert ON public.collection_targets FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS collection_targets_update ON public.collection_targets;
CREATE POLICY collection_targets_update ON public.collection_targets FOR UPDATE
    USING (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));

-- 7. offline_sync_queue
ALTER TABLE public.offline_sync_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS offline_sync_queue_select ON public.offline_sync_queue;
CREATE POLICY offline_sync_queue_select ON public.offline_sync_queue FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS offline_sync_queue_insert ON public.offline_sync_queue;
CREATE POLICY offline_sync_queue_insert ON public.offline_sync_queue FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS offline_sync_queue_update ON public.offline_sync_queue;
CREATE POLICY offline_sync_queue_update ON public.offline_sync_queue FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS offline_sync_queue_delete ON public.offline_sync_queue;
CREATE POLICY offline_sync_queue_delete ON public.offline_sync_queue FOR DELETE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 8. org_invitations
ALTER TABLE public.org_invitations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS org_invitations_select ON public.org_invitations;
CREATE POLICY org_invitations_select ON public.org_invitations FOR SELECT
    USING (org_id = public.get_user_org_id() OR email = (SELECT email FROM auth.users WHERE id = auth.uid()));
DROP POLICY IF EXISTS org_invitations_insert ON public.org_invitations;
CREATE POLICY org_invitations_insert ON public.org_invitations FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS org_invitations_update ON public.org_invitations;
CREATE POLICY org_invitations_update ON public.org_invitations FOR UPDATE
    USING (org_id = public.get_user_org_id() OR email = (SELECT email FROM auth.users WHERE id = auth.uid()));

-- 9. staff_achievements
ALTER TABLE public.staff_achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_achievements_select ON public.staff_achievements;
CREATE POLICY staff_achievements_select ON public.staff_achievements FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
DROP POLICY IF EXISTS staff_achievements_insert ON public.staff_achievements;
CREATE POLICY staff_achievements_insert ON public.staff_achievements FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS staff_achievements_update ON public.staff_achievements;
CREATE POLICY staff_achievements_update ON public.staff_achievements FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 10. staff_breaks
ALTER TABLE public.staff_breaks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_breaks_select ON public.staff_breaks;
CREATE POLICY staff_breaks_select ON public.staff_breaks FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
DROP POLICY IF EXISTS staff_breaks_insert ON public.staff_breaks;
CREATE POLICY staff_breaks_insert ON public.staff_breaks FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS staff_breaks_update ON public.staff_breaks;
CREATE POLICY staff_breaks_update ON public.staff_breaks FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 11. staff_locations
ALTER TABLE public.staff_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_locations_select ON public.staff_locations;
CREATE POLICY staff_locations_select ON public.staff_locations FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_locations_insert ON public.staff_locations;
CREATE POLICY staff_locations_insert ON public.staff_locations FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 12. staff_notifications
ALTER TABLE public.staff_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_notifications_select ON public.staff_notifications;
CREATE POLICY staff_notifications_select ON public.staff_notifications FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()) OR org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_notifications_insert ON public.staff_notifications;
CREATE POLICY staff_notifications_insert ON public.staff_notifications FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_notifications_update ON public.staff_notifications;
CREATE POLICY staff_notifications_update ON public.staff_notifications FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 13. staff_points
ALTER TABLE public.staff_points ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_points_select ON public.staff_points;
CREATE POLICY staff_points_select ON public.staff_points FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
DROP POLICY IF EXISTS staff_points_insert ON public.staff_points;
CREATE POLICY staff_points_insert ON public.staff_points FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS staff_points_update ON public.staff_points;
CREATE POLICY staff_points_update ON public.staff_points FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 14. staff_points_log
ALTER TABLE public.staff_points_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_points_log_select ON public.staff_points_log;
CREATE POLICY staff_points_log_select ON public.staff_points_log FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
DROP POLICY IF EXISTS staff_points_log_insert ON public.staff_points_log;
CREATE POLICY staff_points_log_insert ON public.staff_points_log FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 15. staff_streaks
ALTER TABLE public.staff_streaks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_streaks_select ON public.staff_streaks;
CREATE POLICY staff_streaks_select ON public.staff_streaks FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_streaks_insert ON public.staff_streaks;
CREATE POLICY staff_streaks_insert ON public.staff_streaks FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS staff_streaks_update ON public.staff_streaks;
CREATE POLICY staff_streaks_update ON public.staff_streaks FOR UPDATE
    USING (org_id = public.get_user_org_id() AND staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 16. staff_wallet
ALTER TABLE public.staff_wallet ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS staff_wallet_select ON public.staff_wallet;
CREATE POLICY staff_wallet_select ON public.staff_wallet FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_wallet_insert ON public.staff_wallet;
CREATE POLICY staff_wallet_insert ON public.staff_wallet FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS staff_wallet_update ON public.staff_wallet;
CREATE POLICY staff_wallet_update ON public.staff_wallet FOR UPDATE
    USING (org_id = public.get_user_org_id());

-- 17. sync_conflicts
ALTER TABLE public.sync_conflicts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sync_conflicts_select ON public.sync_conflicts;
CREATE POLICY sync_conflicts_select ON public.sync_conflicts FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));
DROP POLICY IF EXISTS sync_conflicts_insert ON public.sync_conflicts;
CREATE POLICY sync_conflicts_insert ON public.sync_conflicts FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS sync_conflicts_update ON public.sync_conflicts;
CREATE POLICY sync_conflicts_update ON public.sync_conflicts FOR UPDATE
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 18. system_settings
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS system_settings_select ON public.system_settings;
CREATE POLICY system_settings_select ON public.system_settings FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS system_settings_insert ON public.system_settings;
CREATE POLICY system_settings_insert ON public.system_settings FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS system_settings_update ON public.system_settings;
CREATE POLICY system_settings_update ON public.system_settings FOR UPDATE
    USING (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));
DROP POLICY IF EXISTS system_settings_delete ON public.system_settings;
CREATE POLICY system_settings_delete ON public.system_settings FOR DELETE
    USING (org_id = public.get_user_org_id() AND public.get_user_role() IN ('executiveAdmin', 'manager'));

-- 19. visit_logs
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS visit_logs_select ON public.visit_logs;
CREATE POLICY visit_logs_select ON public.visit_logs FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS visit_logs_insert ON public.visit_logs;
CREATE POLICY visit_logs_insert ON public.visit_logs FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() AND staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));
DROP POLICY IF EXISTS visit_logs_update ON public.visit_logs;
CREATE POLICY visit_logs_update ON public.visit_logs FOR UPDATE
    USING (org_id = public.get_user_org_id() AND staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

-- 20. wallet_transactions
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS wallet_transactions_select ON public.wallet_transactions;
CREATE POLICY wallet_transactions_select ON public.wallet_transactions FOR SELECT
    USING (org_id = public.get_user_org_id());
DROP POLICY IF EXISTS wallet_transactions_insert ON public.wallet_transactions;
CREATE POLICY wallet_transactions_insert ON public.wallet_transactions FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());
