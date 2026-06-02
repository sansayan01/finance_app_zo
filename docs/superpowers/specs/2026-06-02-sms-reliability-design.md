# SMS Reliability — Design Spec

**Date:** 2026-06-02
**Status:** Approved (pending user spec review)
**Author:** Claude (brainstorming → spec)
**Scope:** On-device SMS dispatch on Android + Flutter pipeline

---

## Problem

On a real dual-SIM Android device, SMS messages "don't go out at all" when a user records a collection. The Dart-side logs show no error, but the member never receives the message.

## Root causes (confirmed by code audit)

1. **Dual-SIM binding is implicit.** `SmsManager.getDefault()` returns a manager bound to the system-chosen subscription, not a stable, user-controlled slot. On multi-SIM devices the message is silently dropped when that slot has no signal/credit. ([SmsSenderPlugin.kt:97-100](android/app/src/main/kotlin/com/example/finance/SmsSenderPlugin.kt#L97-L100))
2. **Result-callback race.** `SmsSenderPlugin.smsResult` is a single shared field. Two overlapping `send_sms` calls overwrite each other's pending result. ([SmsSenderPlugin.kt:30-31, 103, 121](android/app/src/main/kotlin/com/example/finance/SmsSenderPlugin.kt#L30))
3. **Multipart `PendingIntent` reuse.** All parts of a multipart message share the same `sentIntent`/`deliveredIntent`. The first part to finish resolves the result; the rest have no way to report. ([SmsSenderPlugin.kt:166-167](android/app/src/main/kotlin/com/example/finance/SmsSenderPlugin.kt#L166))
4. **In-memory outbox + SharedPreferences queue.** A process kill mid-flush loses every queued message. No idempotent retry, no backoff, no dead-letter. ([sms_provider.dart:30-83](lib/core/providers/sms_provider.dart#L30))
5. **Timer-based scheduler.** `Timer.periodic` is paused by Doze and killed when backgrounded. "Send reminders at 08:00" effectively means "send at 08:00 only if the app is open that minute." ([sms_scheduler_service.dart:18-22](lib/core/services/sms_scheduler_service.dart#L18))
6. **No per-loan "already reminded today" guard.** First run after 08:00 sends reminders for *every* due EMI. ([sms_scheduler_service.dart:29-90](lib/core/services/sms_scheduler_service.dart#L29))
7. **No SMS history UI.** The "View Sent SMS" tile is a `SnackBar` placeholder. ([sms_settings_page.dart:121-127](lib/core/presentation/pages/sms_settings_page.dart#L121))

## Goals (in scope)

- Bind SMS dispatch to a user-chosen SIM slot (manual picker; default-voice as initial pick).
- Eliminate result-callback races by correlating native callbacks to Dart `Future`s via a `requestId`.
- Multipart-safe: one `PendingIntent` per part, scoped by `(requestId, partIndex)`.
- Durable outbox: a Hive-backed queue that survives process death, with retry policy **30s → 5m → 30m → dead-letter** (3 retries total; row is dead-lettered once `attempts` reaches 3, *after* the 3rd failed send).
- WorkManager-backed reminder scheduler that survives Doze and process death, idempotent per loan per day.
- Real SMS History page reading `sms_notifications`.
- "Send test SMS" button on the settings page that surfaces the actual native result code.

## Non-goals (out of scope, flagged for roadmap)

- Server-side SMS gateway (Twilio / MSG91 / Textlocal) — bigger change, requires DLT registration in India.
- iOS-side changes — `sms:` intent path is unchanged and working.
- DLT template registration for India.
- RLS tightening on `sms_notifications` (out of scope, will file a separate task).
- SMS cost monitoring, per-org sender-ID display name, member opt-out.

---

## Architecture

### Component map

**Android (Kotlin)**
- `SmsSenderPlugin` — rewritten: per-request correlation, per-part PendingIntents, SIM subscription binding, new `pickSubscription` + `setSubscription` channels.
- `MainActivity` — registers the two new channels.
- `SmsBootReceiver` — receives `BOOT_COMPLETED` and re-enqueues the WorkManager job (`WorkManager.enqueueUniquePeriodicWork("sms_reminder", KEEP, ...)`) so reminders resume after a reboot. Also calls `SmsOutboxService` via MethodChannel to re-enqueue any `pending` rows whose `scheduledFor <= now`.
- `SmsReminderWorker` — `CoroutineWorker` that runs the reminder query + send and re-enqueues itself.
- `AndroidManifest.xml` — `RECEIVE_BOOT_COMPLETED` permission; register `SmsBootReceiver` and the `WorkManager` initializer.

**Flutter (Dart)**
- `SmsService` — gains `requestId` and `subscriptionId` args; new `pickSubscription`, `setSubscription`, `sendTestSms`.
- `CollectionSmsSender` — converted to a `StateNotifier` so its in-flight queue state survives Riverpod invalidation. The outbox call still happens here.
- `SmsOutboxService` (new) — durable outbox on Hive box `sms_outbox_v1`. Schema: `{ id, phone, message, memberId, recipientName, collectorName, sentBy, status, attempts, lastError, scheduledFor, createdAt }`. States: `pending | sending | sent | failed | dead`. `sending` is set transiently by `markSending(id)` immediately before the native call, and a row that is `sending` at app start is treated as `pending` (assume the previous process died mid-dispatch).
- `SmsSchedulerService` — becomes a thin Dart wrapper that delegates to the Kotlin `WorkManager` job. Dart side kick-and-forget only.
- `sms_settings_page.dart` — adds SIM picker tile, "Send test SMS" button, scheduler status row; wires the "View Sent SMS" tile to the history page.
- `sms_history_page.dart` (new) — reads `sms_notifications` with `order=created_at desc, limit=200`, filter by status/date/member.

**SQL / Supabase**
- Migration `supabase/migrations/2026-06-02_sms_reliability.sql`:
  - `alter table loans add column last_reminder_sent_at timestamptz` (idempotency guard for the worker).
  - `create index if not exists sms_notifications_status_created_at_idx on sms_notifications (status, created_at desc)` for the history page.

### Data flow — collection recorded

```
[CollectionPage]
  └─ recordCollection() success
       └─ CollectionNotifier._sendSms(collection)            [non-blocking]
            └─ CollectionSmsSender.sendCollectionSms(...)
                 ├─ message = SmsService.buildCollectionSms(...)  [unchanged]
                 ├─ requestId = uuid()
                 ├─ SmsOutboxService.enqueue({...})               [durable write]
                 │     └─ Hive row: status=pending, attempts=0
                 ├─ SmsService.sendSms({
                 │     phone, message, requestId, subscriptionId
                 │   })
                 │     └─ MethodChannel("com.microflow/sms", "send_sms", {..., request_id})
                 │           └─ SmsSenderPlugin.sendSms(phone, msg, result, requestId)
                 │                 ├─ SmsManager bound to subscriptionId
                 │                 ├─ per-part PendingIntents keyed by (requestId, partIndex)
                 │                 ├─ store (requestId → result) in ConcurrentHashMap
                 │                 └─ SmsManager.sendMultipartTextMessage(...)
                 ├─ await native callback (timeout 30s)
                 │     ├─ success: outbox.markSent(requestId); insert sms_notifications status=sent
                 │     ├─ failure: outbox.scheduleRetry(requestId, code)
                 │     └─ dead-letter: outbox.markDead(requestId); insert sms_notifications status=failed
                 └─ _logSms(status) [best-effort, non-blocking]
```

On app start, `SmsOutboxService` replays any rows where `status=pending` and `scheduledFor <= now`. Rows past the retry budget are dead-lettered immediately.

### Data flow — reminder scheduler

```
[Dart]  app start, or scheduled kick
  └─ SmsSchedulerService.triggerReminderRun()
       └─ MethodChannel("com.microflow/sms", "enqueue_reminder_worker", {
            orgId, time, enabled
          })
            └─ SmsReminderWorker (Kotlin CoroutineWorker)
                 ├─ query loans with emi_schedule.due_date <= today and is_paid=false
                 │  AND (loans.last_reminder_sent_at is null OR < today)
                 ├─ for each loan: SmsSenderPlugin.sendSms(...)
                 ├─ update loans set last_reminder_sent_at = now where id in (...)
                 └─ return Result.success() — WorkManager auto-reschedules per policy
```

WorkManager policy: `PeriodicWorkRequest` of 1 day, runs at the configured `reminderTime` (we use `setInitialDelay` from now to the next 08:00). The worker itself is idempotent and short — even if WorkManager fires at 07:30 or 09:00, the per-loan guard prevents duplicates.

If reminders are disabled in settings, Dart calls `enqueue_reminder_worker` with `enabled=false` → Kotlin calls `WorkManager.cancelUniqueWork("sms_reminder")`.

### Data flow — SIM picker

```
[Settings page] user taps "SMS SIM slot"
  └─ SmsService.pickSubscription()
       └─ MethodChannel("com.microflow/sms", "pick_subscription")
            └─ SmsSubscriptionPicker
                 ├─ SubscriptionManager.getActiveSubscriptionInfoList()
                 ├─ return [{ subscriptionId, simSlotIndex, carrierName, displayName }, ...]
                 └─ Dart shows a CupertinoActionSheet / Material modal
  └─ on user choice: SmsService.setSubscription(id)
       └─ SharedPreferences.setInt("sms_subscription_id", id)  // Dart-side: prefs.setInt(...)
       └─ SmsSenderPlugin caches it for the next dispatch (the plugin reads it on each `send_sms` if no `subscriptionId` arg is passed)
```

If the device has no `getActiveSubscriptionInfoList` results (single-SIM), the picker shows "This device has one SIM. Using it."

---

## Error handling

| Failure | Detection | User-visible | Recovery |
|---|---|---|---|
| `SEND_SMS` permission denied | `smsPermissionProvider` returns false | Red banner on settings; "Send test SMS" returns error toast | `openAppSettings()` from settings page |
| No SIM / no signal | `SmsManager.sendTextMessage` returns `RESULT_ERROR_NO_SERVICE` or `RADIO_OFF` | "Couldn't reach cellular network. Will retry." | Outbox retry with backoff |
| Wrong SIM picked | `RESULT_ERROR_GENERIC_FAILURE` + carrier log | Settings row "Last dispatch used SIM 2 — tap to switch" | One-tap switch in SIM picker |
| Radio timeout (>30s) | Dart-side `Future.timeout(30s)` | "Send timed out — queued for retry" | Outbox retry |
| Outbox exceeds 500 entries | `quota_exceeded` from Hive write | Status row on settings page | Cap at 500, dead-letter oldest |
| Database insert to `sms_notifications` fails | `try/catch` | `debugPrint` only (non-blocking) | Best-effort log; SMS still went out |
| Worker fires for already-reminded loan | `loans.last_reminder_sent_at >= today` in query | Nothing | Skip silently |
| Hive box corruption on launch | catch + log | "Outbox reset due to error" banner | One-time clean rebuild |

---

## Testing

### Unit tests (host, no device)

- `SmsOutboxService`:
  - enqueue → row has `status=pending, attempts=0`
  - markSent → row has `status=sent`
  - markFailed with attempts<3 → row has `status=pending, attempts+1, scheduledFor = now+backoff(attempts)` (backoff(0)=30s, backoff(1)=5m, backoff(2)=30m)
  - markFailed with attempts==3 → row has `status=dead`
  - on init: rows where `status=pending and scheduledFor<=now` are returned by `pendingDue()`
  - on init: rows where `status=sending` are treated as `pending` (orphaned by previous process death)
  - on init: rows where `status=pending and attempts>=3` are dead-lettered
- `SmsService.build*` — golden-string tests for: ₹/no-₹, missing member name, multibyte name, all-optional-fields-null.
- `SmsConfig.copyWith` / `SmsConfig.fromPrefs` / `SmsConfigNotifier` toggles.
- Files: `test/core/services/sms_outbox_service_test.dart`, `test/core/services/sms_service_test.dart`, `test/core/providers/sms_config_provider_test.dart`.

### Integration tests (real device)

- `integration_test/sms_dispatch_test.dart`:
  1. **Happy path (single-SIM).** Send to your own number, observe `RESULT_OK` in `adb logcat`, observe `sms_notifications` row with `status='sent'`.
  2. **Permission denial.** Revoke `SEND_SMS`, hit "Send test SMS" → expect error toast + red banner.
  3. **Offline queue.** Airplane mode, record 3 collections, see `pending` in outbox. Online → see `sent`.
  4. **WorkManager reminder.** Set reminder 2 min in the future, lock the device, wait → reminder row in `sms_notifications` and `SmsReminderWorker` in logcat.
  5. **Dual-SIM** — **gated on device availability**: force-pick SIM 2, send, verify the native callback maps to the chosen slot. If only single-SIM is available, this is a `// TODO: device-test on dual-SIM` and the code must still compile + not regress single-SIM.

### Manual smoke

- Settings: every existing toggle still works.
- "Send test SMS" works.
- SIM picker shows the active SIM(s).
- History page renders 200 rows, filter by status, scroll to bottom.

---

## Files

### New
- `android/app/src/main/kotlin/com/example/finance/SmsBootReceiver.kt`
- `android/app/src/main/kotlin/com/example/finance/SmsReminderWorker.kt`
- `lib/core/services/sms_outbox_service.dart`
- `lib/core/presentation/pages/sms_history_page.dart`
- `test/core/services/sms_outbox_service_test.dart`
- `test/core/services/sms_service_test.dart`
- `test/core/providers/sms_config_provider_test.dart`
- `integration_test/sms_dispatch_test.dart`
- `supabase/migrations/2026-06-02_sms_reliability.sql`

### Modified
- `android/app/src/main/kotlin/com/example/finance/SmsSenderPlugin.kt` — rewrite send path; add subscription picker handler.
- `android/app/src/main/kotlin/com/example/finance/MainActivity.kt` — register new channels.
- `android/app/src/main/AndroidManifest.xml` — add `RECEIVE_BOOT_COMPLETED`; register `SmsBootReceiver`.
- `lib/core/services/sms_service.dart` — new `pickSubscription`, `setSubscription`, `sendTestSms`; `sendSms` accepts `requestId` and `subscriptionId`.
- `lib/core/providers/sms_provider.dart` — `CollectionSmsSender` becomes `StateNotifier`; outbox-driven; `_logSms` reads outbox result.
- `lib/core/services/sms_scheduler_service.dart` — replace `Timer.periodic` with MethodChannel kick to WorkManager.
- `lib/core/presentation/pages/sms_settings_page.dart` — SIM picker, test SMS, scheduler status row, wire history tile.

### Unchanged (but worth knowing)
- `lib/core/providers/sms_config_provider.dart` — settings keys unchanged.
- `lib/features/staff/data/providers/sms_provider.dart` — re-export shim, no change.
- `supabase_schema.sql` — the migration file is additive; main schema unchanged.
- iOS path — `SmsService._sendIosSms` unchanged.

---

## Risks

- **WorkManager on a vendor-customized Android** (Xiaomi, Vivo) can be killed by aggressive battery savers regardless of what we do. We surface this in the settings page ("If reminders stop firing, allow MicroFlow in your phone's battery settings") rather than trying to fight the OEM.
- **sqflite is not in `pubspec.yaml`**; we use Hive (already present) to avoid adding a dependency.
- **Concurrent multipart sends** are still serialized on the native side per slot (one `sendTextMessage` in flight at a time per `SmsManager`). The per-request correlation does *not* change that, but it does mean callbacks can come back out of order. Per-(requestId, partIndex) intent IDs keep the mapping clean.
- **Real-device verification** requires a SIM with credit. The CI environment won't run the integration test — it must be run on your dev device.

---

## Acceptance criteria

1. On a real Android device, recording a collection reliably delivers an SMS to the member within 30 seconds (assuming good signal).
2. On a dual-SIM device, the user can pick which SIM is used, and the choice persists across restarts.
3. Killing the app during a dispatch does not lose the message; it's sent on next launch.
4. Reminders fire at the configured time even if the app was backgrounded.
5. The History page shows the last 200 SMS events with status, member, and timestamp.
6. The "Send test SMS" button returns the actual native result code in a toast/banner.

---

## Next step

Spec self-review, then user review, then `superpowers:writing-plans` to produce an implementation plan.
