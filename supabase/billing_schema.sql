-- =====================================================
-- BILLING & SUBSCRIPTION SCHEMA
-- MicroFlow Pro - SaaS Billing System
-- =====================================================

-- 1. Subscription Plans
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price_monthly DECIMAL(10,2) NOT NULL,
    price_yearly DECIMAL(10,2),
    currency TEXT DEFAULT 'INR',
    max_members INTEGER DEFAULT 100,
    max_branches INTEGER DEFAULT 1,
    max_staff INTEGER DEFAULT 5,
    max_loans INTEGER DEFAULT 50,
    features JSONB DEFAULT '[]'::jsonb,
    stripe_price_id_monthly TEXT,
    stripe_price_id_yearly TEXT,
    is_active BOOLEAN DEFAULT true,
    is_popular BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 2. Organization Subscriptions
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    plan_id TEXT REFERENCES public.subscription_plans(id),
    stripe_customer_id TEXT UNIQUE,
    stripe_subscription_id TEXT UNIQUE,
    billing_cycle TEXT DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'canceled', 'incomplete', 'paused')),
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    trial_start TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN DEFAULT false,
    canceled_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    UNIQUE(org_id)
);

-- 3. Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
    stripe_invoice_id TEXT UNIQUE,
    invoice_number TEXT UNIQUE,
    amount DECIMAL(12,2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    tax_amount DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'paid', 'void', 'uncollectible')),
    invoice_url TEXT,
    invoice_pdf TEXT,
    hosted_invoice_url TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    voided_at TIMESTAMP WITH TIME ZONE,
    lines JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 4. Payment Methods
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    stripe_payment_method_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    type TEXT NOT NULL CHECK (type IN ('card', 'upi', 'bank_transfer', 'netbanking')),
    card_brand TEXT,
    card_last4 TEXT,
    card_exp_month INTEGER,
    card_exp_year INTEGER,
    upi_id TEXT,
    bank_name TEXT,
    bank_last4 TEXT,
    is_default BOOLEAN DEFAULT false,
    is_verified BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 5. Usage Records (for metered billing)
CREATE TABLE IF NOT EXISTS public.usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    resource_type TEXT NOT NULL,
    quantity INTEGER DEFAULT 0,
    unit_price DECIMAL(10,4) DEFAULT 0,
    total_cost DECIMAL(12,2) DEFAULT 0,
    stripe_usage_record_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 6. Billing Events (audit trail)
CREATE TABLE IF NOT EXISTS public.billing_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    stripe_event_id TEXT UNIQUE,
    payload JSONB NOT NULL,
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 7. Discounts & Coupons
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL,
    max_redemptions INTEGER DEFAULT 0,
    redemptions_count INTEGER DEFAULT 0,
    min_amount DECIMAL(10,2) DEFAULT 0,
    max_discount DECIMAL(10,2),
    valid_from TIMESTAMP WITH TIME ZONE,
    valid_until TIMESTAMP WITH TIME ZONE,
    applies_to_plan_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- 8. Referrals
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    referee_org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL,
    referral_code TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'signup', 'paid', 'rewarded', 'expired')),
    reward_type TEXT CHECK (reward_type IN ('credit', 'discount', 'cash')),
    reward_value DECIMAL(10,2),
    reward_granted_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- SEED DEFAULT PLANS
INSERT INTO public.subscription_plans (id, name, description, price_monthly, price_yearly, max_members, max_branches, max_staff, features, is_popular, sort_order) VALUES
('starter', 'Starter', 'Perfect for small MFIs just getting started', 999, 9999, 100, 1, 3, 
 '["Up to 100 members", "1 branch", "3 staff accounts", "Basic analytics", "Email support", "Mobile app access"]'::jsonb, false, 1),
('growth', 'Growth', 'For growing MFIs with multiple branches', 2499, 24999, 500, 5, 15,
 '["Up to 500 members", "5 branches", "15 staff accounts", "Advanced analytics", "Priority email support", "Mobile app access", "API access", "Custom reports"]'::jsonb, true, 2),
('professional', 'Professional', 'For established MFIs with large operations', 4999, 49999, 2000, 15, 50,
 '["Up to 2000 members", "15 branches", "50 staff accounts", "Full analytics suite", "Priority support", "Mobile app access", "Full API access", "Custom reports", "White-label branding", "SSO integration"]'::jsonb, false, 3),
('enterprise', 'Enterprise', 'For large-scale MFI operations', 0, 0, 0, 0, 0,
 '["Unlimited members", "Unlimited branches", "Unlimited staff", "Enterprise analytics", "24/7 dedicated support", "Custom development", "On-premise deployment", "SLA guarantee", "Dedicated account manager"]'::jsonb, false, 4);

