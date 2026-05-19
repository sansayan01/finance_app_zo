import '../../../../core/constants/enums.dart';

class TransactionModel {
  final String id;
  final String memberId;
  final String memberName;
  final TransactionType type;
  final double amount;
  final String? loanId;
  final String? savingsId;
  final DateTime createdAt;
  final String? description;
  final PaymentMode? paymentMode;
  final String? agentId;

  TransactionModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.amount,
    this.loanId,
    this.savingsId,
    required this.createdAt,
    this.description,
    this.paymentMode,
    this.agentId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? '',
      type: TransactionType.values.firstWhere(
        (e) =>
            e.name == json['type'] ||
            _toCamel(json['type']?.toString() ?? '') == e.name,
        orElse: () => TransactionType.other,
      ),
      amount: _parseAmount(json['amount']),
      loanId: json['loan_id']?.toString(),
      savingsId: json['savings_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      description: json['description']?.toString(),
      paymentMode: json['payment_mode'] != null
          ? PaymentMode.values.firstWhere(
              (e) => e.name == json['payment_mode'],
              orElse: () => PaymentMode.cash,
            )
          : null,
      agentId: json['agent_id']?.toString(),
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String _toCamel(String snake) {
    List<String> parts = snake.split('_');
    if (parts.isEmpty) return snake;
    String res = parts[0];
    for (int i = 1; i < parts.length; i++) {
      res += parts[i][0].toUpperCase() + parts[i].substring(1);
    }
    return res;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'member_id': memberId,
      'member_name': memberName,
      'type': type.name,
      'amount': amount,
      'loan_id': loanId,
      'savings_id': savingsId,
      'created_at': createdAt.toIso8601String(),
      'description': description,
      'payment_mode': paymentMode?.name,
      'agent_id': agentId,
    };
  }
}
