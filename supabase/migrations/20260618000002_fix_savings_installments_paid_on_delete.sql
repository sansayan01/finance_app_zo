-- =============================================================
-- Fix: delete_savings_transaction drifts installments_paid
--
-- Symptom: After deleting a savings collection transaction, the
-- corresponding savings_plan.installments_paid count stays at the
-- pre-delete value. Re-recording a payment bumps it by 1 again,
-- leaving the UI's "overdue installments" counter one ahead of
-- reality (expectedByNow - installmentsPaidCount reads the stale
-- stored value, derived from savings_plans.installments_paid).
--
-- Root cause: public.delete_savings_transaction (defined in
-- supabase/fix_transaction_deletion.sql) recalculates
-- current_amount and next_due_date but never decrements
-- installments_paid.
--
-- This migration patches the function so it stays consistent going
-- forward, and runs a one-time backfill that brings every plan
-- already in a drifted state back in sync.
-- =============================================================

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

  -- 2. Delete matching savings_collections record (best-effort match)
  IF v_savings_id IS NOT NULL THEN
    DELETE FROM public.savings_collections
    WHERE savings_plan_id = v_savings_id
      AND member_id = v_member_id
      AND (amount_collected = v_amount OR amount_expected = v_amount)
      AND org_id = v_org_id;
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

  -- 6. Update savings plan.
  -- installment_count is computed from the live savings_collections
  -- rows so the value can never drift; we floor at 0 to avoid a
  -- pathological subtraction on a poorly matched delete.
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

-- =============================================================
-- One-time backfill: any plan whose installments_paid was
-- drifted above the true COUNT(savings_collections) is reset
-- now, atomically with the function replacement above, so the
-- "1 overdue" badge clears the moment this migration commits
-- instead of waiting for an unrelated edit.
-- =============================================================
UPDATE public.savings_plans sp
SET installments_paid = GREATEST(
  0,
  COALESCE((
    SELECT COUNT(*) FROM public.savings_collections sc
    WHERE sc.savings_plan_id = sp.id
  ), 0)
),
updated_at = NOW()
WHERE sp.installments_paid > COALESCE((
  SELECT COUNT(*) FROM public.savings_collections sc
  WHERE sc.savings_plan_id = sp.id
), 0);
