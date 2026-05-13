-- =====================================================
-- SUPER ADMIN PORTAL SCHEMA
-- Platform-wide management and analytics
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- =====================================================
-- PLATFORM ANALYTICS TABLES
-- =====================================================

-- Platform-wide daily metrics (aggregated)
CREATE TABLE IF NOT EXISTS public.platform_daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_date DATE NOT NULL UNIQUE,
    total_organizations INTEGER DEFAULT 0,
    active_organizations INTEGER DEFAULT 0,
    total_users INTEGER DEFAULT 0,
    active_users INTEGER DEFAULT 0,
    total_branches INTEGER DEFAULT 0,
    total_members INTEGER DEFAULT 0,
    total_loans INTEGER DEFAULT 0,
    total_loan_amount DECIMAL(18,2) DEFAULT 0,
    total_collections DECIMAL(18,2) DEFAULT 0,
    total_savings DECIMAL(18,2) DEFAULT 0,
    new_registrations INTEGER DEFAULT 0,
    mrr DECIMAL(12,2) DEFAULT 0, -- Monthly Recurring Revenue
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Platform real-time activity
CREATE TABLE IF NOT EXISTS public.platform_activity_feed (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    activity_type VARCHAR(50) NOT NULL, -- 'login', 'collection', 'loan_disbursed', etc.
    activity_data JSONB DEFAULT '{}',
    branch_id UUID,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for fast queries
CREATE INDEX IF NOT EXISTS idx_platform_activity_date ON public.platform_activity_feed(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_platform_activity_type ON public.platform_activity_feed(activity_type);
CREATE INDEX IF NOT EXISTS idx_platform_activity_org ON public.platform_activity_feed(org_id);

-- =====================================================
-- ORGANIZATION HEALTH SCORING
-- =====================================================

-- Organization health metrics (calculated daily)
CREATE TABLE IF NOT EXISTS public.organization_health_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    score_date DATE NOT NULL,
    overall_score INTEGER DEFAULT 0, -- 0-100
    collection_efficiency_score INTEGER DEFAULT 0,
    member_growth_score INTEGER DEFAULT 0,
    staff_productivity_score INTEGER DEFAULT 0,
    financial_health_score INTEGER DEFAULT 0,
    compliance_score INTEGER DEFAULT 0,
    metrics JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(org_id, score_date)
);

-- =====================================================
-- FEATURE FLAGS
-- =====================================================

-- Platform feature flags
CREATE TABLE IF NOT EXISTS public.feature_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    is_enabled BOOLEAN DEFAULT false,
    rollout_percentage INTEGER DEFAULT 100, -- 0-100
    target_orgs UUID[] DEFAULT '{}', -- Empty = all orgs
    target_roles VARCHAR[] DEFAULT '{}', -- Empty = all roles
    config JSONB DEFAULT '{}',
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Feature flag usage tracking
CREATE TABLE IF NOT EXISTS public.feature_flag_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    flag_id UUID REFERENCES public.feature_flags(id) ON DELETE CASCADE,
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PLATFORM ANNOUNCEMENTS
-- =====================================================

-- Platform-wide announcements
CREATE TABLE IF NOT EXISTS public.platform_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(300) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'info', -- 'info', 'warning', 'critical', 'maintenance'
    target_audience VARCHAR(50) DEFAULT 'all', -- 'all', 'admins', 'managers', 'agents'
    target_orgs UUID[] DEFAULT '{}', -- Empty = all orgs
    is_active BOOLEAN DEFAULT true,
    show_from TIMESTAMP WITH TIME ZONE,
    show_until TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Announcement reads
CREATE TABLE IF NOT EXISTS public.announcement_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID REFERENCES public.platform_announcements(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(announcement_id, user_id)
);

-- =====================================================
-- SYSTEM AUDIT LOGS
-- =====================================================

-- Comprehensive audit trail
CREATE TABLE IF NOT EXISTS public.system_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    action VARCHAR(100) NOT NULL, -- 'create', 'update', 'delete', 'login', 'export', etc.
    entity_type VARCHAR(100) NOT NULL, -- 'organization', 'user', 'loan', 'branch', etc.
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_date ON public.system_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_org ON public.system_audit_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.system_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.system_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.system_audit_logs(entity_type, entity_id);

-- =====================================================
-- API USAGE TRACKING
-- =====================================================

-- API usage analytics
CREATE TABLE IF NOT EXISTS public.api_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    endpoint VARCHAR(500) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    request_size INTEGER,
    response_size INTEGER,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_api_usage_date ON public.api_usage_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_api_usage_org ON public.api_usage_logs(org_id);
CREATE INDEX IF NOT EXISTS idx_api_usage_endpoint ON public.api_usage_logs(endpoint);

-- =====================================================
-- ERROR LOGGING
-- =====================================================

-- System error logs
CREATE TABLE IF NOT EXISTS public.system_error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    error_type VARCHAR(100) NOT NULL,
    error_message TEXT,
    stack_trace TEXT,
    context JSONB DEFAULT '{}',
    resolved BOOLEAN DEFAULT false,
    resolved_by UUID REFERENCES auth.users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- SUPPORT TICKETS
-- =====================================================

-- Support ticket system
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    user_id UUID REFERENCES auth.users(id),
    subject VARCHAR(300) NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'general', -- 'technical', 'billing', 'feature_request', 'general'
    priority VARCHAR(20) DEFAULT 'normal', -- 'low', 'normal', 'high', 'critical'
    status VARCHAR(20) DEFAULT 'open', -- 'open', 'in_progress', 'waiting_customer', 'resolved', 'closed'
    assigned_to UUID REFERENCES auth.users(id),
    messages JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE
);

