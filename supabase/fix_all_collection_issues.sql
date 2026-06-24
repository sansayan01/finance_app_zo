-- =====================================================
-- COMPLETE DATABASE SCHEMA FIX FOR COLLECTION SYSTEM
-- Run this in Supabase SQL Editor to fix all schema issues
-- =====================================================

-- 1. Fix transactions table type constraint to accept all needed values
ALTER TABLE public.transactions 
DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions 
ADD CONSTRAINT transactions_type_check 
CHECK (type IN (
  'emiCollection', 'loanDisbursement', 'savingsDeposit', 
  'savingsWithdrawal', 'penalty', 'staffCashDeposit', 
  'other', 'collection', 'deposit', 'withdrawal', 'emiPayment'
));

-- 2. Add missing columns to transactions table
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS staff_id UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS payment_mode TEXT;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS reference_number TEXT;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS transaction_date DATE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS transaction_time TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS sync_status TEXT DEFAULT 'synced';

ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Add transaction_id to collections table if it doesn't exist
ALTER TABLE public.collections 
ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_collections_transaction_id ON public.collections(transaction_id);

-- 3. Add missing columns to loans table
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

-- 4. Create emi_schedule table if it doesn't exist
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
    status TEXT DEFAULT 'upcoming',
    is_paid BOOLEAN DEFAULT false,
    paid_date TIMESTAMP WITH TIME ZONE,
    paid_on TIMESTAMP WITH TIME ZONE,
    payment_mode TEXT,
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

-- 5. Enable RLS on all tables
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emi_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;

-- 6. Drop and recreate RLS policies for transactions
DROP POLICY IF EXISTS transactions_select ON public.transactions;
DROP POLICY IF EXISTS transactions_insert ON public.transactions;
DROP POLICY IF EXISTS transactions_update ON public.transactions;
DROP POLICY IF EXISTS transactions_delete ON public.transactions;
DROP POLICY IF EXISTS org_select ON public.transactions;
DROP POLICY IF EXISTS org_insert ON public.transactions;
DROP POLICY IF EXISTS org_update ON public.transactions;
DROP POLICY IF EXISTS org_delete ON public.transactions;

CREATE POLICY transactions_select ON public.transactions 
FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY transactions_insert ON public.transactions 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY transactions_update ON public.transactions 
FOR UPDATE USING (org_id = public.get_user_org_id());

CREATE POLICY transactions_delete ON public.transactions 
FOR DELETE USING (org_id = public.get_user_org_id());

-- 7. Drop and recreate RLS policies for emi_schedule
DROP POLICY IF EXISTS emi_schedule_select ON public.emi_schedule;
DROP POLICY IF EXISTS emi_schedule_insert ON public.emi_schedule;
DROP POLICY IF EXISTS emi_schedule_update ON public.emi_schedule;
DROP POLICY IF EXISTS emi_schedule_delete ON public.emi_schedule;

CREATE POLICY emi_schedule_select ON public.emi_schedule 
FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY emi_schedule_insert ON public.emi_schedule 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY emi_schedule_update ON public.emi_schedule 
FOR UPDATE USING (org_id = public.get_user_org_id());

CREATE POLICY emi_schedule_delete ON public.emi_schedule 
FOR DELETE USING (org_id = public.get_user_org_id());

-- 8. Drop and recreate RLS policies for loans
DROP POLICY IF EXISTS loans_select ON public.loans;
DROP POLICY IF EXISTS loans_insert ON public.loans;
DROP POLICY IF EXISTS loans_update ON public.loans;
DROP POLICY IF EXISTS loans_delete ON public.loans;
DROP POLICY IF EXISTS org_select ON public.loans;
DROP POLICY IF EXISTS org_insert ON public.loans;
DROP POLICY IF EXISTS org_update ON public.loans;
DROP POLICY IF EXISTS org_delete ON public.loans;

CREATE POLICY loans_select ON public.loans 
FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY loans_insert ON public.loans 
FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

CREATE POLICY loans_update ON public.loans 
FOR UPDATE USING (org_id = public.get_user_org_id());

CREATE POLICY loans_delete ON public.loans 
FOR DELETE USING (org_id = public.get_user_org_id());

-- 9. Create helper function for safe loan deletion
CREATE OR REPLACE FUNCTION public.delete_loan_safely(p_loan_id UUID, p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Delete transactions first
  DELETE FROM public.transactions WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Delete EMI schedules
  DELETE FROM public.emi_schedule WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Nullify loan_id in collections
  UPDATE public.collections SET loan_id = NULL WHERE loan_id = p_loan_id AND org_id = p_org_id;
  
  -- Delete the loan
  DELETE FROM public.loans WHERE id = p_loan_id AND org_id = p_org_id;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  
  RETURN v_count > 0;
END;
$$;

-- 10. Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_transactions_org ON public.transactions(org_id);
CREATE INDEX IF NOT EXISTS idx_transactions_loan ON public.transactions(loan_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_loans_org ON public.loans(org_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_customer ON public.loans(customer_id);
