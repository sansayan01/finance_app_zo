import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/collection_repository.dart';
import '../models/staff_profile_model.dart';
import '../models/wallet_model.dart';
import '../models/streak_model.dart';
import '../models/target_model.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return StaffRepository(ref.watch(supabaseClientProvider), orgId);
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return CollectionRepository(ref.watch(supabaseClientProvider), orgId);
});

// Current staff profile
final staffProfileProvider =
    FutureProvider<StaffProfileModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );

  if (user == null) return null;

  final repository = ref.watch(staffRepositoryProvider);
  return repository.getStaffProfile(
    user.id,
    user.userMetadata?['full_name'] as String?,
    user.email,
  );
});

// Staff profile by ID (for supervisors viewing other staff)
final staffByIdProvider =
    FutureProvider.family<StaffProfileModel?, String>((ref, staffId) async {
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getStaffById(staffId);
});

// Staff wallet
final staffWalletProvider = FutureProvider<WalletModel?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;

  final repository = ref.watch(staffRepositoryProvider);
  return repository.getWallet(profile.id);
});

// Staff streak
final staffStreakProvider = FutureProvider<StreakModel?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;

  final repository = ref.watch(staffRepositoryProvider);
  return repository.getStreak(profile.id);
});

// Today's target
final todayTargetProvider = FutureProvider<TargetModel?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;

  final repository = ref.watch(staffRepositoryProvider);
  
  // Ensure target exists
  await repository.ensureTodayTarget(
    profile.id,
    profile.dailyCollectionTarget,
  );
  
  return repository.getTodayTarget(profile.id);
});

// Today's summary
final todaySummaryProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;

  final repository = ref.watch(staffRepositoryProvider);
  return repository.getTodaySummary(profile.id);
});

// Daily summary for a specific date
final dailySummaryProvider = FutureProvider.family<Map<String, dynamic>, ({String staffId, DateTime date})>((ref, params) async {
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getDailySummary(params.staffId, params.date);
});

// Today's breaks
final todayBreaksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, staffId) async {
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getTodayBreaks(staffId);
});

// Current activity status
final currentActivityProvider = FutureProvider.family<String?, String>((ref, staffId) async {
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getCurrentActivity(staffId);
});

// Refresh all staff data
final refreshStaffDataProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.invalidate(staffProfileProvider);
    ref.invalidate(staffWalletProvider);
    ref.invalidate(staffStreakProvider);
    ref.invalidate(todayTargetProvider);
    ref.invalidate(todaySummaryProvider);
  };
});

// ─── Notifications ───

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return 0;
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getUnreadNotificationCount(profile.id);
});

final recentNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getRecentNotifications(profile.id);
});

// ─── Visit / Check-In ───

final activeVisitProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getActiveVisit(profile.id);
});

// ─── Recent Activities ───

final recentActivitiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getRecentActivities(profile.id);
});

// ─── Savings Stats ───

final todaySavingsStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) {
    return {
      'total_savings': 0.0,
      'cash_savings': 0.0,
      'digital_savings': 0.0,
      'savings_count': 0,
    };
  }
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getTodaySavingsStats(profile.id);
});

// ─── Weekly Trend ───

final weeklyTrendProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getWeeklyTrend(profile.id);
});

// ─── Nearby Overdue Count ───

final nearbyOverdueCountProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return 0;
  final repository = ref.watch(staffRepositoryProvider);
  return repository.getNearbyOverdueCount(profile.id);
});
