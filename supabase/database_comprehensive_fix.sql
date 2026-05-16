-- =====================================================
-- MICROFLOW PRO - COMPREHENSIVE DATABASE FIX
-- Run this in Supabase SQL Editor to fix all schema issues
-- =====================================================

-- =====================================================
-- PART 1: CORE HELPER FUNCTIONS (must exist first)
-- =====================================================

-- Drop if exists to recreate cleanly
DROP FUNCTION IF EXISTS public.get_user_org_id();
DROP FUNCTION IF EXISTS public.get_user_role();
DROP FUNCTION IF EXISTS public.is_super_admin();

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

-- =====================================================
-- PART 2: ORGANIZATIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    display_name TEXT,
    domain TEXT,
    logo_url TEXT,
    primary_color TEXT DEFAULT '#6366F1',
    secondary_color TEXT DEFAULT '#8B5CF6',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial', 'inactive')),
    max_branches INTEGER DEFAULT 5,
    max_staff INTEGER DEFAULT 20,
    max_members INTEGER DEFAULT 500,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    phone TEXT,
    email TEXT,
    gst_number TEXT,
    brand_color TEXT DEFAULT '#1976D2',
    trial_ends_at TIMESTAMP WITH TIME ZONE,
    settings JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Insert default org if not exists
INSERT INTO public.organizations (id, name, slug, status, max_branches, max_staff, max_members)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'My MFI', 'my-mfi', 'active', 10, 50, 5000)
ON CONFLICT (slug) DO NOTHING;

-- =====================================================
-- PART 3: BRANCHES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT,
    zone TEXT,
    district TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    phone TEXT,
    email TEXT,
    manager_id UUID,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    geofence_radius INTEGER DEFAULT 500,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Unique constraint per org
ALTER TABLE public.branches DROP CONSTRAINT IF EXISTS branches_org_code_unique;
ALTER TABLE public.branches ADD CONSTRAINT branches_org_code_unique UNIQUE (org_id, code);

CREATE INDEX IF NOT EXISTS idx_branches_org ON public.branches(org_id);

-- =====================================================
-- PART 4: PROFILES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT,
    email TEXT UNIQUE,
    phone TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'customer' CHECK (role IN ('superAdmin', 'superadmin', 'executiveAdmin', 'executiveadmin', 'admin', 'manager', 'collectionAgent', 'collectionagent', 'staff', 'customer', 'retailmember')),
    org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    staff_code TEXT UNIQUE,
    member_id TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'on_leave', 'pending')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_profiles_org ON public.profiles(org_id);
CREATE INDEX IF NOT EXISTS idx_profiles_branch ON public.profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_profiles_user ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

-- Update existing profiles with org_id
UPDATE public.profiles SET org_id = '00000000-0000-0000-0000-000000000001'::uuid WHERE org_id IS NULL;

-- =====================================================
-- PART 5: MEMBERS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    full_name TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    area TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    member_id TEXT UNIQUE,
    kyc_status TEXT DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected', 'notSubmitted')),
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    gps_address TEXT,
    profile_photo_url TEXT,
    date_of_birth DATE,
    gender TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_members_org ON public.members(org_id);
CREATE INDEX IF NOT EXISTS idx_members_branch ON public.members(branch_id);
CREATE INDEX IF NOT EXISTS idx_members_phone ON public.members(phone);
CREATE INDEX IF NOT EXISTS idx_members_kyc ON public.members(kyc_status);

