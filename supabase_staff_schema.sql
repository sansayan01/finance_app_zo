-- =====================================================
-- STAFF PORTAL SCHEMA EXTENSION
-- MicroFlow Pro - Field Collector Portal
-- =====================================================
-- Run this AFTER the base schema (supabase_schema.sql)
-- in your Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. BRANCHES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    zone TEXT NOT NULL,
    district TEXT,
    state TEXT DEFAULT 'Tamil Nadu',
    manager_id UUID,  -- References auth.users or staff_profiles later
    address TEXT,
    phone TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for zone-based queries
CREATE INDEX IF NOT EXISTS idx_branches_zone ON public.branches(zone);
CREATE INDEX IF NOT EXISTS idx_branches_status ON public.branches(status);

-- =====================================================
-- 2. STAFF PROFILES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- Links to Supabase Auth
    staff_code TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'collector' CHECK (role IN ('collector', 'supervisor', 'branch_manager', 'area_manager')),
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'on_leave')),
    assigned_areas TEXT[],  -- Array of area names this staff covers
    shift TEXT DEFAULT 'morning' CHECK (shift IN ('morning', 'evening', 'full_day')),
    hire_date DATE,
    daily_collection_target DECIMAL(12,2) DEFAULT 50000.00,
    monthly_collection_target DECIMAL(12,2) DEFAULT 1500000.00,
    supervisor_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for staff queries
CREATE INDEX IF NOT EXISTS idx_staff_profiles_branch ON public.staff_profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_role ON public.staff_profiles(role);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_status ON public.staff_profiles(status);
CREATE INDEX IF NOT EXISTS idx_staff_profiles_supervisor ON public.staff_profiles(supervisor_id);

-- =====================================================
-- 3. ADD AGENT_ID TO EXISTING LOANS TABLE
-- =====================================================
-- This links loans to the staff member who disbursed/manages them
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'loans' 
        AND column_name = 'agent_id'
    ) THEN
        ALTER TABLE public.loans ADD COLUMN agent_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Index for agent-based loan queries
CREATE INDEX IF NOT EXISTS idx_loans_agent ON public.loans(agent_id);

-- =====================================================
-- 4. ADD MEMBER LOCATION FIELDS
-- =====================================================
-- Add location fields to members for GPS-based features
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'members' 
        AND column_name = 'gps_lat'
    ) THEN
        ALTER TABLE public.members ADD COLUMN gps_lat DECIMAL(10,8);
        ALTER TABLE public.members ADD COLUMN gps_lng DECIMAL(11,8);
        ALTER TABLE public.members ADD COLUMN gps_address TEXT;
        ALTER TABLE public.members ADD COLUMN area TEXT;
        ALTER TABLE public.members ADD COLUMN village TEXT;
        ALTER TABLE public.members ADD COLUMN pincode TEXT;
    END IF;
END $$;

-- Index for area-based queries
CREATE INDEX IF NOT EXISTS idx_members_area ON public.members(area);

