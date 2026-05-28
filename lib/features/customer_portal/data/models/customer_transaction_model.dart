class CustomerTransactionModel {
  final String id;
  final double amount;
  final String type;
  final String? description;
  final String? paymentMode;
  final DateTime? transactionDate;
  final String status;
  final String? memberName;
  final String? referenceNumber;

  CustomerTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    this.description,
    this.paymentMode,
    this.transactionDate,
    required this.status,
    this.memberName,
    this.referenceNumber,
  });

  factory CustomerTransactionModel.fromJson(Map<String, dynamic> json) {
    return CustomerTransactionModel(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type']?.toString() ?? 'other',
      description: json['description']?.toString(),
      paymentMode: json['payment_mode']?.toString(),
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      status: json['sync_status']?.toString() ?? 'synced',
      memberName: json['member_name']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
    );
  }

  bool get isCredit =>
      type == 'savingsDeposit' ||
      type == 'loanDisbursement' ||
      type == 'deposit' ||
      type == 'collection';

  bool get isDebit =>
      type == 'emiPayment' ||
      type == 'savingsWithdrawal' ||
      type == 'withdrawal' ||
      type == 'penalty';
}
