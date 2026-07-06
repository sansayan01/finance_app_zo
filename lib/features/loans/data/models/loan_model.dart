import '../../../../core/constants/enums.dart';

class LoanModel {
  final String id;
  final String customerId;
  final String? memberId;
  final String? planId;
  final String? staffId;
  final String loanNumber;
  final double amount;
  final double interestRate;
  final int tenureMonths;
  final int? tenureValue;
  final String? tenureUnit;
  final String? frequency;
  final double emiAmount;
  final double totalInterest;
  final double totalRepayable;
  final double outstandingBalance;
  final InterestType interestType;
  final DateTime? disbursementDate;
  final DateTime? firstEmiDate;
  final DateTime? nextDueDate;
  final int paidEmis;
  final int totalEmis;
  final DateTime? lastPaymentDate;
  final LoanStatus status;
  final String? purpose;
  final String? remarks;
  final String? createdBy;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Interest details
  final String? interestMode;   // 'flat', 'reducing', 'amount', 'percentage'
  final double? interestAmount; // actual interest in ₹ (for amount mode)
  final String? interestBasis;  // 'onPrincipal', 'onTotal'

  // Date freeze
  final bool freezeEnabled;
  final int frozenCount;
  final int gracePeriodDays;

  // Joined Data
  final String? customerName;
  final String? customerPhone;
  final String? customerPhotoUrl;
  final String? staffName;
  final String? staffPhone;

  LoanModel({
    required this.id,
    required this.customerId,
    this.memberId,
    this.planId,
    this.staffId,
    required this.loanNumber,
    required this.amount,
    required this.interestRate,
    required this.tenureMonths,
    this.tenureValue,
    this.tenureUnit,
    this.frequency,
    required this.emiAmount,
    required this.totalInterest,
    required this.totalRepayable,
    required this.outstandingBalance,
    required this.interestType,
    this.disbursementDate,
    this.firstEmiDate,
    this.nextDueDate,
    this.paidEmis = 0,
    this.totalEmis = 0,
    this.lastPaymentDate,
    required this.status,
    this.purpose,
    this.remarks,
    this.createdBy,
    this.approvedBy,
    this.rejectedBy,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.customerPhone,
    this.customerPhotoUrl,
    this.staffName,
    this.staffPhone,
    this.interestMode,
    this.interestAmount,
    this.interestBasis,
    this.freezeEnabled = false,
    this.frozenCount = 0,
    this.gracePeriodDays = 0,
  });

