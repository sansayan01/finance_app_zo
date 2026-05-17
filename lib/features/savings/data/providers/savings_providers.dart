import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/savings_model.dart';
import '../repositories/savings_repository.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../transactions/data/repositories/transactions_repository.dart';
import '../../../transactions/data/models/transaction_model.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return SavingsRepository(ref.watch(supabaseClientProvider), orgId);
});

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return TransactionsRepository(ref.watch(supabaseClientProvider), orgId);
});

final allSavingsProvider = FutureProvider<List<SavingsModel>>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getAllSavingsPlans();
});

final savingsSummaryProvider = FutureProvider<SavingsSummary>((ref) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getSavingsSummary();
});

// Alias for backward compatibility if needed by other pages
final savingsProvider = allSavingsProvider;

final savingDetailProvider =
    FutureProvider.family<SavingsModel?, String>((ref, id) async {
  final repository = ref.watch(savingsRepositoryProvider);
  return repository.getSavingPlanById(id);
});

final savingTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, id) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionsBySavingsId(id);
});

final userSavingsProvider =
    FutureProvider.family<List<SavingsModel>, String>((ref, userId) async {
  final savings = await ref.watch(allSavingsProvider.future);
  return savings.where((s) => s.memberId == userId).toList();
});
