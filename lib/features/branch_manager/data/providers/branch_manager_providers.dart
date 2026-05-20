import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../repositories/branch_manager_repository.dart';
import '../models/branch_stats_model.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Branch Manager Repository Provider
final branchManagerRepositoryProvider =
    Provider<BranchManagerRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BranchManagerRepository(client);
});

/// Branch Stats Provider
final branchStatsProvider =
    FutureProvider.family<BranchStats, String>((ref, branchId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchStats(branchId);
});

/// Branch Staff Provider
final branchStaffProvider =
    FutureProvider.family<List<ProfileModel>, String>((ref, branchId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchStaff(branchId);
});

/// Branch Collections Provider (for a specific date)
final branchCollectionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (String, DateTime)>(
        (ref, params) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchCollections(params.$1, date: params.$2);
});

/// Pending Approvals Provider
final pendingApprovalsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getPendingApprovals(branchId);
});

/// Branch Overdue Loans Provider
final branchOverdueLoansProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, branchId) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchOverdueLoans(branchId);
});

/// Staff Performance Provider
final staffPerformanceProvider = FutureProvider.family<
    List<Map<String, dynamic>>,
    (String, DateTime?, DateTime?)>((ref, params) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getStaffPerformance(params.$1,
      startDate: params.$2, endDate: params.$3);
});

/// Branch Daily Summary Provider
final branchDailySummaryProvider =
    FutureProvider.family<Map<String, dynamic>, (String, DateTime)>(
        (ref, params) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchDailySummary(params.$1, params.$2);
});

/// Branch Targets Provider
final branchTargetsProvider =
    FutureProvider.family<Map<String, dynamic>, (String, int, int)>(
        (ref, params) async {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return repository.getBranchTargets(params.$1,
      month: params.$2, year: params.$3);
});

/// Current User's Branch ID Provider
final currentUserBranchIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.branchId;
});

/// Branch Manager Dashboard Data Provider
final branchManagerDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final branchId = ref.watch(currentUserBranchIdProvider);
  if (branchId == null) throw Exception('No branch assigned');

  final repository = ref.watch(branchManagerRepositoryProvider);

  final stats = await repository.getBranchStats(branchId);
  final pendingApprovals = await repository.getPendingApprovals(branchId);
  final dailySummary =
      await repository.getBranchDailySummary(branchId, DateTime.now());
  final targets = await repository.getBranchTargets(branchId);

  return {
    'stats': stats,
    'pending_approvals_count': pendingApprovals.length,
    'daily_summary': dailySummary,
    'targets': targets,
  };
});

/// Approval Actions Notifier
class ApprovalNotifier extends StateNotifier<AsyncValue<void>> {
  final BranchManagerRepository _repository;
  final Ref _ref;

  ApprovalNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> approve(String requestId, String managerId,
      {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.approveRequest(requestId, managerId, notes: notes);
      _ref.invalidate(pendingApprovalsProvider);
      _ref.invalidate(branchManagerDashboardProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reject(String requestId, String managerId, String reason) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectRequest(requestId, managerId, reason);
      _ref.invalidate(pendingApprovalsProvider);
      _ref.invalidate(branchManagerDashboardProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final approvalActionsProvider =
    StateNotifierProvider<ApprovalNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(branchManagerRepositoryProvider);
  return ApprovalNotifier(repository, ref);
});
