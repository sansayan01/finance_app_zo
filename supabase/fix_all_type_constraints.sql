-- =====================================================
-- COMPREHENSIVE TYPE CONSTRAINT FIX
-- Fixes all CHECK constraint mismatches between app code and database
-- Run this ONCE in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. FIX: transactions.type constraint
-- =====================================================
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check 
CHECK (type IN (
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
));

-- Migrate legacy type values
UPDATE public.transactions SET type = 'emiPayment' WHERE type IN ('emiCollection', 'emi_payment');

-- =====================================================
-- 2. FIX: wallet_transactions.type constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'wallet_transactions_type_check'
    ) THEN
        ALTER TABLE public.wallet_transactions DROP CONSTRAINT wallet_transactions_type_check;
    END IF;
END $$;

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check 
CHECK (type IN (
    'collection',
    'deposit',
    'withdrawal',
    'adjustment',
    'refund'
));

-- =====================================================
-- 3. FIX: collections.collection_type constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'collections_collection_type_check'
    ) THEN
        ALTER TABLE public.collections DROP CONSTRAINT collections_collection_type_check;
    END IF;
END $$;

ALTER TABLE public.collections ADD CONSTRAINT collections_collection_type_check 
CHECK (collection_type IN (
    'emi',
    'overdue',
    'advance',
    'partial',
    'savings',
    'loan',
    'penalty',
    'other'
));

-- =====================================================
-- 4. FIX: staff_notifications.type constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'staff_notifications_type_check'
    ) THEN
        ALTER TABLE public.staff_notifications DROP CONSTRAINT staff_notifications_type_check;
    END IF;
END $$;

ALTER TABLE public.staff_notifications ADD CONSTRAINT staff_notifications_type_check 
CHECK (type IN (
    'info',
    'warning',
    'success',
    'error',
    'system',
    'reminder',
    'alert',
    'target',
    'overdue',
    'sync'
));

-- =====================================================
-- 5. FIX: collections.payment_mode constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'collections_payment_mode_check'
    ) THEN
        ALTER TABLE public.collections DROP CONSTRAINT collections_payment_mode_check;
    END IF;
END $$;

ALTER TABLE public.collections ADD CONSTRAINT collections_payment_mode_check 
CHECK (payment_mode IN (
    'cash',
    'upi',
    'bankTransfer',
    'bank',
    'cheque',
    'card',
    'adjustment',
    'other'
));

-- =====================================================
-- 6. FIX: wallet_transactions.direction constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'wallet_transactions_direction_check'
    ) THEN
        ALTER TABLE public.wallet_transactions DROP CONSTRAINT wallet_transactions_direction_check;
    END IF;
END $$;

ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_direction_check 
CHECK (direction IN ('in', 'out'));

-- =====================================================
-- 7. FIX: loans.status constraint
-- =====================================================
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'loans_status_check'
    ) THEN
        ALTER TABLE public.loans DROP CONSTRAINT loans_status_check;
    END IF;
END $$;

ALTER TABLE public.loans ADD CONSTRAINT loans_status_check 
CHECK (status IN (
    'draft',
    'pending',
    'approved',
    'active',
    'closed',
    'rejected',
    'defaultStatus',
    'defaulted',
    'restructured'
));

-- =====================================================
-- VERIFICATION
-- =====================================================
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname LIKE '%type_check%' 
   OR conname LIKE '%payment_mode_check%'
ORDER BY conname;
