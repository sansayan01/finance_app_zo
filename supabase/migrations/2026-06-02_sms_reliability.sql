-- SMS reliability migration
-- Adds idempotency guard for the reminder worker and audit columns referenced by the Dart sender.

BEGIN;

-- 1. Idempotency guard for SmsReminderWorker (per-loan, per-day)
ALTER TABLE public.loans
  ADD COLUMN IF NOT EXISTS last_reminder_sent_at TIMESTAMPTZ;

-- 2. Columns referenced by lib/core/providers/sms_provider.dart:_logSms
--    (Dart code already writes them; making the table match.)
ALTER TABLE public.sms_notifications
  ADD COLUMN IF NOT EXISTS recipient_phone TEXT,
  ADD COLUMN IF NOT EXISTS recipient_name TEXT,
  ADD COLUMN IF NOT EXISTS collector_name TEXT;

-- 3. Composite index used by sms_history_page
CREATE INDEX IF NOT EXISTS sms_notifications_status_created_at_idx
  ON public.sms_notifications (status, created_at DESC);

-- 4. Partial index for the "last 200 sent" view
CREATE INDEX IF NOT EXISTS sms_notifications_org_created_at_idx
  ON public.sms_notifications (org_id, created_at DESC);

COMMIT;
