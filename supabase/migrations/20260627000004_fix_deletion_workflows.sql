-- =============================================================
-- FIX: delete_savings_transaction and delete_loan_collection
-- Use transaction_id for precise matching instead of amount.
-- Ensure installments_paid is recalculated on every delete.
-- =============================================================

-- 1. Fixed delete_savings_transaction RPC
CREATE OR REPLACE FUNCTION public.delete_savings_transaction(p_transaction_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tx RECORD;
  v_savings_id UUID;
  v_amount DECIMAL(12,2);
  v_org_id UUID;
  v_member_id UUID;
  v_opening_balance DECIMAL(12,2);
  v_new_balance DECIMAL(12,2);
  v_collection_type TEXT;
  v_start_date DATE;
  v_max_paid_date DATE;
  v_new_next_due DATE;
BEGIN
  -- 1. Fetch the transaction
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
  END IF;

  v_savings_id := v_tx.savings_id;
  v_amount := v_tx.amount;
  v_org_id := v_tx.org_id;
  v_member_id := v_tx.member_id;

  -- 2. Delete matching savings_collections record using transaction_id first for precision
  IF v_savings_id IS NOT NULL THEN
    DELETE FROM public.savings_collections
    WHERE transaction_id = p_transaction_id;

    -- Fallback: if no collection linked by transaction_id, try amount/member match but only ONE record
    IF NOT FOUND THEN
      DELETE FROM public.savings_collections
      WHERE id = (
        SELECT sc.id FROM public.savings_collections sc
        WHERE sc.savings_plan_id = v_savings_id
          AND sc.member_id = v_member_id
          AND (sc.amount_collected = v_amount OR sc.amount_expected = v_amount)
          AND sc.org_id = v_org_id
        LIMIT 1
      );
    END IF;
  END IF;

  -- 3. Delete the transaction
  DELETE FROM public.transactions WHERE id = p_transaction_id;

  -- 4. Recalculate current_amount
  SELECT COALESCE(opening_balance, 0) INTO v_opening_balance
  FROM public.savings_plans WHERE id = v_savings_id;

  SELECT COALESCE(SUM(
    CASE WHEN t.type IN ('savingsDeposit', 'deposit') THEN t.amount
         WHEN t.type IN ('savingsWithdrawal', 'withdrawal') THEN -t.amount
         ELSE 0 END
  ), 0) INTO v_new_balance
  FROM public.transactions t
  WHERE t.savings_id = v_savings_id;

  v_new_balance := v_opening_balance + v_new_balance;
  IF v_new_balance < 0 THEN v_new_balance := 0; END IF;

  -- 5. Recalculate next_due_date
  SELECT collection_type, start_date INTO v_collection_type, v_start_date
  FROM public.savings_plans WHERE id = v_savings_id;

  SELECT MAX(collection_date) INTO v_max_paid_date
  FROM public.savings_collections
  WHERE savings_plan_id = v_savings_id;

  IF v_max_paid_date IS NULL THEN
    v_new_next_due := v_start_date;
  ELSE
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := v_max_paid_date + 1;
      WHEN 'weekly' THEN
        v_new_next_due := v_max_paid_date + 7;
      ELSE
        v_new_next_due := v_max_paid_date + INTERVAL '1 month';
    END CASE;
  END IF;

  -- 6. Update savings plan with recalculated installments_paid from COUNT of remaining collections
  UPDATE public.savings_plans
  SET
    current_amount = v_new_balance,
    next_due_date = v_new_next_due,
    installments_paid = GREATEST(
      0,
      COALESCE((
        SELECT COUNT(*) FROM public.savings_collections sc
        WHERE sc.savings_plan_id = v_savings_id
      ), 0)
    ),
    updated_at = NOW()
  WHERE id = v_savings_id;

  RETURN jsonb_build_object(
    'success', true,
    'savings_id', v_savings_id,
    'new_balance', v_new_balance,
    'new_next_due_date', v_new_next_due
  );
END;
$$;

-- 2. Fixed delete_loan_collection RPC
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

  -- 3. Find and delete the matching transaction using transaction_id first for precision
  IF v_col.transaction_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = v_col.transaction_id;
  ELSE
    -- Fallback: match by amount but only if no other collection uses this transaction
    SELECT id INTO v_tx_id
    FROM public.transactions
    WHERE loan_id = v_loan_id
      AND amount = v_amount
      AND org_id = v_col.org_id
      AND NOT EXISTS (
        SELECT 1 FROM public.collections c
        WHERE c.transaction_id = public.transactions.id
          AND c.id != p_collection_id
      )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_tx_id IS NOT NULL THEN
      DELETE FROM public.transactions WHERE id = v_tx_id;
    END IF;
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

-- 3. Fixed recalculate_savings_balance to also update installments_paid
CREATE OR REPLACE FUNCTION public.recalculate_savings_balance(p_savings_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_opening DECIMAL(12,2) := 0;
  v_new_balance DECIMAL(12,2) := 0;
  v_collection_type TEXT;
  v_start_date DATE;
  v_max_paid_date DATE;
  v_new_next_due DATE;
BEGIN
  -- 1. Pull plan metadata
  SELECT
    COALESCE(opening_balance, 0),
    COALESCE(collection_type, 'monthly'),
    start_date
  INTO v_opening, v_collection_type, v_start_date
  FROM public.savings_plans
  WHERE id = p_savings_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'savings plan not found');
  END IF;

  -- 2. Recompute balance from remaining transactions
  SELECT COALESCE(SUM(
    CASE
      WHEN t.type IN ('savingsWithdrawal', 'withdrawal') THEN -t.amount
      ELSE t.amount
    END
  ), 0) INTO v_new_balance
  FROM public.transactions t
  WHERE t.savings_id = p_savings_id;

  v_new_balance := v_opening + v_new_balance;
  IF v_new_balance < 0 THEN v_new_balance := 0; END IF;

  -- 3. Recompute next_due_date from the latest remaining collection
  SELECT MAX(collection_date) INTO v_max_paid_date
  FROM public.savings_collections
  WHERE savings_plan_id = p_savings_id;

  IF v_max_paid_date IS NOT NULL THEN
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := v_max_paid_date + 1;
      WHEN 'weekly' THEN
        v_new_next_due := v_max_paid_date + 7;
      ELSE
        v_new_next_due := (v_max_paid_date + INTERVAL '1 month')::date;
    END CASE;
  ELSE
    v_new_next_due := v_start_date;
  END IF;

  -- ALWAYS advance if the calculated date is in the past
  IF v_new_next_due < CURRENT_DATE THEN
    CASE v_collection_type
      WHEN 'daily' THEN
        v_new_next_due := CURRENT_DATE;
      WHEN 'weekly' THEN
        v_new_next_due := CURRENT_DATE + (7 - EXTRACT(DOW FROM CURRENT_DATE)::int + EXTRACT(DOW FROM v_start_date)::int)::int % 7;
        IF v_new_next_due <= CURRENT_DATE THEN
          v_new_next_due := CURRENT_DATE + 1;
        END IF;
      ELSE
        v_new_next_due := CURRENT_DATE;
    END CASE;
  END IF;

  -- 4. Persist with installments_paid recalculated from live savings_collections
  UPDATE public.savings_plans
  SET current_amount = v_new_balance,
      next_due_date = v_new_next_due,
      installments_paid = GREATEST(
        0,
        COALESCE((
          SELECT COUNT(*) FROM public.savings_collections sc
          WHERE sc.savings_plan_id = p_savings_id
        ), 0)
      ),
      updated_at = NOW()
  WHERE id = p_savings_id;

  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'next_due_date', v_new_next_due
  );
END;
$$;

-- 4. One-time backfill to fix already corrupted installments_paid and outstanding
-- Fix savings_plans where installments_paid is wrong
UPDATE public.savings_plans sp
SET installments_paid = GREATEST(
  0,
  COALESCE((
    SELECT COUNT(*) FROM public.savings_collections sc
    WHERE sc.savings_plan_id = sp.id
  ), 0)
),
updated_at = NOW()
WHERE sp.installments_paid != GREATEST(
  0,
  COALESCE((
    SELECT COUNT(*) FROM public.savings_collections sc
    WHERE sc.savings_plan_id = sp.id
  ), 0)
);

-- Fix loans with wrong outstanding by recalculating from EMI schedule
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

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_savings_transaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_loan_collection(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recalculate_savings_balance(UUID) TO authenticated;
