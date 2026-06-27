-- =============================================================
-- COMPREHENSIVE FIX: Loan outstanding + EMI schedule repair
-- Safe to run — uses only columns guaranteed to exist
-- (id, loan_id, due_date, emi_amount, is_paid, status)
-- =============================================================

-- 1. recalculate_loan_outstanding
CREATE OR REPLACE FUNCTION public.recalculate_loan_outstanding(p_loan_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_repaid DECIMAL(12,2) := 0;
  v_paid_count INTEGER := 0;
  v_total_emi DECIMAL(12,2) := 0;
  v_new_outstanding DECIMAL(12,2) := 0;
BEGIN
  SELECT
    COALESCE(SUM(CASE WHEN is_paid THEN emi_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN is_paid THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(emi_amount), 0)
  INTO v_total_repaid, v_paid_count, v_total_emi
  FROM public.emi_schedule
  WHERE loan_id = p_loan_id;

  v_new_outstanding := v_total_emi - v_total_repaid;
  IF v_new_outstanding < 0 THEN v_new_outstanding := 0; END IF;

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
    'paid_emis', v_paid_count,
    'total_emi', v_total_emi,
    'new_outstanding', v_new_outstanding
  );
END;
$$;

-- 2. rebuild_emi_schedule_from_collections
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
BEGIN
  SELECT COALESCE(SUM(amount_collected), 0)
  INTO v_total_collected
  FROM public.collections
  WHERE loan_id = p_loan_id;

  IF v_total_collected <= 0 THEN
    RETURN jsonb_build_object('success', true, 'collected', 0, 'emis_marked', 0);
  END IF;

  v_remaining := v_total_collected;

  FOR v_emi IN
    SELECT id, emi_amount, is_paid
    FROM public.emi_schedule
    WHERE loan_id = p_loan_id
    ORDER BY due_date ASC, id ASC
  LOOP
    EXIT WHEN v_remaining <= 0;

    IF v_emi.is_paid = false THEN
      UPDATE public.emi_schedule
      SET
        is_paid = true,
        status = 'paid',
        amount_paid = v_emi.emi_amount,
        payment_mode = 'migrated'
      WHERE id = v_emi.id;

      v_emis_marked := v_emis_marked + 1;
    END IF;

    v_remaining := v_remaining - v_emi.emi_amount;
  END LOOP;

  SELECT public.recalculate_loan_outstanding(p_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object(
    'success', true,
    'total_collected', v_total_collected,
    'emis_marked', v_emis_marked,
    'recalc', v_rec_result
  );
END;
$$;

-- 3. delete_loan_collection RPC (fixed)
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
  SELECT * INTO v_col FROM public.collections WHERE id = p_collection_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Collection not found');
  END IF;

  v_loan_id := v_col.loan_id;
  v_amount := v_col.amount_collected;
  v_schedule_id := v_col.selected_schedule_id;

  IF v_schedule_id IS NOT NULL THEN
    UPDATE public.emi_schedule
    SET is_paid = false, status = 'pending', paid_on = NULL,
        paid_date = NULL, payment_mode = NULL, amount_paid = 0, transaction_id = NULL
    WHERE id = v_schedule_id AND is_paid = true;
  ELSE
    UPDATE public.emi_schedule
    SET is_paid = false, status = 'pending', paid_on = NULL,
        paid_date = NULL, payment_mode = NULL, amount_paid = 0, transaction_id = NULL
    WHERE id = (
      SELECT es.id FROM public.emi_schedule es
      WHERE es.loan_id = v_loan_id AND es.is_paid = true
        AND NOT EXISTS (
          SELECT 1 FROM public.collections c
          WHERE c.loan_id = v_loan_id AND c.selected_schedule_id = es.id AND c.id != p_collection_id
        )
      ORDER BY es.due_date DESC NULLS LAST, es.id DESC LIMIT 1
    );
  END IF;

  SELECT id INTO v_tx_id FROM public.transactions
  WHERE loan_id = v_loan_id AND amount = v_amount AND org_id = v_col.org_id
  ORDER BY created_at DESC LIMIT 1;
  IF v_tx_id IS NOT NULL THEN
    DELETE FROM public.transactions WHERE id = v_tx_id;
  END IF;

  DELETE FROM public.collections WHERE id = p_collection_id;

  SELECT public.recalculate_loan_outstanding(v_loan_id) INTO v_rec_result;

  RETURN jsonb_build_object('success', true, 'restored_amount', v_amount, 'recalc', v_rec_result);
END;
$$;

-- 4. DIAGNOSTIC: Check current state of Sefali's loan
DO $$
DECLARE
  v_rec RECORD;
  v_emi_count INTEGER;
  v_paid_count INTEGER;
  v_collected DECIMAL(12,2);
BEGIN
  RAISE NOTICE '=== LOAN DIAGNOSTIC ===';

  FOR v_rec IN
    SELECT l.id, l.loan_number, l.outstanding_amount, l.paid_emis, l.amount
    FROM public.loans l WHERE l.loan_number = 'L-20260626-3354'
  LOOP
    SELECT COUNT(*), COALESCE(SUM(CASE WHEN is_paid THEN 1 ELSE 0 END), 0)
    INTO v_emi_count, v_paid_count
    FROM public.emi_schedule WHERE loan_id = v_rec.id;

    SELECT COALESCE(SUM(amount_collected), 0) INTO v_collected
    FROM public.collections WHERE loan_id = v_rec.id;

    RAISE NOTICE 'Loan: %', v_rec.loan_number;
    RAISE NOTICE '  Outstanding: % | paid_emis: %', v_rec.outstanding_amount, v_rec.paid_emis;
    RAISE NOTICE '  EMI rows: % | Marked paid: %', v_emi_count, v_paid_count;
    RAISE NOTICE '  Collections total: %', v_collected;

    RAISE NOTICE '  --- First 15 EMIs ---';
    FOR v_rec IN
      SELECT due_date, emi_amount, is_paid, status
      FROM public.emi_schedule WHERE loan_id = v_rec.id
      ORDER BY due_date ASC LIMIT 15
    LOOP
      RAISE NOTICE '    due=% amt=% paid=% status=%', v_rec.due_date, v_rec.emi_amount, v_rec.is_paid, v_rec.status;
    END LOOP;

    RAISE NOTICE '  --- All Collections ---';
    FOR v_rec IN
      SELECT amount_collected, collection_date, selected_schedule_id
      FROM public.collections WHERE loan_id = v_rec.id
      ORDER BY collection_date ASC
    LOOP
      RAISE NOTICE '    amt=% date=% schedule=%', v_rec.amount_collected, v_rec.collection_date, v_rec.selected_schedule_id;
    END LOOP;
  END LOOP;
END;
$$;

-- 5. FIX: Rebuild EMI schedule for ALL loans with collections
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
        RAISE NOTICE 'Fixed loan %: marked % EMIs', v_loan.loan_id, v_result->>'emis_marked';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Error fixing loan %: %', v_loan.loan_id, SQLERRM;
    END;
  END LOOP;

  RAISE NOTICE '=== Total loans fixed: % ===', v_fixed;
END;
$$;