-- =====================================================
-- PART 6: LOANS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    agent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    loan_number TEXT,
    amount DECIMAL(12, 2),
    interest_rate DECIMAL(5, 2),
    tenure_months INTEGER,
    emi DECIMAL(12, 2),
    emi_amount DECIMAL(12, 2),
    frequency TEXT DEFAULT 'weekly' CHECK (frequency IN ('daily', 'weekly', 'monthly')),
    collection_type TEXT,
    interest_type TEXT,
    outstanding_amount DECIMAL(12, 2) DEFAULT 0,
    total_repayable DECIMAL(12, 2),
    principal DECIMAL(12, 2),
    interest DECIMAL(12, 2),
    start_date DATE,
    first_installment_date DATE,
    end_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('draft', 'pending', 'approved', 'active', 'closed', 'rejected', 'defaulted', 'restructured')),
    paid_emis INTEGER DEFAULT 0,
    total_emis INTEGER,
    closed_date DATE,
    closed_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_loans_org ON public.loans(org_id);
CREATE INDEX IF NOT EXISTS idx_loans_customer ON public.loans(customer_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_agent ON public.loans(agent_id);

-- =====================================================
-- PART 7: LOAN SCHEDULES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.loan_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    period INTEGER,
    due_date DATE,
    emi DECIMAL(12, 2),
    emi_amount DECIMAL(12, 2),
    principal DECIMAL(12, 2),
    interest DECIMAL(12, 2),
    balance DECIMAL(12, 2),
    is_paid BOOLEAN DEFAULT false,
    is_overdue BOOLEAN DEFAULT false,
    paid_date TIMESTAMP WITH TIME ZONE,
    penalty DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_loan_schedules_loan ON public.loan_schedules(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_schedules_due ON public.loan_schedules(due_date);
CREATE INDEX IF NOT EXISTS idx_loan_schedules_org ON public.loan_schedules(org_id);

-- =====================================================
-- PART 8: SAVINGS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    plan_name TEXT,
    account_number TEXT,
    balance DECIMAL(12, 2) DEFAULT 0,
    target_amount DECIMAL(12, 2),
    monthly_deposit DECIMAL(12, 2),
    interest_rate DECIMAL(5, 2) DEFAULT 0,
    tenure_months INTEGER,
    maturity_date DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'matured', 'withdrawn', 'cancelled', 'paused')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_savings_org ON public.savings(org_id);
CREATE INDEX IF NOT EXISTS idx_savings_member ON public.savings(member_id);
CREATE INDEX IF NOT EXISTS idx_savings_status ON public.savings(status);

-- =====================================================
-- PART 9: COLLECTIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
    loan_schedule_id UUID REFERENCES public.loan_schedules(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_name TEXT,
    member_phone TEXT,
    loan_number TEXT,
    amount_expected DECIMAL(12, 2),
    amount_collected DECIMAL(12, 2),
    is_partial BOOLEAN DEFAULT false,
    is_advance BOOLEAN DEFAULT false,
    is_offline BOOLEAN DEFAULT false,
    collection_type TEXT DEFAULT 'emi' CHECK (collection_type IN ('emi', 'overdue', 'advance', 'partial', 'savings')),
    payment_mode TEXT DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card', 'other')),
    reference_number TEXT,
    receipt_number TEXT,
    collection_date DATE,
    collection_time TIMESTAMP WITH TIME ZONE,
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    gps_accuracy DECIMAL(8, 2),
    gps_address TEXT,
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    local_id TEXT,
    sync_attempts INTEGER DEFAULT 0,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_collections_org ON public.collections(org_id);
CREATE INDEX IF NOT EXISTS idx_collections_staff ON public.collections(staff_id);
CREATE INDEX IF NOT EXISTS idx_collections_member ON public.collections(member_id);
CREATE INDEX IF NOT EXISTS idx_collections_date ON public.collections(collection_date);
CREATE INDEX IF NOT EXISTS idx_collections_loan ON public.collections(loan_id);

-- =====================================================
-- PART 10: STAFF PROFILES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    supervisor_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    full_name TEXT,
    email TEXT,
    phone TEXT,
    avatar_url TEXT,
    employee_id TEXT,
    designation TEXT,
    area TEXT,
    assigned_zone TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'on_leave')),
    date_of_joining DATE,
    date_of_birth DATE,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_org ON public.staff_profiles(org_id);
