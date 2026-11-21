-- ============================================================
-- Give savings vaults a real SMS opt-out
-- ------------------------------------------------------------
-- The savings detail page had an "SMS Notifications" switch that only wrote to
-- SharedPreferences. `savings_plans` had no sms_enabled column, so the switch
-- read its state from nothing and always came back ON after reopening the
-- vault (and on any other device it was always ON).
--
-- With the column in place the preference is per vault, shared across devices
-- and readable by whatever sends the reminders.
-- ============================================================

ALTER TABLE public.savings_plans
  ADD COLUMN IF NOT EXISTS sms_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.savings_plans.sms_enabled IS
  'Per-vault SMS reminder opt-out. Defaults to true (reminders on).';
