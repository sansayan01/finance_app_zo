import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/branch_repository.dart';
import '../../models/branch_model.dart';

/// Branch Repository Provider
final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return BranchRepository(client, orgId);
});

/// All Branches Provider
final branchesProvider = FutureProvider<List<BranchModel>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranches();
});

/// Active Branches Provider
final activeBranchesProvider = FutureProvider<List<BranchModel>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getActiveBranches();
});

/// Single Branch Provider
final branchProvider = FutureProvider.family<BranchModel?, String>((ref, id) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranch(id);
});

/// Branch Stats Provider
final branchStatsProvider =
    FutureProvider.family<BranchStats, String>((ref, branchId) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranchStats(branchId);
});

/// Branch Count Provider
final branchCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranchCount();
});

/// Potential Managers Provider
final potentialManagersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getPotentialManagers();
});

/// Branch Staff Provider
final branchStaffProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, branchId) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranchStaff(branchId);
});

/// Branch Members Provider
final branchMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, branchId) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.getBranchMembers(branchId);
});

/// Branch Notifier for CRUD operations
final branchNotifierProvider =
    StateNotifierProvider<BranchNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return BranchNotifier(repository, ref);
});

class BranchNotifier extends StateNotifier<AsyncValue<void>> {
  final BranchRepository _repository;
  final Ref _ref;

  BranchNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<BranchModel?> createBranch({
    required String name,
    required String code,
    String? address,
    String? city,
    String? addressState,
    String? pincode,
    String? phone,
    String? email,
    String? managerId,
    double? locationLat,
    double? locationLng,
  }) async {
    state = const AsyncValue.loading();
    try {
      final branch = await _repository.createBranch(
        name: name,
        code: code,
        address: address,
        city: city,
        state: addressState,
        pincode: pincode,
        phone: phone,
        email: email,
        managerId: managerId,
        locationLat: locationLat,
        locationLng: locationLng,
      );
      _ref.invalidate(branchesProvider);
      _ref.invalidate(activeBranchesProvider);
      _ref.invalidate(branchCountProvider);
      state = const AsyncValue.data(null);
      return branch;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<BranchModel?> updateBranch(
      String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final branch = await _repository.updateBranch(id, data);
      _ref.invalidate(branchesProvider);
      _ref.invalidate(activeBranchesProvider);
      _ref.invalidate(branchProvider(id));
      state = const AsyncValue.data(null);
      return branch;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteBranch(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteBranch(id);
      _ref.invalidate(branchesProvider);
      _ref.invalidate(activeBranchesProvider);
      _ref.invalidate(branchCountProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> assignManager(String branchId, String? managerId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.assignManager(branchId, managerId);
      _ref.invalidate(branchesProvider);
      _ref.invalidate(branchProvider(branchId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
