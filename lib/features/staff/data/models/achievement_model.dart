import 'package:equatable/equatable.dart';

enum AchievementType {
  collection,
  streak,
  target,
  visit,
  speed,
  accuracy,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

class AchievementModel extends Equatable {
  final String id;
  final String code;
  final String title;
  final String description;
  final AchievementType type;
  final AchievementTier tier;
  final int points;
  final String icon;
  final int requirement;
  final int? currentProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int? position;

  const AchievementModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.tier,
    required this.points,
    required this.icon,
    required this.requirement,
    this.currentProgress,
    this.isUnlocked = false,
    this.unlockedAt,
    this.position,
  });

  double get progress {
    if (isUnlocked) return 1.0;
    if (currentProgress == null || currentProgress == 0) return 0.0;
    return (currentProgress! / requirement).clamp(0.0, 1.0);
  }

  bool get isAlmostUnlocked => progress >= 0.8 && !isUnlocked;

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: AchievementType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AchievementType.collection,
      ),
      tier: AchievementTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => AchievementTier.bronze,
      ),
      points: json['points'] ?? 0,
      icon: json['icon'] ?? 'star',
      requirement: json['requirement'] ?? 1,
      currentProgress: json['current_progress'],
      isUnlocked: json['is_unlocked'] ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
          : null,
      position: json['position'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'description': description,
      'type': type.name,
      'tier': tier.name,
      'points': points,
      'icon': icon,
      'requirement': requirement,
      'current_progress': currentProgress,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'position': position,
    };

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        description,
        type,
        tier,
        points,
        icon,
        requirement,
        currentProgress,
        isUnlocked,
        unlockedAt,
        position,
      ];
}

/// Pre-defined achievements
class Achievements {
  static const List<Map<String, dynamic>> defaults = [
    // Collection achievements
    {
      'code': 'first_collection',
      'title': 'First Collection',
      'description': 'Complete your first collection',
      'type': 'collection',
      'tier': 'bronze',
      'points': 10,
      'icon': 'star',
      'requirement': 1,
    },
    {
      'code': 'collection_50',
      'title': '50 Collections',
      'description': 'Complete 50 total collections',
      'type': 'collection',
      'tier': 'silver',
      'points': 50,
      'icon': 'stars',
      'requirement': 50,
    },
    {
      'code': 'collection_100',
      'title': 'Century Club',
      'description': 'Complete 100 total collections',
      'type': 'collection',
      'tier': 'gold',
      'points': 100,
      'icon': 'workspace_premium',
      'requirement': 100,
    },
    {
      'code': 'collection_500',
      'title': 'Collector Elite',
      'description': 'Complete 500 total collections',
      'type': 'collection',
      'tier': 'platinum',
      'points': 250,
      'icon': 'diamond',
      'requirement': 500,
    },

    // Streak achievements
    {
      'code': 'streak_3',
      'title': 'Hat Trick',
      'description': 'Collect for 3 consecutive days',
      'type': 'streak',
      'tier': 'bronze',
      'points': 15,
      'icon': 'local_fire_department',
      'requirement': 3,
    },
    {
      'code': 'streak_7',
      'title': 'Week Warrior',
      'description': 'Collect for 7 consecutive days',
      'type': 'streak',
      'tier': 'silver',
      'points': 50,
      'icon': 'local_fire_department',
      'requirement': 7,
    },
    {
      'code': 'streak_30',
      'title': 'Monthly Master',
      'description': 'Collect for 30 consecutive days',
      'type': 'streak',
      'tier': 'gold',
      'points': 200,
      'icon': 'local_fire_department',
      'requirement': 30,
    },
    {
      'code': 'streak_100',
      'title': 'Streak Legend',
      'description': 'Collect for 100 consecutive days',
      'type': 'streak',
      'tier': 'diamond',
      'points': 500,
      'icon': 'local_fire_department',
      'requirement': 100,
    },

    // Target achievements
    {
      'code': 'target_first',
      'title': 'Target Achieved',
      'description': 'Hit your daily target for the first time',
      'type': 'target',
      'tier': 'bronze',
      'points': 20,
      'icon': 'flag',
      'requirement': 1,
    },
    {
      'code': 'target_5',
      'title': 'Consistent Performer',
      'description': 'Hit daily target 5 times',
      'type': 'target',
      'tier': 'silver',
      'points': 75,
      'icon': 'emoji_events',
      'requirement': 5,
    },
    {
      'code': 'target_20',
      'title': 'Target Master',
      'description': 'Hit daily target 20 times',
      'type': 'target',
      'tier': 'gold',
      'points': 150,
      'icon': 'emoji_events',
      'requirement': 20,
    },

    // Speed achievements
    {
      'code': 'speed_10',
      'title': 'Quick Hands',
      'description': 'Complete 10 collections in under 5 minutes each',
      'type': 'speed',
      'tier': 'bronze',
      'points': 30,
      'icon': 'speed',
      'requirement': 10,
    },
    {
      'code': 'speed_50',
      'title': 'Speed Star',
      'description': 'Complete 50 collections in under 5 minutes each',
      'type': 'speed',
      'tier': 'silver',
      'points': 100,
      'icon': 'speed',
      'requirement': 50,
    },

    // Visit achievements
    {
      'code': 'visit_100',
      'title': 'Road Warrior',
      'description': 'Complete 100 customer visits',
      'type': 'visit',
      'tier': 'silver',
      'points': 50,
      'icon': 'place',
      'requirement': 100,
    },
    {
      'code': 'visit_500',
      'title': 'Travel Pro',
      'description': 'Complete 500 customer visits',
      'type': 'visit',
      'tier': 'gold',
      'points': 150,
      'icon': 'map',
      'requirement': 500,
    },
  ];
}
