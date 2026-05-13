import 'package:equatable/equatable.dart';

/// Organization subscription model
class OrgSubscriptionModel extends Equatable {
  final String id;
  final String orgId;
  final String planId;
  final String planName;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String billingCycle;
  final String status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final bool cancelAtPeriodEnd;
  final DateTime? canceledAt;

  const OrgSubscriptionModel({
    required this.id,
    required this.orgId,
    required this.planId,
    required this.planName,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.billingCycle = 'monthly',
    this.status = 'active',
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialStart,
    this.trialEnd,
    this.cancelAtPeriodEnd = false,
    this.canceledAt,
  });

  /// Is subscription active?
  bool get isActive => status == 'active' || status == 'trialing';

  /// Is this a trial subscription?
  bool get isTrial => status == 'trialing';

  /// Is subscription past due?
  bool get isPastDue => status == 'past_due';

  /// Is subscription canceled?
  bool get isCanceled => status == 'canceled';

  /// Days remaining in trial
  int get trialDaysRemaining {
    if (trialEnd == null) return 0;
    final remaining = trialEnd!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Days until renewal
  int get daysUntilRenewal {
    if (currentPeriodEnd == null) return 0;
    final remaining = currentPeriodEnd!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Status display text
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Active';
      case 'trialing':
        return 'Trial';
      case 'past_due':
        return 'Past Due';
      case 'canceled':
        return 'Canceled';
      case 'paused':
        return 'Paused';
      case 'incomplete':
        return 'Incomplete';
      default:
        return status;
    }
  }

  factory OrgSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return OrgSubscriptionModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      billingCycle: json['billing_cycle'] as String? ?? 'monthly',
      status: json['status'] as String? ?? 'active',
      currentPeriodStart: json['current_period_start'] != null
          ? DateTime.tryParse(json['current_period_start'] as String)
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.tryParse(json['current_period_end'] as String)
          : null,
      trialStart: json['trial_start'] != null
          ? DateTime.tryParse(json['trial_start'] as String)
          : null,
      trialEnd: json['trial_end'] != null
          ? DateTime.tryParse(json['trial_end'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      canceledAt: json['canceled_at'] != null
          ? DateTime.tryParse(json['canceled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'org_id': orgId,
    'plan_id': planId,
    'plan_name': planName,
    'stripe_customer_id': stripeCustomerId,
    'stripe_subscription_id': stripeSubscriptionId,
    'billing_cycle': billingCycle,
    'status': status,
    'current_period_start': currentPeriodStart?.toIso8601String(),
    'current_period_end': currentPeriodEnd?.toIso8601String(),
    'trial_start': trialStart?.toIso8601String(),
    'trial_end': trialEnd?.toIso8601String(),
    'cancel_at_period_end': cancelAtPeriodEnd,
    'canceled_at': canceledAt?.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id, orgId, planId, planName, stripeCustomerId, stripeSubscriptionId,
    billingCycle, status, currentPeriodStart, currentPeriodEnd,
    trialStart, trialEnd, cancelAtPeriodEnd, canceledAt,
  ];
}
