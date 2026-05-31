-- =============================================================
-- RPC: delete_savings_transaction
-- Atomically deletes a savings transaction, its matching
-- savings_collections record, recalculates current_amount,
-- and reverts next_due_date to the prior period.
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

  -- 6. Update savings plan
  UPDATE public.savings_plans
  SET
    current_amount = v_new_balance,
    next_due_date = v_new_next_due,
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
-- RPC: delete_loan_collection
-- Atomically deletes a collection record, unmarks its paid EMIs
-- (most recently paid first), restores the loan outstanding
-- balance, and removes the matching transaction.
-- =============================================================
CREATE OR REPLACE FUNCTION public.delete_loan_collection(p_collection_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_col RECORD;
  v_loan_id UUID;
  v_amount DECIMAL(12,2);
  v_org_id UUID;
  v_member_id UUID;
  v_tx_id UUID;
  v_remaining DECIMAL(12,2);
  v_current_outstanding DECIMAL(12,2);
  v_emi RECORD;
BEGIN
  -- 1. Fetch the collection
  SELECT * INTO v_col FROM public.collections WHERE id = p_collection_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Collection not found');
  END IF;

  v_loan_id := v_col.loan_id;
  v_amount := v_col.amount_collected;
  v_org_id := v_col.org_id;
  v_member_id := v_col.member_id;

  -- 2. Find matching transaction
  SELECT id INTO v_tx_id
  FROM public.transactions
  WHERE loan_id = v_loan_id
    AND amount = v_amount
    AND org_id = v_org_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- 3. Unmark EMIs that were paid by this collection
  -- Walk most-recently-paid EMIs in reverse, unmarking until
  -- we have undone the collection amount.
  v_remaining := v_amount;
  FOR v_emi IN
    SELECT id, emi_amount
    FROM public.emi_schedule
    WHERE loan_id = v_loan_id
      AND is_paid = true
      AND paid_on IS NOT NULL
    ORDER BY paid_on DESC, emi_number DESC
  LOOP
    EXIT WHEN v_remaining <= 0;

    UPDATE public.emi_schedule
    SET
      is_paid = false,
      status = 'upcoming',
      paid_on = NULL,
      payment_mode = NULL,
      amount_paid = 0
    WHERE id = v_emi.id;

    v_remaining := v_remaining - v_emi.emi_amount;
  END LOOP;

  -- 4. Restore loan outstanding
  SELECT COALESCE(outstanding_amount, outstanding_balance, 0)
    INTO v_current_outstanding
  FROM public.loans WHERE id = v_loan_id;

  UPDATE public.loans
  SET
    outstanding_amount = v_current_outstanding + v_amount,
    outstanding_balance = v_current_outstanding + v_amount,
    status = CASE WHEN status = 'closed' THEN 'active' ELSE status END
  WHERE id = v_loan_id;

  -- 5. Delete the transaction
  IF v_tx_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = v_tx_id;
  END IF;

  -- 6. Delete the collection
  DELETE FROM public.collections WHERE id = p_collection_id;

  RETURN jsonb_build_object(
    'success', true,
    'loan_id', v_loan_id,
    'restored_amount', v_amount,
    'new_outstanding', v_current_outstanding + v_amount
  );
END;
$$;
