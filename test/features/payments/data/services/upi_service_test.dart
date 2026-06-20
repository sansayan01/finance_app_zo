import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/payments/data/services/upi_service.dart';

void main() {
  group('UpiService.buildUpiUri', () {
    test('builds correct UPI URI with all params', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'merchant@upi',
        amount: 2500.00,
        merchantName: 'My Finance Org',
        transactionNote: 'Loan #123 - EMI #5',
      );
      expect(uri, contains('upi://pay?'));
      expect(uri, contains('pa=merchant%40upi'));
      expect(uri, contains('am=2500.00'));
      expect(uri, contains('pn=My%20Finance%20Org'));
      expect(uri, contains('cu=INR'));
    });

    test('builds correct UPI URI with integer amount', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'test@upi',
        amount: 100,
        merchantName: 'Test',
        transactionNote: 'Savings #1',
      );
      expect(uri, contains('am=100.00'));
    });

    test('encodes special characters in transaction note', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'test@upi',
        amount: 500,
        merchantName: 'Org',
        transactionNote: 'Loan#123-EMI#5',
      );
      expect(uri, contains('tn=Loan%23123-EMI%235'));
    });

    test('validates VPA format contains @', () {
      expect(UpiService.isValidVpa('merchant@upi'), true);
      expect(UpiService.isValidVpa('user@bank'), true);
      expect(UpiService.isValidVpa('invalid-vpa'), false);
      expect(UpiService.isValidVpa(''), false);
    });
  });
}
