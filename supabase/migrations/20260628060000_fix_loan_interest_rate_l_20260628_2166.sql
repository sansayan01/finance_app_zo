-- ============================================================================
-- Migration: 20260628060000_fix_loan_interest_rate_l_20260628_2166.sql
--
-- Purpose:
--   Fix an obviously wrong interest_rate value on a single loan
--   in staging for the Test Customer. The stored rate (10138.89) was
--   inconsistent with the rest of the loan math:
--
--     principal        = 50000.00
--     interest_amount  = 10000.00  (flat, on principal)
--     interest_rate    = should be (10000 / 50000) * 100 = 20.00
--
--   This file is idempotent and only touches the loan with number
--   'L-20260628-2166'. It is safe to re-apply.
-- ============================================================================

UPDATE public.loans
   SET interest_rate = 20.00,
       updated_at    = NOW()
 WHERE loan_number  = 'L-20260628-2166'
   AND interest_rate <> 20.00;
