-- =====================================================
-- MULTI-TENANCY MIGRATION
-- MicroFlow Pro - SaaS Scaling
-- =====================================================
-- Run order: base schema → staff schema → this migration
-- =====================================================

-- 1. ORGANIZATIONS TABLE
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    domain TEXT,
    logo_url TEXT,
    primary_color TEXT DEFAULT '#6366F1',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial')),
    max_branches INTEGER DEFAULT 5,
    max_staff INTEGER DEFAULT 20,
    max_members INTEGER DEFAULT 500,
    settings JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. ADD org_id TO ALL EXISTING TABLES
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'org_id') THEN
        ALTER TABLE public.profiles ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'members' AND column_name = 'org_id') THEN
        ALTER TABLE public.members ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'loans' AND column_name = 'org_id') THEN
        ALTER TABLE public.loans ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'emi_schedule' AND column_name = 'org_id') THEN
        ALTER TABLE public.emi_schedule ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'savings' AND column_name = 'org_id') THEN
        ALTER TABLE public.savings ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'savings_plans' AND column_name = 'org_id') THEN
        ALTER TABLE public.savings_plans ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'transactions' AND column_name = 'org_id') THEN
        ALTER TABLE public.transactions ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'activity_logs' AND column_name = 'org_id') THEN
        ALTER TABLE public.activity_logs ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'system_settings' AND column_name = 'org_id') THEN
        ALTER TABLE public.system_settings ADD COLUMN org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 3. SEED DEFAULT ORGANIZATION (for existing data)
INSERT INTO public.organizations (id, name, slug, status, max_branches, max_staff, max_members)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'My MFI', 'my-mfi', 'active', 10, 50, 5000)
ON CONFLICT (slug) DO NOTHING;

UPDATE public.profiles SET org_id = '00000000-0000-0000-0000-000000000001'::uuid WHERE org_id IS NULL;

-- 4. RLS HELPER FUNCTIONS (SECURITY DEFINER to bypass RLS and avoid recursion)
CREATE OR REPLACE FUNCTION public.get_user_org_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(profiles.org_id, '00000000-0000-0000-0000-000000000001'::uuid)
  FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

-- 5. ENABLE RLS ON ALL TABLES (done via migration tool)
-- RLS policies are managed separately in rls_policies.sql

-- 6. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_profiles_org ON public.profiles(org_id);
CREATE INDEX IF NOT EXISTS idx_members_org ON public.members(org_id);
CREATE INDEX IF NOT EXISTS idx_loans_org ON public.loans(org_id);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_org ON public.emi_schedule(org_id);
CREATE INDEX IF NOT EXISTS idx_savings_org ON public.savings(org_id);
CREATE INDEX IF NOT EXISTS idx_savings_plans_org ON public.savings_plans(org_id);
CREATE INDEX IF NOT EXISTS idx_transactions_org ON public.transactions(org_id);
