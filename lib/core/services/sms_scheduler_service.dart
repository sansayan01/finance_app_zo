import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/sms_provider.dart';
import '../providers/sms_config_provider.dart';

/// Scans for due/overdue EMIs and sends automated reminder SMS.
/// Runs on app start and periodically while foreground.
class SmsSchedulerService {
  final SupabaseClient _client;
  final CollectionSmsSender _smsSender;
  final SmsConfig _config;
  Timer? _timer;
  DateTime _lastRun = DateTime(2000);

  SmsSchedulerService(this._client, this._smsSender, this._config);

  void start({Duration interval = const Duration(hours: 1)}) {
    _runOnce();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _runOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runOnce() async {
    if (!_config.reminderEnabled) return;
    // Avoid re-running within 30 minutes
    if (DateTime.now().difference(_lastRun).inMinutes < 30) return;
    _lastRun = DateTime.now();

    try {
      final now = DateTime.now();
      final today = now.toIso8601String().split('T').first;

      // Query loans from the org with due/unpaid EMIs
      final response = await _client
          .from('loans')
          .select('''
            id,
            member_id,
            member_name,
            loan_number,
            outstanding_amount,
            members!inner(id, phone),
            emi_schedule!inner(id, due_date, emi_amount, is_paid, is_overdue)
          ''')
          .eq('status', 'active')
          .lte('emi_schedule.due_date', today)
          .eq('emi_schedule.is_paid', false);

      final nowTime = _parseTime(_config.reminderTime);
      if (nowTime == null) return;

      final todayDt = DateTime(now.year, now.month, now.day, nowTime.hour, nowTime.minute);
      // Only send if current time is past the configured reminder time
      if (now.isBefore(todayDt)) return;

      for (final loan in response) {
        final memberPhone = loan['members']?['phone'] as String?;
        if (memberPhone == null || memberPhone.isEmpty) continue;

        final schedules = loan['emi_schedule'] as List? ?? [];
        for (final schedule in schedules) {
          final dueDateStr = schedule['due_date'] as String?;
          if (dueDateStr == null) continue;
          final dueDate = DateTime.tryParse(dueDateStr);
          if (dueDate == null) continue;

          final isOverdue = schedule['is_overdue'] == true ||
              dueDate.isBefore(DateTime(now.year, now.month, now.day));
          final emiAmount = (schedule['emi_amount'] as num?)?.toDouble() ?? 0;

          _smsSender.sendReminderSms(
            memberPhone: memberPhone,
            memberName: loan['member_name'] as String? ?? '',
            memberId: loan['member_id'] as String?,
            loanNumber: loan['loan_number'] as String? ?? '',
            dueAmount: emiAmount,
            outstandingBalance: (loan['outstanding_amount'] as num?)?.toDouble(),
            dueDate: dueDate,
            staffId: 'scheduler',
            orgName: null,
            isOverdue: isOverdue,
          );
        }
      }
    } catch (e) {
      debugPrint('SMS scheduler error: $e');
    }
  }

  TimeOfDay? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

class TimeOfDay {
  final int hour;
  final int minute;
  TimeOfDay({required this.hour, required this.minute});
}
