import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/features/customer_portal/data/models/customer_savings_model.dart';
import 'package:microflow_pro/features/savings/data/models/savings_model.dart';
import 'package:microflow_pro/features/savings/data/services/savings_statement_models.dart';

/// Guards the savings interest maths.
///
/// The user's rule is fixed: interest = maturity amount - total capital
/// invested (opening balance + installments x installment). These tests make
/// sure that rule survives future edits and that interest can never be paid
/// out twice.
void main() {
  SavingsModel buildPlan({
    double monthlyDeposit = 100,
    int totalInstallments = 10,
    double openingBalance = 0,
    double maturityAmount = 1100,
    double storedInterestAmount = 0,
    double interestPaid = 0,
    double currentAmount = 1000,
    DateTime? maturityDate,
    String status = 'active',
  }) {
    return SavingsModel(
      id: 'plan-1',
      memberId: 'member-1',
      memberName: 'Test Customer',
      planName: 'Daily 100',
      targetAmount: 1000,
      currentAmount: currentAmount,
      monthlyDeposit: monthlyDeposit,
      interestRate: 0,
      maturityDate: maturityDate ?? DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime(2026, 1, 1),
      status: status,
      collectionType: 'daily',
      totalInstallments: totalInstallments,
      maturityAmount: maturityAmount,
      openingBalance: openingBalance,
      storedInterestAmount: storedInterestAmount,
      interestPaid: interestPaid,
    );
  }

  group('SavingsModel interest', () {
    test('uses the stored interest column when present', () {
      final plan = buildPlan(storedInterestAmount: 250);
      expect(plan.interestAmount, 250);
    });

    test('falls back to maturity minus capital for old rows', () {
      // 100 x 10 = 1000 capital, maturity 1100 -> 100 interest
      final plan = buildPlan();
      expect(plan.interestAmount, 100);
    });

    test('includes the opening balance in the capital', () {
      final plan = buildPlan(openingBalance: 500, maturityAmount: 1700);
      expect(plan.interestAmount, 200); // 1700 - (500 + 1000)
    });

    test('never returns negative interest', () {
      final plan = buildPlan(maturityAmount: 800);
      expect(plan.interestAmount, 0);
    });

    test('interestRemaining subtracts what was already paid', () {
      final plan = buildPlan(storedInterestAmount: 100, interestPaid: 40);
      expect(plan.interestRemaining, 60);
    });

    test('interestRemaining never goes below zero (no double payout)', () {
      final plan = buildPlan(storedInterestAmount: 100, interestPaid: 130);
      expect(plan.interestRemaining, 0);
    });
  });

  group('SavingsModel.isMatured', () {
    test('false for a vault maturing in the future', () {
      final plan = buildPlan(
        maturityDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(plan.isMatured, isFalse);
    });

    test('true once the maturity date has passed', () {
      final plan = buildPlan(
        maturityDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(plan.isMatured, isTrue);
    });

    test('maturity today still counts as active, not matured', () {
      final plan = buildPlan(maturityDate: DateTime.now());
      expect(plan.isMatured, isFalse);
    });

    test('false for a closed vault', () {
      final plan = buildPlan(
        maturityDate: DateTime.now().subtract(const Duration(days: 5)),
        status: 'closed',
      );
      expect(plan.isMatured, isFalse);
    });
  });

  group('SavingsStatementPlanBlock interest', () {
    SavingsStatementPlanBlock buildBlock({
      double interestAmount = 100,
      List<SavingsStatementTx> withdrawals = const [],
      int totalInstallments = 10,
      int paidInstallments = 5,
    }) {
      return SavingsStatementPlanBlock(
        planId: 'plan-1',
        planName: 'Daily 100',
        status: 'active',
        targetAmount: 1000,
        currentAmount: 500,
        openingBalance: 0,
        closingBalance: 500,
        interestRate: 0,
        interestAmount: interestAmount,
        maturityDate: DateTime(2026, 12, 31),
        collectionType: 'daily',
        monthlyDeposit: 100,
        maturityAmount: 1100,
        deposits: [],
        withdrawals: withdrawals,
        totalInstallments: totalInstallments,
        paidInstallments: paidInstallments,
      );
    }

    SavingsStatementTx tx(double amount, {double interest = 0}) {
      return SavingsStatementTx(
        date: DateTime(2026, 6, 1),
        amount: amount,
        description: 'Payout',
        interestAmount: interest,
      );
    }

    test('promisedInterest comes from the stored plan interest', () {
      expect(buildBlock().promisedInterest, 100);
    });

    test('interestPaid sums the interest component of withdrawals', () {
      final block = buildBlock(
        withdrawals: [tx(200, interest: 20), tx(300, interest: 30)],
      );
      expect(block.interestPaid, 50);
    });

    test('interestAccrued is proportional to paid installments', () {
      final block = buildBlock(paidInstallments: 5, totalInstallments: 10);
      expect(block.interestAccrued, 50); // half of 100
    });

    test('interestAccrued never exceeds the promised interest', () {
      final block = buildBlock(paidInstallments: 14, totalInstallments: 10);
      expect(block.interestAccrued, 100);
    });

    test('interestRemaining subtracts paid interest from promised', () {
      final block = buildBlock(withdrawals: [tx(500, interest: 30)]);
      expect(block.interestRemaining, 70);
    });

    test('zero rate no longer forces zero interest', () {
      // Regression: interest used to be computed as balance * interestRate / 100,
      // and interest_rate is always 0 on savings plans.
      final block = buildBlock();
      expect(block.interestRate, 0);
      expect(block.interestAccrued, greaterThan(0));
    });
  });

  group('CustomerSavingsModel interest', () {
    test('reads the stored interest amount', () {
      final model = CustomerSavingsModel.fromJson({
        'id': 'plan-1',
        'interest_amount': 150,
      });
      expect(model.interestAmount, 150);
    });

    test('falls back to maturity minus capital when not stored', () {
      final model = CustomerSavingsModel.fromJson({
        'id': 'plan-1',
        'maturity_amount': 1100,
        'opening_balance': 0,
        'monthly_deposit': 100,
        'total_installments': 10,
      });
      expect(model.interestAmount, 100);
    });

    test('interestRemaining is promise minus paid, floored at zero', () {
      final model = CustomerSavingsModel.fromJson({
        'id': 'plan-1',
        'interest_amount': 100,
        'interest_paid': 100,
      });
      expect(model.interestRemaining, 0);
    });
  });
}
