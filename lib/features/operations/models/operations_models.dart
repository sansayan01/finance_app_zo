import 'package:equatable/equatable.dart';

/// System status/incident model
class SystemStatusModel extends Equatable {
  final String id;
  final String incidentNumber;
  final String title;
  final String? description;
  final String type;
  final List<String> affectedComponents;
  final String status;
  final String severity;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final List<dynamic> updates;
  final DateTime createdAt;

  const SystemStatusModel({
    required this.id,
    required this.incidentNumber,
    required this.title,
    this.description,
    this.type = 'incident',
    this.affectedComponents = const [],
    this.status = 'investigating',
    this.severity = 'minor',
    required this.startedAt,
    this.resolvedAt,
    this.updates = const [],
    required this.createdAt,
  });

  factory SystemStatusModel.fromJson(Map<String, dynamic> json) {
    return SystemStatusModel(
      id: json['id'] as String,
      incidentNumber: json['incident_number'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'incident',
      affectedComponents:
          (json['affected_components'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'investigating',
      severity: json['severity'] as String? ?? 'minor',
      startedAt: DateTime.parse(json['started_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      updates: json['updates'] as List<dynamic>? ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        incidentNumber,
        title,
        description,
        type,
        affectedComponents,
        status,
        severity,
        startedAt,
        resolvedAt,
        updates,
        createdAt
      ];
}

/// Help article model
class HelpArticleModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String category;
  final List<String> tags;
  final int viewCount;
  final int helpfulCount;
  final int notHelpfulCount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HelpArticleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.viewCount = 0,
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.status = 'published',
    required this.createdAt,
    required this.updatedAt,
  });

  factory HelpArticleModel.fromJson(Map<String, dynamic> json) {
    return HelpArticleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      viewCount: json['view_count'] as int? ?? 0,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      notHelpfulCount: json['not_helpful_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  double get helpfulPercentage => (helpfulCount + notHelpfulCount) > 0
      ? (helpfulCount / (helpfulCount + notHelpfulCount)) * 100
      : 0;

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        category,
        tags,
        viewCount,
        helpfulCount,
        notHelpfulCount,
        status,
        createdAt,
        updatedAt
      ];
}

/// Video tutorial model
class VideoTutorialModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String category;
  final List<String> tags;
  final int viewCount;
  final String status;
  final DateTime createdAt;

  const VideoTutorialModel({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    required this.category,
    this.tags = const [],
    this.viewCount = 0,
    this.status = 'published',
    required this.createdAt,
  });

  factory VideoTutorialModel.fromJson(Map<String, dynamic> json) {
    return VideoTutorialModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      viewCount: json['view_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        videoUrl,
        thumbnailUrl,
        durationSeconds,
        category,
        tags,
        viewCount,
        status,
        createdAt
      ];
}
