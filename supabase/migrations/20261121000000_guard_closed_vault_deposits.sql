-- ============================================================
-- Stop deposits into vaults that are no longer active
-- ------------------------------------------------------------
-- A closed (or matured/withdrawn/cancelled) vault could still receive money:
-- four different code paths insert into savings_collections and none of them
-- looked at the plan status. That silently changed a settled vault's balance,
-- broke the payout accounting and made statements wrong.
--
-- Guarding at the database level covers every path at once, including offline
-- replays, the UPI flow, the auto-collection job and any future caller.
-- ============================================================

CREATE OR REPLACE FUNCTION public.guard_savings_deposit_on_closed_vault()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  IF NEW.savings_plan_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_status
  FROM public.savings_plans
  WHERE id = NEW.savings_plan_id;

  IF v_status IS NULL THEN
    RETURN NEW;
  END IF;

  IF v_status <> 'active' THEN
    RAISE EXCEPTION
      'This vault is % and cannot accept deposits. Reopen it first.', v_status
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_savings_collection_status ON public.savings_collections;
CREATE TRIGGER trg_guard_savings_collection_status
  BEFORE INSERT ON public.savings_collections
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_savings_deposit_on_closed_vault();

-- The deposit transaction is inserted before the collection row in some paths,
-- so guard it too; otherwise a failed collection would leave an orphan
-- deposit transaction behind and still inflate the statements.
CREATE OR REPLACE FUNCTION public.guard_savings_deposit_transaction()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  IF NEW.type <> 'savingsDeposit' OR NEW.savings_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_status
  FROM public.savings_plans
  WHERE id = NEW.savings_id;

  IF v_status IS NULL THEN
    RETURN NEW;
  END IF;

  IF v_status <> 'active' THEN
    RAISE EXCEPTION
      'This vault is % and cannot accept deposits. Reopen it first.', v_status
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_savings_deposit_tx ON public.transactions;
CREATE TRIGGER trg_guard_savings_deposit_tx
  BEFORE INSERT ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_savings_deposit_transaction();
