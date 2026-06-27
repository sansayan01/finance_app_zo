-- =====================================================
-- MICROFLOW PRO - COMPLETE LOCAL SCHEMA
-- Properly ordered: tables -> functions -> RLS -> triggers
-- =====================================================

-- ═══════════════════════════════════════════════════════
-- SECTION 1: ALL TABLES
-- ═══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    display_name TEXT,
    logo_url TEXT,
    primary_color TEXT DEFAULT '#6366F1',
    secondary_color TEXT DEFAULT '#8B5CF6',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial', 'inactive')),
    max_branches INTEGER DEFAULT 5,
    max_staff INTEGER DEFAULT 20,
    max_members INTEGER DEFAULT 500,
    address TEXT, city TEXT, state TEXT, pincode TEXT,
    phone TEXT, email TEXT, gst_number TEXT,
    brand_color TEXT DEFAULT '#1976D2',
    settings JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

INSERT INTO public.organizations (id, name, slug, status)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'My MFI', 'my-mfi', 'active')
ON CONFLICT (slug) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL, code TEXT, zone TEXT, district TEXT,
    address TEXT, city TEXT, state TEXT, pincode TEXT,
    phone TEXT, email TEXT, manager_id UUID,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
    latitude DECIMAL(10,8), longitude DECIMAL(11,8),
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT, email TEXT UNIQUE, phone TEXT, avatar_url TEXT,
    role TEXT DEFAULT 'customer' CHECK (role IN ('superAdmin','superadmin','executiveAdmin','executiveadmin','admin','manager','collectionAgent','collectionagent','staff','customer','retailmember')),
    org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    staff_code TEXT UNIQUE, member_id TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','suspended','on_leave','pending')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT, phone TEXT, email TEXT, address TEXT,
    area TEXT, city TEXT, state TEXT, pincode TEXT,
    member_id TEXT UNIQUE,
    kyc_status TEXT DEFAULT 'pending' CHECK (kyc_status IN ('pending','verified','rejected','notSubmitted')),
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8), gps_address TEXT,
    profile_photo_url TEXT, date_of_birth DATE, gender TEXT,
    total_savings DECIMAL(12,2) DEFAULT 0.00, active_loans INTEGER DEFAULT 0,
    village TEXT, father_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    supervisor_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    full_name TEXT, email TEXT, phone TEXT, avatar_url TEXT,
    staff_code TEXT UNIQUE, employee_id TEXT, designation TEXT,
    role TEXT DEFAULT 'collector' CHECK (role IN ('collector','supervisor','branch_manager','area_manager')),
    area TEXT, assigned_zone TEXT, assigned_areas TEXT[],
    shift TEXT DEFAULT 'morning' CHECK (shift IN ('morning','evening','full_day')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','suspended','on_leave')),
    date_of_joining DATE, hire_date DATE,
    daily_collection_target DECIMAL(12,2) DEFAULT 50000.00,
    monthly_collection_target DECIMAL(12,2) DEFAULT 1500000.00,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    loan_number TEXT, member_name TEXT,
    amount DECIMAL(12,2), principal DECIMAL(12,2),
    interest_rate DECIMAL(5,2), tenure_months INTEGER,
    emi DECIMAL(12,2), emi_amount DECIMAL(12,2),
    frequency TEXT DEFAULT 'weekly' CHECK (frequency IN ('daily','weekly','monthly')),
    outstanding_amount DECIMAL(12,2) DEFAULT 0,
    outstanding_balance DECIMAL(12,2),
    total_repayable DECIMAL(12,2),
    interest DECIMAL(12,2),
    start_date DATE, first_installment_date DATE, end_date DATE,
    risk_category TEXT DEFAULT 'standard',
    status TEXT DEFAULT 'pending' CHECK (status IN ('draft','submitted','underReview','pending','approved','rejected','active','defaultStatus','defaulted','restructured','closed')),
    paid_emis INTEGER DEFAULT 0, total_emis INTEGER,
    closed_date DATE, closed_reason TEXT,
    disbursed_at TIMESTAMPTZ, approved_at TIMESTAMPTZ,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.loan_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    period INTEGER, due_date DATE,
    emi DECIMAL(12,2), emi_amount DECIMAL(12,2),
    principal DECIMAL(12,2), interest DECIMAL(12,2), balance DECIMAL(12,2),
    is_paid BOOLEAN DEFAULT false, is_overdue BOOLEAN DEFAULT false,
    paid_date TIMESTAMPTZ, penalty DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.emi_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    period INTEGER NOT NULL, due_date DATE NOT NULL,
    emi_amount DECIMAL(12,2) NOT NULL,
    principal DECIMAL(12,2) NOT NULL, interest DECIMAL(12,2) NOT NULL,
    balance DECIMAL(12,2) NOT NULL,
    is_paid BOOLEAN DEFAULT false, is_overdue BOOLEAN DEFAULT false,
    paid_date TIMESTAMPTZ, payment_mode TEXT,
    status TEXT DEFAULT 'pending',
    penalty DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    member_name TEXT, plan_name TEXT, account_number TEXT,
    balance DECIMAL(12,2) DEFAULT 0,
    current_amount DECIMAL(12,2) DEFAULT 0.00,
    target_amount DECIMAL(12,2), monthly_deposit DECIMAL(12,2),
    interest_rate DECIMAL(5,2) DEFAULT 0, tenure_months INTEGER,
    maturity_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active','completed','matured','withdrawn','cancelled','paused')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.savings_installments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    savings_id UUID REFERENCES public.savings(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL,
    paid_on TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
    savings_id UUID,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    member_name TEXT,
    type TEXT CHECK (type IN ('loanDisbursement','emiPayment','savingsDeposit','savingsWithdrawal','penalty','staffCashDeposit','other','collection','deposit','withdrawal')),
    amount DECIMAL(12,2), payment_mode TEXT,
    reference_number TEXT, description TEXT,
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8),
    transaction_date DATE, transaction_time TIMESTAMPTZ,
    status TEXT DEFAULT 'completed',
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
    loan_schedule_id UUID REFERENCES public.loan_schedules(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    member_name TEXT, member_phone TEXT, loan_number TEXT,
    amount_expected DECIMAL(12,2), amount_collected DECIMAL(12,2),
    is_partial BOOLEAN DEFAULT false, is_advance BOOLEAN DEFAULT false,
    is_offline BOOLEAN DEFAULT false,
    collection_type TEXT DEFAULT 'emi',
    payment_mode TEXT DEFAULT 'cash',
    reference_number TEXT, receipt_number TEXT,
    collection_date DATE, collection_time TIMESTAMPTZ,
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8),
    gps_accuracy DECIMAL(8,2), gps_address TEXT,
    sync_status TEXT DEFAULT 'synced',
    local_id TEXT, sync_attempts INTEGER DEFAULT 0,
    last_sync_at TIMESTAMPTZ, remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_wallet (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE UNIQUE,
    cash_in_hand DECIMAL(12,2) DEFAULT 0,
    digital_balance DECIMAL(12,2) DEFAULT 0,
    safe_limit DECIMAL(12,2) DEFAULT 50000.00,
    total_collected_today DECIMAL(12,2) DEFAULT 0,
    total_deposited_today DECIMAL(12,2) DEFAULT 0,
    last_deposit_amount DECIMAL(12,2),
    last_deposit_at TIMESTAMPTZ, last_deposit_mode TEXT,
    is_over_limit BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    type TEXT, amount DECIMAL(12,2), direction TEXT,
    payment_mode TEXT,
    collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL,
    savings_collection_id UUID,
    reference_number TEXT, balance_after DECIMAL(12,2),
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8),
    transaction_time TIMESTAMPTZ DEFAULT now(),
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.collection_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    target_amount DECIMAL(12,2), achieved_amount DECIMAL(12,2) DEFAULT 0,
    achieved_count INTEGER DEFAULT 0,
    overdue_target_amount DECIMAL(12,2) DEFAULT 0.00,
    overdue_achieved_amount DECIMAL(12,2) DEFAULT 0.00,
    target_count INTEGER,
    period_type TEXT DEFAULT 'daily',
    target_date DATE, period_start DATE, period_end DATE,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.visit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    purpose TEXT, visit_type TEXT DEFAULT 'collection',
    check_in_time TIMESTAMPTZ, check_in_at TIMESTAMPTZ,
    check_in_lat DECIMAL(10,8), check_in_lng DECIMAL(11,8),
    check_out_time TIMESTAMPTZ, check_out_at TIMESTAMPTZ,
    check_out_lat DECIMAL(10,8), check_out_lng DECIMAL(11,8),
    outcome TEXT, notes TEXT,
    status TEXT DEFAULT 'in_progress',
    sync_status TEXT DEFAULT 'synced', local_id TEXT,
    duration_minutes INTEGER,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    latitude DECIMAL(10,8) NOT NULL, longitude DECIMAL(11,8) NOT NULL,
    accuracy DECIMAL(8,2), altitude DECIMAL(10,2),
    speed DECIMAL(8,2), heading DECIMAL(5,2),
    activity_type TEXT DEFAULT 'idle',
    battery_level INTEGER, is_charging BOOLEAN DEFAULT false,
    recorded_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    sync_status TEXT DEFAULT 'synced'
);

CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL, entity_type TEXT, entity_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8), gps_address TEXT,
    device_id TEXT, app_version TEXT, platform TEXT,
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL, message TEXT,
    type TEXT DEFAULT 'info',
    priority TEXT DEFAULT 'normal',
    action_type TEXT, action_url TEXT, action_data JSONB,
    is_read BOOLEAN DEFAULT false, read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL, entity_type TEXT, entity_id UUID,
    details JSONB, ip_address TEXT, user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.cash_deposits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    deposit_method TEXT NOT NULL,
    reference_number TEXT, notes TEXT,
    deposit_time TIMESTAMPTZ DEFAULT now() NOT NULL,
    status TEXT DEFAULT 'pending_verification',
    verified_by UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    break_type TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL, end_time TIMESTAMPTZ,
    notes TEXT, status TEXT DEFAULT 'in_progress',
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    code TEXT NOT NULL, title TEXT NOT NULL, description TEXT,
    icon TEXT DEFAULT 'trophy', points INTEGER DEFAULT 0,
    category TEXT DEFAULT 'general',
    target_value INTEGER DEFAULT 1, is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(org_id, code)
);

CREATE TABLE IF NOT EXISTS public.staff_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    achievement_id UUID REFERENCES public.achievements(id) ON DELETE CASCADE,
    achievement_code TEXT NOT NULL, progress INTEGER DEFAULT 0,
    is_unlocked BOOLEAN DEFAULT false, unlocked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(staff_id, achievement_code)
);