-- =====================================================
-- MAINTENANCE MODE
-- =====================================================

-- Maintenance scheduling
CREATE TABLE IF NOT EXISTS public.maintenance_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(300) NOT NULL,
    description TEXT,
    scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_end TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT false,
    affected_services TEXT[] DEFAULT '{}', -- 'api', 'web', 'mobile'
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PLATFORM SETTINGS
-- =====================================================

-- Platform-wide settings
CREATE TABLE IF NOT EXISTS public.platform_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false, -- Can be accessed by non-super-admins
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default platform settings
INSERT INTO public.platform_settings (key, value, description, is_public) VALUES
('platform_name', '"MicroFlow Pro"', 'Platform display name', true),
('platform_tagline', '"Micro-Finance Management Platform"', 'Platform tagline', true),
('support_email', '"support@microflowpro.com"', 'Support email address', true),
('max_organizations_per_plan', '{"free": 1, "starter": 1, "professional": 3, "enterprise": 10}', 'Max organizations per plan', false),
('max_branches_per_plan', '{"free": 1, "starter": 3, "professional": 10, "enterprise": 50}', 'Max branches per organization', false),
('max_users_per_plan', '{"free": 5, "starter": 20, "professional": 100, "enterprise": 500}', 'Max users per organization', false),
('default_interest_rate', '12.0', 'Default annual interest rate (%)', true),
('late_payment_penalty', '2.0', 'Late payment penalty rate (%)', true),
('grace_period_days', '7', 'Grace period for EMI payments (days)', true)
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- REVENUE ANALYTICS
-- =====================================================

-- Revenue tracking
CREATE TABLE IF NOT EXISTS public.platform_revenue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id),
    subscription_id UUID,
    amount DECIMAL(12,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50),
    gateway_transaction_id VARCHAR(200),
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'completed', 'failed', 'refunded'
    invoice_number VARCHAR(100),
    invoice_url TEXT,
    period_start DATE,
    period_end DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = user_id
        AND role = 'superAdmin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get platform metrics
