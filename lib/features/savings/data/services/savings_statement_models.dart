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
  double get interestAccrued => closingBalance * interestRate / 100;
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

  const SavingsStatementTx({
    required this.date,
    required this.amount,
    required this.description,
    this.paymentMode,
    this.collectedByName,
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