CREATE TABLE IF NOT EXISTS public.staff_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    total_points INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_points_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    points INTEGER NOT NULL, reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.staff_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE UNIQUE,
    current_streak INTEGER DEFAULT 0, longest_streak INTEGER DEFAULT 0,
    last_collection_date DATE, last_activity_date DATE,
    total_collections INTEGER DEFAULT 0,
    total_amount_collected DECIMAL(14,2) DEFAULT 0.00,
    perfect_days INTEGER DEFAULT 0, badges JSONB DEFAULT '[]',
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.offline_sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    action_type TEXT NOT NULL, entity_table TEXT NOT NULL,
    entity_id UUID, payload JSONB NOT NULL,
    retry_count INTEGER DEFAULT 0, max_retries INTEGER DEFAULT 3,
    last_error TEXT, status TEXT DEFAULT 'pending',
    priority INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    last_attempt_at TIMESTAMPTZ, synced_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.sync_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    table_name TEXT NOT NULL, record_id UUID,
    conflict_type TEXT NOT NULL,
    local_data JSONB NOT NULL, server_data JSONB NOT NULL,
    resolution TEXT DEFAULT 'pending', resolved_data JSONB,
    detected_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    resolved_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.savings_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL, description TEXT,
    min_deposit DECIMAL(12,2) NOT NULL DEFAULT 100.00,
    interest_rate DECIMAL(5,2) DEFAULT 0.00,
    tenure_months INTEGER NOT NULL DEFAULT 12,
    opening_balance DECIMAL(12,2) DEFAULT 0,
    collection_type TEXT DEFAULT 'monthly',
    start_date DATE, next_due_date DATE,
    installments_paid INTEGER DEFAULT 0,
    current_amount DECIMAL(12,2) DEFAULT 0,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.savings_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    savings_id UUID REFERENCES public.savings(id) ON DELETE SET NULL,
    savings_plan_id UUID REFERENCES public.savings_plans(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_name TEXT, member_phone TEXT,
    amount DECIMAL(12,2), amount_collected DECIMAL(12,2),
    amount_expected DECIMAL(12,2),
    payment_mode TEXT DEFAULT 'cash',
    collection_date DATE, collection_time TIMESTAMPTZ,
    gps_lat DECIMAL(10,8), gps_lng DECIMAL(11,8),
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    key TEXT NOT NULL, value TEXT, description TEXT,
    category TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    UNIQUE(org_id, key)
);