CREATE INDEX IF NOT EXISTS idx_staff_branch ON public.staff_profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_staff_user ON public.staff_profiles(user_id);

-- =====================================================
-- PART 11: STAFF WALLET TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_wallet (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE UNIQUE,
    cash_in_hand DECIMAL(12, 2) DEFAULT 0,
    digital_balance DECIMAL(12, 2) DEFAULT 0,
    safe_limit DECIMAL(12, 2) DEFAULT 50000.00,
    total_collected_today DECIMAL(12, 2) DEFAULT 0,
    total_deposited_today DECIMAL(12, 2) DEFAULT 0,
    last_deposit_amount DECIMAL(12, 2),
    last_deposit_at TIMESTAMP WITH TIME ZONE,
    last_deposit_mode TEXT,
    is_over_limit BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =====================================================
-- PART 12: STAFF STREAKS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE UNIQUE,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    streak_start_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =====================================================
-- PART 13: COLLECTION TARGETS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.collection_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    target_amount DECIMAL(12, 2),
    achieved_amount DECIMAL(12, 2) DEFAULT 0,
    period_type TEXT DEFAULT 'daily' CHECK (period_type IN ('daily', 'weekly', 'monthly')),
    target_date DATE,
    period_start DATE,
    period_end DATE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'achieved', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_targets_staff ON public.collection_targets(staff_id);
CREATE INDEX IF NOT EXISTS idx_targets_date ON public.collection_targets(target_date);

-- =====================================================
-- PART 14: TRANSACTIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    type TEXT CHECK (type IN ('loanDisbursement', 'emiPayment', 'savingsDeposit', 'savingsWithdrawal', 'penalty', 'staffCashDeposit', 'other', 'collection', 'deposit', 'withdrawal')),
    amount DECIMAL(12, 2),
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bankTransfer', 'bank_transfer', 'cheque', 'card')),
    reference_number TEXT,
    description TEXT,
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    transaction_date DATE,
    transaction_time TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transactions_org ON public.transactions(org_id);
CREATE INDEX IF NOT EXISTS idx_transactions_member ON public.transactions(member_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(transaction_date);

-- =====================================================
-- PART 15: WALLET TRANSACTIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    type TEXT CHECK (type IN ('collection', 'deposit', 'withdrawal', 'adjustment', 'refund')),
    amount DECIMAL(12, 2),
    direction TEXT CHECK (direction IN ('in', 'out')),
    payment_mode TEXT,
    collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL,
    balance_after DECIMAL(12, 2),
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_wallet_trans_staff ON public.wallet_transactions(staff_id);

-- =====================================================
-- PART 16: VISIT LOGS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.visit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    purpose TEXT,
    visit_type TEXT DEFAULT 'collection',
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_in_at TIMESTAMP WITH TIME ZONE,
    check_in_lat DECIMAL(10, 8),
    check_in_lng DECIMAL(11, 8),
    check_out_time TIMESTAMP WITH TIME ZONE,
    check_out_at TIMESTAMP WITH TIME ZONE,
    check_out_lat DECIMAL(10, 8),
    check_out_lng DECIMAL(11, 8),
    outcome TEXT,
    notes TEXT,
    status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_visits_staff ON public.visit_logs(staff_id);
CREATE INDEX IF NOT EXISTS idx_visits_customer ON public.visit_logs(customer_id);
CREATE INDEX IF NOT EXISTS idx_visits_status ON public.visit_logs(status);

-- =====================================================
-- PART 17: STAFF LOCATIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(8, 2),
    altitude DECIMAL(10, 2),
    speed DECIMAL(8, 2),
    heading DECIMAL(5, 2),
    activity_type TEXT DEFAULT 'idle',
    battery_level INTEGER,
    is_charging BOOLEAN DEFAULT false,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_locations_staff ON public.staff_locations(staff_id);
CREATE INDEX IF NOT EXISTS idx_locations_org ON public.staff_locations(org_id);
CREATE INDEX IF NOT EXISTS idx_locations_recorded ON public.staff_locations(recorded_at);

-- =====================================================
-- PART 18: ACTIVITY LOGS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    gps_address TEXT,
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activity_staff ON public.activity_logs(staff_id);
CREATE INDEX IF NOT EXISTS idx_activity_org ON public.activity_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_activity_created ON public.activity_logs(created_at);

-- =====================================================
-- PART 19: STAFF NOTIFICATIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT,
    type TEXT DEFAULT 'info' CHECK (type IN ('info', 'warning', 'success', 'error', 'system', 'reminder', 'alert')),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    action_url TEXT,
    action_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_staff ON public.staff_notifications(staff_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.staff_notifications(is_read);

-- =====================================================
-- PART 20: AUDIT LOGS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_org ON public.audit_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.audit_logs(created_at);

-- =====================================================
-- PART 21: CASH DEPOSITS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.cash_deposits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_cash_deposits_staff ON public.cash_deposits(staff_id);
CREATE INDEX IF NOT EXISTS idx_cash_deposits_org ON public.cash_deposits(org_id);

-- =====================================================
-- PART 22: STAFF BREAKS TABLE
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_staff_breaks_staff ON public.staff_breaks(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_breaks_org ON public.staff_breaks(org_id);

-- =====================================================
-- PART 23: ACHIEVEMENTS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'trophy',
    points INTEGER DEFAULT 0,
    category TEXT DEFAULT 'general' CHECK (category IN ('collections', 'streak', 'targets', 'overdue', 'social', 'general')),
    target_value INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(org_id, code)
);

CREATE INDEX IF NOT EXISTS idx_achievements_org ON public.achievements(org_id);

-- =====================================================
-- PART 24: STAFF ACHIEVEMENTS TABLE
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_staff_achievements_staff ON public.staff_achievements(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_achievements_org ON public.staff_achievements(org_id);

-- =====================================================
-- PART 25: STAFF POINTS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    total_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_points_staff ON public.staff_points(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_points_org ON public.staff_points(org_id);

-- =====================================================
-- PART 26: STAFF POINTS LOG TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.staff_points_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    points INTEGER NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_points_log_staff ON public.staff_points_log(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_points_log_org ON public.staff_points_log(org_id);

-- =====================================================
-- PART 27: SYNC CONFLICTS TABLE
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_sync_conflicts_table ON public.sync_conflicts(table_name);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_status ON public.sync_conflicts(resolution);
CREATE INDEX IF NOT EXISTS idx_sync_conflicts_org ON public.sync_conflicts(org_id);

-- =====================================================
-- PART 28: SAVINGS PLANS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.savings_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    min_deposit DECIMAL(12, 2) NOT NULL DEFAULT 100.00,
    interest_rate DECIMAL(5,2) DEFAULT 0.00,
    tenure_months INTEGER NOT NULL DEFAULT 12,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_savings_plans_org ON public.savings_plans(org_id);

-- =====================================================
-- PART 29: SAVINGS COLLECTIONS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.savings_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    savings_id UUID REFERENCES public.savings(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_name TEXT,
    member_phone TEXT,
    amount DECIMAL(12, 2),
    payment_mode TEXT DEFAULT 'cash',
    collection_date DATE,
    collection_time TIMESTAMP WITH TIME ZONE,
    gps_lat DECIMAL(10, 8),
    gps_lng DECIMAL(11, 8),
    sync_status TEXT DEFAULT 'synced',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_savings_collections_staff ON public.savings_collections(staff_id);
CREATE INDEX IF NOT EXISTS idx_savings_collections_date ON public.savings_collections(collection_date);

-- =====================================================
-- PART 30: EMI SCHEDULE TABLE
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_emi_schedule_loan ON public.emi_schedule(loan_id);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_due ON public.emi_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_org ON public.emi_schedule(org_id);

-- =====================================================
-- PART 31: SYSTEM SETTINGS TABLE
-- =====================================================

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

CREATE INDEX IF NOT EXISTS idx_system_settings_org ON public.system_settings(org_id);

-- =====================================================
-- PART 32: STAFF TODAY SUMMARY VIEW
-- =====================================================

CREATE OR REPLACE VIEW public.staff_today_summary AS
SELECT
    sp.id,
    sp.org_id,
    sp.full_name,
    COALESCE(SUM(c.amount_collected), 0) as total_collected,
    COUNT(c.id) as collection_count,
    COUNT(DISTINCT vl.id) as visit_count
FROM public.staff_profiles sp
LEFT JOIN public.collections c ON c.staff_id = sp.id AND c.collection_date = CURRENT_DATE
LEFT JOIN public.visit_logs vl ON vl.staff_id = sp.id AND vl.check_in_at::date = CURRENT_DATE
GROUP BY sp.id, sp.org_id, sp.full_name;

-- =====================================================
-- PART 33: OVERDUE LOANS VIEW
-- =====================================================

CREATE OR REPLACE VIEW public.overdue_loans_view AS
SELECT
    l.id,
    l.org_id,
    l.customer_id,
    l.agent_id,
    l.loan_number,
    l.outstanding_amount,
    l.status,
    m.full_name as customer_name,
    m.phone as customer_phone,
    m.area,
    m.gps_lat,
    m.gps_lng,
    m.gps_address,
    ls.due_date,
    ls.emi_amount,
    ls.is_overdue,
    COALESCE(
        EXTRACT(DAY FROM (CURRENT_DATE - ls.due_date::date))::integer,
        0
    ) as days_overdue
FROM public.loans l
JOIN public.members m ON m.id = l.customer_id
LEFT JOIN LATERAL (
    SELECT * FROM public.loan_schedules
    WHERE loan_id = l.id AND is_paid = false AND is_overdue = true
    ORDER BY due_date ASC LIMIT 1
) ls ON true
WHERE l.status = 'active';

-- =====================================================
-- PART 34: UPDATE TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN
        SELECT table_name
        FROM information_schema.columns
        WHERE column_name = 'updated_at'
        AND table_schema = 'public'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS update_%I_updated_at ON public.%I;
            CREATE TRIGGER update_%I_updated_at
            BEFORE UPDATE ON public.%I
            FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
        ', t.table_name, t.table_name, t.table_name, t.table_name);
    END LOOP;
END $$;

-- =====================================================
-- PART 35: STAFF POINTS AUTO-CREATE TRIGGER
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
-- PART 36: STAFF WALLET AUTO-CREATE TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION public.create_staff_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.staff_wallet (staff_id)
    VALUES (NEW.id)
    ON CONFLICT (staff_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS create_wallet_on_staff_create ON public.staff_profiles;
CREATE TRIGGER create_wallet_on_staff_create
    AFTER INSERT ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.create_staff_wallet();

-- =====================================================
-- PART 37: STAFF STREAK AUTO-CREATE TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION public.create_staff_streak()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.staff_streaks (staff_id)
    VALUES (NEW.id)
    ON CONFLICT (staff_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS create_streak_on_staff_create ON public.staff_profiles;
CREATE TRIGGER create_streak_on_staff_create
    AFTER INSERT ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.create_staff_streak();

-- =====================================================
-- PART 38: RPC FUNCTIONS
-- =====================================================

-- Get frequent customers RPC
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
    WHERE c.staff_id = p_staff_id AND c.member_id IS NOT NULL
    GROUP BY c.member_id
    ORDER BY total_collections DESC
    LIMIT p_limit;
$$;

-- Get staff rank RPC
CREATE OR REPLACE FUNCTION public.get_staff_rank(p_staff_id UUID)
RETURNS TABLE (rank BIGINT) LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT CAST(sub.rn AS BIGINT) AS rank
    FROM (
        SELECT sp.id, ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(c.amount_collected), 0) DESC) AS rn
        FROM public.staff_profiles sp
        LEFT JOIN public.collections c ON c.staff_id = sp.id AND c.collection_date = CURRENT_DATE
        WHERE sp.status = 'active'
        GROUP BY sp.id
    ) sub
    WHERE sub.id = p_staff_id;
$$;

-- =====================================================
-- PART 39: RLS POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_points_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emi_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Core policies
-- Organizations: readable by all authenticated users in org
DROP POLICY IF EXISTS orgs_select ON public.organizations;
CREATE POLICY orgs_select ON public.organizations FOR SELECT USING (true);

-- Profiles: users see their own profile + org users
DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles FOR SELECT USING (
    org_id = public.get_user_org_id() OR user_id = auth.uid()
);

DROP POLICY IF EXISTS profiles_insert ON public.profiles;
CREATE POLICY profiles_insert ON public.profiles FOR INSERT WITH CHECK (
    user_id = auth.uid() OR (
        org_id = public.get_user_org_id() AND
        public.get_user_role() IN ('superAdmin', 'superadmin', 'executiveAdmin', 'executiveadmin', 'manager')
    )
);

DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles FOR UPDATE USING (
    user_id = auth.uid() OR (
        org_id = public.get_user_org_id() AND
        public.get_user_role() IN ('superAdmin', 'superadmin', 'executiveAdmin', 'executiveadmin', 'manager')
    )
);

-- Branches
DROP POLICY IF EXISTS branches_select ON public.branches;
CREATE POLICY branches_select ON public.branches FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS branches_insert ON public.branches;
CREATE POLICY branches_insert ON public.branches FOR INSERT WITH CHECK (
    org_id = public.get_user_org_id() AND
    public.get_user_role() IN ('superAdmin', 'superadmin', 'executiveAdmin', 'executiveadmin', 'manager')
);

DROP POLICY IF EXISTS branches_update ON public.branches;
CREATE POLICY branches_update ON public.branches FOR UPDATE USING (
    org_id = public.get_user_org_id() AND
    public.get_user_role() IN ('superAdmin', 'superadmin', 'executiveAdmin', 'executiveadmin', 'manager')
);

-- Members
DROP POLICY IF EXISTS members_select ON public.members;
CREATE POLICY members_select ON public.members FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS members_insert ON public.members;
CREATE POLICY members_insert ON public.members FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS members_update ON public.members;
CREATE POLICY members_update ON public.members FOR UPDATE USING (org_id = public.get_user_org_id());

-- Loans
DROP POLICY IF EXISTS loans_select ON public.loans;
CREATE POLICY loans_select ON public.loans FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS loans_insert ON public.loans;
CREATE POLICY loans_insert ON public.loans FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS loans_update ON public.loans;
CREATE POLICY loans_update ON public.loans FOR UPDATE USING (org_id = public.get_user_org_id());

-- Loan Schedules
DROP POLICY IF EXISTS loan_schedules_select ON public.loan_schedules;
CREATE POLICY loan_schedules_select ON public.loan_schedules FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.loans WHERE loans.id = loan_schedules.loan_id AND loans.org_id = public.get_user_org_id())
);

DROP POLICY IF EXISTS loan_schedules_update ON public.loan_schedules;
CREATE POLICY loan_schedules_update ON public.loan_schedules FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.loans WHERE loans.id = loan_schedules.loan_id AND loans.org_id = public.get_user_org_id())
);

-- Savings
DROP POLICY IF EXISTS savings_select ON public.savings;
CREATE POLICY savings_select ON public.savings FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_insert ON public.savings;
CREATE POLICY savings_insert ON public.savings FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_update ON public.savings;
CREATE POLICY savings_update ON public.savings FOR UPDATE USING (org_id = public.get_user_org_id());

-- Collections
DROP POLICY IF EXISTS collections_select ON public.collections;
CREATE POLICY collections_select ON public.collections FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS collections_insert ON public.collections;
CREATE POLICY collections_insert ON public.collections FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS collections_update ON public.collections;
CREATE POLICY collections_update ON public.collections FOR UPDATE USING (org_id = public.get_user_org_id());

-- Staff Profiles
DROP POLICY IF EXISTS staff_profiles_select ON public.staff_profiles;
CREATE POLICY staff_profiles_select ON public.staff_profiles FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_profiles_insert ON public.staff_profiles;
CREATE POLICY staff_profiles_insert ON public.staff_profiles FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_profiles_update ON public.staff_profiles;
CREATE POLICY staff_profiles_update ON public.staff_profiles FOR UPDATE USING (org_id = public.get_user_org_id());

-- Staff Wallet
DROP POLICY IF EXISTS staff_wallet_select ON public.staff_wallet;
CREATE POLICY staff_wallet_select ON public.staff_wallet FOR SELECT USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS staff_wallet_update ON public.staff_wallet;
CREATE POLICY staff_wallet_update ON public.staff_wallet FOR UPDATE USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid())
);

-- Transactions
DROP POLICY IF EXISTS transactions_select ON public.transactions;
CREATE POLICY transactions_select ON public.transactions FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS transactions_insert ON public.transactions;
CREATE POLICY transactions_insert ON public.transactions FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Visit Logs
DROP POLICY IF EXISTS visit_logs_select ON public.visit_logs;
CREATE POLICY visit_logs_select ON public.visit_logs FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS visit_logs_insert ON public.visit_logs;
CREATE POLICY visit_logs_insert ON public.visit_logs FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS visit_logs_update ON public.visit_logs;
CREATE POLICY visit_logs_update ON public.visit_logs FOR UPDATE USING (org_id = public.get_user_org_id());

-- Staff Locations
DROP POLICY IF EXISTS staff_locations_select ON public.staff_locations;
CREATE POLICY staff_locations_select ON public.staff_locations FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_locations_insert ON public.staff_locations;
CREATE POLICY staff_locations_insert ON public.staff_locations FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Activity Logs
DROP POLICY IF EXISTS activity_logs_select ON public.activity_logs;
CREATE POLICY activity_logs_select ON public.activity_logs FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS activity_logs_insert ON public.activity_logs;
CREATE POLICY activity_logs_insert ON public.activity_logs FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Staff Notifications
DROP POLICY IF EXISTS staff_notifications_select ON public.staff_notifications;
CREATE POLICY staff_notifications_select ON public.staff_notifications FOR SELECT USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS staff_notifications_update ON public.staff_notifications;
CREATE POLICY staff_notifications_update ON public.staff_notifications FOR UPDATE USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid())
);

