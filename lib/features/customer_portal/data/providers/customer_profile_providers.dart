import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/customer_profile_repository.dart';
import '../models/customer_profile_model.dart';
import 'customer_member_provider.dart';

final customerProfileRepositoryProvider =
    Provider<CustomerProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CustomerProfileRepository(client, orgId);
});

final customerProfileProvider =
    FutureProvider<CustomerProfileModel?>((ref) async {
  final memberId = ref.watch(currentCustomerIdSyncProvider);
  if (memberId == null) return null;
  final repository = ref.watch(customerProfileRepositoryProvider);
  final data = await repository.getMemberProfile(memberId);
  if (data == null) return null;
  return CustomerProfileModel.fromJson(data);
});

class CustomerProfileUpdateNotifier
    extends StateNotifier<AsyncValue<bool>> {
  final CustomerProfileRepository _repository;

  CustomerProfileUpdateNotifier(this._repository)
      : super(const AsyncValue.data(false));

  Future<bool> updateProfile(
    String memberId,
    Map<String, dynamic> data,
  ) async {
    state = const AsyncValue.loading();
    final success = await _repository.updateMemberProfile(memberId, data);
    state = AsyncValue.data(success);
    return success;
  }
}

final customerProfileUpdateProvider =
    StateNotifierProvider<CustomerProfileUpdateNotifier, AsyncValue<bool>>(
        (ref) {
  final repository = ref.watch(customerProfileRepositoryProvider);
  return CustomerProfileUpdateNotifier(repository);
});
