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

/// Maps transaction_id -> collection info (date + collector name) for a savings plan.
/// Used to show "Deposited up to [date]" and collector name on contribution tiles.
final savingsCollectionDatesProvider =
    FutureProvider.family<Map<String, DateTime>, String>(
        (ref, savingsId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final data = await client
        .from('savings_collections')
        .select('transaction_id, collection_date')
        .eq('savings_plan_id', savingsId);

    final map = <String, DateTime>{};
    for (final row in data) {
      final txId = row['transaction_id']?.toString();
      final dateStr = row['collection_date']?.toString();
      if (txId == null || txId.isEmpty || dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final existing = map[txId];
      if (existing == null || date.isAfter(existing)) {
        map[txId] = date;
      }
    }
    return map;
  } catch (_) {
    return {};
  }
});

/// Maps transaction_id -> collector name for a savings plan.
final savingsCollectorNamesProvider =
    FutureProvider.family<Map<String, String>, String>(
        (ref, savingsId) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final data = await client
        .from('savings_collections')
        .select('transaction_id, collected_by_name')
        .eq('savings_plan_id', savingsId);

    final map = <String, String>{};
    for (final row in data) {
      final txId = row['transaction_id']?.toString();
      final name = row['collected_by_name']?.toString();
      if (txId == null || txId.isEmpty || name == null || name.isEmpty) continue;
      map[txId] = name;
    }
    return map;
  } catch (_) {
    return {};
  }
});
