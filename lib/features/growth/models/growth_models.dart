import 'package:equatable/equatable.dart';

/// Referral model
class ReferralModel extends Equatable {
  final String id;
  final String orgId;
  final String? referrerOrgId;
  final String referralCode;
  final String status;
  final double rewardAmount;
  final int discountPercent;
  final DateTime createdAt;

  const ReferralModel({
    required this.id,
    required this.orgId,
    this.referrerOrgId,
    required this.referralCode,
    this.status = 'pending',
    this.rewardAmount = 500.0,
    this.discountPercent = 20,
    required this.createdAt,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      referrerOrgId: json['referrer_org_id'] as String?,
      referralCode: json['referral_code'] as String,
      status: json['status'] as String? ?? 'pending',
      rewardAmount: (json['reward_amount'] as num?)?.toDouble() ?? 500.0,
      discountPercent: json['discount_percent'] as int? ?? 20,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'org_id': orgId,
        'referrer_org_id': referrerOrgId,
        'referral_code': referralCode,
        'status': status,
        'reward_amount': rewardAmount,
        'discount_percent': discountPercent,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        orgId,
        referrerOrgId,
        referralCode,
        status,
        rewardAmount,
        discountPercent,
        createdAt
      ];
}

/// Feature request model
class FeatureRequestModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? category;
  final int votes;
  final String status;
  final DateTime createdAt;

  const FeatureRequestModel({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.votes = 0,
    this.status = 'under_review',
    required this.createdAt,
  });

  factory FeatureRequestModel.fromJson(Map<String, dynamic> json) {
    return FeatureRequestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String?,
      votes: json['votes'] as int? ?? 0,
      status: json['status'] as String? ?? 'under_review',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, description, category, votes, status, createdAt];
}

/// Announcement model
class AnnouncementModel extends Equatable {
  final String id;
  final String title;
  final String content;
  final String type;
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    this.type = 'info',
    this.status = 'published',
    this.publishedAt,
    required this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String? ?? 'info',
      status: json['status'] as String? ?? 'published',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, content, type, status, publishedAt, createdAt];
}
