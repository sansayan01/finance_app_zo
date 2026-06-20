// lib/core/providers/sms_provider.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sms_outbox_service.dart';
import '../services/sms_service.dart';
import '../../providers/supabase_provider.dart';
import 'org_provider.dart';
import 'storage_providers.dart';
import 'sms_outbox_provider.dart';

/// Provides the SmsService singleton.
final smsServiceProvider = Provider<SmsService>((ref) => SmsService());

/// Handles sending SMS notifications and logging to Supabase.
/// StateNotifier so its in-flight state survives Riverpod invalidation.
class CollectionSmsSender extends StateNotifier<CollectionSmsState> {
  final SmsService _smsService;
  final dynamic _client;
  final String? _orgId;
  final SharedPreferences _prefs;
  final Ref _ref;

  CollectionSmsSender(this._smsService, this._client, this._orgId, this._prefs, this._ref)
      : super(const CollectionSmsState());

  Future<bool> _isSmsEnabled(String key) async {
    return _prefs.getBool(key) ?? true;
  }

  /// Resolve the organization display name from the DB as a fallback.
  Future<String> _resolveOrgName(String? callerOrgName) async {
    if (callerOrgName != null && callerOrgName.isNotEmpty) return callerOrgName;
    try {
      final response = await _client
          .from('organizations')
          .select('display_name, name')
          .eq('id', _orgId!)
          .maybeSingle();
      return (response?['display_name'] as String?) ??
          (response?['name'] as String?) ??
          'MicroFlow Finance';
    } catch (_) {
      return 'MicroFlow Finance';
    }
  }

