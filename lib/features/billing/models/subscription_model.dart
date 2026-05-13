class SubscriptionModel {
  final String plan;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxMembers;
  final int maxBranches;
  final int maxStaff;

  SubscriptionModel({
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    this.maxMembers = 100,
    this.maxBranches = 1,
    this.maxStaff = 3,
  });

  bool get isActive => status == 'active' || status == 'trialing';
  bool get isTrial => status == 'trialing';

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      plan: json['plan'] as String? ?? 'starter',
      status: json['status'] as String? ?? 'active',
      startDate: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      endDate: json['trial_end'] != null ? DateTime.tryParse(json['trial_end'] as String) : null,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 100,
      maxBranches: (json['max_branches'] as num?)?.toInt() ?? 1,
      maxStaff: (json['max_staff'] as num?)?.toInt() ?? 3,
    );
  }
}
