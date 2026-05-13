import 'package:intl/intl.dart';

class InvoiceModel {
  final String id;
  final String orgId;
  final String subscriptionId;
  final String? invoiceNumber;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? invoicePdf;
  final String? invoiceUrl;
  final List<InvoiceLineItem> lineItems;

  InvoiceModel({
    required this.id,
    required this.orgId,
    required this.subscriptionId,
    this.invoiceNumber,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.dueDate,
    this.paidAt,
    this.invoicePdf,
    this.invoiceUrl,
    this.lineItems = const [],
  });

  bool get isPaid => status == 'paid';
  bool get isOpen => status == 'open';
  bool get isOverdue => status == 'open' && dueDate.isBefore(DateTime.now());

  String get statusDisplay => status[0].toUpperCase() + status.substring(1);

  String get formattedAmount => NumberFormat.currency(
        symbol: _getCurrencySymbol(currency),
        decimalDigits: 0,
      ).format(amount);

  String _getCurrencySymbol(String code) {
    if (code == 'INR') return '\u20B9';
    if (code == 'USD') return '\u0024';
    return code;
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString() ?? '',
      invoiceNumber: json['number']?.toString(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'unpaid',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      dueDate: DateTime.parse(json['due_date'] ?? DateTime.now().toIso8601String()),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      invoicePdf: json['invoice_pdf']?.toString(),
      invoiceUrl: json['invoice_url']?.toString(),
      lineItems: (json['line_items'] as List?)
              ?.map((e) => InvoiceLineItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class InvoiceLineItem {
  final String description;
  final double amount;
  final String? period;

  InvoiceLineItem({
    required this.description,
    required this.amount,
    this.period,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      period: json['period']?.toString(),
    );
  }
}