-- =====================================================
-- 5. COLLECTIONS TABLE (CORE - FIELD COLLECTIONS)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- References
    loan_id UUID REFERENCES public.loans(id) ON DELETE SET NULL,
    loan_schedule_id UUID REFERENCES public.loan_schedules(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    
    -- Member info (denormalized for offline access)
    member_name TEXT NOT NULL,
    member_phone TEXT,
    loan_number TEXT,
    
    -- Collection details
    amount_expected DECIMAL(12,2) NOT NULL,
    amount_collected DECIMAL(12,2) NOT NULL,
    variance DECIMAL(12,2) GENERATED ALWAYS AS (amount_expected - amount_collected) STORED,
    is_partial BOOLEAN DEFAULT false,
    is_advance BOOLEAN DEFAULT false,
    
    -- Payment details
    payment_mode TEXT NOT NULL DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
    reference_number TEXT,  -- UPI ref, cheque no, etc.
    
    -- GPS Location (mandatory for audit)
    gps_lat DECIMAL(10,8) NOT NULL,
    gps_lng DECIMAL(11,8) NOT NULL,
    gps_accuracy DECIMAL(8,2),
    gps_address TEXT,
    
    -- Timestamps
    collection_date DATE NOT NULL,
    collection_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Sync status (for offline-first)
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    local_id TEXT,  -- Local Hive ID for deduplication
    sync_attempts INTEGER DEFAULT 0,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit trail
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for collection queries
CREATE INDEX IF NOT EXISTS idx_collections_staff ON public.collections(staff_id);
CREATE INDEX IF NOT EXISTS idx_collections_member ON public.collections(member_id);
CREATE INDEX IF NOT EXISTS idx_collections_loan ON public.collections(loan_id);
CREATE INDEX IF NOT EXISTS idx_collections_date ON public.collections(collection_date);
CREATE INDEX IF NOT EXISTS idx_collections_sync_status ON public.collections(sync_status);
CREATE INDEX IF NOT EXISTS idx_collections_staff_date ON public.collections(staff_id, collection_date);

-- =====================================================
-- 6. SAVINGS COLLECTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.savings_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- References
    savings_id UUID REFERENCES public.savings(id) ON DELETE SET NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    
    -- Member info (denormalized)
    member_name TEXT NOT NULL,
    member_phone TEXT,
    
    -- Collection details
    amount DECIMAL(12,2) NOT NULL,
    payment_mode TEXT NOT NULL DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
    reference_number TEXT,
    
    -- GPS Location
    gps_lat DECIMAL(10,8) NOT NULL,
    gps_lng DECIMAL(11,8) NOT NULL,
    gps_accuracy DECIMAL(8,2),
    gps_address TEXT,
    
    -- Timestamps
    collection_date DATE NOT NULL,
    collection_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Sync status
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    local_id TEXT,
    sync_attempts INTEGER DEFAULT 0,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    remarks TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_savings_collections_staff ON public.savings_collections(staff_id);
CREATE INDEX IF NOT EXISTS idx_savings_collections_member ON public.savings_collections(member_id);
CREATE INDEX IF NOT EXISTS idx_savings_collections_date ON public.savings_collections(collection_date);
CREATE INDEX IF NOT EXISTS idx_savings_collections_sync_status ON public.savings_collections(sync_status);

-- =====================================================
-- 7. STAFF LOCATIONS TABLE (GPS TRACKING)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Location
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    accuracy DECIMAL(8,2),
    altitude DECIMAL(10,2),
    speed DECIMAL(8,2),
    heading DECIMAL(5,2),
    
    -- Context
    activity_type TEXT DEFAULT 'idle' CHECK (activity_type IN ('idle', 'traveling', 'collecting', 'resting')),
    battery_level INTEGER CHECK (battery_level >= 0 AND battery_level <= 100),
    is_charging BOOLEAN DEFAULT false,
    
    -- Timestamps
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Sync
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for location queries
CREATE INDEX IF NOT EXISTS idx_staff_locations_staff ON public.staff_locations(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_locations_recorded_at ON public.staff_locations(recorded_at);
CREATE INDEX IF NOT EXISTS idx_staff_locations_staff_time ON public.staff_locations(staff_id, recorded_at DESC);

-- =====================================================
-- 8. ACTIVITY LOGS TABLE (AUDIT TRAIL)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL,
    
    -- Action details
    action TEXT NOT NULL,  -- e.g., 'collection_recorded', 'login', 'sync_completed', 'visit_checkin'
    entity_type TEXT,      -- e.g., 'collection', 'member', 'loan'
    entity_id UUID,
    
    -- Metadata (flexible JSON for any extra details)
    metadata JSONB DEFAULT '{}',
    
    -- GPS Location
    gps_lat DECIMAL(10,8),
    gps_lng DECIMAL(11,8),
    gps_address TEXT,
    
    -- Device info
    device_id TEXT,
    app_version TEXT,
    platform TEXT,
    
    -- Sync
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_activity_logs_staff ON public.activity_logs(staff_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action ON public.activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON public.activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at DESC);

-- =====================================================
-- 9. STAFF WALLET TABLE (CASH IN HAND)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_wallet (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    
    -- Cash tracking
    cash_in_hand DECIMAL(12,2) DEFAULT 0.00 NOT NULL,
    digital_balance DECIMAL(12,2) DEFAULT 0.00 NOT NULL,
    total_collected_today DECIMAL(12,2) DEFAULT 0.00,
    total_deposited_today DECIMAL(12,2) DEFAULT 0.00,
    
    -- Last deposit info
    last_deposit_amount DECIMAL(12,2),
    last_deposit_at TIMESTAMP WITH TIME ZONE,
    last_deposit_mode TEXT CHECK (last_deposit_mode IN ('cash', 'bank', 'upi')),
    
    -- Safe limit (alerts when exceeded)
    safe_limit DECIMAL(12,2) DEFAULT 50000.00,
    is_over_limit BOOLEAN DEFAULT false,
    
    -- Timestamps
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =====================================================
-- 10. WALLET TRANSACTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    
    -- Transaction details
    type TEXT NOT NULL CHECK (type IN ('collection', 'deposit', 'withdrawal', 'adjustment')),
    amount DECIMAL(12,2) NOT NULL,
    direction TEXT NOT NULL CHECK (direction IN ('in', 'out')),
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank', 'adjustment')),
    
    -- Reference
    collection_id UUID REFERENCES public.collections(id) ON DELETE SET NULL,
    savings_collection_id UUID REFERENCES public.savings_collections(id) ON DELETE SET NULL,
    reference_number TEXT,
    
    -- Balance after transaction
    balance_after DECIMAL(12,2) NOT NULL,
    
    -- GPS
    gps_lat DECIMAL(10,8),
    gps_lng DECIMAL(11,8),
    
    -- Sync
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    
    -- Timestamps
    transaction_time TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_staff ON public.wallet_transactions(staff_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON public.wallet_transactions(type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_time ON public.wallet_transactions(transaction_time DESC);

-- =====================================================
-- 11. COLLECTION TARGETS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.collection_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Target period
    period_type TEXT NOT NULL CHECK (period_type IN ('daily', 'weekly', 'monthly')),
    target_date DATE NOT NULL,  -- The date this target applies to
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Targets
    target_amount DECIMAL(12,2) NOT NULL,
    target_count INTEGER,       -- Number of collections
    achieved_amount DECIMAL(12,2) DEFAULT 0.00,
    achieved_count INTEGER DEFAULT 0,
    
    -- Overdue-specific
    overdue_target_amount DECIMAL(12,2) DEFAULT 0.00,
    overdue_achieved_amount DECIMAL(12,2) DEFAULT 0.00,
    
    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'failed', 'cancelled')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Unique constraint: one target per staff per period
    UNIQUE(staff_id, period_type, target_date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_collection_targets_staff ON public.collection_targets(staff_id);
CREATE INDEX IF NOT EXISTS idx_collection_targets_date ON public.collection_targets(target_date);
CREATE INDEX IF NOT EXISTS idx_collection_targets_status ON public.collection_targets(status);

-- =====================================================
-- 12. VISIT LOGS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.visit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    
    -- Visit details
    visit_type TEXT NOT NULL CHECK (visit_type IN ('collection', 'follow_up', 'verification', 'other')),
    purpose TEXT,
    
    -- Location
    check_in_lat DECIMAL(10,8) NOT NULL,
    check_in_lng DECIMAL(11,8) NOT NULL,
    check_out_lat DECIMAL(10,8),
    check_out_lng DECIMAL(11,8),
    
    -- Timestamps
    check_in_at TIMESTAMP WITH TIME ZONE NOT NULL,
    check_out_at TIMESTAMP WITH TIME ZONE,
    duration_minutes INTEGER,
    
    -- Outcome
    outcome TEXT CHECK (outcome IN ('collected', 'not_home', 'refused', 'partial', 'rescheduled', 'other')),
    notes TEXT,
    
    -- Sync
    sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed')),
    local_id TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_visit_logs_staff ON public.visit_logs(staff_id);
CREATE INDEX IF NOT EXISTS idx_visit_logs_member ON public.visit_logs(member_id);
CREATE INDEX IF NOT EXISTS idx_visit_logs_date ON public.visit_logs(check_in_at DESC);

-- =====================================================
-- 13. OFFLINE SYNC QUEUE TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.offline_sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL NOT NULL,
    
    -- Action details
    action_type TEXT NOT NULL,  -- 'collection', 'savings_collection', 'activity_log', 'location', etc.
    entity_table TEXT NOT NULL,
    entity_id UUID,
    payload JSONB NOT NULL,
    
    -- Retry logic
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    last_error TEXT,
    
    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'synced', 'failed', 'cancelled')),
    
    -- Priority (higher = more urgent)
    priority INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_attempt_at TIMESTAMP WITH TIME ZONE,
    synced_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_offline_sync_queue_staff ON public.offline_sync_queue(staff_id);
CREATE INDEX IF NOT EXISTS idx_offline_sync_queue_status ON public.offline_sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_offline_sync_queue_priority ON public.offline_sync_queue(priority DESC, created_at);

-- =====================================================
-- 14. STAFF STREAKS TABLE (GAMIFICATION)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    
    -- Streak data
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_collection_date DATE,
    
    -- Achievements
    total_collections INTEGER DEFAULT 0,
    total_amount_collected DECIMAL(14,2) DEFAULT 0.00,
    perfect_days INTEGER DEFAULT 0,  -- Days where target was met 100%
    
    -- Badges (JSON array of badge IDs)
    badges JSONB DEFAULT '[]',
    
    -- Timestamps
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =====================================================
-- 15. NOTIFICATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Notification details
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('target', 'overdue', 'sync', 'alert', 'reminder', 'system')),
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Action
    action_type TEXT,  -- 'open_collection', 'open_member', 'open_report', etc.
    action_data JSONB,
    
    -- Read status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_staff_notifications_staff ON public.staff_notifications(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_notifications_unread ON public.staff_notifications(staff_id, is_read);
CREATE INDEX IF NOT EXISTS idx_staff_notifications_created ON public.staff_notifications(created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offline_sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_notifications ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICIES FOR STAFF_PROFILES
-- =====================================================

-- Staff can read their own profile
CREATE POLICY "staff_read_own_profile" ON public.staff_profiles
    FOR SELECT USING (user_id = auth.uid());

-- Staff can update their own profile (limited fields)
CREATE POLICY "staff_update_own_profile" ON public.staff_profiles
    FOR UPDATE USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Supervisors can read profiles of staff in their branch
CREATE POLICY "supervisor_read_branch_staff" ON public.staff_profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.staff_profiles sp
            WHERE sp.user_id = auth.uid()
            AND sp.role IN ('supervisor', 'branch_manager', 'area_manager')
            AND sp.branch_id = staff_profiles.branch_id
        )
    );

-- =====================================================
-- RLS POLICIES FOR COLLECTIONS
-- =====================================================

-- Staff can read their own collections
CREATE POLICY "staff_read_own_collections" ON public.collections
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can insert their own collections
CREATE POLICY "staff_insert_own_collections" ON public.collections
    FOR INSERT WITH CHECK (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can update their own pending collections
CREATE POLICY "staff_update_own_collections" ON public.collections
    FOR UPDATE USING (
        staff_id IN (SELECT id FROM public.staff_profiles WHERE user_id = auth.uid())
        AND sync_status = 'pending'
    );

-- Supervisors can read all collections in their branch
CREATE POLICY "supervisor_read_branch_collections" ON public.collections
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.staff_profiles sp
            WHERE sp.user_id = auth.uid()
            AND sp.role IN ('supervisor', 'branch_manager', 'area_manager')
            AND sp.branch_id = (SELECT branch_id FROM public.staff_profiles WHERE id = collections.staff_id)
        )
    );

-- =====================================================
-- RLS POLICIES FOR STAFF_LOCATIONS
-- =====================================================

-- Staff can insert their own locations
CREATE POLICY "staff_insert_own_locations" ON public.staff_locations
    FOR INSERT WITH CHECK (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can read their own locations
CREATE POLICY "staff_read_own_locations" ON public.staff_locations
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Supervisors can read locations of staff in their branch
CREATE POLICY "supervisor_read_branch_locations" ON public.staff_locations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.staff_profiles sp
            WHERE sp.user_id = auth.uid()
            AND sp.role IN ('supervisor', 'branch_manager', 'area_manager')
            AND sp.branch_id = (SELECT branch_id FROM public.staff_profiles WHERE id = staff_locations.staff_id)
        )
    );

