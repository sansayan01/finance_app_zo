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

final pendingDepositsProvider = FutureProvider<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getPendingDeposits(limit: 10);
});

final recentTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getRecentTransactions(limit: 50);
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
  return repository.getRecentTransactions(limit: 5);
});

final overdueLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  final allLoans = await repository.getAllLoans(limit: 100);
  return allLoans.where((l) => l.status == LoanStatus.defaultStatus).toList();
});

final todayAgendaProvider = FutureProvider<List<dynamic>>((ref) async {
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
