import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/payments/data/models/upi_payment_request_model.dart';

void main() {
  group('UpiPaymentRequest Status Normalization', () {
    test('isPending is true for lowercase, uppercase, and padded pending status', () {
      final req1 = UpiPaymentRequest(
        id: '1',
        orgId: 'org1',
        customerId: 'cust1',
        amount: 100,
        upiVpa: 'test@upi',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(req1.isPending, isTrue);

      final req2 = UpiPaymentRequest(
        id: '2',
        orgId: 'org1',
        customerId: 'cust1',
        amount: 100,
        upiVpa: 'test@upi',
        status: ' PENDING  ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(req2.isPending, isTrue);
    });

    test('isConfirmed and isRejected work with casing/spaces', () {
      final req1 = UpiPaymentRequest(
        id: '1',
        orgId: 'org1',
        customerId: 'cust1',
        amount: 100,
        upiVpa: 'test@upi',
        status: ' CONFIRMED ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(req1.isConfirmed, isTrue);

      final req2 = UpiPaymentRequest(
        id: '2',
        orgId: 'org1',
        customerId: 'cust1',
        amount: 100,
        upiVpa: 'test@upi',
        status: 'rejected',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(req2.isRejected, isTrue);
    });
  });

  group('Savings Installment Date Advancement', () {
    DateTime advanceDate(DateTime base, int offset, String frequency) {
      if (offset <= 0) return base;
      switch (frequency) {
        case 'daily':
          return base.add(Duration(days: offset));
        case 'weekly':
          return base.add(Duration(days: offset * 7));
        case 'yearly':
          return DateTime(base.year + offset, base.month, base.day);
        case 'monthly':
        default:
          int newMonth = base.month + offset;
          int newYear = base.year + (newMonth - 1) ~/ 12;
          newMonth = (newMonth - 1) % 12 + 1;
          int newDay = base.day;
          int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
          if (newDay > daysInNewMonth) {
            newDay = daysInNewMonth;
          }
          return DateTime(newYear, newMonth, newDay);
      }
    }

    test('advances daily correctly', () {
      final base = DateTime(2026, 6, 23);
      expect(advanceDate(base, 3, 'daily'), DateTime(2026, 6, 26));
    });

    test('advances weekly correctly', () {
      final base = DateTime(2026, 6, 23);
      expect(advanceDate(base, 2, 'weekly'), DateTime(2026, 7, 7));
    });

    test('advances monthly correctly', () {
      final base = DateTime(2026, 6, 23);
      expect(advanceDate(base, 2, 'monthly'), DateTime(2026, 8, 23));
    });

    test('advances monthly end-of-month correctly', () {
      final base = DateTime(2026, 1, 31);
      // Adding 1 month to Jan 31st on a non-leap year (2026) -> Feb 28th
      expect(advanceDate(base, 1, 'monthly'), DateTime(2026, 2, 28));
    });
  });
}
