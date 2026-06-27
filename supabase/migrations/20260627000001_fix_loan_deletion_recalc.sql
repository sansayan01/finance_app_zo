-- =============================================================
-- Migration: Fix loan collection deletion + add recalculation RPC
-- 
-- Problem: delete_loan_collection RPC unmarks EMIs from most-recently-paid
-- backwards, which corrupts the loan when collections don't align 1:1
-- with EMIs (e.g., migrated accounts, multi-EMI payments).
--
-- Fix: 
-- 1. Add recalculate_loan_outstanding RPC that derives outstanding
--    directly from the EMI schedule (source of truth).
-- 2. Fix delete_loan_collection to use selected_schedule_id first.
-- 3. After unmarking EMIs, call recalc to fix any drift.
-- =============================================================

-- 1. RPC: recalculate_loan_outstanding
-- Recomputes outstanding_amount, outstanding_balance, and paid_emis
-- from the EMI schedule — the authoritative source.
CREATE OR REPLACE FUNCTION public.recalculate_loan_outstanding(p_loan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_repaid DECIMAL(12,2) := 0;
  v_paid_count INTEGER := 0;
  v_total_emi DECIMAL(12,2) := 0;
  v_loan_amount DECIMAL(12,2) := 0;
  v_new_outstanding DECIMAL(12,2) := 0;
  v_total_repayable DECIMAL(12,2) := 0;
BEGIN
  -- Sum up what's actually been paid according to EMI schedule
  SELECT
    COALESCE(SUM(CASE WHEN is_paid THEN emi_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN is_paid THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(emi_amount), 0)
  INTO v_total_repaid, v_paid_count, v_total_emi
  FROM public.emi_schedule
  WHERE loan_id = p_loan_id;

  -- Get loan's principal amount
  SELECT COALESCE(amount, 0) INTO v_loan_amount
  FROM public.loans WHERE id = p_loan_id;

  -- outstanding = total repayable - what's been paid
  v_new_outstanding := v_total_emi - v_total_repaid;
  IF v_new_outstanding < 0 THEN v_new_outstanding := 0; END IF;

  -- Update the loan
  UPDATE public.loans
  SET
    outstanding_amount = v_new_outstanding,
    outstanding_balance = v_new_outstanding,
    paid_emis = v_paid_count,
    status = CASE
      WHEN v_new_outstanding <= 0 AND status != 'closed' THEN 'closed'
      WHEN v_new_outstanding > 0 AND status = 'closed' THEN 'active'
      ELSE status
    END
  WHERE id = p_loan_id;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', p_loan_id,
    'total_repaid', v_total_repaid,
    'paid_emis', v_paid_count,
    'total_emi', v_total_emi,
    'new_outstanding', v_new_outstanding
  );
END;
$$;

-- 2. Fix delete_loan_collection RPC
-- Use selected_schedule_id when available; fallback to matching by amount.
-- After unmarking, always recalculate from EMI schedule.
CREATE OR REPLACE FUNCTION public.delete_loan_collection(p_collection_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_col RECORD;
  v_loan_id UUID;
  v_amount DECIMAL(12,2);
  v_tx_id UUID;
  v_schedule_id UUID;
  v_rec_result JSONB;
BEGIN
  -- 1. Fetch the collection
  SELECT * INTO v_col FROM public.collections WHERE id = p_collection_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Collection not found');
  END IF;

  v_loan_id := v_col.loan_id;
  v_amount := v_col.amount_collected;
  v_schedule_id := v_col.selected_schedule_id;

  -- 2. Unmark the SPECIFIC EMI if selected_schedule_id is known
  IF v_schedule_id IS NOT NULL THEN
    UPDATE public.emi_schedule
    SET
      is_paid = false,
      status = 'pending',
      paid_on = NULL,
      paid_date = NULL,
      payment_mode = NULL,
      amount_paid = 0,
      transaction_id = NULL
    WHERE id = v_schedule_id
      AND is_paid = true;
  ELSE
    -- Fallback: unmark the most recently paid EMI that hasn't been
    -- linked to a DIFFERENT collection via selected_schedule_id
    UPDATE public.emi_schedule
    SET
      is_paid = false,
      status = 'pending',
      paid_on = NULL,
      paid_date = NULL,
      payment_mode = NULL,
      amount_paid = 0,
      transaction_id = NULL
    WHERE id = (
      SELECT es.id
      FROM public.emi_schedule es
      WHERE es.loan_id = v_loan_id
        AND es.is_paid = true
        AND NOT EXISTS (
          SELECT 1 FROM public.collections c
          WHERE c.loan_id = v_loan_id
            AND c.selected_schedule_id = es.id
            AND c.id != p_collection_id
        )
      ORDER BY es.paid_on DESC NULLS LAST, es.emi_number DESC
      LIMIT 1
    );
  END IF;

  -- 3. Find and delete the matching transaction
  SELECT id INTO v_tx_id
  FROM public.transactions
  WHERE loan_id = v_loan_id
    AND amount = v_amount
    AND org_id = v_col.org_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_tx_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = v_tx_id;
  END IF;

  -- 4. Delete the collection
  DELETE FROM public.collections WHERE id = p_collection_id;

  -- 5. Recalculate outstanding from EMI schedule (source of truth)
  SELECT public.recalculate_loan_outstanding(v_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', v_loan_id,
    'restored_amount', v_amount,
    'recalc', v_rec_result
  );
END;
$$;

-- 3. One-off fix: recalculate outstanding for ALL active loans
-- Run this once to repair any existing drift
DO $$
DECLARE
  v_loan RECORD;
BEGIN
  FOR v_loan IN
    SELECT id FROM public.loans WHERE status IN ('active', 'closed')
  LOOP
    PERFORM public.recalculate_loan_outstanding(v_loan.id);
  END LOOP;
END;
$$;
