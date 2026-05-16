-- Supabase Database Schema for MicroFlow Pro
-- Run this in your Supabase SQL Editor to set up the required tables.

-- 1. Members Table
CREATE TABLE IF NOT EXISTS public.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    member_id TEXT UNIQUE NOT NULL,
    kyc_status TEXT DEFAULT 'pending' CHECK (kyc_status IN ('verified', 'pending', 'rejected')),
    active_loans INTEGER DEFAULT 0,
    total_savings DECIMAL(12,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Loans Table
CREATE TABLE IF NOT EXISTS public.loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    member_name TEXT NOT NULL,
    principal DECIMAL(12,2) NOT NULL,
    outstanding_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL,
    tenure_months INTEGER NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'monthly',
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'underReview', 'approved', 'rejected', 'active', 'defaultStatus', 'closed')),
    risk_category TEXT DEFAULT 'standard' CHECK (risk_category IN ('standard', 'subStandard', 'doubtful', 'loss')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    approved_at TIMESTAMP WITH TIME ZONE,
    disbursed_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    remarks TEXT
);

-- 3. Savings Table
CREATE TABLE IF NOT EXISTS public.savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.members(id) ON DELETE CASCADE,
    member_name TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    target_amount DECIMAL(12,2) NOT NULL,
    current_amount DECIMAL(12,2) DEFAULT 0.00,
    monthly_deposit DECIMAL(12,2) DEFAULT 0.00,
    interest_rate DECIMAL(5,2) DEFAULT 0.00,
    maturity_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'withdrawn')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Transactions Table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id UUID REFERENCES public.members(id) ON DELETE SET NULL,
    member_name TEXT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'loanDisbursement',
        'emiPayment',
        'savingsDeposit',
        'savingsWithdrawal',
        'penalty',
        'staffCashDeposit',
        'other',
        'collection',
        'deposit',
        'withdrawal'
    )),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Loan Schedules Table
CREATE TABLE IF NOT EXISTS public.loan_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID REFERENCES public.loans(id) ON DELETE CASCADE,
    period INTEGER NOT NULL,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    emi DECIMAL(12,2) NOT NULL,
    principal DECIMAL(12,2) NOT NULL,
    interest DECIMAL(12,2) NOT NULL,
    balance DECIMAL(12,2) NOT NULL,
    is_paid BOOLEAN DEFAULT false,
    is_overdue BOOLEAN DEFAULT false,
    paid_date TIMESTAMP WITH TIME ZONE,
    penalty DECIMAL(12,2) DEFAULT 0.00
);
