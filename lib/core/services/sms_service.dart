import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  static const _channel = MethodChannel('com.microflow/sms');

  /// Send SMS silently on Android or via Messages intent on iOS.
  /// Returns true if the SMS was dispatched successfully.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    if (Platform.isAndroid) {
      return _sendAndroidSms(phoneNumber, message);
    } else {
      return _sendIosSms(phoneNumber, message);
    }
  }

  Future<bool> _sendAndroidSms(String phone, String msg) async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      debugPrint('SMS permission not granted');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('send_sms', {
        'phone': phone,
        'message': msg,
      });
      return result == true;
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
