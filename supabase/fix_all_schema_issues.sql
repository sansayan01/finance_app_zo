-- =====================================================
-- COMPREHENSIVE SCHEMA FIX MIGRATION
-- MicroFlow Pro - Fixes all identified issues
-- Run this in Supabase SQL Editor AFTER all other schemas
-- =====================================================

-- =====================================================
-- PART 1: MISSING TABLES
-- =====================================================

-- 1.1 EMI Schedule (referenced by rls_policies.sql and migration_multi_tenant.sql)
CREATE TABLE IF NOT EXISTS public.emi_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    period INTEGER NOT NULL,
    due_date DATE NOT NULL,
    emi_amount DECIMAL(12,2) NOT NULL,
    principal DECIMAL(12,2) NOT NULL,
    interest DECIMAL(12,2) NOT NULL,
    balance DECIMAL(12,2) NOT NULL,
    is_paid BOOLEAN DEFAULT false,
    is_overdue BOOLEAN DEFAULT false,
    paid_date TIMESTAMP WITH TIME ZONE,
    penalty DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.emi_schedule ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_emi_schedule_loan ON public.emi_schedule(loan_id);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_due ON public.emi_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_org ON public.emi_schedule(org_id);

-- 1.2 Savings Plans (referenced by rls_policies.sql and migration_multi_tenant.sql)
CREATE TABLE IF NOT EXISTS public.savings_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    min_deposit DECIMAL(12,2) NOT NULL DEFAULT 100.00,
    interest_rate DECIMAL(5,2) DEFAULT 0.00,
    tenure_months INTEGER NOT NULL DEFAULT 12,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.savings_plans ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_savings_plans_org ON public.savings_plans(org_id);

-- 1.3 System Settings (referenced by migration_multi_tenant.sql)
CREATE TABLE IF NOT EXISTS public.system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    key TEXT NOT NULL,
    value TEXT,
    description TEXT,
    category TEXT DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(org_id, key)
);
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_system_settings_org ON public.system_settings(org_id);

-- 1.4 Cash Deposits (referenced by staff_repository.dart)
CREATE TABLE IF NOT EXISTS public.cash_deposits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    deposit_method TEXT NOT NULL CHECK (deposit_method IN ('cash', 'bank_transfer', 'cheque')),
    reference_number TEXT,
    notes TEXT,
    deposit_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    status TEXT DEFAULT 'pending_verification' CHECK (status IN ('pending_verification', 'verified', 'rejected')),
    verified_by UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.cash_deposits ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_cash_deposits_staff ON public.cash_deposits(staff_id);
CREATE INDEX IF NOT EXISTS idx_cash_deposits_org ON public.cash_deposits(org_id);

-- 1.5 Staff Breaks (referenced by staff_repository.dart)
CREATE TABLE IF NOT EXISTS public.staff_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    break_type TEXT NOT NULL CHECK (break_type IN ('lunch', 'tea', 'rest', 'personal', 'other')),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.staff_breaks ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_staff_breaks_staff ON public.staff_breaks(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_breaks_org ON public.staff_breaks(org_id);

-- 1.6 Achievements Master (referenced by gamification_repository.dart)
CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT DEFAULT 'trophy',
    points INTEGER DEFAULT 0,
    category TEXT DEFAULT 'general' CHECK (category IN ('collections', 'streak', 'targets', 'overdue', 'social', 'general')),
    target_value INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(org_id, code)
);
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_achievements_org ON public.achievements(org_id);

