class PaymentOrder {
  final String id;
  final String orgId;
  final String gateway; // 'razorpay' | 'phonepe'
  final String? gatewayOrderId;
  final String? loanId;
  final String? savingsPlanId;
  final String? emiScheduleId;
  final double amount;
  final String currency;
  final String status; // pending | paid | failed | cancelled | refunded
  final String? paymentMethod;
  final Map<String, dynamic> paymentDetails;
  final String? customerId;
  final String? memberId;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed' || status == 'cancelled';
  String get gatewayLabel => gateway == 'razorpay' ? 'Razorpay' : 'PhonePe';

  PaymentOrder({
    required this.id,
    required this.orgId,
    required this.gateway,
    this.gatewayOrderId,
    this.loanId,
    this.savingsPlanId,
    this.emiScheduleId,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethod,
    this.paymentDetails = const {},
    this.customerId,
    this.memberId,
    this.confirmedBy,
    this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      gateway: json['gateway'] as String,
      gatewayOrderId: json['gateway_order_id'] as String?,
      loanId: json['loan_id'] as String?,
      savingsPlanId: json['savings_plan_id'] as String?,
      emiScheduleId: json['emi_schedule_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String?,
      paymentDetails: (json['payment_details'] as Map<String, dynamic>?) ?? {},
      customerId: json['customer_id'] as String?,
      memberId: json['member_id'] as String?,
      confirmedBy: json['confirmed_by'] as String?,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now(),
    );
  }
}
