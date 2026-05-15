import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/enums.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../loans/data/repositories/loans_repository.dart';
import '../../../savings/data/repositories/savings_repository.dart';
import '../../../members/data/repositories/members_repository.dart';
import '../../../transactions/data/repositories/transactions_repository.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../members/data/models/member_model.dart';
import '../../../transactions/data/models/transaction_model.dart';

/// Enum for analytics time periods
enum AnalyticsPeriod { thisMonth, lastQuarter, ytd, allTime }

extension AnalyticsPeriodLabel on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.thisMonth:
        return 'This Month';
      case AnalyticsPeriod.lastQuarter:
        return 'Last Quarter';
      case AnalyticsPeriod.ytd:
        return 'YTD';
      case AnalyticsPeriod.allTime:
        return 'All Time';
    }
  }
}

class AnalyticsStats {
  // Portfolio
  final double totalDisbursed;
  final double totalCollected;
  final double parPercentage;
  final double disbursementChange;
  final double collectionChange;
  final List<double> monthlyDisbursements;
  final List<double> monthlyCollections;

  // Savings
  final double totalSavings;
  final int activeSavingsAccounts;
  final double interestEarned;
  final double averageSavingsBalance;
  final double savingsChange;
  final List<SavingsModel> upcomingMaturities;

  // Members
  final int totalMembers;
  final int newMembersThisPeriod;
  final int activeMembers;
  final int pendingKYC;
  final double memberGrowthRate;
  final List<MemberModel> recentMembers;

  // Financial Health
  final double collectionEfficiency;
  final double portfolioYield;
  final double nplRatio;
  final double liquidityRatio;

  const AnalyticsStats({
    required this.totalDisbursed,
    required this.totalCollected,
    required this.parPercentage,
    required this.disbursementChange,
    required this.collectionChange,
    required this.monthlyDisbursements,
    required this.monthlyCollections,
    required this.totalSavings,
    required this.activeSavingsAccounts,
    required this.interestEarned,
    required this.averageSavingsBalance,
    required this.savingsChange,
    required this.upcomingMaturities,
    required this.totalMembers,
    required this.newMembersThisPeriod,
    required this.activeMembers,
    required this.pendingKYC,
    required this.memberGrowthRate,
    required this.recentMembers,
    required this.collectionEfficiency,
    required this.portfolioYield,
    required this.nplRatio,
    required this.liquidityRatio,
  });

  factory AnalyticsStats.empty() => const AnalyticsStats(
        totalDisbursed: 0,
        totalCollected: 0,
        parPercentage: 0,
        disbursementChange: 0,
        collectionChange: 0,
        monthlyDisbursements: [],
        monthlyCollections: [],
        totalSavings: 0,
        activeSavingsAccounts: 0,
        interestEarned: 0,
        averageSavingsBalance: 0,
        savingsChange: 0,
        upcomingMaturities: [],
        totalMembers: 0,
        newMembersThisPeriod: 0,
        activeMembers: 0,
        pendingKYC: 0,
        memberGrowthRate: 0,
        recentMembers: [],
        collectionEfficiency: 0,
        portfolioYield: 0,
        nplRatio: 0,
        liquidityRatio: 0,
      );
}

final analyticsPeriodProvider =
    StateProvider<AnalyticsPeriod>((ref) => AnalyticsPeriod.thisMonth);

