// lib/core/services/sms_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsSubscription {
  final int subscriptionId;
  final int simSlotIndex;
  final String carrierName;
  final String displayName;

  SmsSubscription({
    required this.subscriptionId,
    required this.simSlotIndex,
    required this.carrierName,
    required this.displayName,
  });

  factory SmsSubscription.fromMap(Map<dynamic, dynamic> m) => SmsSubscription(
        subscriptionId: m['subscription_id'] as int,
        simSlotIndex: m['sim_slot_index'] as int,
        carrierName: (m['carrier_name'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
      );
}

class SmsService {
  static const _channel = MethodChannel('com.microflow/sms');
  static const _prefsKey = 'sms_subscription_id';

  /// Send SMS via the native sender. Returns true on success.
  /// [requestId] must be a unique UUID per call; [subscriptionId] is the
  /// Android `SubscriptionInfo.subscriptionId` to bind to (use null for default).
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    required String requestId,
    int? subscriptionId,
  }) async {
    if (Platform.isAndroid) {
      return _sendAndroidSms(phoneNumber, message, requestId, subscriptionId);
    } else {
      return _sendIosSms(phoneNumber, message);
    }
  }

  Future<bool> _sendAndroidSms(
      String phone, String msg, String requestId, int? subId) async {
    try {
      // Resolve subscription from prefs if not passed in
      final resolvedSubId = subId ?? await _readSubscriptionId();
      final result = await _channel.invokeMethod<bool>('send_sms', {
        'phone': phone,
        'message': msg,
        'request_id': requestId,
        'subscription_id': resolvedSubId ?? -1,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('SMS send failed for $phone: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('SMS send failed for $phone: $e');
      return false;
    }
  }

  Future<bool> _sendIosSms(String phone, String msg) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': msg},
    );
    return launchUrl(uri);
  }

  /// Returns the list of active subscriptions on Android. Empty on iOS.
  Future<List<SmsSubscription>> pickSubscription() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _channel.invokeMethod<List<dynamic>>('pick_subscription');
    return (raw ?? []).map((e) => SmsSubscription.fromMap(e)).toList();
  }

  /// Persist the chosen subscription id.
  Future<void> setSubscription(int subscriptionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, subscriptionId);
    if (Platform.isAndroid) {
      await _channel.invokeMethod('set_subscription', {'subscription_id': subscriptionId});
    }
  }

  /// Currently bound subscription id, or null if using the OS default.
  Future<int?> getSubscriptionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey);
  }

  Future<int?> _readSubscriptionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKey);
  }

  /// Send a one-off test SMS and return the native result as a string.
  /// Bypasses the outbox.
  Future<String> sendTestSms({required String phone, required String message}) async {
    final requestId = 'test_${DateTime.now().microsecondsSinceEpoch}';
    final ok = await sendSms(
      phoneNumber: phone,
      message: message,
      requestId: requestId,
    );
    return ok ? 'Sent successfully' : 'Send failed (check logs or run adb logcat)';
  }

  /// Build the SMS message for a collection notification.
  String buildCollectionSms({
    required String amount,
    required String collectorName,
    required String orgName,
    required String loanNumber,
    required String outstandingBalance,
    required DateTime date,
  }) {
    final dateStr = DateFormat('dd-MMM-yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);
    return '$amount received from $collectorName, $orgName.\n'
        'Loan: $loanNumber | Bal: $outstandingBalance\n'
        'Date: $dateStr $timeStr\n'
        'Thank you!';
  }

  /// Build the SMS message for a savings deposit notification.
  String buildSavingsSms({
    required String amount,
    required String collectorName,
    required String orgName,
    required String? planName,
    required double newBalance,
    required DateTime date,
  }) {
    final dateStr = DateFormat('dd-MMM-yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);
    final plan = planName != null && planName.isNotEmpty ? planName : 'Savings';
    return '$amount deposited to $plan by $collectorName, $orgName.\n'
        'New Balance: ₹${newBalance.toStringAsFixed(0)}\n'
        'Date: $dateStr $timeStr\n'
        'Thank you!';
  }

  /// Build a reminder SMS for a due or overdue EMI.
  String buildReminderSms({
    required String memberName,
    required String orgName,
    required String loanNumber,
    required double dueAmount,
    required double? outstandingBalance,
    required DateTime dueDate,
    bool isOverdue = false,
  }) {
    final dateStr = DateFormat('dd-MMM-yyyy').format(dueDate);
    final label = isOverdue ? 'OVERDUE' : 'DUE';
    final bal = outstandingBalance != null
        ? 'Balance: ₹${outstandingBalance.toStringAsFixed(0)}'
        : '';
    return 'Hi $memberName,\n'
        'Your EMI of ₹${dueAmount.toStringAsFixed(0)} is $label on $dateStr.\n'
        'Loan: $loanNumber | $bal\n'
        '$orgName\n'
        'Please pay on time to avoid late charges. Thank you!';
  }
}
