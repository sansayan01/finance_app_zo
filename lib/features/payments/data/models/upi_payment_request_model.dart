class UpiPaymentRequest {
  final String id;
  final String orgId;
  final String customerId;
  final String? memberId;
  final String? loanId;
  final String? savingsPlanId;
  final String? emiScheduleId;
  final double amount;
  final String upiVpa;
  final String? transactionRef;
  final String status;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UpiPaymentRequest({
    required this.id,
    required this.orgId,
    required this.customerId,
    this.memberId,
    this.loanId,
    this.savingsPlanId,
    this.emiScheduleId,
    required this.amount,
    required this.upiVpa,
    this.transactionRef,
    required this.status,
    this.confirmedBy,
    this.confirmedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UpiPaymentRequest.fromJson(Map<String, dynamic> json) {
    return UpiPaymentRequest(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      memberId: json['member_id']?.toString(),
      loanId: json['loan_id']?.toString(),
      savingsPlanId: json['savings_plan_id']?.toString(),
      emiScheduleId: json['emi_schedule_id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      upiVpa: json['upi_vpa']?.toString() ?? '',
      transactionRef: json['transaction_ref']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      confirmedBy: json['confirmed_by']?.toString(),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'org_id': orgId,
      'customer_id': customerId,
      if (memberId != null) 'member_id': memberId,
      if (loanId != null) 'loan_id': loanId,
      if (savingsPlanId != null) 'savings_plan_id': savingsPlanId,
      if (emiScheduleId != null) 'emi_schedule_id': emiScheduleId,
      'amount': amount,
      'upi_vpa': upiVpa,
      if (transactionRef != null) 'transaction_ref': transactionRef,
      'status': status,
    };
  }

  UpiPaymentRequest copyWith({
    String? status,
    String? confirmedBy,
    DateTime? confirmedAt,
    String? rejectionReason,
    String? transactionRef,
  }) {
    return UpiPaymentRequest(
      id: id,
      orgId: orgId,
      customerId: customerId,
      memberId: memberId,
      loanId: loanId,
      savingsPlanId: savingsPlanId,
      emiScheduleId: emiScheduleId,
      amount: amount,
      upiVpa: upiVpa,
      transactionRef: transactionRef ?? this.transactionRef,
      status: status ?? this.status,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isLoanPayment => loanId != null;
  bool get isSavingsPayment => savingsPlanId != null;
}
