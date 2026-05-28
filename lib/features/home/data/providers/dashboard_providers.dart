import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../loans/data/providers/loan_providers.dart';
export '../../../loans/data/providers/loan_providers.dart' show loansRepositoryProvider, loansProvider, allLoansProvider;
import '../../../loans/data/models/loan_model.dart';
import '../../../savings/data/models/savings_model.dart';
import '../../../savings/data/providers/savings_providers.dart';
export '../../../savings/data/providers/savings_providers.dart' show savingsSummaryProvider, transactionsRepositoryProvider;
import '../../../transactions/data/models/transaction_model.dart';
import '../../../../core/constants/enums.dart';

final activeLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getActiveLoans(limit: 10);
});

final loanSummaryProvider = FutureProvider.autoDispose<LoanSummary>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getLoanSummary();
});

final activeSavingsProvider = FutureProvider.autoDispose<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getActiveSavingsPlans(limit: 20);
});

final pendingDepositsProvider = FutureProvider.autoDispose<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getPendingDeposits(limit: 10);
});

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getRecentTransactions(limit: 50);
});

final todayStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTodayStats();
});

final dashboardLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getActiveLoans(limit: 5);
});

final dashboardSavingsProvider =
    FutureProvider.autoDispose<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getActiveSavingsPlans(limit: 4);
});

final dashboardTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getRecentTransactions(limit: 5);
});

final overdueLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  final allLoans = await repository.getAllLoans(limit: 100);
  return allLoans.where((l) => l.status == LoanStatus.defaultStatus).toList();
});

final todayAgendaProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdProvider);
  final agenda = <dynamic>[];
  try {
    final today = DateTime.now().toIso8601String().split('T').first;
    final dues = await client
        .from('emi_schedule')
        .select('*, loans!fk_emi_loan(customer_id, members!fk_loans_customer(full_name))')
        .eq('org_id', orgId ?? '')
        .lte('due_date', today)
        .eq('is_paid', false)
        .order('due_date', ascending: true)
        .limit(5);
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
