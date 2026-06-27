-- =============================================================
-- RECONCILE: clean up Sefali's broken test baseline
-- Loan:  4d43b0ca-216c-4f8f-b909-c586bfcd4a8e (L-20260627-5873)
-- RD:    7dc94a67-9a92-4ba7-a4d5-17ee83922dcb
-- Org:   dcca9d7f-870a-4ae1-aada-1b7a2384c0f9
-- Member: 52c57d86-0981-4860-a6f6-0c26f8cb390b (Sefali)
--
-- Why this exists: the migration code paths that pre-fill a plan
-- with back-dated "paid" installments leave orphan collections
-- (transaction_id = NULL) and, for savings, a single back-dated
-- transaction (created_at before plan creation). This migration
-- removes those broken rows so Sefali can be tested from scratch
-- once the fixes (this migration series) are applied to the app.
-- =============================================================

DO $$
DECLARE
  v_loan_id  UUID := '4d43b0ca-216c-4f8f-b909-c586bfcd4a8e';
  v_rd_id    UUID := '7dc94a67-9a92-4ba7-a4d5-17ee83922dcb';
  v_member   UUID := '52c57d86-0981-4860-a6f6-0c26f8cb390b';
  v_org      UUID := 'dcca9d7f-870a-4ae1-aada-1b7a2384c0f9';
  v_del_emi   INT;
  v_del_coll  INT;
  v_del_rdecl INT;
  v_del_scoll INT;
  v_del_tx    INT;
  v_del_loan  INT;
  v_del_plan  INT;
BEGIN
  -- --- 1. Delete collections and EMI rows linked to the test loan ---
  DELETE FROM public.collections WHERE loan_id = v_loan_id;
  GET DIAGNOSTICS v_del_coll = ROW_COUNT;

  DELETE FROM public.emi_schedule WHERE loan_id = v_loan_id;
  GET DIAGNOSTICS v_del_emi = ROW_COUNT;

  -- --- 2. Delete the loan's transactions (explicit, even though cascade
  -- also handles it; this prevents SET NULL chains from lingering).
  DELETE FROM public.transactions WHERE loan_id = v_loan_id;
  GET DIAGNOSTICS v_del_tx = ROW_COUNT;

  -- --- 3. Delete the loan row itself ---
  DELETE FROM public.loans WHERE id = v_loan_id;
  GET DIAGNOSTICS v_del_loan = ROW_COUNT;

  -- --- 4. Delete savings_collections + transactions linked to the test RD ---
  DELETE FROM public.savings_collections WHERE savings_plan_id = v_rd_id;
  GET DIAGNOSTICS v_del_scoll = ROW_COUNT;

  DELETE FROM public.transactions WHERE savings_id = v_rd_id;
  GET DIAGNOSTICS v_del_rdecl = ROW_COUNT;

  -- --- 5. Delete the savings plan row ---
  DELETE FROM public.savings_plans WHERE id = v_rd_id;
  GET DIAGNOSTICS v_del_plan = ROW_COUNT;

  -- --- 6. Verify zero residue ---
  ASSERT (SELECT COUNT(*) FROM public.loans             WHERE id          = v_loan_id) = 0,
         'residue: loans row still present';
  ASSERT (SELECT COUNT(*) FROM public.emi_schedule      WHERE loan_id     = v_loan_id) = 0,
         'residue: emi_schedule rows still present';
  ASSERT (SELECT COUNT(*) FROM public.collections       WHERE loan_id     = v_loan_id) = 0,
         'residue: collections rows still present';
  ASSERT (SELECT COUNT(*) FROM public.transactions      WHERE loan_id     = v_loan_id) = 0,
         'residue: transactions (loan) rows still present';
  ASSERT (SELECT COUNT(*) FROM public.savings_plans     WHERE id          = v_rd_id)   = 0,
         'residue: savings_plans row still present';
  ASSERT (SELECT COUNT(*) FROM public.savings_collections WHERE savings_plan_id = v_rd_id) = 0,
         'residue: savings_collections rows still present';
  ASSERT (SELECT COUNT(*) FROM public.transactions      WHERE savings_id  = v_rd_id)   = 0,
         'residue: transactions (savings) rows still present';

  RAISE NOTICE 'Reconcile Sefali baseline: loans=%, emi=%, collections=%, savings_collections=%, tx_loan=%, tx_savings=%, plan=%',
    v_del_loan, v_del_emi, v_del_coll, v_del_scoll, v_del_tx, v_del_rdecl, v_del_plan;
END $$;
