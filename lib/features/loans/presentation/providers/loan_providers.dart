import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/loan_model.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/constants/enums.dart';

import '../../data/repositories/emi_repository.dart';
import '../../data/models/emi_schedule_model.dart';
import '../../data/services/loan_statement_archive_service.dart';
import '../../data/providers/loan_providers.dart';
export '../../data/providers/loan_providers.dart';

final emiRepositoryProvider = Provider.autoDispose<EMIRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return EMIRepository(ref.watch(supabaseClientProvider), orgId);
});

final loanStatementArchiveServiceProvider =
    Provider.autoDispose<LoanStatementArchiveService>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return LoanStatementArchiveService(
      ref.watch(supabaseClientProvider), orgId);
});

final pastLoanStatementsProvider = FutureProvider.autoDispose
    .family<List<LoanStatementArchive>, String>((ref, loanId) async {
  final svc = ref.watch(loanStatementArchiveServiceProvider);
  return svc.listForLoan(loanId);
});

final loanSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredLoansProvider = Provider.autoDispose<List<LoanModel>>((ref) {
  final loans = ref.watch(allLoansProvider).value ?? [];
  final query = ref.watch(loanSearchQueryProvider).toLowerCase();

  if (query.isEmpty) return loans;

  return loans.where((loan) {
    final nameMatch = loan.customerName?.toLowerCase().contains(query) ?? false;
    final phoneMatch = loan.customerPhone?.contains(query) ?? false;
    final numberMatch = loan.loanNumber.toLowerCase().contains(query);
    return nameMatch || phoneMatch || numberMatch;
  }).toList();
});

final loanStatsProvider = Provider.autoDispose<AsyncValue<Map<String, dynamic>>>((ref) {
  return ref.watch(allLoansProvider).whenData((loans) {
    final active = loans.where((l) => l.status == LoanStatus.active).toList();
    final totalOut = active.fold<double>(
        0.0, (double sum, LoanModel l) => sum + l.outstandingBalance);
    final overdue =
        loans.where((l) => l.status == LoanStatus.defaultStatus).toList();
    final pending = loans.where((l) => l.status == LoanStatus.pending).toList();

    final totalDisbursed = loans
        .where((l) =>
            l.status == LoanStatus.active || l.status == LoanStatus.closed)
        .fold<double>(0.0, (double sum, LoanModel l) => sum + l.amount);

    return {
      'activeCount': active.length,
      'totalOutstanding': totalOut,
      'overdueCount': overdue.length,
      'pendingCount': pending.length,
      'totalDisbursed': totalDisbursed,
      'totalCount': loans.length,
    };
  });
});

final loanDetailProvider =
    FutureProvider.autoDispose.family<LoanModel?, String>((ref, id) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getLoanById(id);
});

final emiScheduleProvider =
    FutureProvider.autoDispose.family<List<EMIScheduleModel>, String>((ref, loanId) async {
  final repository = ref.watch(emiRepositoryProvider);
  return repository.getByLoanId(loanId);
});

final paymentHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, loanId) async {
  final repository = ref.watch(emiRepositoryProvider);
  return repository.getPaymentHistory(loanId);
});

final userLoansProvider =
    FutureProvider.autoDispose.family<List<LoanModel>, String>((ref, userId) async {
  final loans = await ref.watch(allLoansProvider.future);
  return loans.where((l) => l.customerId == userId).toList();
});
