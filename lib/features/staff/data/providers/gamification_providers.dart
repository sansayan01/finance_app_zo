import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/supabase_provider.dart';
import '../models/achievement_model.dart';
import '../models/leaderboard_model.dart';
import '../repositories/gamification_repository.dart';
import 'staff_providers.dart';

// Gamification repository provider
final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return GamificationRepository(client);
});

// User achievements
final userAchievementsProvider = FutureProvider<List<AchievementModel>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];

  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.getUserAchievements(profile.id);
});

// Leaderboard by period
final leaderboardProvider = FutureProvider.family<LeaderboardModel, LeaderboardPeriod>((ref, period) async {
  final profile = await ref.watch(staffProfileProvider.future);
  final repository = ref.watch(gamificationRepositoryProvider);

  return repository.getLeaderboard(
    period: period,
    currentUserStaffId: profile?.id,
  );
});

// User rank
final userRankProvider = FutureProvider<int?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;

  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.getUserRank(profile.id);
});

// User points
final userPointsProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return 0;

  final repository = ref.watch(gamificationRepositoryProvider);
  return repository.getUserPoints(profile.id);
});
