-- Fix transaction type constraint to align with application enums
-- This adds 'emiPayment' and other missing types to the check constraint

-- 1. Drop the existing constraint
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

-- 2. Add the new comprehensive constraint
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

-- 3. Update any existing 'emiCollection' or 'emi_payment' records to 'emiPayment'
UPDATE public.transactions SET type = 'emiPayment' WHERE type IN ('emiCollection', 'emi_payment');
