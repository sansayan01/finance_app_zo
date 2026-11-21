import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import '../repositories/loans_repository.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';

final loansRepositoryProvider = Provider.autoDispose<LoansRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return LoansRepository(ref.watch(supabaseClientProvider), orgId);
});

// Providers for loan metrics and lists
final allLoansProvider = FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getAllLoans();
});

// Alias for backward compatibility
final loansProvider = allLoansProvider;

/// Loan id -> total unpaid overdue EMI amount, for the whole organization.
///
/// Drives the At Risk filter and the header overdue figure. Derived from EMI
/// due dates because no loan is ever marked 'defaulted'.
final overdueByLoanProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  try {
    return await repository.getOverdueByLoan();
  } catch (_) {
    return const <String, double>{};
  }
});
