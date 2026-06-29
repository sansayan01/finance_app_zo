-- ============================================================================
-- Migration: 20260629020000_mark_emis_paid_from_collections.sql
--
-- Problem:
--   The `update_schedule_on_collection_v2` trigger was NOT SECURITY DEFINER
--   (fixed in migration 20260629010000), so when collections were inserted,
--   the UPDATE statements inside the trigger were silently blocked by RLS.
--   Result: collections exist but EMIs were never marked as paid, and
--   loans.outstanding_balance / paid_emis were never updated.
--
--   The previous migration (20260629010000) fixed the trigger and ran
--   recalculate_loan_outstanding, but that function uses EMI schedule as
--   source of truth — since all EMIs were unpaid, it computed full outstanding.
--
-- This migration:
--   1. Marks EMIs as paid based on existing collection records
--   2. Deduplicates: if multiple collections point to the same EMI, only mark once
--   3. Calls recalculate_loan_outstanding for each affected loan
--
-- Safety:
--   - Only affects loans where collections exist but EMIs are unpaid
--   - Idempotent: safe to run multiple times (checks is_paid before marking)
--   - Uses SECURITY DEFINER recalculate function to bypass RLS
-- ============================================================================

-- Step 1: Mark EMIs as paid based on collections
DO $$
DECLARE
    v_collection RECORD;
    v_marked_count INT := 0;
    v_skipped_count INT := 0;
    v_affected_loans TEXT[] := '{}';
BEGIN
    -- Find all collections where the target EMI is NOT yet marked as paid
    FOR v_collection IN
        SELECT DISTINCT ON (c.selected_schedule_id)
            c.id AS collection_id,
            c.selected_schedule_id,
            c.loan_id,
            c.collection_date,
            c.collection_time,
            c.payment_mode,
            c.amount_collected,
            e.is_paid,
            e.emi_number,
            e.emi_amount
        FROM public.collections c
        JOIN public.emi_schedule e ON e.id = c.selected_schedule_id
        WHERE c.selected_schedule_id IS NOT NULL
          AND c.loan_id IS NOT NULL
          AND e.is_paid IS DISTINCT FROM true
        ORDER BY c.selected_schedule_id, c.collection_date ASC
    LOOP
        -- Mark this EMI as paid
        UPDATE public.emi_schedule
        SET
            is_paid = true,
            status = 'paid',
            paid_on = (v_collection.collection_date + v_collection.collection_time)::timestamptz,
            payment_mode = COALESCE(v_collection.payment_mode, 'cash')
        WHERE id = v_collection.selected_schedule_id
          AND is_paid IS DISTINCT FROM true;  -- Idempotent check

        IF FOUND THEN
            v_marked_count := v_marked_count + 1;
            -- Track affected loan IDs
            IF NOT (v_collection.loan_id::text = ANY(v_affected_loans)) THEN
                v_affected_loans := array_append(v_affected_loans, v_collection.loan_id::text);
            END IF;
            RAISE NOTICE 'Marked EMI % (loan %) as paid via collection %',
                v_collection.emi_number, v_collection.loan_id, v_collection.collection_id;
        ELSE
            v_skipped_count := v_skipped_count + 1;
        END IF;
    END LOOP;

    RAISE NOTICE 'EMI marking complete: % marked, % skipped (already paid), % affected loans',
        v_marked_count, v_skipped_count, array_length(v_affected_loans, 1);

    -- Step 2: Recalculate each affected loan
    DECLARE
        v_loan_id TEXT;
        v_result JSONB;
        v_recalculated INT := 0;
    BEGIN
        FOREACH v_loan_id IN ARRAY v_affected_loans
        LOOP
            BEGIN
                v_result := public.recalculate_loan_outstanding(v_loan_id::uuid);
                v_recalculated := v_recalculated + 1;
                RAISE NOTICE 'Recalculated loan %: %', v_loan_id, v_result;
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Failed to recalculate loan %: %', v_loan_id, SQLERRM;
            END;
        END LOOP;

        RAISE NOTICE 'Recalculation complete: % loans recalculated', v_recalculated;
    END;
END;
$$;

-- Step 3: Fix any orphaned collections (collections with no matching transaction)
-- This is a safety net — collections whose transactions were deleted via SQL
-- but the collection record was left behind. These are harmless but we log them.
DO $$
DECLARE
    v_orphan RECORD;
    v_count INT := 0;
BEGIN
    FOR v_orphan IN
        SELECT c.id, c.loan_id, c.amount_collected, c.collection_date
        FROM public.collections c
        WHERE c.loan_id IS NOT NULL
          AND c.transaction_id IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM public.transactions t WHERE t.id = c.transaction_id
          )
    LOOP
        v_count := v_count + 1;
        RAISE NOTICE 'Orphaned collection: id=%, loan=%, amount=%, date=%',
            v_orphan.id, v_orphan.loan_id, v_orphan.amount_collected, v_orphan.collection_date;
    END LOOP;

    IF v_count > 0 THEN
        RAISE WARNING 'Found % orphaned collections (transactions deleted via SQL). These are harmless but may cause duplicate payment records in statements.', v_count;
    ELSE
        RAISE NOTICE 'No orphaned collections found.';
    END IF;
END;
$$;