-- Cash Deposits
DROP POLICY IF EXISTS cash_deposits_select ON public.cash_deposits;
CREATE POLICY cash_deposits_select ON public.cash_deposits FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS cash_deposits_insert ON public.cash_deposits;
CREATE POLICY cash_deposits_insert ON public.cash_deposits FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Staff Breaks
DROP POLICY IF EXISTS staff_breaks_select ON public.staff_breaks;
CREATE POLICY staff_breaks_select ON public.staff_breaks FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_breaks_insert ON public.staff_breaks;
CREATE POLICY staff_breaks_insert ON public.staff_breaks FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Collection Targets
DROP POLICY IF EXISTS collection_targets_select ON public.collection_targets;
CREATE POLICY collection_targets_select ON public.collection_targets FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS collection_targets_insert ON public.collection_targets;
CREATE POLICY collection_targets_insert ON public.collection_targets FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS collection_targets_update ON public.collection_targets;
CREATE POLICY collection_targets_update ON public.collection_targets FOR UPDATE USING (org_id = public.get_user_org_id());

-- Staff Streaks
DROP POLICY IF EXISTS staff_streaks_select ON public.staff_streaks;
CREATE POLICY staff_streaks_select ON public.staff_streaks FOR SELECT USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id())
);

-- Achievements
DROP POLICY IF EXISTS achievements_select ON public.achievements;
CREATE POLICY achievements_select ON public.achievements FOR SELECT USING (org_id = public.get_user_org_id());

