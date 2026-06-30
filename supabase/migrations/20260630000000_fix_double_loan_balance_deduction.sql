-- ============================================================================
-- Migration: 20260630000000_fix_double_loan_balance_deduction.sql
--
-- Root cause:
--   The SQL trigger `update_schedule_on_collection_v2` updates
--   loans.outstanding_balance when a collection is inserted. However,
--   client-side code (collection_sheet.dart, auto_collection_service.dart)
--   also reads the already-updated balance and subtracts again,
--   causing double deduction.
--
--   Example: EMI = 1000, balance = 50000
--   After collection insert: trigger sets balance = 49000
--   Client reads 49000, subtracts 1000, writes 48000
--   Result: balance shows 48000 (should be 49000)
--
-- This migration:
--   1. Recalculates ALL active loan balances from EMI schedule
--      (the single source of truth)
--   2. The recalculate_loan_outstanding RPC is SECURITY DEFINER
--      and derives balance from sum(emi_amount) - sum(paid emi_amount)
-- ============================================================================

DO $$
DECLARE
    loan_rec RECORD;
    result JSONB;
    fixed_count INT := 0;
    error_count INT := 0;
BEGIN
    FOR loan_rec IN
        SELECT l.id, l.loan_number, l.member_name,
               l.outstanding_balance, l.paid_emis
        FROM public.loans l
        WHERE l.status = 'active'
    LOOP
        BEGIN
            result := public.recalculate_loan_outstanding(loan_rec.id);
            fixed_count := fixed_count + 1;
            RAISE NOTICE 'Fixed loan % (%): %',
                loan_rec.loan_number, loan_rec.member_name, result;
        EXCEPTION WHEN OTHERS THEN
            error_count := error_count + 1;
            RAISE WARNING 'Failed to fix loan % (%): %',
                loan_rec.loan_number, loan_rec.member_name, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE 'Migration complete: % loans fixed, % errors', fixed_count, error_count;
END;
$$;
