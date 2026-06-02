// lib/core/services/sms_scheduler_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/sms_config_provider.dart';

/// Thin Dart wrapper around the Android-side `SmsReminderWorker`.
/// On Android we delegate to WorkManager; on iOS this is a no-op.
class SmsSchedulerService {
  static const _channel = MethodChannel('com.microflow/sms_scheduler');
  final SmsConfig _config;

  SmsSchedulerService(this._config);

  void start() {
    unawaited(triggerReminderRun());
  }

  void stop() {
    unawaited(disableReminder());
  }

  Future<void> triggerReminderRun() async {
    if (!_config.reminderEnabled) {
      await disableReminder();
      return;
    }
    try {
      await _channel.invokeMethod('enqueue_reminder_worker', {
        'time': _config.reminderTime,
      });
    } catch (e) {
      debugPrint('SMS scheduler trigger failed: $e');
    }
  }

  Future<void> disableReminder() async {
    try {
      await _channel.invokeMethod('cancel_reminder_worker');
    } catch (e) {
      debugPrint('SMS scheduler cancel failed: $e');
    }
  }

  /// Called by the native worker when it boots a Flutter engine and runs
  /// the reminder pass. Reads config, enqueues any due reminders into the
  /// outbox. Returns the count of reminders enqueued.
  Future<int> runReminderPass() async {
    if (!_config.reminderEnabled) return 0;
    // The actual reminder query (loans with due/overdue EMIs) lives in
    // Supabase; the native side has already started a Flutter engine to call
    // us. This is a stub: the real implementation needs to query Supabase
    // and call the outbox. The plumbing is here; the body comes in a
    // follow-up task.
    debugPrint('runReminderPass invoked but not yet implemented');
    return 0;
  }
}
