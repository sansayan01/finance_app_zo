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
      // VPA @ should be literal (not %40) for UPI app compatibility
      expect(uri, contains('pa=merchant@upi'));
      expect(uri, contains('am=2500.00'));
      // Merchant name should be plain text
      expect(uri, contains('pn=My Finance Org'));
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

    test('encodes only query-reserved characters (& = +)', () {
      final uri = UpiService.buildUpiUri(
        vpa: 'test@upi',
        amount: 500,
        merchantName: 'Org & Co',
        transactionNote: 'Loan#123-EMI#5',
      );
      // # and spaces are kept as-is for UPI compatibility
      expect(uri, contains('tn=Loan#123-EMI#5'));
      // & in merchant name must be encoded
      expect(uri, contains('pn=Org %26 Co'));
    });

    test('validates VPA format contains @', () {
      expect(UpiService.isValidVpa('merchant@upi'), true);
      expect(UpiService.isValidVpa('user@bank'), true);
      expect(UpiService.isValidVpa('invalid-vpa'), false);
      expect(UpiService.isValidVpa(''), false);
    });
  });
}