  /// Enqueue a collection SMS into the durable outbox.
  ///
  /// [forceDispatch] is for testability only — it bypasses the
  /// Android/iOS platform guard so unit tests can verify outbox-row creation
  /// on a non-mobile host. Never set this in production.
  Future<String?> enqueueCollection({
    required String? phone,
    required String? memberId,
    required String memberName,
    String? loanNumber,
    required double amount,
    required double outstandingBalance,
    required String collectorName,
    required String sentBy,
    String? orgName,
    bool smsEnabled = true,
    bool forceDispatch = false,
  }) async {
    if (phone == null || phone.isEmpty) {
      debugPrint('CollectionSmsSender: skipping enqueueCollection, phone is empty');
      await _logSms(
        memberId: memberId,
        recipientPhone: '',
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'No phone number',
        sentBy: sentBy,
      );
      return null;
    }
    // Skip if member has opted out of SMS notifications
    if (!smsEnabled) {
      debugPrint('CollectionSmsSender: SMS skipped — member ${memberId ?? 'unknown'} has disabled SMS notifications');
      return null;
    }
    final enabled = await _isSmsEnabled('sms_on_collection');
    if (!enabled) {
      debugPrint('CollectionSmsSender: skipping enqueueCollection, sms_on_collection is disabled');
      await _logSms(
        memberId: memberId,
        recipientPhone: phone,
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'SMS on collection disabled in settings',
        sentBy: sentBy,
      );
      return null;
    }

    // Only Android has native programmatic SMS.
    if (!forceDispatch && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('CollectionSmsSender: skipping enqueueCollection, unsupported platform: ${Platform.operatingSystem}');
      await _logSms(
        memberId: memberId,
        recipientPhone: phone,
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'unsupported_platform: ${Platform.operatingSystem}',
        sentBy: sentBy,
      );
      return null;
    }

    // Proactive permission check for Android
    if (Platform.isAndroid && !forceDispatch) {
      final hasPermission = await _smsService.hasSmsPermission();
      if (!hasPermission) {
        debugPrint('CollectionSmsSender: SMS permission missing, requesting...');
        final granted = await _smsService.requestSmsPermission();
        if (!granted) {
          debugPrint('CollectionSmsSender: SMS permission denied by user');
          await _logSms(
            memberId: memberId,
            recipientPhone: phone,
            recipientName: memberName,
            collectorName: collectorName,
            message: '',
            status: 'failed',
            errorMessage: 'SMS permission denied',
            sentBy: sentBy,
          );
          return null;
        }
      }
    }

    final resolvedOrgName = await _resolveOrgName(orgName);
    final message = _smsService.buildCollectionSms(
      amount: '₹${amount.toStringAsFixed(0)}',
      memberName: memberName,
      collectorName: collectorName,
      orgName: resolvedOrgName,
      loanNumber: loanNumber ?? 'N/A',
      outstandingBalance: '₹${outstandingBalance.toStringAsFixed(0)}',
      date: DateTime.now(),
    );

    debugPrint('CollectionSmsSender: enqueuing message to $phone (len: ${message.length})');
    final subId = await _smsService.getSubscriptionId();
    debugPrint('CollectionSmsSender: using SIM subscriptionId: ${subId ?? "default (-1)"}');

    final outbox = await _ref.read(smsOutboxProvider.future);
    final id = await outbox.enqueue(
      phone: phone,
      message: message,
      memberId: memberId,
      recipientName: memberName,
      collectorName: collectorName,
      sentBy: sentBy,
    );
    // Dispatch this single row directly via the static function. This bypasses
    // the StateNotifier so the dispatch survives route teardown (the user's
    // collection page navigates away after enqueue).
    final smsService = _smsService;
    final client = _client;
    final orgId = _orgId;
    unawaited(dispatchOutboxRow(
      outbox: outbox,
      row: OutboxRow(
        id: id,
        phone: phone,
        message: message,
        memberId: memberId,
        recipientName: memberName,
        collectorName: collectorName,
        sentBy: sentBy,
        status: OutboxStatus.pending,
        attempts: 0,
        lastError: null,
        scheduledFor: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      smsService: smsService,
      supabaseClient: client,
      orgId: orgId,
    ));
    return id;
  }

  /// Enqueue a savings deposit SMS into the durable outbox.
  Future<String?> enqueueSavings({
    required String? phone,
    required String? memberId,
    required String memberName,
    String? planName,
    required double amount,
    required double newBalance,
    required String collectorName,
    required String sentBy,
    String? orgName,
    bool smsEnabled = true,
    bool forceDispatch = false,
  }) async {
    if (phone == null || phone.isEmpty) {
      debugPrint('CollectionSmsSender: skipping enqueueSavings, phone is empty');
      await _logSms(
        memberId: memberId,
        recipientPhone: '',
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'No phone number',
        sentBy: sentBy,
      );
      return null;
    }
    // Skip if member has opted out of SMS notifications
    if (!smsEnabled) {
      debugPrint('CollectionSmsSender: SMS skipped — member ${memberId ?? 'unknown'} has disabled SMS notifications');
      return null;
    }
    final enabled = await _isSmsEnabled('sms_on_savings');
    if (!enabled) {
      debugPrint('CollectionSmsSender: skipping enqueueSavings, sms_on_savings is disabled');
      await _logSms(
        memberId: memberId,
        recipientPhone: phone,
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'SMS on savings disabled in settings',
        sentBy: sentBy,
      );
      return null;
    }

    if (!forceDispatch && !Platform.isAndroid && !Platform.isIOS) {
      debugPrint('CollectionSmsSender: skipping enqueueSavings, unsupported platform: ${Platform.operatingSystem}');
      await _logSms(
        memberId: memberId,
        recipientPhone: phone,
        recipientName: memberName,
        collectorName: collectorName,
        message: '',
        status: 'skipped',
        errorMessage: 'unsupported_platform: ${Platform.operatingSystem}',
        sentBy: sentBy,
      );
      return null;
    }

    // Proactive permission check for Android
    if (Platform.isAndroid && !forceDispatch) {
      final hasPermission = await _smsService.hasSmsPermission();
      if (!hasPermission) {
        debugPrint('CollectionSmsSender: SMS permission missing, requesting...');
        final granted = await _smsService.requestSmsPermission();
        if (!granted) {
          debugPrint('CollectionSmsSender: SMS permission denied by user');
          await _logSms(
            memberId: memberId,
            recipientPhone: phone,
            recipientName: memberName,
            collectorName: collectorName,
            message: '',
            status: 'failed',
            errorMessage: 'SMS permission denied',
            sentBy: sentBy,
          );
          return null;
        }
      }
    }

    final resolvedOrgName = await _resolveOrgName(orgName);
    final message = _smsService.buildSavingsSms(
      amount: '₹${amount.toStringAsFixed(0)}',
      memberName: memberName,
      collectorName: collectorName,
      orgName: resolvedOrgName,
      planName: planName,
      newBalance: '₹${newBalance.toStringAsFixed(0)}',
      date: DateTime.now(),
    );

    final outbox = await _ref.read(smsOutboxProvider.future);
    final id = await outbox.enqueue(
      phone: phone,
      message: message,
      memberId: memberId,
      recipientName: memberName,
      collectorName: collectorName,
      sentBy: sentBy,
    );

    final smsService = _smsService;
    final client = _client;
    final orgId = _orgId;
    unawaited(dispatchOutboxRow(
      outbox: outbox,
      row: OutboxRow(
        id: id,
        phone: phone,
        message: message,
        memberId: memberId,
        recipientName: memberName,
        collectorName: collectorName,
        sentBy: sentBy,
        status: OutboxStatus.pending,
        attempts: 0,
        lastError: null,
        scheduledFor: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      smsService: smsService,
      supabaseClient: client,
      orgId: orgId,
    ));
    return id;
  }

  /// Drain the outbox: for each pending row that's due, send it. Updates
  /// outbox + sms_notifications accordingly. Safe to call on app start and
  /// after sync.
  ///
  /// Concurrency: guarded by the module-level `_outboxDispatch` Completer so
  /// this and the static `dispatchOutboxRow` (used by enqueueCollection and
  /// the settings "retry now" tile) cannot overlap.
  Future<OutboxFlushResult> flushOutbox({SmsOutboxService? overrideOutbox}) async {
    if (_outboxDispatch != null && !_outboxDispatch!.isCompleted) {
      return const OutboxFlushResult(sent: 0, failed: 0, retried: 0);
    }
    _outboxDispatch = Completer<void>();
    try {
      final outbox = overrideOutbox ?? await _ref.read(smsOutboxProvider.future);
      if (outbox == null) {
        return const OutboxFlushResult(sent: 0, failed: 0, retried: 0);
      }
      int sent = 0, failed = 0, retried = 0;
      for (final row in outbox.pendingDue()) {
        try {
          await outbox.markSending(row.id);
          // Hard 30s timeout: if the native sender hangs (real-device issue
          // observed when the activity gets torn down mid-send), surface it
          // as an exception so the row is reset to pending and retried.
          final ok = await _smsService
              .sendSms(
                phoneNumber: row.phone,
                message: row.message,
                requestId: row.id,
              )
              .timeout(const Duration(seconds: 30));
          if (ok) {
            await outbox.markSent(row.id);
            await _logSms(
              memberId: row.memberId,
              recipientPhone: row.phone,
              recipientName: row.recipientName ?? '',
              collectorName: row.collectorName ?? '',
              message: row.message,
              status: 'sent',
              sentBy: row.sentBy,
            );
            state = state.copyWith(lastSentCount: state.lastSentCount + 1, lastRun: DateTime.now());
            sent++;
          } else {
            await outbox.markFailed(row.id, 'SEND_FAILED');
            if (outbox.get(row.id)!.status == OutboxStatus.dead) {
              await _logSms(
                memberId: row.memberId,
                recipientPhone: row.phone,
                recipientName: row.recipientName ?? '',
                collectorName: row.collectorName ?? '',
                message: row.message,
                status: 'failed',
                errorMessage: 'Dead-letter after 3 attempts',
                sentBy: row.sentBy,
              );
              state = state.copyWith(lastFailedCount: state.lastFailedCount + 1);
              failed++;
            } else {
              state = state.copyWith(lastRetriedCount: state.lastRetriedCount + 1);
              retried++;
            }
          }
        } catch (e) {
          // Exception during send: mark failed so the row re-enters the retry
          // pipeline (otherwise it'd be stuck in `sending` until process restart).
          await outbox.markFailed(row.id, 'EXCEPTION');
          state = state.copyWith(lastRetriedCount: state.lastRetriedCount + 1);
          retried++;
          debugPrint('flushOutbox exception on row ${row.id}: $e');
        }
      }
      return OutboxFlushResult(sent: sent, failed: failed, retried: retried);
    } finally {
      _outboxDispatch!.complete();
      _outboxDispatch = null;
    }
  }

  Future<void> _logSms({
    String? collectionId,
    String? memberId,
    required String recipientPhone,
    required String recipientName,
    required String collectorName,
    required String message,
    required String status,
    String? errorMessage,
    required String sentBy,
  }) async {
    try {
      await _client.from('sms_notifications').insert({
        'org_id': _orgId,
        if (collectionId != null) 'collection_id': collectionId,
        'member_id': memberId,
        'member_phone': recipientPhone,
        'recipient_phone': recipientPhone,
        'recipient_name': recipientName,
        'collector_name': collectorName,
        'message': message,
        'status': status,
        'error_message': errorMessage,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'sent_by': sentBy,
      });
    } catch (e, stack) {
      debugPrint('Failed to log SMS notification: $e');
      debugPrint('Stack: $stack');
    }
  }
}

/// Module-level in-flight guard. Because `dispatchOutboxRow` is a static
/// function (it has to be — it must survive StateNotifier invalidation), the
/// per-instance `_flushing` flag on `CollectionSmsSender` cannot see it. A
/// top-level Completer is the simplest single source of truth: at most one
/// dispatch or flush runs at a time, no matter who calls in.
Completer<void>? _outboxDispatch;

/// Dispatch a single outbox row to the platform. Bypasses the StateNotifier
/// so it survives route teardown. Returns true if the row was sent.
///
/// Why this exists: when the user records a collection, the page navigates
/// away almost immediately. The previous path called `flushOutbox` from
/// `enqueueCollection` with `unawaited(...)`. If the StateNotifier was
/// autoDispose'd or its `Ref` went stale before the future resolved, the
/// in-flight `sendSms` call was effectively cancelled and the row was left
/// stuck in `sending`. This function holds no Riverpod state of its own
/// beyond the explicit outbox handle, so it cannot be invalidated mid-flight.
Future<bool> dispatchOutboxRow({
  required SmsOutboxService outbox,
  required OutboxRow row,
  required SmsService smsService,
  required dynamic supabaseClient,
  required String? orgId,
}) async {
  // Bug C fix: serialize all dispatch entry points (static dispatchOutboxRow,
  // instance flushOutbox, settings-page retry tile) through one lock.
  if (_outboxDispatch != null && !_outboxDispatch!.isCompleted) {
    debugPrint('dispatchOutboxRow: skipped (another dispatch in flight)');
    return false;
  }
  _outboxDispatch = Completer<void>();
  try {
    debugPrint('dispatchOutboxRow start: id=${row.id}, phone=${row.phone}, '
        'messageLen=${row.message.length}, attempts=${row.attempts}');
    try {
      await outbox.markSending(row.id);
      debugPrint('dispatchOutboxRow: marked sending');
      // 30s hard timeout: if the native sender hangs, treat as a failure
      // and let the outbox retry pipeline take over.
      debugPrint('dispatchOutboxRow: calling sendSms...');
      final ok = await smsService
          .sendSms(
            phoneNumber: row.phone,
            message: row.message,
            requestId: row.id,
          )
          .timeout(const Duration(seconds: 30));
      debugPrint('dispatchOutboxRow: sendSms returned: $ok');
      if (ok) {
        // Bug B note: on iOS, sendSms only confirms the system SMS composer
        // was launched — there is no programmatic way to know if the user
        // actually sent the message. We mark the outbox row as `sent` (we
        // can't retry a human-cancelled composer-open anyway) but log the
        // history row as `composer_opened` so the UI can distinguish
        // confirmed sends from best-effort compose-opens.
        final isIos = Platform.isIOS;
        await outbox.markSent(row.id);
        debugPrint('dispatchOutboxRow: marked sent');
        try {
          await supabaseClient.from('sms_notifications').insert({
            'org_id': orgId,
            'member_id': row.memberId,
            'member_phone': row.phone,
            'recipient_phone': row.phone,
            'recipient_name': row.recipientName,
            'collector_name': row.collectorName,
            'message': row.message,
            'status': isIos ? 'composer_opened' : 'sent',
            'platform': isIos ? 'ios' : 'android',
            'sent_by': row.sentBy,
          });
          debugPrint('dispatchOutboxRow: sms_notifications insert: ok=true');
        } catch (e, stack) {
          debugPrint('dispatchOutboxRow: sms_notifications insert: ok=false, error=$e');
          debugPrint('Stack: $stack');
        }
        debugPrint('dispatchOutboxRow: end (sent)');
        return true;
      } else {
        // Bug A fix: native send returned false — must call markFailed so the
        // attempt counter increments and the row re-enters the backoff
        // pipeline. Previously we only read attempts/lastError, leaving the
        // row stuck in `sending` until process restart.
        await outbox.markFailed(row.id, 'SEND_FAILED');
        final updated = outbox.get(row.id);
        final attempts = updated?.attempts ?? row.attempts;
        final lastError = updated?.lastError ?? 'SEND_FAILED';
        debugPrint('dispatchOutboxRow: marked failed (attempts=$attempts, lastError=$lastError)');
        // If the row just hit the dead-letter threshold, log a 'failed'
        // history row so the user sees the dead-letter in SMS history.
        if (updated?.status == OutboxStatus.dead) {
          try {
            await supabaseClient.from('sms_notifications').insert({
              'org_id': orgId,
              'member_id': row.memberId,
              'member_phone': row.phone,
              'recipient_phone': row.phone,
              'recipient_name': row.recipientName,
              'collector_name': row.collectorName,
              'message': row.message,
              'status': 'failed',
              'error_message': 'Dead-letter after $attempts attempts: $lastError',
              'platform': Platform.isAndroid ? 'android' : 'ios',
              'sent_by': row.sentBy,
            });
            debugPrint('dispatchOutboxRow: dead-letter sms_notifications insert: ok=true');
          } catch (e, stack) {
            debugPrint('dispatchOutboxRow: dead-letter sms_notifications insert failed: $e');
            debugPrint('Stack: $stack');
          }
        }
        debugPrint('dispatchOutboxRow: end (send-fail)');
        return false;
      }
    } catch (e, stack) {
      debugPrint('dispatchOutboxRow: exception for row ${row.id}: $e');
      debugPrint('Stack: $stack');
      try {
        await outbox.markFailed(row.id, 'EXCEPTION');
      } catch (_) {}
      debugPrint('dispatchOutboxRow: end (exception)');
      return false;
    }
  } finally {
    _outboxDispatch!.complete();
    _outboxDispatch = null;
  }
}

class CollectionSmsState {
  final int lastSentCount;
  final int lastFailedCount;
  final int lastRetriedCount;
  final DateTime? lastRun;
  const CollectionSmsState({
    this.lastSentCount = 0,
    this.lastFailedCount = 0,
    this.lastRetriedCount = 0,
    this.lastRun,
  });
  CollectionSmsState copyWith({
    int? lastSentCount,
    int? lastFailedCount,
    int? lastRetriedCount,
    DateTime? lastRun,
  }) =>
      CollectionSmsState(
        lastSentCount: lastSentCount ?? this.lastSentCount,
        lastFailedCount: lastFailedCount ?? this.lastFailedCount,
        lastRetriedCount: lastRetriedCount ?? this.lastRetriedCount,
        lastRun: lastRun ?? this.lastRun,
      );
}

class OutboxFlushResult {
  final int sent;
  final int failed;
  final int retried;
  const OutboxFlushResult({required this.sent, required this.failed, required this.retried});
}

final collectionSmsSenderProvider =
    StateNotifierProvider<CollectionSmsSender, CollectionSmsState>((ref) {
  final smsService = ref.watch(smsServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return CollectionSmsSender(smsService, client, orgId, prefs, ref);
});
