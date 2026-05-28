import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/enums.dart';

import '../../../loans/data/models/emi_schedule_model.dart';
import '../../../loans/data/models/loan_model.dart';

import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../savings/data/providers/savings_providers.dart';
import '../../../transactions/data/models/transaction_model.dart';

import '../../../../core/services/offline_queue_service.dart';

class StaffDueItem {
  final String id;
  final String type; // 'emi' or 'savings'
  final String memberName;
  final String? memberPhone;
  final double amount;
  final String? loanId;
  final String? savingsId;
  final int? emiNumber;
  final String? loanNumber;
  final String? planName;
  final DateTime? dueDate;

  StaffDueItem({
    required this.id,
    required this.type,
    required this.memberName,
    this.memberPhone,
    required this.amount,
    this.loanId,
    this.savingsId,
    this.emiNumber,
    this.loanNumber,
    this.planName,
    this.dueDate,
  });
}

class StaffTodayStats {
  final double target;
  final double collected;
  final int totalDues;
  final int collectedCount;
  final int pendingSyncCount;

  StaffTodayStats({
    required this.target,
    required this.collected,
    required this.totalDues,
    required this.collectedCount,
    required this.pendingSyncCount,
  });

  double get remaining => target > collected ? target - collected : 0;
  double get progress =>
      target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
}

final staffTodayEmiDuesProvider =
    FutureProvider.autoDispose<List<EMIScheduleModel>>((ref) async {
  final repository = ref.watch(emiRepositoryProvider);
  return repository.getTodaysDues();
});

final staffActiveLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getAllLoans();
});

final staffActiveSavingsProvider =
    FutureProvider.autoDispose<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getActiveSavingsPlans();
});

final staffTodaysDuesProvider = FutureProvider.autoDispose<List<StaffDueItem>>((ref) async {
  final emisAsync = ref.watch(staffTodayEmiDuesProvider);
  final loansAsync = ref.watch(staffActiveLoansProvider);
  final savingsAsync = ref.watch(staffActiveSavingsProvider);

  final emis = emisAsync.value ?? [];
  final loans = loansAsync.value ?? [];
  final savings = savingsAsync.value ?? [];

  final loanMap = {for (final l in loans) l.id: l};

  final dues = <StaffDueItem>[];

  for (final emi in emis) {
    final loan = loanMap[emi.loanId];
    dues.add(StaffDueItem(
      id: emi.id,
      type: 'emi',
      memberName: loan?.customerName ?? 'Unknown',
      memberPhone: loan?.customerPhone,
      amount: emi.emiAmount,
      loanId: emi.loanId,
      emiNumber: emi.emiNumber,
      loanNumber: loan?.loanNumber,
      dueDate: emi.dueDate,
    ));
  }

  for (final s in savings) {
    if (s.monthlyDeposit > 0) {
      dues.add(StaffDueItem(
        id: s.id,
        type: 'savings',
        memberName: s.memberName,
        amount: s.monthlyDeposit,
        savingsId: s.id,
        planName: s.planName.isNotEmpty ? s.planName : 'Recurring Deposit',
      ));
    }
  }

  return dues;
});

final staffTodayStatsProvider = FutureProvider.autoDispose<StaffTodayStats>((ref) async {
  final duesAsync = ref.watch(staffTodaysDuesProvider);
  final transactionsRepo = ref.watch(transactionsRepositoryProvider);
  final stats = await transactionsRepo.getTodayStats();

  final dues = duesAsync.value ?? [];
  final target = dues.fold<double>(0, (sum, d) => sum + d.amount);
  final collected = (stats['collected'] as double?) ?? 0.0;
  final collectedCount = (stats['collectionCount'] as int?) ?? 0;

  final queue = OfflineQueueService();
  final pendingSync = await queue.pendingCount;

  return StaffTodayStats(
    target: target,
    collected: collected,
    totalDues: dues.length,
    collectedCount: collectedCount,
    pendingSyncCount: pendingSync,
  );
});

final staffRecentActivityProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionsByDate(DateTime.now());
});

final offlineQueueCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final queue = OfflineQueueService();
  return queue.pendingCount;
});

class StaffWallet {
  final double cashInHand;
  final double totalCashCollected;
  final double totalDigitalCollected;
  final double lastDepositAmount;
  final DateTime? lastDepositDate;

  StaffWallet({
    required this.cashInHand,
    required this.totalCashCollected,
    required this.totalDigitalCollected,
    required this.lastDepositAmount,
    this.lastDepositDate,
  });
}

final staffWalletProvider = FutureProvider.autoDispose<StaffWallet>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  final transactions = await repository.getTransactionsByDate(DateTime.now());

  double cashInHand = 0;
  double totalCash = 0;
  double totalDigital = 0;
  double lastDeposit = 0;
  DateTime? lastDate;

  for (final t in transactions) {
    if (t.type == TransactionType.staffCashDeposit) {
      cashInHand -= t.amount;
      lastDeposit = t.amount;
      lastDate = t.createdAt;
    } else if (t.paymentMode == PaymentMode.cash) {
      cashInHand += t.amount;
      totalCash += t.amount;
    } else {
      totalDigital += t.amount;
    }
  }

  return StaffWallet(
    cashInHand: cashInHand,
    totalCashCollected: totalCash,
    totalDigitalCollected: totalDigital,
    lastDepositAmount: lastDeposit,
    lastDepositDate: lastDate,
  );
});
