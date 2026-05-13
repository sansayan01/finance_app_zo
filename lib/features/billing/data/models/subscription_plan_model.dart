import 'package:intl/intl.dart';

class SubscriptionPlanModel {
  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final Map<String, dynamic> limits;
  final List<String> features;
  final bool isActive;
  final int sortOrder;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.limits,
    required this.features,
    required this.isActive,
    required this.sortOrder,
  });

  bool get isEnterprise => name.toLowerCase().contains('enterprise');
  bool get isPopular => name.toLowerCase().contains('pro');

  String get formattedMonthly => NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 0,
      ).format(monthlyPrice);

  String get formattedYearly => NumberFormat.currency(
        symbol: '₹',
        decimalDigits: 0,
      ).format(yearlyPrice);

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      monthlyPrice: (json['monthly_price'] ?? 0.0).toDouble(),
      yearlyPrice: (json['yearly_price'] ?? 0.0).toDouble(),
      limits: Map<String, dynamic>.from(json['limits'] ?? {}),
      features: List<String>.from(json['features'] ?? []),
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
