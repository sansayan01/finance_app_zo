import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../models/leaderboard_model.dart';
import '../repositories/gamification_repository.dart';
import 'staff_providers.dart';

final gamificationRepositoryProvider = Provider.autoDispose<GamificationRepository>((ref) {
  return GamificationRepository(ref.watch(supabaseClientProvider));
});

final staffLeaderboardProvider = FutureProvider.autoDispose<LeaderboardModel>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  final repository = ref.watch(gamificationRepositoryProvider);

  return repository.getLeaderboard(
    period: LeaderboardPeriod.today,
    currentUserStaffId: profile?.id,
  );
});

final weeklyLeaderboardProvider = FutureProvider.autoDispose<LeaderboardModel>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  final repository = ref.watch(gamificationRepositoryProvider);

  return repository.getLeaderboard(
    period: LeaderboardPeriod.thisWeek,
    currentUserStaffId: profile?.id,
  );
});

final monthlyLeaderboardProvider =
    FutureProvider.autoDispose<LeaderboardModel>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  final repository = ref.watch(gamificationRepositoryProvider);

  return repository.getLeaderboard(
    period: LeaderboardPeriod.thisMonth,
    currentUserStaffId: profile?.id,
  );
});

final staffPointsProvider = FutureProvider.autoDispose<int>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return 0;
  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.getUserPoints(profile.id);
});

final staffRankProvider = FutureProvider.autoDispose<int?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;
  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.getUserRank(profile.id);
});
