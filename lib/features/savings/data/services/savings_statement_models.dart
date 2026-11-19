class SavingsStatementCustomer {
  final String id;
  final String memberId;
  final String fullName;
  final String phone;
  final String? address;

  const SavingsStatementCustomer({
    required this.id,
    required this.memberId,
    required this.fullName,
    this.phone = '',
    this.address,
  });
}

class SavingsStatementPlanBlock {
  final String planId;
  final String planName;
  final String status;
  final double targetAmount;
  final double currentAmount;
  final double openingBalance;
  final double closingBalance;
  final double interestRate;
  /// Interest promised for the whole plan (maturity amount - capital).
  final double interestAmount;
  final DateTime maturityDate;
  final String collectionType;
  final double monthlyDeposit;
  final double maturityAmount;
  final DateTime? nextDueDate;
  final int? totalInstallments;
  final int? paidInstallments;
  final List<SavingsStatementTx> deposits;
  final List<SavingsStatementTx> withdrawals;

  SavingsStatementPlanBlock({
    required this.planId,
    required this.planName,
    required this.status,
    required this.targetAmount,
    required this.currentAmount,
    required this.openingBalance,
    required this.closingBalance,
    required this.interestRate,
    this.interestAmount = 0,
    required this.maturityDate,
    required this.collectionType,
    required this.monthlyDeposit,
    required this.maturityAmount,
    this.nextDueDate,
    this.totalInstallments,
    this.paidInstallments,
    required this.deposits,
    required this.withdrawals,
  });

  double get totalDeposited =>
      deposits.fold(0.0, (sum, t) => sum + t.amount);
  double get totalWithdrawn =>
      withdrawals.fold(0.0, (sum, t) => sum + t.amount);

  /// Interest promised for the whole plan, straight from the plan record.
  double get promisedInterest => interestAmount > 0 ? interestAmount : 0;

  /// Interest already handed back to the customer on this plan.
  double get interestPaid =>
      withdrawals.fold(0.0, (sum, t) => sum + t.interestAmount);

  /// Interest earned so far, proportional to the installments paid.
  ///
  /// Uses the promised interest (maturity - capital) as the source of truth.
  /// The old rate-based RD formula is gone because `interest_rate` is not
  /// populated on savings plans, so it always produced 0.
  double get interestAccrued {
    final promised = promisedInterest;
    if (promised <= 0) return 0;
    final total = totalInstallments ?? 0;
    if (total <= 0) return promised;
    final paid = paidInstallments ?? 0;
    final ratio = paid / total;
    return promised * (ratio > 1 ? 1 : ratio);
  }

  /// Interest promised but not yet handed back.
  double get interestRemaining {
    final remaining = promisedInterest - interestPaid;
    return remaining > 0 ? remaining : 0;
  }
  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;
  int get installmentsRemaining =>
      (totalInstallments ?? 0) - (paidInstallments ?? 0);
}

class SavingsStatementTx {
  final DateTime date;
  final double amount;
  final String description;
  final String? paymentMode;
  final String? collectedByName;
  /// For payouts: the interest portion included in [amount].
  final double interestAmount;

  const SavingsStatementTx({
    required this.date,
    required this.amount,
    required this.description,
    this.paymentMode,
    this.collectedByName,
    this.interestAmount = 0,
  });
}

class SavingsStatementPortfolioSummary {
  final double openingBalance;
  final double totalDeposits;
  final double totalWithdrawals;
  final double interestEarned;
  final double closingBalance;
  final int activePlans;
  final int totalPlans;

  const SavingsStatementPortfolioSummary({
    required this.openingBalance,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.interestEarned,
    required this.closingBalance,
    required this.activePlans,
    required this.totalPlans,
  });
}

enum SavingsFormat { pdf, excel, csv }

class SavingsStatementOptions {
  final DateTime periodStart;
  final DateTime periodEnd;
  final SavingsFormat format;

  const SavingsStatementOptions({
    required this.periodStart,
    required this.periodEnd,
    required this.format,
  });
}

class SavingsStatementData {
  final SavingsStatementCustomer customer;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<SavingsStatementPlanBlock> plans;
  final SavingsStatementPortfolioSummary portfolio;

  SavingsStatementData({
    required this.customer,
    required this.periodStart,
    required this.periodEnd,
    required this.plans,
    required this.portfolio,
  });
}
