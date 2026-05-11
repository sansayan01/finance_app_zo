import 'package:equatable/equatable.dart';

enum LeaderboardPeriod {
  today,
  thisWeek,
  thisMonth,
  allTime,
}

class LeaderboardEntry extends Equatable {
  final String staffId;
  final String staffName;
  final String? avatarUrl;
  final int rank;
  final double totalCollected;
  final int collectionsCount;
  final int visitsCount;
  final double? targetAchieved;
  final int? streakDays;

  const LeaderboardEntry({
    required this.staffId,
    required this.staffName,
    this.avatarUrl,
    required this.rank,
    required this.totalCollected,
    required this.collectionsCount,
    required this.visitsCount,
    this.targetAchieved,
    this.streakDays,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      staffId: json['staff_id'] ?? '',
      staffName: json['staff_name'] ?? json['name'] ?? 'Unknown',
      avatarUrl: json['avatar_url'],
      rank: json['rank'] ?? 0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      collectionsCount: json['collections_count'] ?? 0,
      visitsCount: json['visits_count'] ?? 0,
      targetAchieved: (json['target_achieved'] as num?)?.toDouble(),
      streakDays: json['streak_days'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'staff_name': staffName,
      'avatar_url': avatarUrl,
      'rank': rank,
      'total_collected': totalCollected,
      'collections_count': collectionsCount,
      'visits_count': visitsCount,
      'target_achieved': targetAchieved,
      'streak_days': streakDays,
    };

  @override
  List<Object?> get props => [
        staffId,
        staffName,
        avatarUrl,
        rank,
        totalCollected,
        collectionsCount,
        visitsCount,
        targetAchieved,
        streakDays,
      ];
}

class LeaderboardModel extends Equatable {
  final LeaderboardPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final List<LeaderboardEntry> entries;
  final int totalParticipants;
  final String? currentUserStaffId;
  final int? currentUserRank;

  const LeaderboardModel({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.totalParticipants,
    this.currentUserStaffId,
    this.currentUserRank,
  });

  LeaderboardEntry? get currentUserEntry {
    if (currentUserStaffId == null) return null;
    try {
      return entries.firstWhere((e) => e.staffId == currentUserStaffId);
    } catch (_) {
      return null;
    }
  }

  List<LeaderboardEntry> get topThree => entries.take(3).toList();
  List<LeaderboardEntry> get topTen => entries.take(10).toList();

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      period: LeaderboardPeriod.values.firstWhere(
        (p) => p.name == json['period'],
        orElse: () => LeaderboardPeriod.thisWeek,
      ),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      entries: (json['entries'] as List?)
              ?.map((e) => LeaderboardEntry.fromJson(e))
              .toList() ??
          [],
      totalParticipants: json['total_participants'] ?? 0,
      currentUserStaffId: json['current_user_staff_id'],
      currentUserRank: json['current_user_rank'],
    );
  }

  @override
  List<Object?> get props => [
        period,
        startDate,
        endDate,
        entries,
        totalParticipants,
        currentUserStaffId,
        currentUserRank,
      ];
}
