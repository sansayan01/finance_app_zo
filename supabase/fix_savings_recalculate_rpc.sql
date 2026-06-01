-- =============================================================
-- RPC: recalculate_savings_balance
-- Recomputes current_amount from the remaining transactions
-- and recomputes next_due_date from the latest savings_collection.
-- SECURITY DEFINER so RLS can't silently block the revert when
-- a transaction is deleted.
-- =============================================================
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

  -- 4. Persist
  UPDATE public.savings_plans
  SET
    current_amount = v_new_balance,
    next_due_date = v_new_next_due,
    updated_at = NOW()
  WHERE id = p_savings_id;

  RETURN jsonb_build_object(
    'success', true,
    'savings_id', p_savings_id,
    'new_balance', v_new_balance,
    'new_next_due_date', v_new_next_due
  );
END;
$$;

-- Allow authenticated users to invoke the recalc RPC
GRANT EXECUTE ON FUNCTION public.recalculate_savings_balance(UUID) TO authenticated;
