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
  bool _flushing = false;

  CollectionSmsSender(this._smsService, this._client, this._orgId, this._prefs, this._ref)
      : super(const CollectionSmsState());

  Future<bool> _isSmsEnabled(String key) async {
    return _prefs.getBool(key) ?? true;
  }

  /// Enqueue a collection SMS into the durable outbox.
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
  }) async {
    if (phone == null || phone.isEmpty) {
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
    final enabled = await _isSmsEnabled('sms_on_collection');
    if (!enabled) return null;

    final message = _smsService.buildCollectionSms(
      amount: '₹${amount.toStringAsFixed(0)}',
      collectorName: collectorName,
      orgName: orgName ?? 'MicroFlow Finance',
      loanNumber: loanNumber ?? 'N/A',
      outstandingBalance: '₹${outstandingBalance.toStringAsFixed(0)}',
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
    // Best-effort immediate flush so SMS go out without waiting for manual trigger.
    // On failure, the row is already durable in the outbox and will retry on next flush.
    unawaited(flushOutbox(overrideOutbox: outbox));
    return id;
  }

  /// Drain the outbox: for each pending row that's due, send it. Updates
  /// outbox + sms_notifications accordingly. Safe to call on app start and
  /// after sync.
  Future<OutboxFlushResult> flushOutbox({SmsOutboxService? overrideOutbox}) async {
    if (_flushing) {
      return const OutboxFlushResult(sent: 0, failed: 0, retried: 0);
    }
    _flushing = true;
    try {
      final outbox = overrideOutbox ?? await _ref.read(smsOutboxProvider.future);
      if (outbox == null) {
        return const OutboxFlushResult(sent: 0, failed: 0, retried: 0);
      }
      int sent = 0, failed = 0, retried = 0;
      for (final row in outbox.pendingDue()) {
        try {
          await outbox.markSending(row.id);
          final ok = await _smsService.sendSms(
            phoneNumber: row.phone,
            message: row.message,
            requestId: row.id,
          );
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
      _flushing = false;
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

/// Backward-compatible legacy free function. New callers should use
/// `CollectionSmsSender.flushOutbox` via the provider.
Future<void> flushPendingSmsQueue({
  required SmsService smsService,
  required dynamic supabaseClient,
  required String? orgId,
}) async {
  // No-op in the durable-outbox world.
}
