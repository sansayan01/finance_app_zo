-- ============================================================================
-- Migration: 20260629010000_fix_collection_trigger_and_recalculate.sql
--
-- Root cause:
--   The trigger function `update_schedule_on_collection_v2` was NOT SECURITY
--   DEFINER, so it ran as the calling user. RLS policies on `emi_schedule`
--   and `loans` blocked the UPDATE statements inside the trigger, causing:
--   1. EMIs never marked as paid after collection
--   2. `loans.outstanding_balance` / `paid_emis` never updated
--   3. Overdue count wrong (all EMIs still "pending" even after payment)
--   4. Interest rate stored incorrectly (formula bug in app code)
--
-- This migration:
--   1. Fixes the trigger function to SECURITY DEFINER
--   2. Recalculates all affected loans from EMI schedule
--   3. Fixes interest rates using correct formula
-- ============================================================================

-- Step 1: Fix the trigger function to be SECURITY DEFINER
CREATE OR REPLACE FUNCTION "public"."update_schedule_on_collection_v2"()
RETURNS "trigger"
LANGUAGE "plpgsql"
SECURITY DEFINER  -- CRITICAL: must run as owner to bypass RLS
AS $$
DECLARE
    v_remaining_amount  DECIMAL(12, 2);
    v_emi_record        RECORD;
    v_current_outstanding DECIMAL(12, 2);
    v_selected_emi        RECORD;
    v_emis_marked   INT := 0;
    v_emi_cursor CURSOR FOR
        SELECT id, emi_amount
        FROM public.emi_schedule
        WHERE loan_id = NEW.loan_id
          AND is_paid = false
          AND paid_on IS NULL
        ORDER BY emi_number ASC;
BEGIN
    -- Only proceed for loan collections
    IF NEW.loan_id IS NOT NULL THEN
        v_remaining_amount := NEW.amount_collected;

        IF NEW.selected_schedule_id IS NOT NULL THEN
            SELECT id, emi_amount, is_paid
            INTO v_selected_emi
            FROM public.emi_schedule
            WHERE id = NEW.selected_schedule_id
              AND loan_id = NEW.loan_id;

            IF FOUND THEN
                IF v_selected_emi.is_paid IS DISTINCT FROM true THEN
                    IF v_remaining_amount >= v_selected_emi.emi_amount THEN
                        UPDATE public.emi_schedule
                        SET
                            is_paid = true,
                            status = 'paid',
                            paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                            payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                        WHERE id = v_selected_emi.id;
                        v_emis_marked := 1;
                        v_remaining_amount := v_remaining_amount - v_selected_emi.emi_amount;
                    ELSE
                        v_remaining_amount := 0;
                    END IF;
                ELSE
                    RETURN NEW;
                END IF;
            END IF;
        ELSE
            FOR v_emi_record IN v_emi_cursor LOOP
                EXIT WHEN v_remaining_amount <= 0;
                IF v_remaining_amount >= v_emi_record.emi_amount THEN
                    UPDATE public.emi_schedule
                    SET
                        is_paid = true,
                        status = 'paid',
                        paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                        payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                    WHERE id = v_emi_record.id;
                    v_emis_marked := v_emis_marked + 1;
                    v_remaining_amount := v_remaining_amount - v_emi_record.emi_amount;
                ELSE
                    v_remaining_amount := 0;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Update loan outstanding amount and paid_emis
    IF NEW.loan_id IS NOT NULL THEN
        SELECT COALESCE(outstanding_amount, outstanding_balance, total_repayable, amount, 0)
        INTO v_current_outstanding
        FROM public.loans WHERE id = NEW.loan_id;

        UPDATE public.loans
        SET
            outstanding_amount = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            outstanding_balance = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            paid_emis = COALESCE(paid_emis, 0) + v_emis_marked,
            status = CASE
                WHEN v_current_outstanding - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;

    RETURN NEW;
END;
$$;


-- Step 2: Recalculate ALL loans from EMI schedule (fixes existing broken data)
-- This uses the recalculate_loan_outstanding RPC which is already SECURITY DEFINER
DO $$
DECLARE
    loan_rec RECORD;
    result JSONB;
    fixed_count INT := 0;
BEGIN
    FOR loan_rec IN
        SELECT l.id, l.loan_number, l.member_name, l.outstanding_balance, l.paid_emis
        FROM public.loans l
        WHERE l.status = 'active'
    LOOP
        result := public.recalculate_loan_outstanding(loan_rec.id);
        fixed_count := fixed_count + 1;
    END LOOP;

    RAISE NOTICE 'Recalculated % active loans from EMI schedule', fixed_count;
END;
$$;


-- Step 3: Fix interest rates using correct formula
-- interest_rate = (interest_amount / principal) * 100
-- This fixes the bug where interest_rate was stored as a large number
-- instead of the actual percentage
UPDATE public.loans
SET interest_rate = ROUND((interest_amount::numeric / NULLIF(principal::numeric, 0)) * 100, 2)
WHERE principal > 0
  AND interest_amount > 0
  AND interest_rate::numeric > 100  -- Only fix obviously wrong rates
  AND interest_type = 'flat';
