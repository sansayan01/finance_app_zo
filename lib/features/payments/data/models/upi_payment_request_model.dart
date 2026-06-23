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

  /// The installment due date this payment is covering (loan EMI or
  /// savings installment). Null on legacy rows — callers should fall
  /// back to `emiScheduleId` lookup in that case.
  final DateTime? installmentDate;

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
    this.installmentDate,
  });

  factory UpiPaymentRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      // Postgres DATE serialises as 'YYYY-MM-DD'; try tryParse which
      // handles both bare dates and full ISO timestamps.
      return DateTime.tryParse(s);
    }

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
      installmentDate: parseDate(json['installment_date']),
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
      if (installmentDate != null)
        'installment_date': _formatDateOnly(installmentDate!),
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
      installmentDate: installmentDate,
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

  bool get isPending => status.trim().toLowerCase() == 'pending';
  bool get isConfirmed => status.trim().toLowerCase() == 'confirmed';
  bool get isRejected => status.trim().toLowerCase() == 'rejected';
  bool get isLoanPayment => loanId != null;
  bool get isSavingsPayment => savingsPlanId != null;

  /// Postgres DATE column accepts YYYY-MM-DD. Strip any time component.
  static String _formatDateOnly(DateTime d) {
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
