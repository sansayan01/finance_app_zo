import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement_model.dart';
import '../models/leaderboard_model.dart';

class GamificationRepository {
  final SupabaseClient _client;

  GamificationRepository(this._client);

  /// Get user achievements
  Future<List<AchievementModel>> getUserAchievements(String staffId) async {
    try {
      final response = await _client.from('staff_achievements').select('''
            *,
            achievements(*)
          ''').eq('staff_id', staffId);

      return (response as List)
          .map((json) => AchievementModel.fromJson({
                ...json['achievements'] ?? {},
                ...json,
                'current_progress': json['progress'],
              }))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get leaderboard
  Future<LeaderboardModel> getLeaderboard({
    required LeaderboardPeriod period,
    String? currentUserStaffId,
  }) async {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case LeaderboardPeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case LeaderboardPeriod.thisWeek:
        final weekday = now.weekday;
        startDate = DateTime(now.year, now.month, now.day - weekday + 1);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case LeaderboardPeriod.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
      case LeaderboardPeriod.allTime:
        startDate = DateTime(2020);
        endDate = now.add(const Duration(days: 1));
        break;
    }

    try {
      final response = await _client
          .from('staff_leaderboard_view')
          .select()
          .order('total_collected', ascending: false)
          .limit(50);

      final entries = <LeaderboardEntry>[];
      int rank = 1;

      for (final row in (response as List)) {
        entries.add(LeaderboardEntry.fromJson({
          ...row,
          'rank': rank++,
        }));
      }

      int? currentUserRank;
      if (currentUserStaffId != null) {
        try {
          final currentUserIndex = entries.indexWhere(
            (e) => e.staffId == currentUserStaffId,
          );
          currentUserRank = currentUserIndex >= 0 ? currentUserIndex + 1 : null;
        } catch (_) {}
      }

      return LeaderboardModel(
        period: period,
        startDate: startDate,
        endDate: endDate,
        entries: entries,
        totalParticipants: (response as List).length,
        currentUserStaffId: currentUserStaffId,
        currentUserRank: currentUserRank,
      );
    } catch (e) {
      return LeaderboardModel(
        period: period,
        startDate: startDate,
        endDate: endDate,
        entries: [],
        totalParticipants: 0,
        currentUserStaffId: currentUserStaffId,
      );
    }
  }

  /// Get user rank
  Future<int?> getUserRank(String staffId) async {
    try {
      final response = await _client
          .rpc('get_staff_rank', params: {'p_staff_id': staffId}).maybeSingle();

      return response?['rank'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Get user total points
  Future<int> getUserPoints(String staffId) async {
    try {
      final response = await _client
          .from('staff_points')
          .select('total_points')
          .eq('staff_id', staffId)
          .maybeSingle();

      return response?['total_points'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Award achievement
  Future<void> awardAchievement(String staffId, String achievementCode) async {
    await _client.from('staff_achievements').upsert({
      'staff_id': staffId,
      'title': achievementCode,
      'is_unlocked': true,
      'unlocked_at': DateTime.now().toIso8601String(),
    });
  }

  /// Update achievement progress
  Future<void> updateAchievementProgress(
    String staffId,
    String achievementCode,
    int progress,
  ) async {
    await _client.from('staff_achievements').upsert({
      'staff_id': staffId,
      'title': achievementCode,
      'progress': progress,
    }, onConflict: 'staff_id,title');
  }

  /// Add points
  Future<void> addPoints(String staffId, int points, String reason) async {
    // Add to points log
    await _client.from('staff_points_log').insert({
      'staff_id': staffId,
      'points': points,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update total points
    await _client.rpc('update_staff_points', params: {
      'p_staff_id': staffId,
      'p_points': points,
    });
  }

  /// Check and award achievements based on action
  Future<List<AchievementModel>> checkAndAwardAchievements({
    required String staffId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    final newAchievements = <AchievementModel>[];

    // Get current progress for relevant achievements
    switch (action) {
      case 'collection':
        // Check collection-related achievements
        final totalCollections = metadata?['total_collections'] as int? ?? 0;

        if (totalCollections == 1) {
          await awardAchievement(staffId, 'first_collection');
        }
        if (totalCollections >= 50) {
          await awardAchievement(staffId, 'collection_50');
        }
        if (totalCollections >= 100) {
          await awardAchievement(staffId, 'collection_100');
        }

        // Add points
        await addPoints(staffId, 5, 'Collection completed');

        break;

      case 'target_achieved':
        final targetsHit = metadata?['targets_hit'] as int? ?? 0;

        if (targetsHit == 1) {
          await awardAchievement(staffId, 'target_first');
        }
        if (targetsHit >= 5) {
          await awardAchievement(staffId, 'target_5');
        }
        if (targetsHit >= 20) {
          await awardAchievement(staffId, 'target_20');
        }

        // Add bonus points
        await addPoints(staffId, 50, 'Target achieved');

        break;

      case 'streak_updated':
        final streakDays = metadata?['streak_days'] as int? ?? 0;

        if (streakDays >= 3) {
          await awardAchievement(staffId, 'streak_3');
        }
        if (streakDays >= 7) {
          await awardAchievement(staffId, 'streak_7');
        }
        if (streakDays >= 30) {
          await awardAchievement(staffId, 'streak_30');
        }
        if (streakDays >= 100) {
          await awardAchievement(staffId, 'streak_100');
        }

        break;
    }

    return newAchievements;
  }
}
