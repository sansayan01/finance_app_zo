-- Migration: Create loan_products and savings_products tables
-- These tables allow Executive Admins to define reusable product templates

-- ============================================================
-- 1. LOAN PRODUCTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.loan_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  interest_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
  interest_mode TEXT DEFAULT 'reducing' CHECK (interest_mode IN ('flat', 'reducing', 'amount', 'percentage')),
  interest_basis TEXT DEFAULT 'onPrincipal' CHECK (interest_basis IN ('onPrincipal', 'onTotal')),
  min_amount DECIMAL(12,2),
  max_amount DECIMAL(12,2),
  tenure_months INTEGER DEFAULT 12,
  tenure_unit TEXT DEFAULT 'months' CHECK (tenure_unit IN ('months', 'weeks', 'days')),
  frequency TEXT DEFAULT 'monthly' CHECK (frequency IN ('monthly', 'weekly', 'daily')),
  processing_fee DECIMAL(10,2) DEFAULT 0,
  late_penalty_pct DECIMAL(5,2) DEFAULT 0,
  grace_period_days INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.loan_products OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_loan_products_org ON public.loan_products(org_id);

-- RLS for loan_products
ALTER TABLE public.loan_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY loan_products_select ON public.loan_products
  FOR SELECT USING (org_id = public.get_user_org_id() OR public.get_user_role() = 'superAdmin');

CREATE POLICY loan_products_insert ON public.loan_products
  FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY loan_products_update ON public.loan_products
  FOR UPDATE USING (org_id = public.get_user_org_id());

CREATE POLICY loan_products_delete ON public.loan_products
  FOR DELETE USING (org_id = public.get_user_org_id());

-- ============================================================
-- 2. SAVINGS PRODUCTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.savings_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  interest_rate DECIMAL(10,2) DEFAULT 0,
  collection_type TEXT DEFAULT 'monthly' CHECK (collection_type IN ('daily', 'weekly', 'monthly', 'yearly')),
  min_deposit DECIMAL(12,2),
  max_deposit DECIMAL(12,2),
  tenure INTEGER DEFAULT 12,
  tenure_unit TEXT DEFAULT 'months' CHECK (tenure_unit IN ('months', 'weeks', 'days')),
  premature_penalty DECIMAL(10,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.savings_products OWNER TO postgres;

CREATE INDEX IF NOT EXISTS idx_savings_products_org ON public.savings_products(org_id);

-- RLS for savings_products
ALTER TABLE public.savings_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY savings_products_select ON public.savings_products
  FOR SELECT USING (org_id = public.get_user_org_id() OR public.get_user_role() = 'superAdmin');

CREATE POLICY savings_products_insert ON public.savings_products
  FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY savings_products_update ON public.savings_products
  FOR UPDATE USING (org_id = public.get_user_org_id());

CREATE POLICY savings_products_delete ON public.savings_products
  FOR DELETE USING (org_id = public.get_user_org_id());

-- Grants
GRANT ALL ON TABLE public.loan_products TO anon;
GRANT ALL ON TABLE public.loan_products TO authenticated;
GRANT ALL ON TABLE public.loan_products TO service_role;

GRANT ALL ON TABLE public.savings_products TO anon;
GRANT ALL ON TABLE public.savings_products TO authenticated;
GRANT ALL ON TABLE public.savings_products TO service_role;