-- 1.7 Staff Achievements (referenced by gamification_repository.dart)
CREATE TABLE IF NOT EXISTS public.staff_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    achievement_id UUID REFERENCES public.achievements(id) ON DELETE CASCADE,
    achievement_code TEXT NOT NULL,
    progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT false,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(staff_id, achievement_code)
);
ALTER TABLE public.staff_achievements ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_staff_achievements_staff ON public.staff_achievements(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_achievements_org ON public.staff_achievements(org_id);

-- 1.8 Staff Points (referenced by gamification_repository.dart)
CREATE TABLE IF NOT EXISTS public.staff_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    total_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.staff_points ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_staff_points_staff ON public.staff_points(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_points_org ON public.staff_points(org_id);

-- 1.9 Staff Points Log (referenced by gamification_repository.dart)
CREATE TABLE IF NOT EXISTS public.staff_points_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    points INTEGER NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.staff_points_log ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_staff_points_log_staff ON public.staff_points_log(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_points_log_org ON public.staff_points_log(org_id);

-- 1.10 Sync Conflicts (referenced by conflict_resolution_service.dart)
CREATE TABLE IF NOT EXISTS public.sync_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    table_name TEXT NOT NULL,
    record_id UUID,
    conflict_type TEXT NOT NULL CHECK (conflict_type IN ('updateUpdate', 'deleteUpdate', 'updateDelete', 'duplicate')),
    local_data JSONB NOT NULL,
    server_data JSONB NOT NULL,
    resolution TEXT DEFAULT 'pending' CHECK (resolution IN ('pending', 'localWins', 'serverWins', 'merged', 'manual')),
    resolved_data JSONB,
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public.sync_conflicts ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_table ON public.sync_conflicts(table_name);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON public.sync_conflicts(resolution);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_org ON public.sync_conflicts(org_id);

-- =====================================================
-- PART 2: MISSING COLUMNS IN EXISTING TABLES
-- =====================================================

-- 2.1 Add missing columns to loans table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'loan_number') THEN
        ALTER TABLE public.loans ADD COLUMN loan_number TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'emi') THEN
        ALTER TABLE public.loans ADD COLUMN emi DECIMAL(12,2);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'start_date') THEN
        ALTER TABLE public.loans ADD COLUMN start_date DATE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'paid_emis') THEN
        ALTER TABLE public.loans ADD COLUMN paid_emis INTEGER DEFAULT 0;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'total_emis') THEN
        ALTER TABLE public.loans ADD COLUMN total_emis INTEGER;
    END IF;
END $$;

-- 2.2 Add missing columns to savings table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'savings' AND column_name = 'account_number') THEN
        ALTER TABLE public.savings ADD COLUMN account_number TEXT;
    END IF;
END $$;

-- 2.3 Add missing columns to collections table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'collections' AND column_name = 'receipt_number') THEN
        ALTER TABLE public.collections ADD COLUMN receipt_number TEXT;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'collections' AND column_name = 'collection_type') THEN
        ALTER TABLE public.collections ADD COLUMN collection_type TEXT DEFAULT 'emi' CHECK (collection_type IN ('emi', 'overdue', 'advance', 'partial', 'savings'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'collections' AND column_name = 'is_offline') THEN
        ALTER TABLE public.collections ADD COLUMN is_offline BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 2.4 Add missing columns to visit_logs table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'visit_logs' AND column_name = 'customer_id') THEN
        ALTER TABLE public.visit_logs ADD COLUMN customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'visit_logs' AND column_name = 'status') THEN
        ALTER TABLE public.visit_logs ADD COLUMN status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'visit_logs' AND column_name = 'check_in_time') THEN
        ALTER TABLE public.visit_logs ADD COLUMN check_in_time TIMESTAMP WITH TIME ZONE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'visit_logs' AND column_name = 'check_out_time') THEN
        ALTER TABLE public.visit_logs ADD COLUMN check_out_time TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- 2.5 Add missing columns to members table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'members' AND column_name = 'address') THEN
        ALTER TABLE public.members ADD COLUMN address TEXT;
    END IF;
END $$;

-- 2.6 Add org_id to staff_locations (missed in multi-tenancy fix)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff_locations' AND column_name = 'org_id') THEN
        ALTER TABLE public.staff_locations ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_staff_locations_org ON public.staff_locations(org_id);
    END IF;
