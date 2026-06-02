import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/core/services/sms_service.dart';

void main() {
  final svc = SmsService();

  test('buildCollectionSms includes all required fields', () {
    final msg = svc.buildCollectionSms(
      amount: '₹500',
      collectorName: 'Ravi',
      orgName: 'Acme',
      loanNumber: 'L-1',
      outstandingBalance: '₹4500',
      date: DateTime(2026, 6, 2, 10, 30),
    );
    expect(msg, contains('₹500'));
    expect(msg, contains('Ravi'));
    expect(msg, contains('Acme'));
    expect(msg, contains('L-1'));
    expect(msg, contains('02-Jun-2026'));
  });

  test('buildSavingsSms uses plan name when provided', () {
    final msg = svc.buildSavingsSms(
      amount: '₹200',
      collectorName: 'Ravi',
      orgName: 'Acme',
      planName: 'Gold',
      newBalance: 1500,
      date: DateTime(2026, 6, 2),
    );
    expect(msg, contains('Gold'));
    expect(msg, contains('₹1500'));
  });

  test('buildReminderSms marks overdue correctly', () {
    final msg = svc.buildReminderSms(
      memberName: 'Alice',
      orgName: 'Acme',
      loanNumber: 'L-1',
      dueAmount: 500,
      outstandingBalance: 4500,
      dueDate: DateTime(2026, 6, 2),
      isOverdue: true,
    );
    expect(msg, contains('OVERDUE'));
    expect(msg, contains('Alice'));
  });
}
