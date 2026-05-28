enum ActivityType {
  userAction,
  systemUpdate,
  securityAlert,
  financialTransaction,
  authAction,
}

class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String details;
  final ActivityType type;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.details,
    required this.type,
    required this.timestamp,
  });

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'System',
      action: json['action'] as String,
      details: json['details'] as String? ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.userAction,
      ),
      timestamp: DateTime.parse((json['created_at'] ?? json['timestamp']) as String),
    );
  }
}
