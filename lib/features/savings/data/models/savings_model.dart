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
  final DateTime? startDate;
  final String? tenureUnit;
  final int tenure;
  final String? orgId;
  final DateTime? updatedAt;
  final double openingBalance;
  final double totalReturnAmount;
  final int installmentsPaid;
  final DateTime? lastPaymentDate;
  final String? memberPhotoUrl;

  // Date freeze
  final bool freezeEnabled;
  final int frozenCount;
  final List<String> frozenDates;

  // SMS notifications
  final bool smsEnabled;

  /// Computed: total return minus total capital invested (opening + installments * amount).
  double get interestAmount => totalReturnAmount > 0
      ? totalReturnAmount - (openingBalance + (monthlyDeposit * totalInstallments))
      : 0;

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
    this.startDate,
    this.tenureUnit,
    this.tenure = 12,
    this.orgId,
    this.updatedAt,
    this.openingBalance = 0,
    this.totalReturnAmount = 0,
    this.installmentsPaid = 0,
    this.lastPaymentDate,
    this.memberPhotoUrl,
    this.freezeEnabled = false,
    this.frozenCount = 0,
    this.frozenDates = const [],
    this.smsEnabled = true,
  });

  factory SavingsModel.fromJson(Map<String, dynamic> json) {
    return SavingsModel(
      id: json['id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['member_name'] as String? ??
          (json['members'] as Map<String, dynamic>?)?['full_name'] as String? ??
          '',
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
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      tenureUnit: json['tenure_unit'] as String?,
      tenure: (json['tenure'] as num?)?.toInt() ?? 12,
      orgId: json['org_id'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
      totalReturnAmount: (json['total_return_amount'] as num?)?.toDouble() ?? 0,
      installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.tryParse(json['last_payment_date'] as String)
          : null,
      memberPhotoUrl: (json['member_photo_url'] as String?) ??
          (json['member_avatar_url'] as String?) ??
          (() {
            final m = json['members'] as Map<String, dynamic>?;
            if (m == null) return null;
            final direct = (m['profile_photo_url'] ?? m['shop_photo_url']) as String?;
            if (direct != null && direct.isNotEmpty) return direct;
            final profile = m['profile'] as Map<String, dynamic>?;
            return (profile?['avatar_url'] as String?);
          })(),
      freezeEnabled: json['freeze_enabled'] as bool? ?? false,
      frozenCount: (json['frozen_count'] as num?)?.toInt() ?? 0,
      frozenDates: (json['frozen_dates'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      smsEnabled: json['sms_enabled'] as bool? ?? true,
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
      if (startDate != null) 'start_date': startDate!.toIso8601String().split('T')[0],
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
      'tenure': tenure,
      if (orgId != null) 'org_id': orgId,
      'opening_balance': openingBalance,
      'total_return_amount': totalReturnAmount,
      'installments_paid': installmentsPaid,
      if (lastPaymentDate != null) 'last_payment_date': lastPaymentDate!.toIso8601String().split('T')[0],
      'freeze_enabled': freezeEnabled,
      'frozen_count': frozenCount,
      'frozen_dates': frozenDates,
      'sms_enabled': smsEnabled,
    };
  }

  SavingsModel copyWith({
    String? id,
    String? memberId,
    String? memberName,
    String? planName,
    double? targetAmount,
    double? currentAmount,
    double? monthlyDeposit,
    double? interestRate,
    DateTime? maturityDate,
    DateTime? createdAt,
    String? status,
    String? collectionType,
    double? prematurePenalty,
    int? totalInstallments,
    double? maturityAmount,
    DateTime? nextDueDate,
    DateTime? startDate,
    String? tenureUnit,
    int? tenure,
    String? orgId,
    DateTime? updatedAt,
    double? openingBalance,
    double? totalReturnAmount,
    int? installmentsPaid,
    DateTime? lastPaymentDate,
    bool? freezeEnabled,
    int? frozenCount,
    List<String>? frozenDates,
    bool? smsEnabled,
  }) {
    return SavingsModel(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      planName: planName ?? this.planName,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      monthlyDeposit: monthlyDeposit ?? this.monthlyDeposit,
      interestRate: interestRate ?? this.interestRate,
      maturityDate: maturityDate ?? this.maturityDate,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      collectionType: collectionType ?? this.collectionType,
      prematurePenalty: prematurePenalty ?? this.prematurePenalty,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      maturityAmount: maturityAmount ?? this.maturityAmount,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      startDate: startDate ?? this.startDate,
      tenureUnit: tenureUnit ?? this.tenureUnit,
      tenure: tenure ?? this.tenure,
      orgId: orgId ?? this.orgId,
      updatedAt: updatedAt ?? this.updatedAt,
      openingBalance: openingBalance ?? this.openingBalance,
      totalReturnAmount: totalReturnAmount ?? this.totalReturnAmount,
      installmentsPaid: installmentsPaid ?? this.installmentsPaid,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      freezeEnabled: freezeEnabled ?? this.freezeEnabled,
      frozenCount: frozenCount ?? this.frozenCount,
      frozenDates: frozenDates ?? this.frozenDates,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
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