END $$;

-- =====================================================
-- PART 3: MISSING INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_loan_schedules_loan_id ON public.loan_schedules(loan_id);
CREATE INDEX IF NOT EXISTS idx_transactions_member ON public.transactions(member_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_loans_member ON public.loans(member_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);
CREATE INDEX IF NOT EXISTS idx_savings_member ON public.savings(member_id);

-- =====================================================
-- PART 4: MISSING VIEWS
-- =====================================================

-- 4.1 Staff Leaderboard View
CREATE OR REPLACE VIEW public.staff_leaderboard_view AS
SELECT 
    sp.id AS staff_id,
    sp.full_name AS staff_name,
    sp.branch_id,
    COUNT(c.id) AS collections_count,
    COALESCE(SUM(c.amount_collected), 0) AS total_collected,
    COUNT(DISTINCT vl.id) AS visits_count,
    COALESCE(
        CASE 
            WHEN ct.target_amount > 0 THEN (SUM(c.amount_collected) / NULLIF(ct.target_amount, 0)) * 100
            ELSE 0
        END, 0
    ) AS target_achieved,
    ss.current_streak AS streak_days,
    MIN(c.collection_time) AS collection_time
FROM public.staff_profiles sp
LEFT JOIN public.collections c ON c.staff_id = sp.id
LEFT JOIN public.visit_logs vl ON vl.staff_id = sp.id 
    AND vl.status = 'completed'
LEFT JOIN public.collection_targets ct ON ct.staff_id = sp.id 
    AND ct.period_type = 'daily'
    AND ct.target_date = CURRENT_DATE
LEFT JOIN public.staff_streaks ss ON ss.staff_id = sp.id
WHERE sp.status = 'active'
GROUP BY sp.id, sp.full_name, sp.branch_id, ct.target_amount, ss.current_streak;

-- =====================================================
-- PART 5: MISSING RPC FUNCTIONS
-- =====================================================

-- 5.1 Get frequent customers RPC
CREATE OR REPLACE FUNCTION public.get_frequent_customers(
    p_staff_id UUID,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    member_id UUID,
    member_name TEXT,
    member_phone TEXT,
    area TEXT,
    total_collections BIGINT,
    total_amount DECIMAL(12,2)
) LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT 
        c.member_id,
        MAX(c.member_name) AS member_name,
        MAX(c.member_phone) AS member_phone,
        MAX(m.area) AS area,
        COUNT(*) AS total_collections,
        SUM(c.amount_collected) AS total_amount
    FROM public.collections c
    LEFT JOIN public.members m ON m.id = c.member_id
    WHERE c.staff_id = p_staff_id
        AND c.member_id IS NOT NULL
    GROUP BY c.member_id
    ORDER BY total_collections DESC
    LIMIT p_limit;
$$;

-- 5.2 Get staff rank RPC
CREATE OR REPLACE FUNCTION public.get_staff_rank(p_staff_id UUID)
RETURNS TABLE (rank BIGINT) LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT 
        CAST(sub.rn AS BIGINT) AS rank
    FROM (
        SELECT 
            sp.id,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(c.amount_collected), 0) DESC) AS rn
        FROM public.staff_profiles sp
        LEFT JOIN public.collections c ON c.staff_id = sp.id
            AND c.collection_date = CURRENT_DATE
        WHERE sp.status = 'active'
        GROUP BY sp.id
    ) sub
    WHERE sub.id = p_staff_id;
$$;