final analyticsProvider = FutureProvider<AnalyticsStats>((ref) async {
  final period = ref.watch(analyticsPeriodProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);

  final loansRepo = LoansRepository(supabase, orgId);
  final savingsRepo = SavingsRepository(supabase, orgId);
  final membersRepo = MembersRepository(supabase, orgId);
  final transactionsRepo = TransactionsRepository(supabase, orgId);

  // Fetch all data in parallel
  final results = await Future.wait([
    loansRepo.getLoanSummary(),
    savingsRepo.getActiveSavingsPlans(limit: 100),
    savingsRepo.getSavingsSummary(),
    membersRepo.getMembers(limit: 100),
    membersRepo.getMemberSummary(),
    transactionsRepo.getRecentTransactions(limit: 200),
  ]);

  final loanSummary = results[0] as dynamic;
  final savingsPlans = results[1] as List<SavingsModel>;
  // final savingsSummary = results[2] as dynamic; // Unused
  final members = results[3] as List<MemberModel>;
  final memberSummary = results[4] as MemberSummary;
  final transactions = results[5] as List<TransactionModel>;

  // Compute date range for the selected period
  final now = DateTime.now();
  DateTime periodStart;
  DateTime? prevPeriodStart;
  DateTime? prevPeriodEnd;

  switch (period) {
    case AnalyticsPeriod.thisMonth:
      periodStart = DateTime(now.year, now.month, 1);
      prevPeriodStart = DateTime(now.year, now.month - 1, 1);
      prevPeriodEnd = periodStart.subtract(const Duration(days: 1));
      break;
    case AnalyticsPeriod.lastQuarter:
      final currentQuarter = ((now.month - 1) ~/ 3);
      final lastQStartMonth = (currentQuarter - 1) * 3 + 1;
      periodStart = DateTime(now.year, lastQStartMonth, 1);
      final lastQEndMonth = lastQStartMonth + 2;
      prevPeriodStart = DateTime(now.year, lastQStartMonth - 3, 1);
      prevPeriodEnd = DateTime(now.year, lastQEndMonth + 1, 1)
          .subtract(const Duration(days: 1));
      break;
    case AnalyticsPeriod.ytd:
      periodStart = DateTime(now.year, 1, 1);
      prevPeriodStart = DateTime(now.year - 1, 1, 1);
      prevPeriodEnd = DateTime(now.year - 1, 12, 31);
      break;
    case AnalyticsPeriod.allTime:
      periodStart = DateTime(2000, 1, 1);
      prevPeriodStart = null;
      prevPeriodEnd = null;
      break;
  }

  // Filter transactions by period
  final periodTransactions =
      transactions.where((t) => t.createdAt.isAfter(periodStart)).toList();
  final prevPeriodTransactions = prevPeriodStart != null
      ? transactions
          .where((t) =>
              t.createdAt.isAfter(prevPeriodStart!) &&
              t.createdAt.isBefore(prevPeriodEnd!))
          .toList()
      : <TransactionModel>[];

  // Compute monthly disbursement/collection data (last 6 months)
  final monthlyDisbursements = <double>[];
  final monthlyCollections = <double>[];
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final nextMonth = DateTime(now.year, now.month - i + 1, 1);
    final monthTransactions = transactions.where((t) =>
        t.createdAt.isAfter(month.subtract(const Duration(days: 1))) &&
        t.createdAt.isBefore(nextMonth));

    double disbursed = 0;
    double collected = 0;
    for (final t in monthTransactions) {
      if (t.type == TransactionType.loanDisbursement) {
        disbursed += t.amount;
      } else if (t.type == TransactionType.emiPayment ||
          t.type == TransactionType.savingsDeposit) {
        collected += t.amount;
      }
    }
    monthlyDisbursements.add(disbursed);
    monthlyCollections.add(collected);
  }

  // Compute period changes
  double periodDisbursed = 0;
  double periodCollected = 0;
  for (final t in periodTransactions) {
    if (t.type == TransactionType.loanDisbursement) {
      periodDisbursed += t.amount;
    }
    if (t.type == TransactionType.emiPayment ||
        t.type == TransactionType.savingsDeposit) {
      periodCollected += t.amount;
    }
  }

  double prevDisbursed = 0;
  double prevCollected = 0;
  for (final t in prevPeriodTransactions) {
    if (t.type == TransactionType.loanDisbursement) {
      prevDisbursed += t.amount;
    }
    if (t.type == TransactionType.emiPayment ||
        t.type == TransactionType.savingsDeposit) {
      prevCollected += t.amount;
    }
  }

  double disbursementChange = 0;
  double collectionChange = 0;
  if (prevDisbursed > 0) {
    disbursementChange =
        ((periodDisbursed - prevDisbursed) / prevDisbursed) * 100;
  }
  if (prevCollected > 0) {
    collectionChange =
        ((periodCollected - prevCollected) / prevCollected) * 100;
  }

  // Savings analytics
  final totalSavings =
      savingsPlans.fold<double>(0, (sum, s) => sum + s.currentAmount);
  final interestEarned = savingsPlans.fold<double>(
      0, (sum, s) => sum + (s.currentAmount * s.interestRate / 100));
  final avgBalance =
      savingsPlans.isNotEmpty ? totalSavings / savingsPlans.length : 0.0;
  final upcomingMaturities = savingsPlans
      .where((s) =>
          s.maturityDate.difference(now).inDays <= 30 &&
          s.maturityDate.isAfter(now))
      .toList();

  // Member analytics
  final newMembers =
      members.where((m) => m.createdAt.isAfter(periodStart)).toList();
  final prevNewMembers = prevPeriodStart != null
      ? members
          .where((m) =>
              m.createdAt.isAfter(prevPeriodStart!) &&
              m.createdAt.isBefore(prevPeriodEnd!))
          .length
      : 0;
  double memberGrowthRate = 0;
  if (prevNewMembers > 0) {
    memberGrowthRate =
        ((newMembers.length - prevNewMembers) / prevNewMembers) * 100;
  }

  // Financial health metrics
  final totalCollected = transactions
      .where((t) =>
          t.type == TransactionType.emiPayment ||
          t.type == TransactionType.savingsDeposit)
      .fold<double>(0, (sum, t) => sum + t.amount);

  final totalDue = loanSummary.totalOutstanding;
  final collectionEfficiency =
      totalDue > 0 ? (totalCollected / (totalDue + totalCollected)) * 100 : 0.0;
  final portfolioYield = loanSummary.totalDisbursed > 0
      ? (totalCollected / loanSummary.totalDisbursed) * 100
      : 0.0;
  final nplRatio = loanSummary.parPercentage;
  final liquidityRatio = totalSavings > 0
      ? (loanSummary.totalOutstanding / totalSavings) * 100
      : 0.0;

  return AnalyticsStats(
    totalDisbursed: loanSummary.totalDisbursed,
    totalCollected: totalCollected,
    parPercentage: loanSummary.parPercentage,
    disbursementChange: disbursementChange,
    collectionChange: collectionChange,
    monthlyDisbursements: monthlyDisbursements,
    monthlyCollections: monthlyCollections,
    totalSavings: totalSavings,
    activeSavingsAccounts: savingsPlans.length,
    interestEarned: interestEarned,
    averageSavingsBalance: avgBalance,
    savingsChange: 0,
    upcomingMaturities: upcomingMaturities,
    totalMembers: memberSummary.totalMembers,
    newMembersThisPeriod: newMembers.length,
    activeMembers: memberSummary.activeMembers,
    pendingKYC: memberSummary.pendingKYC,
    memberGrowthRate: memberGrowthRate,
    recentMembers: members.take(5).toList(),
    collectionEfficiency: collectionEfficiency.clamp(0, 100),
    portfolioYield: portfolioYield.clamp(0, 100),
    nplRatio: nplRatio,
    liquidityRatio: liquidityRatio.clamp(0, 500),
  );
});