  LoanModel copyWith({
    String? id,
    String? customerId,
    String? memberId,
    String? planId,
    String? staffId,
    String? loanNumber,
    double? amount,
    double? interestRate,
    int? tenureMonths,
    int? tenureValue,
    String? tenureUnit,
    String? frequency,
    double? emiAmount,
    double? totalInterest,
    double? totalRepayable,
    double? outstandingBalance,
    InterestType? interestType,
    DateTime? disbursementDate,
    DateTime? firstEmiDate,
    DateTime? nextDueDate,
    int? paidEmis,
    int? totalEmis,
    DateTime? lastPaymentDate,
    LoanStatus? status,
    String? purpose,
    String? remarks,
    String? createdBy,
    String? approvedBy,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? freezeEnabled,
    int? frozenCount,
    int? gracePeriodDays,
    String? customerName,
    String? customerPhone,
    String? customerPhotoUrl,
    String? staffName,
    String? staffPhone,
    String? interestMode,
    double? interestAmount,
    String? interestBasis,
  }) {
    return LoanModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      memberId: memberId ?? this.memberId,
      planId: planId ?? this.planId,
      staffId: staffId ?? this.staffId,
      loanNumber: loanNumber ?? this.loanNumber,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      tenureValue: tenureValue ?? this.tenureValue,
      tenureUnit: tenureUnit ?? this.tenureUnit,
      frequency: frequency ?? this.frequency,
      emiAmount: emiAmount ?? this.emiAmount,
      totalInterest: totalInterest ?? this.totalInterest,
      totalRepayable: totalRepayable ?? this.totalRepayable,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      interestType: interestType ?? this.interestType,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      firstEmiDate: firstEmiDate ?? this.firstEmiDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      paidEmis: paidEmis ?? this.paidEmis,
      totalEmis: totalEmis ?? this.totalEmis,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      status: status ?? this.status,
      purpose: purpose ?? this.purpose,
      remarks: remarks ?? this.remarks,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      freezeEnabled: freezeEnabled ?? this.freezeEnabled,
      frozenCount: frozenCount ?? this.frozenCount,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerPhotoUrl: customerPhotoUrl ?? this.customerPhotoUrl,
      staffName: staffName ?? this.staffName,
      staffPhone: staffPhone ?? this.staffPhone,
      interestMode: interestMode ?? this.interestMode,
      interestAmount: interestAmount ?? this.interestAmount,
      interestBasis: interestBasis ?? this.interestBasis,
    );
  }

  String get formattedTenure {
    if (tenureValue != null && tenureUnit != null) {
      final unitLabel = _getUnitLabel(tenureUnit!);
      return '$tenureValue $unitLabel${tenureValue! > 1 ? 's' : ''}';
    }
    return '$tenureMonths Months';
  }

  String _getUnitLabel(String unit) {
    switch (unit.toLowerCase()) {
      case 'day':
      case 'days':
        return 'Day';
      case 'week':
      case 'weeks':
        return 'Week';
      case 'month':
      case 'months':
        return 'Month';
      case 'year':
      case 'years':
        return 'Year';
      default:
        return 'Month';
    }
  }

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    // Handle Supabase join format (customer_id FK → members table)
    final profilesJson =
        (json['members'] ?? json['profiles'] ?? json['customers']) as Map<String, dynamic>?;
    final staffJson = json['staff'] as Map<String, dynamic>?;

    return LoanModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String? ??
          json['borrower_id'] as String? ??
          '',
      memberId: json['member_id'] as String?,
      planId: json['plan_id'] as String?,
      staffId: json['staff_id'] as String?,
      loanNumber: json['loan_number'] as String? ??
          json['id'].toString().substring(0, 8).toUpperCase(),
      amount: (json['amount'] ?? json['principal_amount'] ?? 0.0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0.0).toDouble(),
      tenureMonths: json['tenure_months'] as int? ?? 12,
      tenureValue: json['tenure_value'] as int?,
      tenureUnit: json['tenure_unit'] as String?,
      frequency: json['frequency'] as String?,
      emiAmount: (json['emi_amount'] ?? json['estimated_installment'] ?? 0.0)
          .toDouble(),
      totalInterest: (json['total_interest'] ?? 0.0).toDouble(),
      totalRepayable:
          (json['total_repayable'] ?? json['total_exposure'] ?? 0.0).toDouble(),
      outstandingBalance: (json['outstanding_amount'] ??
              json['outstanding_balance'] ??
              json['total_exposure'] ??
              0.0)
          .toDouble(),
      interestType: InterestType.values.firstWhere(
        (e) =>
            e.name == json['interest_type'] ||
            _toSnake(e.name) == json['interest_type'],
        orElse: () => InterestType.flat,
      ),
      disbursementDate: json['disbursement_date'] != null
          ? DateTime.parse(json['disbursement_date'] as String)
          : null,
      firstEmiDate:
          (json['first_emi_date'] ?? json['first_installment_date']) != null
              ? DateTime.parse((json['first_emi_date'] ??
                  json['first_installment_date']) as String)
              : null,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.parse(json['next_due_date'] as String)
          : null,
      paidEmis: (json['paid_emis'] as num?)?.toInt() ?? 0,
      totalEmis: (json['total_emis'] as num?)?.toInt() ?? 0,
      lastPaymentDate: json['last_payment_date'] != null
          ? DateTime.parse(json['last_payment_date'] as String)
          : null,
      status: LoanStatus.values.firstWhere(
        (e) =>
            e.name == json['status'] ||
            _toSnake(e.name) == json['status'] ||
            (json['status'] == 'defaulted' && e == LoanStatus.defaultStatus),
        orElse: () => LoanStatus.draft,
      ),
      purpose: json['purpose'] as String?,
      remarks: json['remarks'] as String?,
      createdBy: json['created_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      rejectedBy: json['rejected_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      customerName: profilesJson?['full_name'] as String?,
      customerPhone: profilesJson?['phone'] as String?,
      customerPhotoUrl: () {
        final direct = profilesJson?['profile_photo_url'] as String?;
        if (direct != null && direct.isNotEmpty) return direct;
        final shop = profilesJson?['shop_photo_url'] as String?;
        if (shop != null && shop.isNotEmpty) return shop;
        final profileJson = profilesJson?['profile'] as Map<String, dynamic>?;
        final avatar = profileJson?['avatar_url'] as String?;
        if (avatar != null && avatar.isNotEmpty) return avatar;
        return null;
      }(),
      staffName: staffJson?['full_name'] as String?,
      staffPhone: staffJson?['phone'] as String?,
      interestMode: json['interest_mode'] as String?,
      interestAmount: (json['interest_amount'] as num?)?.toDouble(),
      interestBasis: json['interest_basis'] as String?,
      freezeEnabled: json['freeze_enabled'] as bool? ?? false,
      frozenCount: (json['frozen_count'] as num?)?.toInt() ?? 0,
      gracePeriodDays: (json['grace_period_days'] as num?)?.toInt() ?? 0,
    );
  }

  static String _toSnake(String s) {
    return s.replaceAllMapped(
        RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'plan_id': planId,
      'staff_id': staffId,
      'loan_number': loanNumber,
      'amount': amount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      if (tenureValue != null) 'tenure_value': tenureValue,
      if (tenureUnit != null) 'tenure_unit': tenureUnit,
      if (frequency != null) 'frequency': frequency,
      'emi_amount': emiAmount,
      'total_interest': totalInterest,
      'total_repayable': totalRepayable,
      'outstanding_amount': outstandingBalance,
      'interest_type': interestType.name,
      'freeze_enabled': freezeEnabled,
      'frozen_count': frozenCount,
      'grace_period_days': gracePeriodDays,
      'disbursement_date': disbursementDate?.toIso8601String(),
      'first_emi_date': firstEmiDate?.toIso8601String(),
      'paid_emis': paidEmis,
      'total_emis': totalEmis,
      'last_payment_date': lastPaymentDate?.toIso8601String().split('T').first,
      'status': status.name,
      'purpose': purpose,
      'remarks': remarks,
      'created_by': createdBy,
      'approved_by': approvedBy,
      'rejected_by': rejectedBy,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class LoanSummary {
  final int totalLoans;
  final int activeLoans;
  final int defaultLoans;
  final double totalOutstanding;
  final double totalDisbursed;
  final double totalCollected;
  final double overdueAmount;
  final double parPercentage;

  LoanSummary({
    required this.totalLoans,
    required this.activeLoans,
    required this.defaultLoans,
    required this.totalOutstanding,
    required this.totalDisbursed,
    required this.totalCollected,
    required this.overdueAmount,
    required this.parPercentage,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) {
    return LoanSummary(
      totalLoans: json['total_loans'] as int? ?? 0,
      activeLoans: json['active_loans'] as int? ?? 0,
      defaultLoans: json['default_loans'] as int? ?? 0,
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? 0,
      totalDisbursed: (json['total_disbursed'] as num?)?.toDouble() ?? 0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0,
      parPercentage: (json['par_percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}
