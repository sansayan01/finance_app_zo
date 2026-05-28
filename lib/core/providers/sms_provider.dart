import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/sms_service.dart';
import '../../providers/supabase_provider.dart';
import 'org_provider.dart';
import '../../features/staff/data/models/collection_model.dart';

/// Provides the SmsService singleton.
final smsServiceProvider = Provider<SmsService>((ref) => SmsService());

/// Whether SMS permission is currently granted.
final smsPermissionProvider = FutureProvider<bool>((ref) async {
  if (Platform.isAndroid) {
    return (await Permission.sms.status).isGranted;
  }
  // iOS uses sms: URI — no permission needed.
  return true;
});

/// Handles sending collection SMS notifications and logging to Supabase.
class CollectionSmsSender {
  final SmsService _smsService;
  final dynamic _client; // SupabaseClient
  final String? _orgId;

  CollectionSmsSender(this._smsService, this._client, this._orgId);

  /// Send an SMS notification for a collection.
  /// Fires in background — never throws, never blocks the collection flow.
  Future<void> sendCollectionSms({
    required CollectionModel collection,
    required String collectorName,
    String? orgName,
  }) async {
    try {
      final phone = collection.memberPhone;
      if (phone == null || phone.isEmpty) {
        await _logSms(
          collection: collection,
          collectorName: collectorName,
          recipientPhone: phone ?? '',
          message: '',
          status: 'skipped',
          errorMessage: 'No phone number',
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

      await _logSms(
        collection: collection,
        collectorName: collectorName,
        recipientPhone: phone,
        message: message,
        status: sent ? 'sent' : 'failed',
        errorMessage: sent ? null : 'SMS dispatch returned false',
      );
    } catch (e) {
      debugPrint('Collection SMS failed: $e');
      await _logSms(
        collection: collection,
        collectorName: collectorName,
        recipientPhone: collection.memberPhone ?? '',
        message: '',
        status: 'failed',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _logSms({
    required CollectionModel collection,
    required String collectorName,
    required String recipientPhone,
    required String message,
    required String status,
    String? errorMessage,
  }) async {
    try {
      await _client.from('sms_notifications').insert({
        'org_id': _orgId,
        'collection_id': collection.id,
        'member_id': collection.memberId,
        'member_phone': recipientPhone,
        'recipient_phone': recipientPhone,
        'recipient_name': collection.memberName,
        'collector_name': collectorName,
        'message': message,
        'status': status,
        'error_message': errorMessage,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'sent_by': collection.staffId,
      });
    } catch (e) {
      debugPrint('Failed to log SMS notification: $e');
    }
  }
}

/// Provides the CollectionSmsSender.
final collectionSmsSenderProvider = Provider<CollectionSmsSender>((ref) {
  final smsService = ref.watch(smsServiceProvider);
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  return CollectionSmsSender(smsService, client, orgId);
});
