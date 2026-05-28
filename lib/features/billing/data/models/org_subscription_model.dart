class OrgSubscriptionModel {
  final String id;
  final String orgId;
  final String planId;
  final String planName;
  final String status;
  final String billingCycle;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;
  final DateTime? trialStart;
  final DateTime? trialEnd;

  OrgSubscriptionModel({
    required this.id,
    required this.orgId,
    required this.planId,
    required this.planName,
    required this.status,
    required this.billingCycle,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    this.canceledAt,
    this.trialStart,
    this.trialEnd,
  });

  bool get isTrial => status == 'trialing';
  bool get isActive => status == 'active' || status == 'trialing';
  bool get isPastDue => status == 'past_due';

  int get trialDaysRemaining {
    if (trialEnd == null) return 0;
    final diff = trialEnd!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  factory OrgSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return OrgSubscriptionModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? 'Basic',
      status: json['status']?.toString() ?? 'unknown',
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      currentPeriodStart: DateTime.parse(
          json['current_period_start'] ?? DateTime.now().toIso8601String()),
      currentPeriodEnd: DateTime.parse(
          json['current_period_end'] ?? DateTime.now().toIso8601String()),
      cancelAtPeriodEnd: json['cancel_at_period_end'] ?? false,
      canceledAt: json['canceled_at'] != null
          ? DateTime.parse(json['canceled_at'])
          : null,
      trialStart: json['trial_start'] != null
          ? DateTime.parse(json['trial_start'])
          : null,
      trialEnd:
          json['trial_end'] != null ? DateTime.parse(json['trial_end']) : null,
    );
  }
}
