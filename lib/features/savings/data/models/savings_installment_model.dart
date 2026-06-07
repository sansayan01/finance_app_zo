import 'package:microflow_pro/features/savings/data/models/savings_model.dart';

/// Lightweight installment generated client-side for calendar selection.
class SavingsInstallment {
  final int number; // Installment # (1, 2, 3...)
  final DateTime dueDate; // When this installment is due
  final bool isPaid; // Whether a savings_collection exists for this date
  final double amount; // Installment amount (monthlyDeposit)

  const SavingsInstallment({
    required this.number,
    required this.dueDate,
    required this.isPaid,
    required this.amount,
  });
}

/// Generates the full savings installment schedule client-side.
///
/// Logic:
/// 1. Start from `plan.startDate`
/// 2. Generate dates at intervals based on `plan.collectionType`:
///    - daily: +1 day each
///    - weekly: +7 days each
///    - monthly: +1 month each (respecting collection_day_of_month if set)
/// 3. Stop at `plan.maturityDate` or after `plan.totalInstallments`
/// 4. Mark each as paid if a matching `savings_collections` record exists
/// 5. Compare dates ignoring time (date-only comparison)
class SavingsScheduleGenerator {
  /// Generate the full schedule.
  ///
  /// [plan] - The savings plan
  /// [paidDates] - Set of dates (date-only) that have been collected
  static List<SavingsInstallment> generate({
    required SavingsModel plan,
    required Set<DateTime> paidDates,
  }) {
    final schedule = <SavingsInstallment>[];
    final start = plan.startDate ?? plan.createdAt;
    final startOnly = DateTime(start.year, start.month, start.day);
    final maturity = plan.maturityDate;
    final collectionType = plan.collectionType;
    final amount = plan.monthlyDeposit;
    final total = plan.totalInstallments;

    DateTime currentDate = startOnly;
    int installmentNumber = 1;

    // Generate up to totalInstallments or maturity date, whichever comes first
    while (installmentNumber <= total && !currentDate.isAfter(maturity)) {
      final isPaid = paidDates.any((d) =>
          d.year == currentDate.year &&
          d.month == currentDate.month &&
          d.day == currentDate.day);

      schedule.add(SavingsInstallment(
        number: installmentNumber,
        dueDate: currentDate,
        isPaid: isPaid,
        amount: amount,
      ));

      // Advance to next due date
      switch (collectionType) {
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case 'monthly':
          // Move to same day next month, handling month-end overflow
          int targetMonth = currentDate.month + 1;
          int targetYear = currentDate.year + ((targetMonth - 1) ~/ 12);
          targetMonth = ((targetMonth - 1) % 12) + 1;
          int targetDay = currentDate.day;
          int daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
          if (targetDay > daysInTargetMonth) targetDay = daysInTargetMonth;
          currentDate = DateTime(targetYear, targetMonth, targetDay);
          break;
        default: // daily
          currentDate = currentDate.add(const Duration(days: 1));
      }

      installmentNumber++;
    }

    return schedule;
  }

  /// Helper: fetch paid dates from savings_collections for a plan.
  /// Returns a set of date-only DateTime objects.
  static Future<Set<DateTime>> fetchPaidDates({
    required dynamic client, // SupabaseClient
    required String planId,
  }) async {
    final response = await client
        .from('savings_collections')
        .select('collection_date')
        .eq('savings_plan_id', planId);

    return (response as List)
        .map((row) {
          final dateStr = row['collection_date'] as String;
          final date = DateTime.parse(dateStr);
          return DateTime(date.year, date.month, date.day);
        })
        .toSet();
  }
}
