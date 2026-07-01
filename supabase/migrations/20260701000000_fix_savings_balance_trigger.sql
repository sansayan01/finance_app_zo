-- ============================================================
-- Migration: Add trigger to auto-update savings_plans on collection
-- + Data fix for existing discrepancies
--
-- Problem: No trigger existed on savings_collections, so current_amount
-- and installments_paid were managed by 7 different Dart code paths,
-- leading to inconsistencies (₹33,600 discrepancy on production).
--
-- Fix: Mirror the loan trigger pattern (update_schedule_on_collection_v2).
-- The trigger fires AFTER INSERT on savings_collections and:
--   1. Adds amount_collected to current_amount
--   2. Increments installments_paid by 1
--   3. Updates last_payment_date
--   4. Advances next_due_date by one period (daily/weekly/monthly)
--
-- Security: Uses SECURITY DEFINER to run with elevated privileges.
-- ============================================================

-- ── 1. Create trigger function ──────────────────────────────
CREATE OR REPLACE FUNCTION public.update_savings_plan_on_collection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_plan RECORD;
    v_next_due DATE;
    v_target_day INT;
    v_days_in_month INT;
    v_target_month INT;
    v_target_year INT;
BEGIN
    -- Only proceed if savings_plan_id is present
    IF NEW.savings_plan_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Fetch the current plan state
    SELECT id, collection_type, next_due_date, collection_day_of_month, collection_day_of_week
    INTO v_plan
    FROM public.savings_plans
    WHERE id = NEW.savings_plan_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- ── 1. Update current_amount and installments_paid ──
    UPDATE public.savings_plans
    SET
        current_amount   = COALESCE(current_amount, 0) + NEW.amount_collected,
        installments_paid = COALESCE(installments_paid, 0) + 1,
        last_payment_date = NEW.collection_date,
        updated_at        = now()
    WHERE id = NEW.savings_plan_id;

    -- ── 2. Advance next_due_date by one period ──
    -- Only advance if collection_date is >= current next_due_date
    -- (prevents retroactive advances for backdated payments)
    IF v_plan.next_due_date IS NULL OR NEW.collection_date >= v_plan.next_due_date THEN
        CASE v_plan.collection_type
            WHEN 'weekly' THEN
                v_next_due := NEW.collection_date + INTERVAL '7 days';

            WHEN 'monthly' THEN
                v_target_day := COALESCE(v_plan.collection_day_of_month, EXTRACT(DAY FROM NEW.collection_date)::int);
                v_target_month := EXTRACT(MONTH FROM NEW.collection_date)::int + 1;
                v_target_year  := EXTRACT(YEAR FROM NEW.collection_date)::int + ((v_target_month - 1) / 12);
                v_target_month := ((v_target_month - 1) % 12) + 1;
                v_days_in_month := EXTRACT(DAY FROM (make_date(v_target_year, v_target_month + 1, 1) - INTERVAL '1 day'))::int;
                IF v_target_day > v_days_in_month THEN
                    v_target_day := v_days_in_month;
                END IF;
                v_next_due := make_date(v_target_year, v_target_month, v_target_day);

            ELSE
                -- daily: advance by 1 day
                v_next_due := NEW.collection_date + INTERVAL '1 day';
        END CASE;

        UPDATE public.savings_plans
        SET next_due_date = v_next_due
        WHERE id = NEW.savings_plan_id;
    END IF;

    RETURN NEW;
END;
$function$;

-- ── 2. Create trigger ──────────────────────────────────────
DROP TRIGGER IF EXISTS trg_update_savings_plan_on_collection ON public.savings_collections;

CREATE TRIGGER trg_update_savings_plan_on_collection
    AFTER INSERT ON public.savings_collections
    FOR EACH ROW
    EXECUTE FUNCTION public.update_savings_plan_on_collection();

-- ── 3. Data fix: Recalculate balances from actual collections ──
-- This corrects any existing discrepancies where current_amount
-- doesn't match SUM(amount_collected) from savings_collections.
UPDATE public.savings_plans sp
SET
    current_amount = COALESCE(sub.total_collected, 0),
    installments_paid = COALESCE(sub.collection_count, 0),
    last_payment_date = sub.last_collection_date,
    updated_at = now()
FROM (
    SELECT
        savings_plan_id,
        SUM(amount_collected) AS total_collected,
        COUNT(*) AS collection_count,
        MAX(collection_date) AS last_collection_date
    FROM public.savings_collections
    GROUP BY savings_plan_id
) sub
WHERE sp.id = sub.savings_plan_id
  AND (
      sp.current_amount IS DISTINCT FROM sub.total_collected
      OR sp.installments_paid IS DISTINCT FROM sub.collection_count
  );
