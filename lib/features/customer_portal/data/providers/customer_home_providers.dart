import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_home_repository.dart';
import '../models/customer_transaction_model.dart';
import 'customer_member_provider.dart';

final customerHomeRepositoryProvider = Provider<CustomerHomeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerHomeRepository(client, orgId);
});

final customerDashboardProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return null;
  final repository = ref.watch(customerHomeRepositoryProvider);
  return repository.getDashboardData(memberId);
});

final customerRecentTransactionsProvider =
    FutureProvider<List<CustomerTransactionModel>>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return [];
  final repository = ref.watch(customerHomeRepositoryProvider);
  return repository.getRecentTransactions(memberId);
});

final customerAllTransactionsProvider =
    FutureProvider<List<CustomerTransactionModel>>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return [];
  final repository = ref.watch(customerHomeRepositoryProvider);
  return repository.getRecentTransactions(memberId, limit: 1000);
});