-- Staff Achievements
DROP POLICY IF EXISTS staff_achievements_select ON public.staff_achievements;
CREATE POLICY staff_achievements_select ON public.staff_achievements FOR SELECT USING (org_id = public.get_user_org_id());

-- Staff Points
DROP POLICY IF EXISTS staff_points_select ON public.staff_points;
CREATE POLICY staff_points_select ON public.staff_points FOR SELECT USING (org_id = public.get_user_org_id());

-- Staff Points Log
DROP POLICY IF EXISTS staff_points_log_select ON public.staff_points_log;
CREATE POLICY staff_points_log_select ON public.staff_points_log FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS staff_points_log_insert ON public.staff_points_log;
CREATE POLICY staff_points_log_insert ON public.staff_points_log FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Sync Conflicts
DROP POLICY IF EXISTS sync_conflicts_select ON public.sync_conflicts;
CREATE POLICY sync_conflicts_select ON public.sync_conflicts FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS sync_conflicts_insert ON public.sync_conflicts;
CREATE POLICY sync_conflicts_insert ON public.sync_conflicts FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- Savings Plans
DROP POLICY IF EXISTS savings_plans_select ON public.savings_plans;
CREATE POLICY savings_plans_select ON public.savings_plans FOR SELECT USING (org_id = public.get_user_org_id());