-- 5.3 Update staff points RPC
CREATE OR REPLACE FUNCTION public.update_staff_points(
    p_staff_id UUID,
    p_points INTEGER
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_org_id UUID;
BEGIN
    SELECT org_id INTO v_org_id FROM public.staff_profiles WHERE id = p_staff_id;
    
    INSERT INTO public.staff_points (staff_id, org_id, total_points)
    VALUES (p_staff_id, v_org_id, p_points)
    ON CONFLICT (staff_id) 
    DO UPDATE SET 
        total_points = staff_points.total_points + p_points,
        updated_at = timezone('utc'::text, now());
END;
$$;

-- =====================================================
-- PART 6: FIX BROKEN RLS POLICIES (auth.uid() vs profiles.id)
-- =====================================================

-- 6.1 Fix is_super_admin function
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = auth.uid() 
        AND role = 'superAdmin'
    );
$$;

-- 6.2 Fix customer_portal policies (auth.uid() → user_id lookup)
-- Customer Notifications
DROP POLICY IF EXISTS customers_own_notifications ON public.customer_notifications;
CREATE POLICY customers_own_notifications ON public.customer_notifications
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS customers_insert_notifications ON public.customer_notifications;
CREATE POLICY customers_insert_notifications ON public.customer_notifications
    FOR INSERT WITH CHECK (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

-- Customer Payment Requests
DROP POLICY IF EXISTS customers_own_payment_requests ON public.customer_payment_requests;
CREATE POLICY customers_own_payment_requests ON public.customer_payment_requests
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS customers_insert_payment_requests ON public.customer_payment_requests;
CREATE POLICY customers_insert_payment_requests ON public.customer_payment_requests
    FOR INSERT WITH CHECK (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

-- Customer Support Tickets
DROP POLICY IF EXISTS customers_own_tickets ON public.customer_support_tickets;
CREATE POLICY customers_own_tickets ON public.customer_support_tickets
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS customers_insert_tickets ON public.customer_support_tickets;
CREATE POLICY customers_insert_tickets ON public.customer_support_tickets
    FOR INSERT WITH CHECK (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

-- Customer Ticket Messages
DROP POLICY IF EXISTS customers_own_ticket_messages ON public.customer_ticket_messages;
CREATE POLICY customers_own_ticket_messages ON public.customer_ticket_messages
    FOR SELECT USING (
        ticket_id IN (
            SELECT id FROM public.customer_support_tickets
            WHERE customer_id IN (
                SELECT id FROM public.profiles WHERE user_id = auth.uid()
            )
        )
    );

-- Customer Feedback
DROP POLICY IF EXISTS customers_own_feedback ON public.customer_feedback;
CREATE POLICY customers_own_feedback ON public.customer_feedback
    FOR SELECT USING (
        customer_id IN (
            SELECT id FROM public.profiles WHERE user_id = auth.uid()
        )
    );

-- =====================================================
-- PART 7: ADD RLS POLICIES TO TABLES WITH RLS BUT NO POLICIES
-- =====================================================

-- 7.1 Staff Portal Tables
DROP POLICY IF EXISTS cash_deposits_staff_all ON public.cash_deposits;
CREATE POLICY cash_deposits_staff_all ON public.cash_deposits FOR ALL
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()))
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS staff_breaks_staff_all ON public.staff_breaks;
CREATE POLICY staff_breaks_staff_all ON public.staff_breaks FOR ALL
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()))
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS achievements_org_select ON public.achievements;
CREATE POLICY achievements_org_select ON public.achievements FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_achievements_staff_all ON public.staff_achievements;
CREATE POLICY staff_achievements_staff_all ON public.staff_achievements FOR ALL
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()))
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS staff_points_staff_select ON public.staff_points;
CREATE POLICY staff_points_staff_select ON public.staff_points FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

DROP POLICY IF EXISTS staff_points_log_staff_insert ON public.staff_points_log;
CREATE POLICY staff_points_log_staff_insert ON public.staff_points_log FOR INSERT
    WITH CHECK (staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS staff_points_log_staff_select ON public.staff_points_log;
CREATE POLICY staff_points_log_staff_select ON public.staff_points_log FOR SELECT
    USING (staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id()));

