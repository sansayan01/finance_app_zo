import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sms_service.dart';
import '../../providers/supabase_provider.dart';
import 'org_provider.dart';
import 'storage_providers.dart';
import '../../features/staff/data/models/collection_model.dart';

/// Provides the SmsService singleton.
final smsServiceProvider = Provider<SmsService>((ref) => SmsService());

/// Whether SMS permission is currently granted.
final smsPermissionProvider = FutureProvider<bool>((ref) async {
  if (Platform.isAndroid) {
    return (await Permission.sms.status).isGranted;
  }
  return true;
});

// ─── Offline SMS Queue ────────────────────────────────────────────────

const _pendingSmsQueueKey = 'pending_sms_queue';

Future<void> queuePendingSms(Map<String, dynamic> smsData) async {
  final prefs = await SharedPreferences.getInstance();
  final queueStr = prefs.getString(_pendingSmsQueueKey);
  final queue = queueStr != null
      ? (jsonDecode(queueStr) as List).cast<Map<String, dynamic>>()
      : <Map<String, dynamic>>[];
  smsData['queued_at'] = DateTime.now().toIso8601String();
  smsData['attempts'] = 0;
  queue.add(smsData);
  await prefs.setString(_pendingSmsQueueKey, jsonEncode(queue));
}

Future<void> flushPendingSmsQueue({
  required SmsService smsService,
  required dynamic supabaseClient,
  required String? orgId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final queueStr = prefs.getString(_pendingSmsQueueKey);
  if (queueStr == null) return;

  final queue = (jsonDecode(queueStr) as List).cast<Map<String, dynamic>>();
  if (queue.isEmpty) return;

  final remaining = <Map<String, dynamic>>[];
  for (final item in queue) {
    try {
      final phone = item['phone'] as String;
      final message = item['message'] as String;
      final sent = await smsService.sendSms(phoneNumber: phone, message: message);
      if (sent && supabaseClient != null) {
        await supabaseClient.from('sms_notifications').insert({
          'org_id': orgId,
          'member_id': item['member_id'],
          'member_phone': phone,
          'recipient_phone': phone,
          'recipient_name': item['recipient_name'],
          'collector_name': item['collector_name'],
          'message': message,
          'status': 'sent',
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'sent_by': item['sent_by'],
        });
      }
    } catch (_) {
      item['attempts'] = (item['attempts'] as int? ?? 0) + 1;
      if ((item['attempts'] as int) < 5) {
        remaining.add(item);
      }
    }
  }

  await prefs.setString(_pendingSmsQueueKey, jsonEncode(remaining));
}

/// Handles sending SMS notifications and logging to Supabase.
class CollectionSmsSender {
  final SmsService _smsService;
  final dynamic _client;
  final String? _orgId;
  final SharedPreferences _prefs;

  CollectionSmsSender(this._smsService, this._client, this._orgId, this._prefs);

  Future<bool> _isSmsEnabled(String key) async {
    return _prefs.getBool(key) ?? true;
  }

  /// Send an SMS notification for a collection.
  Future<void> sendCollectionSms({
    required CollectionModel collection,
    required String collectorName,
    String? orgName,
  }) async {
    final enabled = await _isSmsEnabled('sms_on_collection');
    if (!enabled) return;

    try {
      final phone = collection.memberPhone;
      if (phone == null || phone.isEmpty) {
        await _logSms(
          collectionId: collection.id,
          memberId: collection.memberId,
          recipientPhone: '',
          recipientName: collection.memberName,
          collectorName: collectorName,
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
          sentBy: collection.staffId,
        );
        return;
      }

      final message = _smsService.buildCollectionSms(
        amount: '₹${collection.amountCollected.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName ?? 'MicroFlow Finance',
        loanNumber: collection.loanNumber ?? 'N/A',
        outstandingBalance: '₹${collection.amountExpected.toStringAsFixed(0)}',
        date: collection.collectionTime,
      );

      final sent = await _smsService.sendSms(
        phoneNumber: phone,
        message: message,
      );

      if (sent) {
        await _logSms(
          collectionId: collection.id,
          memberId: collection.memberId,
          recipientPhone: phone,
          recipientName: collection.memberName,
          collectorName: collectorName,
          message: message,
          status: 'sent',
          sentBy: collection.staffId,
        );
      } else {
        await _queueOrLogFailure(
          collectionId: collection.id,
          memberId: collection.memberId,
          recipientPhone: phone,
          recipientName: collection.memberName,
          collectorName: collectorName,
          message: message,
          sentBy: collection.staffId,
        );
      }
    } catch (e) {
      debugPrint('Collection SMS failed: $e');
      await _queueOrLogFailure(
        collectionId: collection.id,
        memberId: collection.memberId,
        recipientPhone: collection.memberPhone ?? '',
        recipientName: collection.memberName,
        collectorName: collectorName,
        message: _smsService.buildCollectionSms(
          amount: '₹${collection.amountCollected.toStringAsFixed(0)}',
          collectorName: collectorName,
          orgName: orgName ?? 'MicroFlow Finance',
          loanNumber: collection.loanNumber ?? 'N/A',
          outstandingBalance: '₹${collection.amountExpected.toStringAsFixed(0)}',
          date: collection.collectionTime,
        ),
        sentBy: collection.staffId,
      );
    }
  }

  /// Send SMS for an EMI payment collection.
  Future<void> sendEmiSms({
    required String? memberPhone,
    required String memberName,
    required String? memberId,
    required String? loanNumber,
    required double amount,
    required double? outstandingBalance,
    required String staffId,
    required String collectorName,
    String? orgName,
    String? paymentId,
  }) async {
    final enabled = await _isSmsEnabled('sms_on_collection');
    if (!enabled) return;

    try {
      if (memberPhone == null || memberPhone.isEmpty) {
        await _logSms(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: '',
          recipientName: memberName,
          collectorName: collectorName,
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
          sentBy: staffId,
        );
        return;
      }

      final balance = outstandingBalance != null
          ? '₹${outstandingBalance.toStringAsFixed(0)}'
          : 'N/A';

      final message = _smsService.buildCollectionSms(
        amount: '₹${amount.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName ?? 'MicroFlow Finance',
        loanNumber: loanNumber ?? 'N/A',
        outstandingBalance: balance,
        date: DateTime.now(),
      );

      final sent = await _smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      if (sent) {
        await _logSms(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: memberPhone,
          recipientName: memberName,
          collectorName: collectorName,
          message: message,
          status: 'sent',
          sentBy: staffId,
        );
      } else {
        await _queueOrLogFailure(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: memberPhone,
          recipientName: memberName,
          collectorName: collectorName,
          message: message,
          sentBy: staffId,
        );
      }
    } catch (e) {
      debugPrint('EMI SMS error: $e');
    }
  }

  /// Send SMS for a savings deposit.
  Future<void> sendSavingsSms({
    required String? memberPhone,
    required String memberName,
    required String? memberId,
    required double amount,
    required String? planName,
    required double newBalance,
    required String staffId,
    required String collectorName,
    String? orgName,
    String? paymentId,
  }) async {
    final enabled = await _isSmsEnabled('sms_on_savings');
    if (!enabled) return;

    try {
      if (memberPhone == null || memberPhone.isEmpty) {
        await _logSms(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: '',
          recipientName: memberName,
          collectorName: collectorName,
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
          sentBy: staffId,
        );
        return;
      }

      final message = _smsService.buildSavingsSms(
        amount: '₹${amount.toStringAsFixed(0)}',
        collectorName: collectorName,
        orgName: orgName ?? 'MicroFlow Finance',
        planName: planName,
        newBalance: newBalance,
        date: DateTime.now(),
      );

      final sent = await _smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      if (sent) {
        await _logSms(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: memberPhone,
          recipientName: memberName,
          collectorName: collectorName,
          message: message,
          status: 'sent',
          sentBy: staffId,
        );
      } else {
        await _queueOrLogFailure(
          collectionId: paymentId,
          memberId: memberId,
          recipientPhone: memberPhone,
          recipientName: memberName,
          collectorName: collectorName,
          message: message,
          sentBy: staffId,
        );
      }
    } catch (e) {
      debugPrint('Savings SMS error: $e');
    }
  }

  /// Send a reminder SMS for a due/overdue EMI.
  Future<void> sendReminderSms({
    required String memberPhone,
    required String memberName,
    required String? memberId,
    required String loanNumber,
    required double dueAmount,
    required double? outstandingBalance,
    required DateTime dueDate,
    required String staffId,
    String? orgName,
    bool isOverdue = false,
  }) async {
    try {
      final message = _smsService.buildReminderSms(
        memberName: memberName,
        orgName: orgName ?? 'MicroFlow Finance',
        loanNumber: loanNumber,
        dueAmount: dueAmount,
        outstandingBalance: outstandingBalance,
        dueDate: dueDate,
        isOverdue: isOverdue,
      );

      final sent = await _smsService.sendSms(
        phoneNumber: memberPhone,
        message: message,
      );

      await _logSms(
        memberId: memberId,
        recipientPhone: memberPhone,
        recipientName: memberName,
        collectorName: 'Auto-Reminder',
        message: message,
        status: sent ? 'sent' : 'failed',
        sentBy: staffId,
      );
    } catch (e) {
      debugPrint('Reminder SMS error: $e');
    }
  }

  Future<void> _queueOrLogFailure({
    String? collectionId,
    String? memberId,
    required String recipientPhone,
    required String recipientName,
    required String collectorName,
    required String message,
    required String sentBy,
  }) async {
    // Try offline queue first
    try {
      await queuePendingSms({
        'phone': recipientPhone,
        'message': message,
        'member_id': memberId,
        'recipient_name': recipientName,
        'collector_name': collectorName,
        'sent_by': sentBy,
      });
    } catch (_) {
      // If queue itself fails, log as failed
      await _logSms(
        collectionId: collectionId,
        memberId: memberId,
        recipientPhone: recipientPhone,
        recipientName: recipientName,
        collectorName: collectorName,
        message: message,
        status: 'failed',
        errorMessage: 'SMS dispatch failed, queued offline',
        sentBy: sentBy,
      );
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
    } catch (e) {
      debugPrint('Failed to log SMS notification: $e');
    }
  }
}

final collectionSmsSenderProvider = Provider<CollectionSmsSender>((ref) {
  final smsService = ref.watch(smsServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return CollectionSmsSender(smsService, client, orgId, prefs);
});