-- Savings Collections
DROP POLICY IF EXISTS savings_collections_select ON public.savings_collections;
CREATE POLICY savings_collections_select ON public.savings_collections FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS savings_collections_insert ON public.savings_collections;
CREATE POLICY savings_collections_insert ON public.savings_collections FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- EMI Schedule
DROP POLICY IF EXISTS emi_schedule_select ON public.emi_schedule;
CREATE POLICY emi_schedule_select ON public.emi_schedule FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_update ON public.emi_schedule;
CREATE POLICY emi_schedule_update ON public.emi_schedule FOR UPDATE USING (org_id = public.get_user_org_id());

-- System Settings
DROP POLICY IF EXISTS system_settings_select ON public.system_settings;
CREATE POLICY system_settings_select ON public.system_settings FOR SELECT USING (org_id = public.get_user_org_id());

-- Wallet Transactions
DROP POLICY IF EXISTS wallet_transactions_select ON public.wallet_transactions;
CREATE POLICY wallet_transactions_select ON public.wallet_transactions FOR SELECT USING (
    staff_id IN (SELECT id FROM public.staff_profiles WHERE org_id = public.get_user_org_id())
);

DROP POLICY IF EXISTS wallet_transactions_insert ON public.wallet_transactions;
CREATE POLICY wallet_transactions_insert ON public.wallet_transactions FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- =====================================================
-- PART 40: STORAGE BUCKET FOR BRAND ASSETS
-- =====================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS brand_assets_public_read ON storage.objects;
CREATE POLICY brand_assets_public_read ON storage.objects FOR SELECT USING (bucket_id = 'brand-assets');

DROP POLICY IF EXISTS brand_assets_upload ON storage.objects;
CREATE POLICY brand_assets_upload ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'brand-assets' AND auth.uid() IS NOT NULL
);

-- =====================================================
-- VERIFICATION QUERIES (Run to verify setup)
-- =====================================================
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
-- SELECT * FROM pg_policies WHERE tablename = 'profiles';
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public';

-- =====================================================
-- END OF COMPREHENSIVE DATABASE FIX
-- =====================================================