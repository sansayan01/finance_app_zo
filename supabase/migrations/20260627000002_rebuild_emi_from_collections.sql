-- =============================================================
-- Fix: Rebuild emi_schedule paid status from collections table
-- and recalculate loan outstanding accordingly.
--
-- Problem: When a loan is created with migrated/prepaid EMIs,
-- the collections record is created but emi_schedule rows are
-- NOT marked as is_paid=true. This causes outstanding_balance
-- to be wrong because recalculate_loan_outstanding reads from
-- emi_schedule.
--
-- This migration:
-- 1. For each loan with collections, determines total collected.
-- 2. Walks EMIs oldest-first, marking as paid until accounted for.
-- 3. Recalculates outstanding from corrected emi_schedule.
-- =============================================================

-- Step 1: Fix function to rebuild EMI schedule from collections
CREATE OR REPLACE FUNCTION public.rebuild_emi_schedule_from_collections(p_loan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_collected DECIMAL(12,2) := 0;
  v_emi RECORD;
  v_remaining DECIMAL(12,2);
  v_emis_marked INTEGER := 0;
  v_rec_result JSONB;
  v_first_collection_date DATE;
BEGIN
  -- 1. Sum all collections for this loan
  SELECT COALESCE(SUM(amount_collected), 0),
         MIN(collection_date)
  INTO v_total_collected, v_first_collection_date
  FROM public.collections
  WHERE loan_id = p_loan_id;

  IF v_total_collected <= 0 THEN
    RETURN jsonb_build_object('success', true, 'note', 'no collections', 'collected', 0);
  END IF;

  -- 2. Walk EMIs from oldest to newest, marking as paid
  --    until we've accounted for total collected amount
  v_remaining := v_total_collected;

  FOR v_emi IN
    SELECT id, emi_amount, is_paid, emi_number
    FROM public.emi_schedule
    WHERE loan_id = p_loan_id
    ORDER BY emi_number ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    IF v_emi.is_paid = false THEN
      UPDATE public.emi_schedule
      SET
        is_paid = true,
        status = 'paid',
        amount_paid = v_emi.emi_amount,
        paid_on = COALESCE(v_first_collection_date, CURRENT_DATE)::text || 'T00:00:00Z',
        payment_mode = 'migrated'
      WHERE id = v_emi.id;

      v_emis_marked := v_emis_marked + 1;
    END IF;

    v_remaining := v_remaining - v_emi.emi_amount;
  END LOOP;

  -- 3. Recalculate outstanding from corrected emi_schedule
  SELECT public.recalculate_loan_outstanding(p_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', p_loan_id,
    'total_collected', v_total_collected,
    'emis_marked', v_emis_marked,
    'recalc', v_rec_result
  );
END;
$$;

-- Step 2: Fix ALL loans that have collections
DO $$
DECLARE
  v_loan RECORD;
  v_result JSONB;
  v_fixed INTEGER := 0;
BEGIN
  FOR v_loan IN
    SELECT DISTINCT c.loan_id
    FROM public.collections c
    INNER JOIN public.loans l ON c.loan_id = l.id
    WHERE c.loan_id IS NOT NULL
  LOOP
    BEGIN
      SELECT public.rebuild_emi_schedule_from_collections(v_loan.loan_id) INTO v_result;
      IF (v_result->>'emis_marked')::int > 0 THEN
        v_fixed := v_fixed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Error fixing loan %: %', v_loan.loan_id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE 'Fixed % loans by rebuilding EMI schedule from collections', v_fixed;
END;
$$;
