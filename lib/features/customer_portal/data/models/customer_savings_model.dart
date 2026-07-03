class CustomerSavingsModel {
  final String id;
  final String? planName;
  final double targetAmount;
  final double currentAmount;
  final double monthlyDeposit;
  final double interestRate;
  final int? tenureMonths;
  final DateTime? maturityDate;
  final String status;
  final String collectionType;
  final List<String> frozenDates;

  CustomerSavingsModel({
    required this.id,
    this.planName,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyDeposit,
    required this.interestRate,
    this.tenureMonths,
    this.maturityDate,
    required this.status,
    this.collectionType = 'monthly',
    this.frozenDates = const [],
  });

  factory CustomerSavingsModel.fromJson(Map<String, dynamic> json) {
    return CustomerSavingsModel(
      id: json['id']?.toString() ?? '',
      planName: json['plan_name']?.toString(),
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentAmount: (json['current_amount'] ?? 0).toDouble(),
      monthlyDeposit: (json['monthly_deposit'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0).toDouble(),
      tenureMonths: json['total_installments'] as int?,
      maturityDate: json['maturity_date'] != null
          ? DateTime.tryParse(json['maturity_date'].toString())
          : null,
      status: json['status']?.toString() ?? 'active',
      collectionType: json['collection_type']?.toString() ?? 'monthly',
      frozenDates: (json['frozen_dates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  /// Display label for the collection frequency
  String get frequencyLabel {
    switch (collectionType) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'yearly':
        return 'Yearly';
      case 'monthly':
      default:
        return 'Monthly';
    }
  }

  String get displayName => planName ?? 'Savings Account';

  /// Human-readable tenure label based on collection type, e.g. "365d",
  /// "52w", "12mo".
  String get tenureLabel {
    final installments = tenureMonths; // total_installments from DB
    if (installments == null || installments <= 0) return '';
    switch (collectionType) {
      case 'daily':
        return '${installments}d';
      case 'weekly':
        return '${installments}w';
      case 'monthly':
      default:
        return '${installments}mo';
    }
  }

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }
}
