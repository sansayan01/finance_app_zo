-- =====================================================
-- Fix: EMI status is never updated to 'overdue' as time
-- passes. The only status change in the DB happens when
-- a collection is recorded (via update_schedule_on_collection),
-- which only ever sets 'paid'. As a result, the Loan
-- Detail page's "Upcoming Payments" timeline shows past-due
-- EMIs as 'PENDING' even when they're clearly overdue.
--
-- The Flutter UI now computes `isOverdue` from the
-- `due_date` directly (see EMIScheduleModelX extension),
-- so the UI is always correct even if the DB is stale.
--
-- This migration (1) backfills overdue rows immediately,
-- (2) installs a daily cron job so the DB stays in sync.
-- =====================================================

-- 1) One-time backfill of stale statuses.
UPDATE public.emi_schedule
SET status = 'overdue',
    is_overdue = true
WHERE is_paid = false
  AND status NOT IN ('paid', 'waived', 'overdue')
  AND due_date < CURRENT_DATE;

-- 2) Schedule a daily refresh at 02:00 server time.
--    Requires the pg_cron extension. If the extension is
--    not enabled in this project, the schedule call will
--    fail; that's fine — the UI fix above is the primary
--    fix and the backfill has already corrected all current
--    rows.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Remove any previous instance to keep this idempotent
    PERFORM cron.unschedule('mark_overdue_emis_daily');
    PERFORM cron.schedule(
      'mark_overdue_emis_daily',
      '0 2 * * *',
      $cmd$
        UPDATE public.emi_schedule
        SET status = 'overdue',
            is_overdue = true
        WHERE is_paid = false
          AND status NOT IN ('paid', 'waived', 'overdue')
          AND due_date < CURRENT_DATE;
      $cmd$
    );
  ELSE
    RAISE NOTICE 'pg_cron is not enabled; skipping schedule. Run the UPDATE above manually if needed.';
  END IF;
END
$$;
