import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/core/utils/formatters.dart';

void main() {
  group('AppFormatters', () {
    group('formatCurrency', () {
      test('formats integer correctly', () {
        expect(AppFormatters.formatCurrency(1000), '₹1,000.00');
        expect(AppFormatters.formatCurrency(10000), '₹10,000.00');
      });

      test('formats double correctly', () {
        expect(AppFormatters.formatCurrency(1000.50), '₹1,000.50');
        expect(AppFormatters.formatCurrency(1234.99), '₹1,234.99');
      });

      test('formats zero correctly', () {
        expect(AppFormatters.formatCurrency(0), '₹0.00');
      });
    });

    group('formatCompactCurrency', () {
      test('formats large numbers', () {
        expect(AppFormatters.formatCompactCurrency(1000000), '₹1L');
        expect(AppFormatters.formatCompactCurrency(10000000), '₹10Cr');
      });
    });

    group('formatDate', () {
      test('formats DateTime to readable string', () {
        final date = DateTime(2024, 6, 15);
        expect(AppFormatters.formatDate(date), '15 Jun 2024');
      });
    });

    group('formatShortDate', () {
      test('formats to dd/MM/yyyy', () {
        final date = DateTime(2024, 6, 15);
        expect(AppFormatters.formatShortDate(date), '15/06/2024');
      });
    });

    group('formatPhone', () {
      test('formats 10-digit Indian number', () {
        expect(AppFormatters.formatPhone('9876543210'), '+91 9876543210');
      });

      test('returns original for non-10-digit', () {
        expect(AppFormatters.formatPhone('123'), '123');
      });
    });

    group('formatLoanId', () {
      test('formats id with prefix', () {
        expect(AppFormatters.formatLoanId('abc12345def'), 'LFABC12345');
      });
    });

    group('formatMemberId', () {
      test('formats id with prefix', () {
        expect(AppFormatters.formatMemberId('abc12345def'), 'MBABC12345');
      });
    });

    group('formatDaysRemaining', () {
      test('returns overdue for negative', () {
        expect(AppFormatters.formatDaysRemaining(-1), 'Overdue');
      });

      test('returns singular day', () {
        expect(AppFormatters.formatDaysRemaining(1), '1 day left');
      });

      test('returns days for small numbers', () {
        expect(AppFormatters.formatDaysRemaining(5), '5 days left');
      });

      test('returns weeks for 7-30 days', () {
        expect(AppFormatters.formatDaysRemaining(14), '2 weeks left');
      });

      test('returns months for 30+ days', () {
        expect(AppFormatters.formatDaysRemaining(60), '2 months left');
      });
    });

    group('formatRelativeTime', () {
      test('returns just now for recent', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 30));
        expect(AppFormatters.formatRelativeTime(recent), 'Just now');
      });

      test('returns minutes ago', () {
        final minutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(AppFormatters.formatRelativeTime(minutesAgo), '5m ago');
      });

      test('returns hours ago', () {
        final hoursAgo = DateTime.now().subtract(const Duration(hours: 3));
        expect(AppFormatters.formatRelativeTime(hoursAgo), '3h ago');
      });

      test('returns days ago', () {
        final daysAgo = DateTime.now().subtract(const Duration(days: 5));
        expect(AppFormatters.formatRelativeTime(daysAgo), '5d ago');
      });
    });
  });
}