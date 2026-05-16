-- Fix collection system database schema
-- Run this in Supabase SQL Editor to ensure all required columns exist

-- 1. Add missing columns to transactions table if they don't exist
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card'));

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS reference_number TEXT;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS transaction_date DATE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS transaction_time TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'reversed'));

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS sync_status TEXT DEFAULT 'synced' CHECK (sync_status IN ('pending', 'synced', 'failed'));

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- 2. Add missing columns to loans table
ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS loan_number TEXT;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.members(id) ON DELETE SET NULL;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS emi_amount DECIMAL(12, 2);

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS total_repayable DECIMAL(12, 2);

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS collection_type TEXT;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS interest_type TEXT;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS tenure_value INTEGER;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS tenure_unit TEXT;

ALTER TABLE public.loans 
ADD COLUMN IF NOT EXISTS purpose TEXT;

-- 3. Create emi_schedule table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.emi_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    emi_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    emi_amount DECIMAL(12,2) NOT NULL,
    principal DECIMAL(12,2) NOT NULL,
    interest DECIMAL(12,2) NOT NULL,
    balance_after DECIMAL(12,2) NOT NULL,
    status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'paid', 'overdue', 'defaulted', 'pendingPayment')),
    is_paid BOOLEAN DEFAULT false,
    paid_date TIMESTAMP WITH TIME ZONE,
    paid_on TIMESTAMP WITH TIME ZONE,
    payment_mode TEXT CHECK (payment_mode IN ('cash', 'upi', 'bank_transfer', 'cheque', 'card')),
    amount_paid DECIMAL(12,2) DEFAULT 0,
    transaction_id UUID REFERENCES public.transactions(id),
    penalty_amount DECIMAL(12,2) DEFAULT 0.00,
    penalty_paid BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_emi_schedule_loan ON public.emi_schedule(loan_id);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_due ON public.emi_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_org ON public.emi_schedule(org_id);
CREATE INDEX IF NOT EXISTS idx_emi_schedule_status ON public.emi_schedule(status);

-- 4. Enable RLS on emi_schedule
ALTER TABLE public.emi_schedule ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for emi_schedule
DROP POLICY IF EXISTS emi_schedule_select ON public.emi_schedule;
CREATE POLICY emi_schedule_select ON public.emi_schedule 
FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_insert ON public.emi_schedule;
CREATE POLICY emi_schedule_insert ON public.emi_schedule 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_update ON public.emi_schedule;
CREATE POLICY emi_schedule_update ON public.emi_schedule 
FOR UPDATE USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS emi_schedule_delete ON public.emi_schedule;
CREATE POLICY emi_schedule_delete ON public.emi_schedule 
FOR DELETE USING (org_id = public.get_user_org_id());

-- 6. Ensure RLS policies exist for transactions
DROP POLICY IF EXISTS transactions_select ON public.transactions;
CREATE POLICY transactions_select ON public.transactions 
FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS transactions_insert ON public.transactions;
CREATE POLICY transactions_insert ON public.transactions 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS transactions_update ON public.transactions;
CREATE POLICY transactions_update ON public.transactions 
FOR UPDATE USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS transactions_delete ON public.transactions;
CREATE POLICY transactions_delete ON public.transactions 
FOR DELETE USING (org_id = public.get_user_org_id());

-- 7. Ensure RLS policies exist for loans
DROP POLICY IF EXISTS loans_select ON public.loans;
CREATE POLICY loans_select ON public.loans 
FOR SELECT USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS loans_insert ON public.loans;
CREATE POLICY loans_insert ON public.loans 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS loans_update ON public.loans;
CREATE POLICY loans_update ON public.loans 
FOR UPDATE USING (org_id = public.get_user_org_id());

DROP POLICY IF EXISTS loans_delete ON public.loans;
CREATE POLICY loans_delete ON public.loans 
FOR DELETE USING (org_id = public.get_user_org_id());
