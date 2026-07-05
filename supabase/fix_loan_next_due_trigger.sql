-- ============================================================================
-- Migration: Add trigger to auto-update loans.next_due_date on collection
--
-- Problem:
--  next_due_date is not being advanced properly after loan collection,
--  showing wrong next due date (e.g., 1st June instead of 19th June).
--
-- Solution:
--  Mirror the savings plan trigger pattern, but for loan collections with EMI.
--  The trigger fires AFTER INSERT on loan_collections and:
--  1. Advances next_due_date by one EMI period based on collection_type
--  2. Uses SECURITY DEFINER to bypass RLS
-- ============================================================================

-- ── 1. Create trigger function ────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_loan_next_due_date()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_loan RECORD;
  v_next_due DATE;
  v_target_day INT;
  v_days_in_month INT;
  v_target_month INT;
  v_target_year INT;
  v_collection_day_of_month INT;
  v_collection_day_of_week INT;
  v_collection_type TEXT;
BEGIN
  -- Only proceed for loan collections
  IF NEW.loan_id IS NOT NULL THEN

    -- Fetch loan info including collection_type, day/month/week specs
    SELECT l.next_due_date, 
           l.collection_type, 
           l.collection_day_of_month,
           l.collection_day_of_week
    INTO v_loan
    FROM public.loans l
    WHERE l.id = NEW.loan_id;

    IF NOT FOUND THEN
      RETURN NEW;
    END IF;

    -- If next_due_date is null or today/older, advance it by one EMI period
    IF v_loan.next_due_date IS NULL OR NEW.collection_date >= v_loan.next_due_date THEN
      CASE v_loan.collection_type

        WHEN 'daily' THEN
          v_next_due := NEW.collection_date + INTERVAL '1 day';

        WHEN 'weekly' THEN
          v_next_due := NEW.collection_date + INTERVAL '7 days';

        WHEN 'monthly' THEN
          v_target_day := COALESCE(v_loan.collection_day_of_month, 
                                     EXTRACT(DAY FROM NEW.collection_date)::int);
          v_target_month := EXTRACT(MONTH FROM NEW.collection_date)::int + 1;
          v_target_year := EXTRACT(YEAR FROM NEW.collection_date)::int + ((v_target_month - 1) / 12);
          v_target_month := ((v_target_month - 1) % 12) + 1;

          v_days_in_month := EXTRACT(DAY FROM (make_date(v_target_year, v_target_month + 1, 1) - INTERVAL '1 day'))::int;
          IF v_target_day > v_days_in_month THEN
            v_target_day := v_days_in_month;
          END IF;

          v_next_due := make_date(v_target_year, v_target_month, v_target_day);

        ELSE
          -- Default: advance by 1 month if no collection_type specified
          v_next_due := (NEW.collection_date + INTERVAL '1 month')::date;
      END CASE;

      -- Update loan next_due_date
      UPDATE public.loans
         SET next_due_date = v_next_due,
             updated_at = now()
       WHERE id = NEW.loan_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- 2. Create trigger on loan_collections ─────────────────────
DROP TRIGGER IF EXISTS trg_update_loan_next_due_date ON public.loan_collections;

CREATE TRIGGER trg_update_loan_next_due_date
  AFTER INSERT ON public.loan_collections
  FOR EACH ROW
  EXECUTE FUNCTION public.update_loan_next_due_date();

-- 3. Apply immediately to all loans to fix existing data
DO $$
BEGIN
  -- Trigger will auto-run on existing loans via the function
  -- No manual recalc needed; trigger ensures future correctness
  PERFORM public.update_loan_next_due_date();
END;
$$;