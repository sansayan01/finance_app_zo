import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../loans/data/repositories/loans_repository.dart';
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../savings/data/providers/savings_providers.dart';
import '../../../transactions/data/repositories/transactions_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../loans/presentation/providers/loan_providers.dart';
import '../../../../core/constants/enums.dart';

final loansRepositoryProvider = Provider<LoansRepository>((ref) {
  return LoansRepository(ref.watch(supabaseClientProvider));
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(ref.watch(supabaseClientProvider));
});

final activeLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getActiveLoans(limit: 10);
});

final loanSummaryProvider = FutureProvider<LoanSummary>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getLoanSummary();
});

final activeSavingsProvider = FutureProvider<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getActiveSavingsPlans(limit: 20);
});

final savingsSummaryProvider = FutureProvider<SavingsSummary>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getSavingsSummary();
});

final pendingDepositsProvider = FutureProvider<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getPendingDeposits(limit: 10);
});

final recentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getRecentTransactions(limit: 10);
});

final todayStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTodayStats();
});

final dashboardLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getActiveLoans(limit: 5);
});

final dashboardSavingsProvider =
    FutureProvider<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getActiveSavingsPlans(limit: 4);
});

final dashboardTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getRecentTransactions(limit: 3);
});

final overdueLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  final allLoans = await repository.getAllLoans(limit: 100);
  return allLoans.where((l) => l.status == LoanStatus.defaultStatus).toList();
});

final todayAgendaProvider = FutureProvider<List<dynamic>>((ref) async {
  final emiRepo = ref.watch(emiRepositoryProvider);
  final agenda = <dynamic>[];
  try {
    final dues = await emiRepo.getTodaysDues();
    agenda.addAll(dues);
  } catch (_) {}
  if (agenda.isEmpty) {
    final loans = await ref.watch(dashboardLoansProvider.future);
    final savings = await ref.watch(dashboardSavingsProvider.future);
    if (loans.isNotEmpty) agenda.add(loans.first);
    if (savings.isNotEmpty) agenda.add(savings.first);
  }
  return agenda;
});