-- INDEXES
CREATE INDEX idx_subscriptions_org ON public.subscriptions(org_id);
CREATE INDEX idx_subscriptions_stripe_customer ON public.subscriptions(stripe_customer_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_invoices_org ON public.invoices(org_id);
CREATE INDEX idx_invoices_status ON public.invoices(status);
CREATE INDEX idx_payment_methods_org ON public.payment_methods(org_id);
CREATE INDEX idx_billing_events_org ON public.billing_events(org_id);
CREATE INDEX idx_usage_records_org_period ON public.usage_records(org_id, period_start, period_end);

-- RLS POLICIES
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Plans are public read
CREATE POLICY "Plans are publicly readable" ON public.subscription_plans
    FOR SELECT USING (is_active = true);

-- Subscription policies
CREATE POLICY "Users can view own org subscription" ON public.subscriptions
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Admins can manage subscription" ON public.subscriptions
    FOR ALL USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- Invoice policies
CREATE POLICY "Users can view own org invoices" ON public.invoices
    FOR SELECT USING (org_id = public.get_user_org_id());

-- Payment method policies
CREATE POLICY "Users can view own org payment methods" ON public.payment_methods
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Admins can manage payment methods" ON public.payment_methods
    FOR ALL USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- TRIGGER: Update subscription on org creation
CREATE OR REPLACE FUNCTION public.handle_new_organization()
RETURNS TRIGGER AS $$
BEGIN
    -- Create trial subscription
    INSERT INTO public.subscriptions (org_id, plan_id, status, trial_start, trial_end)
    VALUES (
        NEW.id, 
        'starter', 
        'trialing',
        now(),
        now() + interval '14 days'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_org_created
    AFTER INSERT ON public.organizations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_organization();

-- HELPER: Check subscription limits
CREATE OR REPLACE FUNCTION public.check_subscription_limit(
    p_org_id UUID,
    p_limit_type TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_max_value INTEGER;
    v_current_value INTEGER;
BEGIN
    -- Get plan limits
    SELECT 
        CASE p_limit_type
            WHEN 'members' THEN sp.max_members
            WHEN 'branches' THEN sp.max_branches
            WHEN 'staff' THEN sp.max_staff
            WHEN 'loans' THEN sp.max_loans
            ELSE 0
        END
    INTO v_max_value
    FROM public.subscriptions s
    JOIN public.subscription_plans sp ON s.plan_id = sp.id
    WHERE s.org_id = p_org_id AND s.status IN ('active', 'trialing');
    
    -- If no subscription or plan, deny
    IF v_max_value IS NULL THEN
        RETURN false;
    END IF;
    
    -- Get current usage
    SELECT 
        CASE p_limit_type
            WHEN 'members' THEN (SELECT COUNT(*) FROM public.members WHERE org_id = p_org_id)
            WHEN 'branches' THEN (SELECT COUNT(*) FROM public.branches WHERE org_id = p_org_id)
            WHEN 'staff' THEN (SELECT COUNT(*) FROM public.staff_profiles WHERE org_id = p_org_id)
            WHEN 'loans' THEN (SELECT COUNT(*) FROM public.loans WHERE org_id = p_org_id)
            ELSE 0
        END
    INTO v_current_value;
    
    -- Enterprise plan has unlimited (0 = unlimited)
    IF v_max_value = 0 THEN
        RETURN true;
    END IF;
    
    RETURN v_current_value < v_max_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- HELPER: Get subscription status
CREATE OR REPLACE FUNCTION public.get_subscription_status(p_org_id UUID)
RETURNS TABLE (
    plan_id TEXT,
    plan_name TEXT,
    status TEXT,
    trial_end TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    members_used INTEGER,
    members_limit INTEGER,
    branches_used INTEGER,
    branches_limit INTEGER,
    staff_used INTEGER,
    staff_limit INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sp.id,
        sp.name,
        s.status,
        s.trial_end,
        s.current_period_end,
        (SELECT COUNT(*) FROM public.members WHERE org_id = p_org_id)::INTEGER,
        sp.max_members,
        (SELECT COUNT(*) FROM public.branches WHERE org_id = p_org_id)::INTEGER,
        sp.max_branches,
        (SELECT COUNT(*) FROM public.staff_profiles WHERE org_id = p_org_id)::INTEGER,
        sp.max_staff
    FROM public.subscriptions s
    JOIN public.subscription_plans sp ON s.plan_id = sp.id
    WHERE s.org_id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- END OF BILLING SCHEMA
-- =====================================================
