import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/core/services/sms_service.dart';

void main() {
  final svc = SmsService();

  test('buildCollectionSms includes all required fields', () {
    final msg = svc.buildCollectionSms(
      amount: '₹500',
      memberName: 'Suresh',
      collectorName: 'Ravi',
      orgName: 'Acme',
      loanNumber: 'L-1',
      outstandingBalance: '₹4500',
      date: DateTime(2026, 6, 2, 10, 30),
    );
    expect(msg, contains('500'));
    expect(msg, contains('L-1'));
    // Member + collector names + org name are uppercased as visual emphasis.
    expect(msg, contains('SURESH'));
    expect(msg, contains('RAVI'));
    expect(msg, contains('ACME'));
  });

  test('buildLoanClosedSms renders card format', () {
    final msg = svc.buildLoanClosedSms(
      memberName: 'Priya',
      orgName: 'Acme',
      loanNumber: 'L-2',
      totalPaid: '₹12000',
      closedDate: DateTime(2026, 6, 2),
    );
    expect(msg, contains('PRIYA'));
    expect(msg, contains('L-2'));
    expect(msg, contains('Loan Closed'));
    expect(msg, contains('ACME'));
  });

  test('buildPartialPaymentSms mentions next due date', () {
    final msg = svc.buildPartialPaymentSms(
      memberName: 'Anil',
      collectorName: 'Ravi',
      orgName: 'Acme',
      loanNumber: 'L-3',
      amount: '₹1000',
      outstandingBalance: '₹3000',
      fullAmount: '₹3000',
      date: DateTime(2026, 6, 2),
      nextDueDate: DateTime(2026, 6, 16),
    );
    expect(msg, contains('ANIL'));
    expect(msg, contains('RAVI'));
    expect(msg, contains('ACME'));
    expect(msg, contains('Pay full'));
  });

  test('buildSavingsSms uses plan name when provided', () {
    final msg = svc.buildSavingsSms(
      amount: '₹200',
      memberName: 'Priya',
      collectorName: 'Ravi',
      orgName: 'Acme',
      planName: 'Gold',
      newBalance: 1500,
      date: DateTime(2026, 6, 2),
    );
    expect(msg, contains('Gold'));
    expect(msg, contains('₹1500'));
    expect(msg, contains('Priya'));
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
    expect(msg, contains('Alice'));
    expect(msg, contains('Clear dues'));
  });
}
