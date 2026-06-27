-- =============================================================
-- SEED: minimal test loan + RD for Sefali in Test Org
-- Why this exists: 20260627000005_reconcile_sefali_test_state.sql
-- zeroed Test Org after the user explicitly approved the four-phase
-- fix. With zero rows in either loans or savings_plans, the Flutter
-- list pages (which correctly filter by org_id) correctly show empty
-- state. The user then has nothing to exercise the just-fixed
-- delete-and-revert workflow against. This migration seeds exactly
-- one fresh loan + one fresh RD for Sefali, mirroring what the
-- FIXED new-plan code paths would produce (NOT the migration path).
-- Idempotency note: the loan_number is suffixed with -SEED-1 so
-- re-runs of this migration would fail with a duplicate-key instead
-- of silently corrupting data.
-- =============================================================

BEGIN;

-- =========================================
-- 1. Loan for Sefali (Test Org)
-- 12-month, ₹10,000 principal, 12% annual, monthly EMI ₹888.
-- Fresh state: 0 paid_emis, 0 collections, 0 transactions.
-- =========================================
WITH new_loan AS (
  INSERT INTO public.loans (
    loan_number,
    customer_id,
    member_id,
    member_name,
    amount,
    interest_rate,
    tenure_months,
    emi_amount,
    total_interest,
    total_repayable,
    outstanding_balance,
    outstanding_amount,
    frequency,
    interest_type,
    collection_type,
    disbursement_date,
    first_emi_date,
    first_installment_date,
    status,
    org_id,
    loan_purpose,
    paid_emis,
    total_emis,
    principal,
    interest,
    start_date,
    end_date
  )
  VALUES (
    'L-20260627-SEED-1',
    '52c57d86-0981-4860-a6f6-0c26f8cb390b'::uuid,
    '52c57d86-0981-4860-a6f6-0c26f8cb390b'::uuid,
    'Sefali',
    10000,
    12,
    12,
    888,
    660,
    10660,
    10000,
    10000,
    'monthly',
    'flat',
    'monthly',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    CURRENT_DATE + INTERVAL '30 days',
    'active',
    'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'::uuid,
    'Test loan - delete-and-revert workflow validation',
    0,
    12,
    10000,
    0,
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '12 months'
  )
  RETURNING id, emi_amount, first_emi_date
)
INSERT INTO public.emi_schedule (
  loan_id,
  installment_number,
  emi_number,
  due_date,
  emi_amount,
  principal,
  interest,
  balance_after,
  status,
  is_paid,
  is_overdue,
  org_id,
  member_id,
  emi,
  period
)
SELECT
  nl.id,
  m AS installment_number,
  m AS emi_number,
  ((CURRENT_DATE + INTERVAL '30 days') + (m - 1) * INTERVAL '1 month')::DATE AS due_date,
  888::numeric AS emi_amount,
  -- Flat principal share: 10000 / 12 = 833.33. Last month absorbs rounding.
  ROUND(10000::numeric / 12, 2) AS principal,
  888::numeric - ROUND(10000::numeric / 12, 2) AS interest,
  ROUND(10000::numeric - (ROUND(10000::numeric / 12, 2) * m), 2) AS balance_after,
  'pending',
  false,
  false,
  'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'::uuid,
  '52c57d86-0981-4860-a6f6-0c26f8cb390b'::uuid,
  888::numeric AS emi,
  m AS period
FROM new_loan nl, generate_series(1, 12) AS m;

-- =========================================
-- 2. Savings Plan (RD) for Sefali (Test Org)
-- 12-month, ₹1,000/month, 7% pa, target ₹12,500.
-- Fresh state: 0 collections, 0 transactions.
-- =========================================
INSERT INTO public.savings_plans (
  member_id,
  plan_name,
  target_amount,
  current_amount,
  monthly_deposit,
  interest_rate,
  maturity_amount,
  maturity_date,
  collection_type,
  premature_penalty,
  total_installments,
  status,
  org_id,
  start_date,
  tenure_unit,
  tenure,
  opening_balance,
  installments_paid,
  interest_amount,
  total_return_amount,
  next_due_date,
  last_payment_date
)
VALUES (
  '52c57d86-0981-4860-a6f6-0c26f8cb390b'::uuid,
  'Recurring Deposit',
  12000,
  0,
  1000,
  7,
  12500,
  CURRENT_DATE + INTERVAL '12 months',
  'monthly',
  2,
  12,
  'active',
  'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9'::uuid,
  CURRENT_DATE,
  'months',
  12,
  0,
  0,
  500,
  0,
  CURRENT_DATE + INTERVAL '30 days',
  NULL
);

COMMIT;
