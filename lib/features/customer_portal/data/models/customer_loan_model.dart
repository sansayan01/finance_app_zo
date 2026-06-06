class CustomerLoanModel {
  final String id;
  final String? loanNumber;
  final double amount;
  final double outstandingBalance;
  final double emiAmount;
  final double interestRate;
  final int tenureMonths;
  final String status;
  final DateTime? disbursementDate;
  final DateTime? firstEmiDate;
  final String? memberName;
  final String? purpose;
  final String frequency;
  final double totalInterest;
  final double totalRepayable;

  CustomerLoanModel({
    required this.id,
    this.loanNumber,
    required this.amount,
    required this.outstandingBalance,
    required this.emiAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.status,
    this.disbursementDate,
    this.firstEmiDate,
    this.memberName,
    this.purpose,
    this.frequency = 'monthly',
    required this.totalInterest,
    required this.totalRepayable,
  });

  factory CustomerLoanModel.fromJson(Map<String, dynamic> json) {
    return CustomerLoanModel(
      id: json['id']?.toString() ?? '',
      loanNumber: json['loan_number']?.toString(),
      amount: (json['amount'] ?? json['principal'] ?? 0).toDouble(),
      outstandingBalance:
          (json['outstanding_amount'] ?? json['outstanding_balance'] ?? 0)
              .toDouble(),
      emiAmount: (json['emi_amount'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0).toDouble(),
      tenureMonths:
          ((json['tenure_months'] ?? json['tenure_value']) as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
      disbursementDate: json['disbursement_date'] != null
          ? DateTime.tryParse(json['disbursement_date'].toString())
          : null,
      firstEmiDate: json['first_emi_date'] != null
          ? DateTime.tryParse(json['first_emi_date'].toString())
          : null,
      memberName: json['member_name']?.toString(),
      purpose: json['purpose']?.toString(),
      frequency: json['frequency']?.toString() ?? 'monthly',
      totalInterest: (json['total_interest'] ?? 0.0).toDouble(),
      totalRepayable: (json['total_repayable'] ?? 0.0).toDouble(),
    );
  }

  double get paidPercentage {
    if (amount <= 0) return 0;
    return ((amount - outstandingBalance) / amount * 100).clamp(0, 100);
  }

  bool get isOverdue => status == 'defaulted';
}

class CustomerLoanSummary {
  final int activeLoans;
  final double totalOutstanding;
  final double totalDisbursed;

  CustomerLoanSummary({
    required this.activeLoans,
    required this.totalOutstanding,
    required this.totalDisbursed,
  });

  factory CustomerLoanSummary.fromLoans(List<CustomerLoanModel> loans) {
    final active = loans.where((l) => l.status == 'active').toList();
    return CustomerLoanSummary(
      activeLoans: active.length,
      totalOutstanding:
          active.fold(0.0, (sum, l) => sum + l.outstandingBalance),
      totalDisbursed: loans.fold(0.0, (sum, l) => sum + l.amount),
    );
  }
}
