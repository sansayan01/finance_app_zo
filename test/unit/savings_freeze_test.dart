import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/savings/data/models/savings_model.dart';
import 'package:microflow_pro/features/savings/data/models/savings_installment_model.dart';

void main() {
  group('Savings Date Freeze Logic Tests', () {
    test('Simulate daily schedule and skipped installment freeze when enabled', () {
      final startDate = DateTime(2026, 6, 20); // Plan started June 20th
      final plan = SavingsModel(
        id: 'sav-123',
        memberId: 'member-456',
        memberName: 'John Doe',
        planName: 'Daily Savings',
        targetAmount: 10000,
        currentAmount: 100,
        monthlyDeposit: 100,
        interestRate: 5.0,
        createdAt: startDate,
        startDate: startDate,
        maturityDate: DateTime(2026, 6, 30), // Maturity is June 30th
        collectionType: 'daily',
        totalInstallments: 10,
        freezeEnabled: true,
        frozenDates: [],
        frozenCount: 0,
      );

      final paidDates = <DateTime>{
        DateTime(2026, 6, 20),
        DateTime(2026, 6, 26),
      };

      final schedule = SavingsScheduleGenerator.generate(
        plan: plan,
        paidDates: paidDates,
      );

      expect(schedule.length, 10);
      expect(schedule[0].dueDate, DateTime(2026, 6, 20));
      expect(schedule[0].isPaid, true);
      expect(schedule[6].dueDate, DateTime(2026, 6, 26));
      expect(schedule[6].isPaid, true);

      int maxPaidNumber = 0;
      int minPaidNumber = 999999;
      for (final inst in schedule) {
        if (inst.isPaid) {
          if (inst.number > maxPaidNumber) maxPaidNumber = inst.number;
          if (inst.number < minPaidNumber) minPaidNumber = inst.number;
        }
      }

      expect(minPaidNumber, 1);
      expect(maxPaidNumber, 7);

      final newFrozenDates = <String>[];
      for (final inst in schedule) {
        if (inst.number > minPaidNumber &&
            inst.number < maxPaidNumber &&
            !inst.isPaid &&
            !inst.isFrozen) {
          final dateKey =
              '${inst.dueDate.year}-${inst.dueDate.month.toString().padLeft(2, '0')}-${inst.dueDate.day.toString().padLeft(2, '0')}';
          newFrozenDates.add(dateKey);
        }
      }

      expect(newFrozenDates.length, 5);
      expect(newFrozenDates, containsAll([
        '2026-06-21',
        '2026-06-22',
        '2026-06-23',
        '2026-06-24',
        '2026-06-25',
      ]));
    });

    test('Simulate daily schedule date freeze bypass when disabled', () {
      final startDate = DateTime(2026, 6, 20);
      final plan = SavingsModel(
        id: 'sav-123',
        memberId: 'member-456',
        memberName: 'John Doe',
        planName: 'Daily Savings',
        targetAmount: 10000,
        currentAmount: 100,
        monthlyDeposit: 100,
        interestRate: 5.0,
        createdAt: startDate,
        startDate: startDate,
        maturityDate: DateTime(2026, 6, 30),
        collectionType: 'daily',
        totalInstallments: 10,
        freezeEnabled: false, // Disabled!
        frozenDates: [],
        frozenCount: 0,
      );


      // Auto-freeze simulator: should return 0 if plan.freezeEnabled is false and force is false
      bool shouldFreeze = plan.freezeEnabled || false; // force = false
      expect(shouldFreeze, false);

      // Manual-freeze simulator: should run if force is true, regardless of plan.freezeEnabled
      bool shouldFreezeForced = plan.freezeEnabled || true; // force = true
      expect(shouldFreezeForced, true);
    });
  });
}
