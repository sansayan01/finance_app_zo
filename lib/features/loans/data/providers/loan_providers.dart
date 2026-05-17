import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loan_model.dart';
import '../repositories/loans_repository.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';

final loansRepositoryProvider = Provider<LoansRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return LoansRepository(ref.watch(supabaseClientProvider), orgId);
});

// Providers for loan metrics and lists
final allLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getAllLoans();
});

final loanSummaryProvider = FutureProvider<LoanSummary>((ref) async {
  final repository = ref.watch(loansRepositoryProvider);
  return repository.getLoanSummary();
});

// Alias for backward compatibility
final loansProvider = allLoansProvider;
