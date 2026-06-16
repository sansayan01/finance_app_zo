-- =====================================================
-- Add Migration Fields to Savings Plans
-- =====================================================
-- Adds columns needed for tracking migration-related
-- financial data on savings plans: total return amount,
-- interest amount, number of installments paid, and
-- the date of the last payment.
--
-- All columns are added with sensible defaults so
-- existing rows are unaffected and queries that don't
-- use these columns continue to work unchanged.
-- =====================================================

BEGIN;

-- 1) Add migration-related columns to savings_plans.
ALTER TABLE public.savings_plans
    ADD COLUMN IF NOT EXISTS total_return_amount NUMERIC DEFAULT 0;

ALTER TABLE public.savings_plans
    ADD COLUMN IF NOT EXISTS interest_amount NUMERIC DEFAULT 0;

ALTER TABLE public.savings_plans
    ADD COLUMN IF NOT EXISTS installments_paid INTEGER DEFAULT 0;

ALTER TABLE public.savings_plans
    ADD COLUMN IF NOT EXISTS last_payment_date DATE;

-- 2) Index on installments_paid for fast queries that
--    filter or aggregate by payment progress.
CREATE INDEX IF NOT EXISTS savings_plans_installments_paid_idx
    ON public.savings_plans (installments_paid);

COMMIT;