CREATE OR REPLACE FUNCTION public.get_platform_metrics()
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_organizations', (SELECT COUNT(*) FROM public.organizations),
        'active_organizations', (SELECT COUNT(*) FROM public.organizations WHERE status = 'active'),
        'total_users', (SELECT COUNT(*) FROM public.profiles),
        'active_users', (SELECT COUNT(DISTINCT user_id) FROM public.platform_activity_feed WHERE created_at > NOW() - INTERVAL '30 days'),
        'total_branches', (SELECT COUNT(*) FROM public.branches),
        'total_members', (SELECT COUNT(*) FROM public.members),
        'total_loans', (SELECT COUNT(*) FROM public.loans),
        'total_loan_amount', (SELECT COALESCE(SUM(loan_amount), 0) FROM public.loans),
        'total_collections', (SELECT COALESCE(SUM(amount), 0) FROM public.collections WHERE status = 'completed'),
        'total_savings', (SELECT COALESCE(SUM(current_balance), 0) FROM public.savings_accounts),
        'mrr', (SELECT COALESCE(SUM(amount), 0) FROM public.platform_revenue WHERE status = 'completed' AND created_at > NOW() - INTERVAL '30 days')
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get organization health
CREATE OR REPLACE FUNCTION public.calculate_org_health(org_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    health_score INTEGER := 0;
    collection_score INTEGER := 0;
    growth_score INTEGER := 0;
    productivity_score INTEGER := 0;
BEGIN
    -- Collection efficiency (40% weight)
    SELECT COALESCE(
        (SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100),
        0
    )::INTEGER INTO collection_score
    FROM public.collections
    WHERE org_id = org_uuid
    AND created_at > NOW() - INTERVAL '30 days';
    
    -- Member growth (30% weight)
    SELECT COALESCE(
        LEAST(100, (COUNT(*)::FLOAT / 100) * 100),
        0
    )::INTEGER INTO growth_score
    FROM public.members
    WHERE org_id = org_uuid;
    
    -- Staff productivity (30% weight)
    SELECT COALESCE(
        (AVG(daily_collections)::FLOAT / 10) * 100,
        0
    )::INTEGER INTO productivity_score
    FROM (
        SELECT COUNT(*) as daily_collections
        FROM public.collections
        WHERE org_id = org_uuid
        AND created_at > NOW() - INTERVAL '30 days'
        GROUP BY DATE(created_at)
    ) daily_stats;
    
    -- Calculate weighted average
    health_score := (collection_score * 0.4 + growth_score * 0.3 + productivity_score * 0.3)::INTEGER;
    
    RETURN LEAST(100, GREATEST(0, health_score));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.platform_daily_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_health_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flag_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_revenue ENABLE ROW LEVEL SECURITY;

-- Super admin can access everything
CREATE POLICY "Super admins have full access to platform metrics"
    ON public.platform_daily_metrics FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins have full access to platform activity"
    ON public.platform_activity_feed FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins have full access to org health scores"
    ON public.organization_health_scores FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage feature flags"
    ON public.feature_flags FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage platform announcements"
    ON public.platform_announcements FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins can view all audit logs"
    ON public.system_audit_logs FOR SELECT
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins can view all API usage"
    ON public.api_usage_logs FOR SELECT
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage error logs"
    ON public.system_error_logs FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage support tickets"
    ON public.support_tickets FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage maintenance windows"
    ON public.maintenance_windows FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins manage platform settings"
    ON public.platform_settings FOR ALL
    USING (is_super_admin(auth.uid()));

CREATE POLICY "Super admins view all revenue"
    ON public.platform_revenue FOR ALL
    USING (is_super_admin(auth.uid()));

-- Public settings can be read by authenticated users
CREATE POLICY "Authenticated users can read public platform settings"
    ON public.platform_settings FOR SELECT
    USING (is_public = true AND auth.uid() IS NOT NULL);

-- Active announcements can be read by authenticated users
CREATE POLICY "Authenticated users can read active announcements"
    ON public.platform_announcements FOR SELECT
    USING (is_active = true AND auth.uid() IS NOT NULL);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_platform_metrics_date ON public.platform_daily_metrics(metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_org_health_org ON public.organization_health_scores(org_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_revenue_status ON public.platform_revenue(status);
CREATE INDEX IF NOT EXISTS idx_revenue_date ON public.platform_revenue(created_at DESC);

-- =====================================================
-- END OF SUPER ADMIN SCHEMA
-- =====================================================
