import 'package:equatable/equatable.dart';

/// Invoice model
class InvoiceModel extends Equatable {
  final String id;
  final String orgId;
  final String? subscriptionId;
  final String? stripeInvoiceId;
  final String? invoiceNumber;
  final double amount;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String currency;
  final String status;
  final String? invoiceUrl;
  final String? invoicePdf;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final List<InvoiceLineItem> lineItems;

  const InvoiceModel({
    required this.id,
    required this.orgId,
    this.subscriptionId,
    this.stripeInvoiceId,
    this.invoiceNumber,
    required this.amount,
    this.taxAmount = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.currency = 'INR',
    this.status = 'draft',
    this.invoiceUrl,
    this.invoicePdf,
    this.dueDate,
    this.paidAt,
    this.lineItems = const [],
  });

  bool get isPaid => status == 'paid';
  bool get isOpen => status == 'open';
  bool get isOverdue => isOpen && dueDate != null && dueDate!.isBefore(DateTime.now());

  String get formattedAmount {
    return '₹${totalAmount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String?,
      stripeInvoiceId: json['stripe_invoice_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'draft',
      invoiceUrl: json['invoice_url'] as String?,
      invoicePdf: json['invoice_pdf'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      lineItems: (json['lines'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, subscriptionId, stripeInvoiceId, invoiceNumber,
    amount, taxAmount, discountAmount, totalAmount, currency,
    status, invoiceUrl, invoicePdf, dueDate, paidAt, lineItems,
  ];
}

/// Invoice line item
class InvoiceLineItem extends Equatable {
  final String description;
  final double amount;
  final int quantity;
  final String? period;

  const InvoiceLineItem({
    required this.description,
    required this.amount,
    this.quantity = 1,
    this.period,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      period: json['period'] as String?,
    );
  }

  @override
  List<Object?> get props => [description, amount, quantity, period];
}
