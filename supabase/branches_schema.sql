-- =======================================
-- BRANCHES SCHEMA
-- MicroFlow Pro - Multi-Branch Support
-- =======================================

-- Branches Table
CREATE TABLE IF NOT EXISTS public.branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    pincode TEXT,
    phone TEXT,
    email TEXT,
    manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'closed')),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    operating_hours JSONB DEFAULT '{"open": "09:00", "close": "18:00", "days": ["mon","tue","wed","thu","fri","sat"]}'::jsonb,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    UNIQUE(org_id, code)
);

-- Add branch_id to profiles table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'branch_id') THEN
        ALTER TABLE public.profiles ADD COLUMN branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add branch_id to members table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'members' AND column_name = 'branch_id') THEN
        ALTER TABLE public.members ADD COLUMN branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_branches_org ON public.branches(org_id);
CREATE INDEX IF NOT EXISTS idx_branches_manager ON public.branches(manager_id);
CREATE INDEX IF NOT EXISTS idx_profiles_branch ON public.profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_members_branch ON public.members(branch_id);

-- RLS Policies for branches
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY branches_select ON public.branches FOR SELECT
    USING (org_id = public.get_user_org_id());

CREATE POLICY branches_insert ON public.branches FOR INSERT
    WITH CHECK (org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'executiveAdmin'));

CREATE POLICY branches_update ON public.branches FOR UPDATE
    USING (org_id = public.get_user_org_id()
        AND public.get_user_role() IN ('admin', 'executiveAdmin', 'manager'));

CREATE POLICY branches_delete ON public.branches FOR DELETE
    USING (org_id = public.get_user_org_id()
        AND public.get_user_role() IN ('admin', 'executiveAdmin'));

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_branches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER branches_updated_at
    BEFORE UPDATE ON public.branches
    FOR EACH ROW
    EXECUTE FUNCTION update_branches_updated_at();

-- Function to get branch stats
CREATE OR REPLACE FUNCTION get_branch_stats(p_branch_id UUID)
RETURNS TABLE (
    total_staff INTEGER,
    total_members INTEGER,
    total_loans INTEGER,
    total_savings DECIMAL,
    active_loans DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM public.profiles WHERE branch_id = p_branch_id)::INTEGER,
        (SELECT COUNT(*) FROM public.members WHERE branch_id = p_branch_id)::INTEGER,
        (SELECT COUNT(*) FROM public.loans l 
         JOIN public.members m ON l.member_id = m.id 
         WHERE m.branch_id = p_branch_id)::INTEGER,
        COALESCE((SELECT SUM(amount) FROM public.savings s 
         JOIN public.members m ON s.member_id = m.id 
         WHERE m.branch_id = p_branch_id), 0)::DECIMAL,
        COALESCE((SELECT SUM(outstanding_balance) FROM public.loans l 
         JOIN public.members m ON l.member_id = m.id 
         WHERE m.branch_id = p_branch_id AND l.status = 'active'), 0)::DECIMAL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Comment
COMMENT ON TABLE public.branches IS 'Branch offices for each organization';
COMMENT ON COLUMN public.branches.code IS 'Unique branch code within the organization';
COMMENT ON COLUMN public.branches.manager_id IS 'Reference to the branch manager profile';
