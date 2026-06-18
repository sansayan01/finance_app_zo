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

/// Thrown when [SmsService.pickSubscription] is called but the user has not
/// granted SEND_SMS permission. The UI should request the permission and
/// re-invoke pickSubscription.
class SmsPermissionRequiredException implements Exception {
  final String message;
  SmsPermissionRequiredException(this.message);

  @override
  String toString() => 'SmsPermissionRequiredException: $message';
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
    // Normalize phone number: remove all non-digit characters except leading '+'
    // This handles spaces, dashes, and other formatting that SmsManager might reject.
    final normalizedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (Platform.isAndroid) {
      return _sendAndroidSms(normalizedPhone, message, requestId, subscriptionId);
    } else {
      return _sendIosSms(normalizedPhone, message);
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
    // Bug B fix: launchUrl returns true the moment the system SMS composer
    // opens — not when the user taps Send. Treat any exception as a failure
    // and otherwise return the actual launch result so the dispatcher can
    // log a 'composer_opened' status instead of 'sent'.
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('iOS sms composer launch failed for $phone: $e');
      return false;
    }
  }

  /// Returns the list of active subscriptions on Android. Empty on iOS.
  ///
  /// Throws [SmsPermissionRequiredException] if SEND_SMS is not granted —
  /// callers must check/request the permission first.
  Future<List<SmsSubscription>> pickSubscription() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('pick_subscription');
      return (raw ?? []).map((e) => SmsSubscription.fromMap(e)).toList();
    } on PlatformException catch (e) {
      if (e.code == 'NEEDS_SMS_PERMISSION') {
        throw SmsPermissionRequiredException(
          e.message ?? 'SMS permission required',
        );
      }
      rethrow;
    }
  }

  /// True if SEND_SMS is currently granted. Always true on non-Android.
  Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return true;
    final granted = await _channel.invokeMethod<bool>('check_permission');
    return granted == true;
  }

  /// Prompts the user for SEND_SMS. Returns true on grant.
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return true;
    final granted = await _channel.invokeMethod<bool>('request_permission');
    return granted == true;
  }

  /// Opens the app's system settings page so the user can grant optional
  /// permissions (e.g. phone-state access for multi-SIM selection).
  Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('open_app_settings');
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

  /// Build the SMS message for a collection (loan repayment) receipt.
  ///
  /// Professional, white-labeled receipt format:
  /// ━━━━━━━━━━━━━━━━━━━
  /// [OrgName]
  /// PAYMENT RECEIVED ✓
  /// ━━━━━━━━━━━━━━━━━━━
  String buildCollectionSms({
    required String amount,
    required String memberName,
    required String collectorName,
    required String orgName,
    required String loanNumber,
    required String outstandingBalance,
    required DateTime date,
  }) {
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);
    return '$orgName\n'
        'Payment Received\n'
        '─────────────\n'
        'Dear $memberName,\n'
        'Amount: $amount\n'
        'Loan: $loanNumber\n'
        'Outstanding: $outstandingBalance\n'
        'Collected by: $collectorName\n'
        'Date: $dateStr, $timeStr\n'
        '─────────────\n'
        'Thank you for your payment!';
  }

  /// Build the SMS message for a savings deposit receipt.
  String buildSavingsSms({
    required String amount,
    required String memberName,
    required String collectorName,
    required String orgName,
    required String? planName,
    required double newBalance,
    required DateTime date,
  }) {
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);
    final plan = planName != null && planName.isNotEmpty ? planName : 'Savings';
    return '$orgName\n'
        'Deposit Received\n'
        '─────────────\n'
        'Dear $memberName,\n'
        'Amount: $amount\n'
        'Plan: $plan\n'
        'Balance: ₹${newBalance.toStringAsFixed(0)}\n'
        'Collected by: $collectorName\n'
        'Date: $dateStr, $timeStr\n'
        '─────────────\n'
        'Thank you for saving with us!';
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
    final dateStr = DateFormat('dd MMM yyyy').format(dueDate);
    if (isOverdue) {
      return '$orgName\n'
          'OVERDUE PAYMENT\n'
          '─────────────\n'
          'Hi $memberName,\n'
          'EMI of ₹${dueAmount.toStringAsFixed(0)} was due on $dateStr.\n'
          'Loan: $loanNumber\n'
          '${outstandingBalance != null ? 'Outstanding: ₹${outstandingBalance.toStringAsFixed(0)}\n' : ''}'
          '─────────────\n'
          'Please clear dues to avoid late fees.';
    }
    return '$orgName\n'
        'EMI Reminder\n'
        '─────────────\n'
        'Hi $memberName,\n'
        'Your EMI of ₹${dueAmount.toStringAsFixed(0)} is due on $dateStr.\n'
        'Loan: $loanNumber\n'
        '${outstandingBalance != null ? 'Outstanding: ₹${outstandingBalance.toStringAsFixed(0)}\n' : ''}'
        '─────────────\n'
        'Pay on time to avoid late charges.';
  }
}
