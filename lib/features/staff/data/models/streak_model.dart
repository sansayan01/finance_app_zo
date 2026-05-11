import 'package:equatable/equatable.dart';

class StreakModel extends Equatable {
  final String id;
  final String staffId;
  
  // Streak data
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCollectionDate;
  
  // Achievements
  final int totalCollections;
  final double totalAmountCollected;
  final int perfectDays;
  
  // Badges
  final List<String> badges;
  
  // Timestamps
  final DateTime updatedAt;
  final DateTime createdAt;

  const StreakModel({
    required this.id,
    required this.staffId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCollectionDate,
    this.totalCollections = 0,
    this.totalAmountCollected = 0.0,
    this.perfectDays = 0,
    this.badges = const [],
    required this.updatedAt,
    required this.createdAt,
  });

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    return StreakModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastCollectionDate: json['last_collection_date'] != null
          ? DateTime.parse(json['last_collection_date'] as String)
          : null,
      totalCollections: json['total_collections'] as int? ?? 0,
      totalAmountCollected:
          (json['total_amount_collected'] as num?)?.toDouble() ?? 0.0,
      perfectDays: json['perfect_days'] as int? ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_collection_date': lastCollectionDate?.toIso8601String().split('T').first,
      'total_collections': totalCollections,
      'total_amount_collected': totalAmountCollected,
      'perfect_days': perfectDays,
      'badges': badges,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get hasActiveStreak => currentStreak > 0;
  bool get isNewRecord => currentStreak >= longestStreak && currentStreak > 0;
  
  String get streakEmoji {
    if (currentStreak >= 30) return '🔥🔥🔥';
    if (currentStreak >= 14) return '🔥🔥';
    if (currentStreak >= 7) return '🔥';
    if (currentStreak >= 3) return '✨';
    return '';
  }

  StreakModel copyWith({
    String? id,
    String? staffId,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCollectionDate,
    int? totalCollections,
    double? totalAmountCollected,
    int? perfectDays,
    List<String>? badges,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return StreakModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCollectionDate: lastCollectionDate ?? this.lastCollectionDate,
      totalCollections: totalCollections ?? this.totalCollections,
      totalAmountCollected: totalAmountCollected ?? this.totalAmountCollected,
      perfectDays: perfectDays ?? this.perfectDays,
      badges: badges ?? this.badges,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        staffId,
        currentStreak,
        longestStreak,
        lastCollectionDate,
        totalCollections,
        totalAmountCollected,
        perfectDays,
        badges,
        updatedAt,
        createdAt,
      ];
}
