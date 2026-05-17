import 'package:equatable/equatable.dart';

class Achievements extends Equatable {
  final List<AchievementModel> achievements;

  const Achievements({required this.achievements});

  factory Achievements.fromJson(List<dynamic> json) {
    return Achievements(
      achievements: json.map((e) => AchievementModel.fromJson(e)).toList(),
    );
  }

  @override
  List<Object?> get props => [achievements];
}

class AchievementModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int points;
  final String category;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress;
  final double target;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    required this.category,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
    this.target = 1,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      points: (json['points'] as num).toInt(),
      category: json['category'] as String,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      target: (json['target'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'points': points,
      'category': category,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'progress': progress,
      'target': target,
    };
  }

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? points,
    String? category,
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
    double? target,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      points: points ?? this.points,
      category: category ?? this.category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      target: target ?? this.target,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        icon,
        points,
        category,
        isUnlocked,
        unlockedAt,
        progress,
        target,
      ];
}