DROP POLICY IF EXISTS sync_conflicts_staff_select ON public.sync_conflicts;
CREATE POLICY sync_conflicts_staff_select ON public.sync_conflicts FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS sync_conflicts_staff_insert ON public.sync_conflicts;
CREATE POLICY sync_conflicts_staff_insert ON public.sync_conflicts FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

-- 7.2 EMI Schedule
DROP POLICY IF EXISTS emi_schedule_org_select ON public.emi_schedule;
CREATE POLICY emi_schedule_org_select ON public.emi_schedule FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_org_insert ON public.emi_schedule;
CREATE POLICY emi_schedule_org_insert ON public.emi_schedule FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_org_update ON public.emi_schedule;
CREATE POLICY emi_schedule_org_update ON public.emi_schedule FOR UPDATE
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_org_delete ON public.emi_schedule;
CREATE POLICY emi_schedule_org_delete ON public.emi_schedule FOR DELETE
    USING (org_id = public.get_user_org_id());

-- 7.3 Savings Plans
DROP POLICY IF EXISTS savings_plans_org_select ON public.savings_plans;
CREATE POLICY savings_plans_org_select ON public.savings_plans FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_plans_org_insert ON public.savings_plans;
CREATE POLICY savings_plans_org_insert ON public.savings_plans FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_plans_org_update ON public.savings_plans;
CREATE POLICY savings_plans_org_update ON public.savings_plans FOR UPDATE
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_plans_org_delete ON public.savings_plans;
CREATE POLICY savings_plans_org_delete ON public.savings_plans FOR DELETE
    USING (org_id = public.get_user_org_id());

-- 7.4 System Settings
DROP POLICY IF EXISTS system_settings_org_select ON public.system_settings;
CREATE POLICY system_settings_org_select ON public.system_settings FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS system_settings_org_insert ON public.system_settings;
CREATE POLICY system_settings_org_insert ON public.system_settings FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS system_settings_org_update ON public.system_settings;
CREATE POLICY system_settings_org_update ON public.system_settings FOR UPDATE
    USING (org_id = public.get_user_org_id());

-- 7.5 Whitelabel tables
DROP POLICY IF EXISTS custom_domains_org ON public.custom_domains;
CREATE POLICY custom_domains_org ON public.custom_domains FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS email_templates_org ON public.email_templates;
CREATE POLICY email_templates_org ON public.email_templates FOR ALL
    USING (org_id = public.get_user_org_id() OR org_id IS NULL)
    WITH CHECK (org_id = public.get_user_org_id());

-- 7.6 Operations tables
DROP POLICY IF EXISTS system_status_select ON public.system_status;
CREATE POLICY system_status_select ON public.system_status FOR SELECT USING (true);

DROP POLICY IF EXISTS scheduled_maintenance_select ON public.scheduled_maintenance;
CREATE POLICY scheduled_maintenance_select ON public.scheduled_maintenance FOR SELECT USING (true);

DROP POLICY IF EXISTS uptime_checks_select ON public.uptime_checks;
CREATE POLICY uptime_checks_select ON public.uptime_checks FOR SELECT USING (true);

DROP POLICY IF EXISTS error_logs_staff ON public.error_logs;
CREATE POLICY error_logs_staff ON public.error_logs FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS help_articles_select ON public.help_articles;
CREATE POLICY help_articles_select ON public.help_articles FOR SELECT USING (true);

DROP POLICY IF EXISTS video_tutorials_select ON public.video_tutorials;
CREATE POLICY video_tutorials_select ON public.video_tutorials FOR SELECT USING (true);

-- 7.7 Growth tables
DROP POLICY IF EXISTS referrals_org ON public.referrals;
CREATE POLICY referrals_org ON public.referrals FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS marketplace_templates_select ON public.marketplace_templates;
CREATE POLICY marketplace_templates_select ON public.marketplace_templates FOR SELECT USING (true);

DROP POLICY IF EXISTS template_reviews_select ON public.template_reviews;
CREATE POLICY template_reviews_select ON public.template_reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS announcements_select ON public.announcements;
CREATE POLICY announcements_select ON public.announcements FOR SELECT USING (true);

