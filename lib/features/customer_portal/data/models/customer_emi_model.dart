class CustomerEmiModel {
  final String id;
  final int emiNumber;
  final DateTime? dueDate;
  final double emiAmount;
  final double amountPaid;
  final double principal;
  final double interest;
  final double balanceAfter;
  final bool isPaid;
  final DateTime? paidOn;
  final String status;
  final double? penaltyAmount;

  CustomerEmiModel({
    required this.id,
    required this.emiNumber,
    this.dueDate,
    required this.emiAmount,
    required this.amountPaid,
    required this.principal,
    required this.interest,
    required this.balanceAfter,
    required this.isPaid,
    this.paidOn,
    required this.status,
    this.penaltyAmount,
  });

  factory CustomerEmiModel.fromJson(Map<String, dynamic> json) {
    return CustomerEmiModel(
      id: json['id']?.toString() ?? '',
      emiNumber: (json['emi_number'] ?? 0) as int,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      emiAmount: (json['emi_amount'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ??
          ((json['is_paid'] == true) ? (json['emi_amount'] ?? 0).toDouble() : 0),
      principal: (json['principal'] ?? 0).toDouble(),
      interest: (json['interest'] ?? 0).toDouble(),
      balanceAfter: (json['balance_after'] ?? 0).toDouble(),
      isPaid: json['is_paid'] as bool? ?? false,
      paidOn: json['paid_on'] != null
          ? DateTime.tryParse(json['paid_on'].toString())
          : json['paid_date'] != null
              ? DateTime.tryParse(json['paid_date'].toString())
              : null,
      status: json['status']?.toString() ?? 'pending',
      penaltyAmount: json['penalty_amount'] != null
          ? (json['penalty_amount']).toDouble()
          : null,
    );
  }

  bool get isOverdue {
    if (status == 'overdue') return true;
    if (isPaid || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }
}
