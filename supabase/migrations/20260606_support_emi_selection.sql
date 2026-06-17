-- =====================================================
-- Support EMI Selection on Payment Allocation
-- =====================================================
-- Adds an optional `selected_schedule_id` column to the
-- `collections` table so callers can target a specific
-- EMI for payment instead of relying on FIFO.
--
-- - If `selected_schedule_id` is provided AND the EMI
--   is unpaid: pay that EMI directly (full if amount
--   covers it, partial otherwise — partial does NOT
--   mark the EMI as paid).
-- - If `selected_schedule_id` is NULL: fall back to the
--   original FIFO behaviour (oldest unpaid first).
--
-- All existing loan-balance and auto-close logic is
-- preserved exactly.
-- =====================================================

-- 1) Add the nullable column to collections.
ALTER TABLE public.collections
    ADD COLUMN IF NOT EXISTS selected_schedule_id UUID
    REFERENCES public.emi_schedule(id);

-- 2) Create the updated trigger function.
CREATE OR REPLACE FUNCTION public.update_schedule_on_collection_v2()
RETURNS TRIGGER AS $$
DECLARE
    v_remaining_amount  DECIMAL(12, 2);
    v_emi_record        RECORD;
    v_current_outstanding DECIMAL(12, 2);
    v_total_repayable     DECIMAL(12, 2);
    v_selected_emi        RECORD;
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

        -- ------------------------------------------------
        -- Branch A: Specific EMI selected
        -- ------------------------------------------------
        IF NEW.selected_schedule_id IS NOT NULL THEN
            -- Fetch the target EMI and verify it belongs to
            -- this loan.
            SELECT id, emi_amount, is_paid
            INTO v_selected_emi
            FROM public.emi_schedule
            WHERE id = NEW.selected_schedule_id
              AND loan_id = NEW.loan_id;

            IF FOUND THEN
                -- If the EMI is already paid (e.g. migration record),
                -- skip outstanding reduction to avoid double-counting.
                IF v_selected_emi.is_paid IS DISTINCT FROM true THEN
                    IF v_remaining_amount >= v_selected_emi.emi_amount THEN
                        -- Full payment of the selected EMI
                        UPDATE public.emi_schedule
                        SET
                            is_paid = true,
                            status = 'paid',
                            paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                            payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                        WHERE id = v_selected_emi.id;

                        v_remaining_amount := v_remaining_amount - v_selected_emi.emi_amount;
                    ELSE
                        -- Partial — don't mark as paid
                        v_remaining_amount := 0;
                    END IF;
                ELSE
                    -- EMI already paid — skip to avoid double-counting
                    RETURN NEW;
                END IF;
            END IF;

        -- ------------------------------------------------
        -- Branch B: No specific EMI — original FIFO path
        -- ------------------------------------------------
        ELSE
            FOR v_emi_record IN v_emi_cursor LOOP
                EXIT WHEN v_remaining_amount <= 0;

                IF v_remaining_amount >= v_emi_record.emi_amount THEN
                    -- Full payment of this EMI
                    UPDATE public.emi_schedule
                    SET
                        is_paid = true,
                        status = 'paid',
                        paid_on = (NEW.collection_date + NEW.collection_time)::timestamptz,
                        payment_mode = COALESCE(NEW.payment_mode, payment_mode)
                    WHERE id = v_emi_record.id;

                    v_remaining_amount := v_remaining_amount - v_emi_record.emi_amount;
                ELSE
                    -- Partial payment — don't mark as paid
                    v_remaining_amount := 0;
                END IF;
            END LOOP;
        END IF;
    END IF;

    -- Update loan outstanding amount and outstanding balance
    IF NEW.loan_id IS NOT NULL THEN
        SELECT
            COALESCE(outstanding_balance, outstanding_amount, total_repayable, amount, 0),
            COALESCE(total_repayable, amount, 0)
        INTO v_current_outstanding, v_total_repayable
        FROM public.loans
        WHERE id = NEW.loan_id;

        IF v_current_outstanding <= 0 THEN
            v_current_outstanding := v_total_repayable;
        END IF;

        UPDATE public.loans
        SET
            outstanding_amount = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            outstanding_balance = GREATEST(v_current_outstanding - NEW.amount_collected, 0),
            status = CASE
                WHEN v_current_outstanding - NEW.amount_collected <= 0 THEN 'closed'
                ELSE status
            END
        WHERE id = NEW.loan_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) Replace the trigger to use the new function.
DROP TRIGGER IF EXISTS update_schedule_on_collection ON public.collections;
CREATE TRIGGER update_schedule_on_collection
    AFTER INSERT ON public.collections
    FOR EACH ROW
    EXECUTE FUNCTION public.update_schedule_on_collection_v2();