DROP POLICY IF EXISTS feature_requests_select ON public.feature_requests;
CREATE POLICY feature_requests_select ON public.feature_requests FOR SELECT USING (true);

-- 7.8 Analytics tables
DROP POLICY IF EXISTS analytics_events_org ON public.analytics_events;
CREATE POLICY analytics_events_org ON public.analytics_events FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS org_metrics_org ON public.org_metrics;
CREATE POLICY org_metrics_org ON public.org_metrics FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS dashboard_widgets_org ON public.dashboard_widgets;
CREATE POLICY dashboard_widgets_org ON public.dashboard_widgets FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS custom_reports_org ON public.custom_reports;
CREATE POLICY custom_reports_org ON public.custom_reports FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

-- 7.9 Enterprise tables
DROP POLICY IF EXISTS data_residency_org ON public.data_residency_settings;
CREATE POLICY data_residency_org ON public.data_residency_settings FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS data_deletion_org ON public.data_deletion_requests;
CREATE POLICY data_deletion_org ON public.data_deletion_requests FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS sla_agreements_org ON public.sla_agreements;
CREATE POLICY sla_agreements_org ON public.sla_agreements FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS support_ticket_messages_org ON public.support_ticket_messages;
CREATE POLICY support_ticket_messages_org ON public.support_ticket_messages FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

-- 7.10 Super admin tables
DROP POLICY IF EXISTS feature_flag_usage_super ON public.feature_flag_usage;
CREATE POLICY feature_flag_usage_super ON public.feature_flag_usage FOR SELECT
    USING (public.is_super_admin());

DROP POLICY IF EXISTS announcement_reads_org ON public.announcement_reads;
CREATE POLICY announcement_reads_org ON public.announcement_reads FOR ALL
    USING (org_id = public.get_user_org_id())
    WITH CHECK (org_id = public.get_user_org_id());

-- 7.11 Billing tables
DROP POLICY IF EXISTS usage_records_org ON public.usage_records;
CREATE POLICY usage_records_org ON public.usage_records FOR SELECT
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS billing_events_org ON public.billing_events;
CREATE POLICY billing_events_org ON public.billing_events FOR SELECT
    USING (org_id = public.get_user_org_id());

-- 7.12 API/Webhook tables
DROP POLICY IF EXISTS api_rate_limits_select ON public.api_rate_limits;
CREATE POLICY api_rate_limits_select ON public.api_rate_limits FOR SELECT USING (true);

DROP POLICY IF EXISTS webhook_deliveries_org ON public.webhook_deliveries;
CREATE POLICY webhook_deliveries_org ON public.webhook_deliveries FOR ALL
    USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS api_logs_org ON public.api_logs;
CREATE POLICY api_logs_org ON public.api_logs FOR ALL
    USING (org_id = public.get_user_org_id());

-- =====================================================
-- PART 8: FIX TRIGGER REFERENCES
-- =====================================================

-- 8.1 Fix audit_members_changes trigger (name → full_name)
CREATE OR REPLACE FUNCTION public.audit_members_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (org_id, user_id, action, entity_type, entity_id, details)
        VALUES (NEW.org_id, auth.uid(), 'member_created', 'member', NEW.id, 
                jsonb_build_object('member_name', NEW.full_name));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (org_id, user_id, action, entity_type, entity_id, details)
        VALUES (NEW.org_id, auth.uid(), 'member_updated', 'member', NEW.id,
                jsonb_build_object(
                    'old_name', OLD.full_name, 
                    'new_name', NEW.full_name,
                    'changed_fields', jsonb_strip_nulls(jsonb_build_object(
                        'phone', CASE WHEN OLD.phone <> NEW.phone THEN NEW.phone ELSE NULL END,
                        'kyc_status', CASE WHEN OLD.kyc_status <> NEW.kyc_status THEN NEW.kyc_status ELSE NULL END
                    ))
                ));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (org_id, user_id, action, entity_type, entity_id, details)
        VALUES (OLD.org_id, auth.uid(), 'member_deleted', 'member', OLD.id,
                jsonb_build_object('member_name', OLD.full_name));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8.2 Fix welcome_email_trigger