CREATE TABLE IF NOT EXISTS public.upi_payment_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id),
    loan_id UUID REFERENCES public.loans(id),
    savings_plan_id UUID REFERENCES public.savings_plans(id),
    emi_schedule_id UUID REFERENCES public.emi_schedule(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    upi_vpa TEXT NOT NULL, upi_id TEXT,
    transaction_ref TEXT, status TEXT DEFAULT 'pending',
    installment_number INTEGER, notification_type TEXT,
    confirmed_by UUID REFERENCES auth.users(id),
    confirmed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.sms_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL, message TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    sent_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.sms_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT, api_key TEXT, sender_id TEXT,
    is_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    sms_notifications BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.customer_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    title TEXT NOT NULL, message TEXT, type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    subject TEXT NOT NULL, description TEXT,
    status TEXT DEFAULT 'open', priority TEXT DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.customer_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    rating INTEGER, feedback TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.org_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL, role TEXT, status TEXT DEFAULT 'pending',
    invited_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.org_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    plan_id TEXT, status TEXT DEFAULT 'active',
    starts_at TIMESTAMPTZ, ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    amount DECIMAL(12,2), status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    key_hash TEXT, name TEXT, is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.org_branding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE UNIQUE,
    display_name TEXT, logo_url TEXT,
    primary_color TEXT DEFAULT '#6366F1',
    secondary_color TEXT DEFAULT '#8B5CF6',
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.brand_presets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL, primary_color TEXT,
    secondary_color TEXT, logo_url TEXT
);

CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL, price DECIMAL(12,2),
    max_branches INTEGER, max_staff INTEGER, max_members INTEGER,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.platform_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL, value TEXT, description TEXT
);

CREATE TABLE IF NOT EXISTS public.leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    period TEXT, score DECIMAL(12,2) DEFAULT 0, rank INTEGER,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ═══════════════════════════════════════════════════════
-- SECTION 2: HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.get_user_org_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    (SELECT org_id FROM public.profiles WHERE user_id = auth.uid() LIMIT 1),
    '00000000-0000-0000-0000-000000000001'::uuid
  );
$$;

CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(role, 'customer') FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE user_id = auth.uid()
    AND (role = 'superAdmin' OR role = 'superadmin')
  );
$$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════
-- SECTION 3: RLS POLICIES
-- ═══════════════════════════════════════════════════════

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY orgs_select ON public.organizations FOR SELECT USING (true);
CREATE POLICY profiles_select ON public.profiles FOR SELECT USING (org_id = public.get_user_org_id() OR user_id = auth.uid());
CREATE POLICY profiles_insert ON public.profiles FOR INSERT WITH CHECK (user_id = auth.uid() OR org_id = public.get_user_org_id());
CREATE POLICY profiles_update ON public.profiles FOR UPDATE USING (user_id = auth.uid() OR org_id = public.get_user_org_id());
CREATE POLICY branches_select ON public.branches FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY members_select ON public.members FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY members_insert ON public.members FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY members_update ON public.members FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY loans_select ON public.loans FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY loans_insert ON public.loans FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY loans_update ON public.loans FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY savings_select ON public.savings FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY collections_select ON public.collections FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY collections_insert ON public.collections FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY staff_profiles_select ON public.staff_profiles FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY visit_logs_select ON public.visit_logs FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY visit_logs_insert ON public.visit_logs FOR INSERT WITH CHECK (org_id = public.get_user_org_id());
CREATE POLICY visit_logs_update ON public.visit_logs FOR UPDATE USING (org_id = public.get_user_org_id());
CREATE POLICY transactions_select ON public.transactions FOR SELECT USING (org_id = public.get_user_org_id());
CREATE POLICY transactions_insert ON public.transactions FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- ═══════════════════════════════════════════════════════
-- SECTION 4: INDEXES
-- ═══════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_profiles_org ON public.profiles(org_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_members_org ON public.members(org_id);
CREATE INDEX IF NOT EXISTS idx_members_phone ON public.members(phone);
CREATE INDEX IF NOT EXISTS idx_loans_org ON public.loans(org_id);
CREATE INDEX IF NOT EXISTS idx_loans_customer ON public.loans(customer_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);
CREATE INDEX IF NOT EXISTS idx_collections_staff ON public.collections(staff_id);
CREATE INDEX IF NOT EXISTS idx_collections_date ON public.collections(collection_date);
CREATE INDEX IF NOT EXISTS idx_visit_logs_staff ON public.visit_logs(staff_id);

-- ═══════════════════════════════════════════════════════
-- SECTION 5: STORAGE
-- ═══════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Done!
SELECT 'Schema applied successfully!' AS result;
