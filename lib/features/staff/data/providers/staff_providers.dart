import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../models/staff_profile_model.dart';
import '../models/wallet_model.dart';
import '../models/streak_model.dart';
import '../models/target_model.dart';
import '../repositories/staff_repository.dart';

// Repository provider
final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StaffRepository(client);
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