CREATE OR REPLACE FUNCTION public.handle_new_user_welcome()
RETURNS TRIGGER AS $$
DECLARE
    v_org_name TEXT;
    v_user_email TEXT;
BEGIN
    v_user_email := NEW.email;
    
    SELECT o.name INTO v_org_name
    FROM public.profiles p
    JOIN public.organizations o ON o.id = p.org_id
    WHERE p.user_id = NEW.id
    LIMIT 1;
    
    -- Send welcome notification (replace with actual email logic)
    INSERT INTO public.staff_notifications (staff_id, title, message, type, priority)
    SELECT 
        sp.id,
        'Welcome to MicroFlow Pro',
        'Welcome, ' || COALESCE(NEW.raw_user_meta_data->>'full_name', v_user_email) || '!',
        'system',
        'normal'
    FROM public.staff_profiles sp
    WHERE sp.user_id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate triggers
DROP TRIGGER IF EXISTS audit_members_insert ON public.members;
DROP TRIGGER IF EXISTS audit_members_update ON public.members;
DROP TRIGGER IF EXISTS audit_members_delete ON public.members;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DO $$
BEGIN
    -- Only recreate audit triggers if audit_logs table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_logs') THEN
        CREATE TRIGGER audit_members_insert AFTER INSERT ON public.members
            FOR EACH ROW EXECUTE FUNCTION public.audit_members_changes();
        CREATE TRIGGER audit_members_update AFTER UPDATE ON public.members
            FOR EACH ROW EXECUTE FUNCTION public.audit_members_changes();
        CREATE TRIGGER audit_members_delete AFTER DELETE ON public.members
            FOR EACH ROW EXECUTE FUNCTION public.audit_members_changes();
    END IF;
    
    -- Recreate welcome trigger
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
    CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_welcome();
END $$;

-- =====================================================
-- PART 9: ENABLE RLS ON BASE SCHEMA TABLES
-- =====================================================

ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_schedules ENABLE ROW LEVEL SECURITY;

-- Add loan_schedules RLS policies (missing from rls_policies.sql)
DROP POLICY IF EXISTS org_select ON public.loan_schedules;
CREATE POLICY org_select ON public.loan_schedules FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM public.loans l WHERE l.id = loan_schedules.loan_id AND l.org_id = public.get_user_org_id()
    ));

DROP POLICY IF EXISTS org_insert ON public.loan_schedules;
CREATE POLICY org_insert ON public.loan_schedules FOR INSERT
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.loans l WHERE l.id = loan_schedules.loan_id AND l.org_id = public.get_user_org_id()
    ));

DROP POLICY IF EXISTS org_update ON public.loan_schedules;
CREATE POLICY org_update ON public.loan_schedules FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM public.loans l WHERE l.id = loan_schedules.loan_id AND l.org_id = public.get_user_org_id()
    ));

DROP POLICY IF EXISTS org_delete ON public.loan_schedules;
CREATE POLICY org_delete ON public.loan_schedules FOR DELETE
    USING (EXISTS (
        SELECT 1 FROM public.loans l WHERE l.id = loan_schedules.loan_id AND l.org_id = public.get_user_org_id()
    ));

-- =====================================================
-- PART 10: FIX UPDATE TRIGGERS FOR MISSING UPDATED_AT
-- =====================================================

DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
        AND table_schema = 'public'
        AND table_name NOT IN (
            'branches', 'staff_profiles', 'collections', 'savings_collections',
            'staff_wallet', 'collection_targets', 'staff_streaks',
            'organizations', 'profiles'
        )
    LOOP
        BEGIN
            EXECUTE format('
                DROP TRIGGER IF EXISTS update_%s_updated_at ON public.%I;
                CREATE TRIGGER update_%s_updated_at 
                BEFORE UPDATE ON public.%I
                FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
            ', t.table_name, t.table_name, t.table_name, t.table_name);
        EXCEPTION WHEN OTHERS THEN
            -- Skip if fails
        END;
    END LOOP;
END $$;

-- =====================================================
-- PART 11: FIX WALLET UPDATE TRIGGER (race condition)
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_wallet_on_collection()
RETURNS TRIGGER AS $$
DECLARE
    v_staff_id UUID;
    v_payment_mode TEXT;
    v_is_cash BOOLEAN;
    v_new_cash DECIMAL(12,2);
    v_new_digital DECIMAL(12,2);
BEGIN
    v_staff_id := NEW.staff_id;
    v_payment_mode := NEW.payment_mode;
    v_is_cash := (v_payment_mode = 'cash');
    
    -- Update wallet with RETURNING for atomic balance tracking
    WITH wallet_update AS (
        UPDATE public.staff_wallet
        SET 
            cash_in_hand = CASE WHEN v_is_cash THEN cash_in_hand + NEW.amount_collected ELSE cash_in_hand END,
            digital_balance = CASE WHEN NOT v_is_cash THEN digital_balance + NEW.amount_collected ELSE digital_balance END,
            total_collected_today = COALESCE(total_collected_today, 0) + NEW.amount_collected,
            is_over_limit = (
                CASE WHEN v_is_cash THEN cash_in_hand + NEW.amount_collected ELSE cash_in_hand END
            ) > COALESCE(safe_limit, 50000.00),
            updated_at = timezone('utc'::text, now())
        WHERE staff_id = v_staff_id
        RETURNING cash_in_hand, digital_balance
    )
    SELECT cash_in_hand, digital_balance INTO v_new_cash, v_new_digital FROM wallet_update;
    
    -- Create wallet transaction record
    INSERT INTO public.wallet_transactions (
        staff_id, type, amount, direction, payment_mode, 
        collection_id, balance_after, gps_lat, gps_lng, sync_status
    )
    VALUES (
        v_staff_id,
        'collection',
        NEW.amount_collected,
        'in',
        v_payment_mode,
        NEW.id,
        CASE WHEN v_is_cash THEN COALESCE(v_new_cash, 0) ELSE COALESCE(v_new_digital, 0) END,
        NEW.gps_lat,
        NEW.gps_lng,
        NEW.sync_status
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PART 12: FIX UPDATE SCHEDULE TRIGGER (negative prevention)
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_schedule_on_collection()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.loan_schedule_id IS NOT NULL THEN
        UPDATE public.loan_schedules
        SET 
            is_paid = (NEW.amount_collected >= NEW.amount_expected),
            paid_date = CASE WHEN NEW.amount_collected >= NEW.amount_expected THEN NEW.collection_time ELSE paid_date END
        WHERE id = NEW.loan_schedule_id;
    END IF;
    
    IF NEW.loan_id IS NOT NULL THEN
        UPDATE public.loans
        SET 
            outstanding_amount = GREATEST(outstanding_amount - NEW.amount_collected, 0),
            status = CASE 
                WHEN outstanding_amount - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PART 13: AUTO-CREATE POINTS ON STAFF CREATE
-- =====================================================
CREATE OR REPLACE FUNCTION public.create_staff_points()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.staff_points (staff_id, org_id, total_points)
    VALUES (NEW.id, NEW.org_id, 0)
    ON CONFLICT (staff_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS create_points_on_staff_create ON public.staff_profiles;
CREATE TRIGGER create_points_on_staff_create
    AFTER INSERT ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.create_staff_points();

-- =====================================================
-- END OF COMPREHENSIVE FIX MIGRATION
-- =====================================================