-- =====================================================
-- RLS POLICIES FOR STAFF_WALLET
-- =====================================================

-- Staff can read their own wallet
CREATE POLICY "staff_read_own_wallet" ON public.staff_wallet
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can update their own wallet
CREATE POLICY "staff_update_own_wallet" ON public.staff_wallet
    FOR UPDATE USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can insert wallet transactions
CREATE POLICY "staff_insert_wallet_transactions" ON public.wallet_transactions
    FOR INSERT WITH CHECK (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can read their own wallet transactions
CREATE POLICY "staff_read_own_wallet_transactions" ON public.wallet_transactions
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR ACTIVITY_LOGS
-- =====================================================

-- Staff can insert their own activity logs
CREATE POLICY "staff_insert_own_activity_logs" ON public.activity_logs
    FOR INSERT WITH CHECK (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can read their own activity logs
CREATE POLICY "staff_read_own_activity_logs" ON public.activity_logs
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR COLLECTION_TARGETS
-- =====================================================

-- Staff can read their own targets
CREATE POLICY "staff_read_own_targets" ON public.collection_targets
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can update their own targets (achieved amounts)
CREATE POLICY "staff_update_own_targets" ON public.collection_targets
    FOR UPDATE USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR STAFF_NOTIFICATIONS
-- =====================================================

-- Staff can read their own notifications
CREATE POLICY "staff_read_own_notifications" ON public.staff_notifications
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can update their own notifications (mark as read)
CREATE POLICY "staff_update_own_notifications" ON public.staff_notifications
    FOR UPDATE USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR OFFLINE_SYNC_QUEUE
-- =====================================================

-- Staff can manage their own sync queue
CREATE POLICY "staff_manage_own_sync_queue" ON public.offline_sync_queue
    FOR ALL USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR VISIT_LOGS
-- =====================================================

-- Staff can insert and read their own visit logs
CREATE POLICY "staff_manage_own_visit_logs" ON public.visit_logs
    FOR ALL USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- RLS POLICIES FOR STAFF_STREAKS
-- =====================================================

-- Staff can read their own streaks
CREATE POLICY "staff_read_own_streaks" ON public.staff_streaks
    FOR SELECT USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- Staff can update their own streaks
CREATE POLICY "staff_update_own_streaks" ON public.staff_streaks
    FOR UPDATE USING (staff_id IN (
        SELECT id FROM public.staff_profiles WHERE user_id = auth.uid()
    ));

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers to tables with updated_at
CREATE TRIGGER update_branches_updated_at BEFORE UPDATE ON public.branches
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_staff_profiles_updated_at BEFORE UPDATE ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_collections_updated_at BEFORE UPDATE ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_savings_collections_updated_at BEFORE UPDATE ON public.savings_collections
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_staff_wallet_updated_at BEFORE UPDATE ON public.staff_wallet
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_collection_targets_updated_at BEFORE UPDATE ON public.collection_targets
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_staff_streaks_updated_at BEFORE UPDATE ON public.staff_streaks
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- FUNCTION: AUTO-CREATE STAFF WALLET
-- =====================================================
CREATE OR REPLACE FUNCTION public.create_staff_wallet()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.staff_wallet (staff_id, safe_limit)
    VALUES (NEW.id, NEW.daily_collection_target);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_wallet_on_staff_create
    AFTER INSERT ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.create_staff_wallet();

-- =====================================================
-- FUNCTION: AUTO-CREATE STAFF STREAKS
-- =====================================================
CREATE OR REPLACE FUNCTION public.create_staff_streaks()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.staff_streaks (staff_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER create_streaks_on_staff_create
    AFTER INSERT ON public.staff_profiles
    FOR EACH ROW EXECUTE FUNCTION public.create_staff_streaks();

-- =====================================================
-- FUNCTION: UPDATE WALLET ON COLLECTION
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_wallet_on_collection()
RETURNS TRIGGER AS $$
DECLARE
    v_staff_id UUID;
    v_payment_mode TEXT;
    v_is_cash BOOLEAN;
BEGIN
    -- Get staff ID from the collection
    v_staff_id := NEW.staff_id;
    v_payment_mode := NEW.payment_mode;
    v_is_cash := (v_payment_mode = 'cash');
    
    -- Update wallet
    UPDATE public.staff_wallet
    SET 
        cash_in_hand = CASE WHEN v_is_cash THEN cash_in_hand + NEW.amount_collected ELSE cash_in_hand END,
        digital_balance = CASE WHEN NOT v_is_cash THEN digital_balance + NEW.amount_collected ELSE digital_balance END,
        total_collected_today = total_collected_today + NEW.amount_collected,
        is_over_limit = (CASE WHEN v_is_cash THEN cash_in_hand + NEW.amount_collected ELSE cash_in_hand END) > safe_limit,
        updated_at = timezone('utc'::text, now())
    WHERE staff_id = v_staff_id;
    
    -- Create wallet transaction record
    INSERT INTO public.wallet_transactions (
        staff_id, type, amount, direction, payment_mode, 
        collection_id, balance_after, gps_lat, gps_lng, sync_status
    )
    SELECT 
        v_staff_id,
        'collection',
        NEW.amount_collected,
        'in',
        v_payment_mode,
        NEW.id,
        CASE WHEN v_is_cash THEN w.cash_in_hand + NEW.amount_collected ELSE w.cash_in_hand END,
        NEW.gps_lat,
        NEW.gps_lng,
        NEW.sync_status
    FROM public.staff_wallet w
    WHERE w.staff_id = v_staff_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_wallet_on_collection_insert
    AFTER INSERT ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_wallet_on_collection();

-- =====================================================
-- FUNCTION: UPDATE LOAN SCHEDULE ON COLLECTION
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_schedule_on_collection()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the loan schedule if linked
    IF NEW.loan_schedule_id IS NOT NULL THEN
        UPDATE public.loan_schedules
        SET 
            is_paid = (NEW.amount_collected >= NEW.amount_expected),
            paid_date = CASE WHEN NEW.amount_collected >= NEW.amount_expected THEN NEW.collection_time ELSE paid_date END
        WHERE id = NEW.loan_schedule_id;
    END IF;
    
    -- Update loan outstanding amount
    IF NEW.loan_id IS NOT NULL THEN
        UPDATE public.loans
        SET 
            outstanding_amount = outstanding_amount - NEW.amount_collected,
            status = CASE 
                WHEN outstanding_amount - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_schedule_on_collection_insert
    AFTER INSERT ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_schedule_on_collection();

-- =====================================================
-- FUNCTION: UPDATE COLLECTION TARGET
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_target_on_collection()
RETURNS TRIGGER AS $$
BEGIN
    -- Update today's target
    UPDATE public.collection_targets
    SET 
        achieved_amount = achieved_amount + NEW.amount_collected,
        achieved_count = achieved_count + 1,
        status = CASE 
            WHEN achieved_amount + NEW.amount_collected >= target_amount THEN 'completed'
            ELSE status
        END
    WHERE staff_id = NEW.staff_id
    AND period_type = 'daily'
    AND target_date = NEW.collection_date;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_target_on_collection_insert
    AFTER INSERT ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_target_on_collection();

-- =====================================================
-- FUNCTION: UPDATE STREAK ON COLLECTION
-- =====================================================
CREATE OR REPLACE FUNCTION public.update_streak_on_collection()
RETURNS TRIGGER AS $$
DECLARE
    v_last_date DATE;
    v_current_streak INTEGER;
BEGIN
    -- Get current streak data
    SELECT last_collection_date, current_streak 
    INTO v_last_date, v_current_streak
    FROM public.staff_streaks 
    WHERE staff_id = NEW.staff_id;
    
    -- Update streak
    UPDATE public.staff_streaks
    SET 
        current_streak = CASE 
            WHEN v_last_date = NEW.collection_date - 1 THEN v_current_streak + 1  -- Consecutive day
            WHEN v_last_date = NEW.collection_date THEN v_current_streak  -- Same day
            ELSE 1  -- Reset streak
        END,
        longest_streak = GREATEST(longest_streak, 
            CASE 
                WHEN v_last_date = NEW.collection_date - 1 THEN v_current_streak + 1
                WHEN v_last_date = NEW.collection_date THEN v_current_streak
                ELSE 1
            END
        ),
        last_collection_date = NEW.collection_date,
        total_collections = total_collections + 1,
        total_amount_collected = total_amount_collected + NEW.amount_collected,
        updated_at = timezone('utc'::text, now())
    WHERE staff_id = NEW.staff_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_streak_on_collection_insert
    AFTER INSERT ON public.collections
    FOR EACH ROW EXECUTE FUNCTION public.update_streak_on_collection();

-- =====================================================
-- HELPER VIEWS
-- =====================================================

-- View: Today's Collection Summary for Staff
CREATE OR REPLACE VIEW public.staff_today_summary AS
SELECT 
    s.id AS staff_id,
    s.full_name,
    s.branch_id,
    b.name AS branch_name,
    s.daily_collection_target,
    COALESCE(SUM(c.amount_collected), 0) AS today_collected,
    COUNT(c.id) AS today_collections_count,
    w.cash_in_hand,
    w.digital_balance,
    w.is_over_limit,
    st.current_streak,
    st.total_collections AS total_collections_lifetime,
    ct.target_amount AS today_target,
    ct.achieved_amount AS today_achieved
FROM public.staff_profiles s
LEFT JOIN public.branches b ON s.branch_id = b.id
LEFT JOIN public.collections c ON c.staff_id = s.id AND c.collection_date = CURRENT_DATE
LEFT JOIN public.staff_wallet w ON w.staff_id = s.id
LEFT JOIN public.staff_streaks st ON st.staff_id = s.id
LEFT JOIN public.collection_targets ct ON ct.staff_id = s.id 
    AND ct.period_type = 'daily' 
    AND ct.target_date = CURRENT_DATE
GROUP BY s.id, s.full_name, s.branch_id, b.name, s.daily_collection_target,
         w.cash_in_hand, w.digital_balance, w.is_over_limit,
         st.current_streak, st.total_collections,
         ct.target_amount, ct.achieved_amount;

-- View: Overdue Loans for Collection
CREATE OR REPLACE VIEW public.overdue_loans_view AS
SELECT 
    l.id AS loan_id,
    l.member_id,
    m.full_name AS member_name,
    m.phone AS member_phone,
    m.area,
    m.gps_lat,
    m.gps_lng,
    l.outstanding_amount,
    ls.id AS schedule_id,
    ls.period,
    ls.due_date,
    ls.emi,
    ls.penalty,
    ls.balance,
    (CURRENT_DATE - ls.due_date::date) AS days_overdue,
    s.id AS staff_id,
    s.full_name AS staff_name
FROM public.loans l
JOIN public.members m ON l.member_id = m.id
JOIN public.loan_schedules ls ON ls.loan_id = l.id
LEFT JOIN public.staff_profiles s ON l.agent_id = s.id
WHERE ls.is_paid = false
AND ls.is_overdue = true
ORDER BY ls.due_date ASC;

-- =====================================================
-- INITIAL SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Insert a default branch
INSERT INTO public.branches (name, code, zone, district, state)
VALUES 
    ('Madhavaram Branch', 'MAD001', 'North Chennai', 'Chennai', 'Tamil Nadu'),
    ('Tondiarpet Branch', 'TON001', 'North Chennai', 'Chennai', 'Tamil Nadu'),
    ('Anna Nagar Branch', 'ANN001', 'Central Chennai', 'Chennai', 'Tamil Nadu')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- END OF STAFF PORTAL SCHEMA
-- =====================================================
