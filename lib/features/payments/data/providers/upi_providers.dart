import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../customer_portal/data/providers/customer_member_provider.dart';
import '../repositories/upi_payment_repository.dart';
import '../services/upi_service.dart';

final upiRepositoryProvider = Provider<UpiPaymentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return UpiPaymentRepository(client, orgId);
});

final upiServiceProvider = Provider<UpiService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return UpiService(client, orgId);
});

/// Pending UPI requests for the org (staff/admin/manager view).
final pendingUpiRequestsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getPendingRequests();
});

/// All UPI requests for the org with optional status filter.
final allUpiRequestsProvider =
    FutureProvider.family<List<dynamic>, String?>((ref, status) async {
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getOrgRequests(status: status);
});

/// UPI requests for the current customer.
final customerUpiRequestsProvider =
    FutureProvider<List<dynamic>>((ref) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return [];
  final repository = ref.watch(upiRepositoryProvider);
  return repository.getCustomerRequests(customerId);
});

/// Checks if a pending UPI payment exists for a specific EMI.
final hasPendingUpiProvider =
    FutureProvider.family<bool, String>((ref, emiScheduleId) async {
  final customerId = ref.watch(currentCustomerIdSyncProvider);
  if (customerId == null) return false;
  final repository = ref.watch(upiRepositoryProvider);
  return repository.checkExistingPending(
    emiScheduleId: emiScheduleId,
    customerId: customerId,
  );
});
