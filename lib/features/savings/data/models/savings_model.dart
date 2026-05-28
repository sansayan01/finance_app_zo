class SavingsModel {
  final String id;
  final String memberId;
  final String memberName;
  final String planName;
  final double targetAmount;
  final double currentAmount;
  final double monthlyDeposit;
  final double interestRate;
  final DateTime maturityDate;
  final DateTime createdAt;
  final String status;
  final String collectionType;
  final double prematurePenalty;
  final int totalInstallments;
  final double maturityAmount;
  final DateTime? nextDueDate;
  final String? orgId;
  final DateTime? updatedAt;

  SavingsModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.planName,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyDeposit,
    required this.interestRate,
    required this.maturityDate,
    required this.createdAt,
    this.status = 'active',
    this.collectionType = 'monthly',
    this.prematurePenalty = 2.0,
    this.totalInstallments = 12,
    this.maturityAmount = 0.0,
    this.nextDueDate,
    this.orgId,
    this.updatedAt,
  });

  factory SavingsModel.fromJson(Map<String, dynamic> json) {
    return SavingsModel(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      monthlyDeposit: (json['monthly_deposit'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
      maturityDate: DateTime.parse(json['maturity_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'active',
      collectionType: json['collection_type'] as String? ?? 'monthly',
      prematurePenalty: (json['premature_penalty'] as num?)?.toDouble() ?? 2.0,
      totalInstallments: (json['total_installments'] as num?)?.toInt() ?? 12,
      maturityAmount: (json['maturity_amount'] as num?)?.toDouble() ?? 0.0,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.tryParse(json['next_due_date'] as String)
          : null,
      orgId: json['org_id'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'member_name': memberName,
      'plan_name': planName,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'monthly_deposit': monthlyDeposit,
      'interest_rate': interestRate,
      'maturity_date': maturityDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'collection_type': collectionType,
      'premature_penalty': prematurePenalty,
      'total_installments': totalInstallments,
      'maturity_amount': maturityAmount,
      if (orgId != null) 'org_id': orgId,
    };
  }
}

class SavingsSummary {
  final double totalSavings;
  final int activeAccounts;
  final double averageBalance;
  final double interestEarned;

  SavingsSummary({
    required this.totalSavings,
    required this.activeAccounts,
    required this.averageBalance,
    required this.interestEarned,
  });

  factory SavingsSummary.fromJson(Map<String, dynamic> json) {
    return SavingsSummary(
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0,
      activeAccounts: json['active_accounts'] as int? ?? 0,
      averageBalance: (json['average_balance'] as num?)?.toDouble() ?? 0,
      interestEarned: (json['interest_earned'] as num?)?.toDouble() ?? 0,
    );
  }
}
