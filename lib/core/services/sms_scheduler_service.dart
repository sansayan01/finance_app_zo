// lib/core/services/sms_scheduler_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/supabase_provider.dart';
import 'sms_outbox_service.dart';
import 'sms_service.dart';
import '../providers/org_provider.dart';
import '../providers/sms_config_provider.dart';
import '../providers/sms_outbox_provider.dart';

/// Thin Dart wrapper around the Android-side `SmsReminderWorker`.
/// On Android we delegate to WorkManager; on iOS this is a no-op.
class SmsSchedulerService {
  static const _channel = MethodChannel('com.microflow/sms_scheduler');

  final SmsConfig _config;
  final SmsOutboxService _outbox;
  final SupabaseClient _client;
  final String? _orgId;
  final SmsService _smsService;

  /// When true, the inbound `run_reminder_pass` method-call is answered by
  /// this instance. Set by [start]. The worker spins up a fresh engine and
  /// only one instance can be wired to the channel at a time, so we keep
  /// this flag instead of always re-registering in the constructor.
  bool _handlerWired = false;

  SmsSchedulerService({
    required SmsConfig config,
    required SmsOutboxService outbox,
    required SupabaseClient client,
    required String? orgId,
    SmsService? smsService,
  })  : _config = config,
        _outbox = outbox,
        _client = client,
        _orgId = orgId,
        _smsService = smsService ?? SmsService();

  void start() {
    _wireHandler();
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

  /// Wire the inbound `run_reminder_pass` handler. The Android
  /// `SmsReminderWorker` constructs a fresh Flutter engine, executes the
  /// default entry point, and then invokes this method on the channel. We
  /// answer by running the real reminder pass (see [runReminderPass]).
  void _wireHandler() {
    if (_handlerWired) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'run_reminder_pass':
          try {
            final n = await runReminderPass();
            return n;
          } catch (e, stack) {
            debugPrint('runReminderPass failed: $e');
            debugPrint('Stack: $stack');
            return 0;
          }
        default:
          throw MissingPluginException(
            'SmsSchedulerService has no handler for ${call.method}',
          );
      }
    });
    _handlerWired = true;
  }

  /// Called by the native worker when it boots a Flutter engine and runs
  /// the reminder pass. Queries the org's loans with a due/overdue EMI
  /// (today or earlier) and enqueues a reminder SMS for each into the
  /// durable outbox. Returns the count enqueued.
  ///
  /// Schema assumptions (see supabase/database_comprehensive_fix.sql):
  ///   - public.loans(id, org_id, customer_id, loan_number, status,
  ///                  emi_amount, outstanding_amount)
  ///   - public.loan_schedules(id, loan_id, due_date, is_paid, is_overdue,
  ///                            emi_amount)
  ///   - public.members(id, full_name, phone)
  ///   - public.organizations(id, name)
  ///
  /// Any missing column or table will be caught and surfaced as a
  /// debugPrint; the function returns 0 instead of throwing so the
  /// WorkManager job completes successfully and reschedules itself.
  Future<int> runReminderPass() async {
    if (!_config.reminderEnabled) return 0;
    final orgId = _orgId;
    if (orgId == null) {
      debugPrint('runReminderPass: no orgId, skipping');
      return 0;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayStr = _formatDate(todayDate);

    try {
      // Pull schedules that are due today or earlier and not paid.
      // `members!loans_customer_id_fkey(...)` joins the customer name/phone.
      // We use a simple inner-style select without explicit FK hint and let
      // PostgREST resolve the relationship from `loans.customer_id` ->
      // `members.id`. If the FK name differs the query will fail and we
      // bail out gracefully.
      final response = await _client
          .from('loan_schedules')
          .select(
            'id, due_date, emi_amount, emi, is_paid, is_overdue, '
            'loans!inner(id, org_id, customer_id, loan_number, '
            'emi_amount, outstanding_amount, status, '
            'members!loans_customer_id_fkey(id, full_name, name, phone))',
          )
          .eq('loans.org_id', orgId)
          .lte('due_date', todayStr)
          .eq('is_paid', false)
          .inFilter(
            'loans.status',
            const ['active', 'approved', 'restructured', 'pending'],
          )
          .limit(500);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        debugPrint('runReminderPass: no due schedules for org=$_orgId');
        return 0;
      }

      // Org name (best-effort; not load-bearing for the SMS body).
      String orgName = 'MicroFlow Finance';
      try {
        final org = await _client
            .from('organizations')
            .select('display_name, name')
            .eq('id', orgId)
            .maybeSingle();
        if (org != null) {
          orgName = (org['display_name'] as String?) ??
              (org['name'] as String?) ??
              orgName;
        }
      } catch (_) {
        // Ignore — fall back to default orgName.
      }

      int enqueued = 0;
      for (final row in rows) {
        try {
          final loan =
              (row['loans'] as Map?)?.cast<String, dynamic>();
          if (loan == null) continue;
          final member = (loan['members'] as Map?)?.cast<String, dynamic>();
          final phone = _memberPhone(member);
          if (phone == null || phone.isEmpty) continue;

          final memberName = _memberName(member);
          final loanNumber = (loan['loan_number'] as String?) ?? 'N/A';
          final dueAmount =
              _asDouble(row['emi_amount']) ?? _asDouble(row['emi']) ?? 0;
          final outstanding = _asDouble(loan['outstanding_amount']);
          final dueDate = _parseDate(row['due_date']) ?? todayDate;
          final isOverdue = dueDate.isBefore(todayDate) ||
              (row['is_overdue'] == true);

          final message = _smsService.buildReminderSms(
            memberName: memberName,
            orgName: orgName,
            loanNumber: loanNumber,
            dueAmount: dueAmount,
            outstandingBalance: outstanding,
            dueDate: dueDate,
            isOverdue: isOverdue,
          );

          await _outbox.enqueue(
            phone: phone,
            message: message,
            memberId: member?['id'] as String?,
            recipientName: memberName,
            collectorName: 'system',
            sentBy: 'reminder_worker',
          );
          enqueued++;
        } catch (e) {
          debugPrint('runReminderPass: row enqueue failed: $e');
        }
      }
      debugPrint(
          'runReminderPass: org=$_orgId due=${rows.length} enqueued=$enqueued');
      return enqueued;
    } catch (e, stack) {
      debugPrint('runReminderPass: query failed: $e');
      debugPrint('Stack: $stack');
      return 0;
    }
  }

  // --- helpers ---

  static String _memberName(Map<String, dynamic>? m) {
    if (m == null) return 'Customer';
    return (m['full_name'] as String?) ??
        (m['name'] as String?) ??
        'Customer';
  }

  static String? _memberPhone(Map<String, dynamic>? m) {
    if (m == null) return null;
    for (final k in const ['phone', 'phone_number', 'mobile', 'phone_mobile']) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Riverpod provider for the scheduler service. Depends on the outbox
/// FutureProvider so callers don't need to await outbox initialization
/// themselves.
final smsSchedulerServiceProvider =
    Provider<SmsSchedulerService>((ref) {
  final config = ref.watch(smsConfigProvider);
  final outbox = ref.watch(smsOutboxProvider).requireValue;
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  return SmsSchedulerService(
    config: config,
    outbox: outbox,
    client: client,
    orgId: orgId,
  );
});
