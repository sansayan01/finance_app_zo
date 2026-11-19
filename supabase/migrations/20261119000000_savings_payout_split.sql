-- ============================================================
-- Savings payout split: principal vs interest
-- ------------------------------------------------------------
-- Problem this fixes
--   1. The app recorded money coming IN (savings_collections) but never
--      recorded how much PRINCIPAL vs INTEREST was handed back OUT.
--   2. `savings_plans.interest_amount` was never written, so the promised
--      interest showed as 0 everywhere after the create form closed.
--   3. A customer could be paid interest twice: once on a premature
--      withdrawal and again at maturity, because nothing tracked it.
--
-- Result:
--   transactions.principal_amount / interest_amount -> exact split per payout
--   savings_plans.interest_paid                     -> cumulative interest given
-- ============================================================

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS principal_amount numeric(12,2),
  ADD COLUMN IF NOT EXISTS interest_amount  numeric(12,2);

ALTER TABLE public.savings_plans
  ADD COLUMN IF NOT EXISTS interest_paid numeric(12,2) DEFAULT 0;

-- Existing deposits/withdrawals were recorded as pure principal with no
-- interest component, so backfill them that way.
UPDATE public.transactions
SET principal_amount = amount,
    interest_amount  = 0
WHERE principal_amount IS NULL
  AND type IN ('savingsDeposit', 'savingsWithdrawal', 'withdrawal');

-- Seed the cumulative counter from any withdrawal that did carry interest
-- (zero for all historical rows, but keeps the counter correct if this
-- migration is re-run after the app starts writing splits).
UPDATE public.savings_plans sp
SET interest_paid = COALESCE((
  SELECT sum(t.interest_amount)
  FROM public.transactions t
  WHERE t.savings_id = sp.id
    AND t.type = 'savingsWithdrawal'
    AND t.interest_amount IS NOT NULL
    AND t.interest_amount > 0
), 0)
WHERE COALESCE(sp.interest_paid, 0) = 0;

-- Backfill the promised interest for existing vaults using the same rule the
-- app uses: interest = maturity_amount - (opening_balance + installment x total).
UPDATE public.savings_plans
SET interest_amount =
  GREATEST(0, COALESCE(maturity_amount, 0)
    - (COALESCE(opening_balance, 0)
       + (COALESCE(monthly_deposit, 0) * COALESCE(total_installments, 0))))
WHERE COALESCE(interest_amount, 0) = 0
  AND COALESCE(maturity_amount, 0) > 0;
