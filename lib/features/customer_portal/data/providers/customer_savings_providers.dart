import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_savings_repository.dart';
import '../models/customer_savings_model.dart';
import '../models/customer_transaction_model.dart';
import 'customer_member_provider.dart';

final customerSavingsRepositoryProvider =
    Provider<CustomerSavingsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerSavingsRepository(client, orgId);
});

final customerSavingsProvider =
    FutureProvider<List<CustomerSavingsModel>>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return [];
  final repository = ref.watch(customerSavingsRepositoryProvider);
  return repository.getCustomerSavings(memberId);
});

final customerSavingsDetailProvider =
    FutureProvider.family<CustomerSavingsModel?, String>((ref, id) async {
  final repository = ref.watch(customerSavingsRepositoryProvider);
  return repository.getSavingsById(id);
});

final customerSavingsTransactionsProvider =
    FutureProvider.family<List<CustomerTransactionModel>, String>(
        (ref, savingsId) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  final repository = ref.watch(customerSavingsRepositoryProvider);
  return repository.getSavingsTransactions(savingsId, memberId: memberId);
});
