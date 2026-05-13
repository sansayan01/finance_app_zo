import 'package:equatable/equatable.dart';

/// Subscription plan model
class SubscriptionPlanModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double priceMonthly;
  final double? priceYearly;
  final String currency;
  final int maxMembers;
  final int maxBranches;
  final int maxStaff;
  final int maxLoans;
  final List<String> features;
  final bool isPopular;
  final bool isActive;
  final int sortOrder;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.priceMonthly,
    this.priceYearly,
    this.currency = 'INR',
    this.maxMembers = 100,
    this.maxBranches = 1,
    this.maxStaff = 5,
    this.maxLoans = 50,
    this.features = const [],
    this.isPopular = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  /// Yearly discount percentage
  double get yearlyDiscount {
    if (priceYearly == null || priceYearly == 0) return 0;
    final monthlyTotal = priceMonthly * 12;
    return ((monthlyTotal - priceYearly!) / monthlyTotal * 100).roundToDouble();
  }

  /// Price per month for yearly plan
  double get monthlyEquivalent {
    if (priceYearly == null || priceYearly == 0) return priceMonthly;
    return priceYearly! / 12;
  }

  /// Is this the enterprise plan?
  bool get isEnterprise => priceMonthly == 0;

  /// Formatted monthly price
  String get formattedMonthly {
    if (isEnterprise) return 'Custom';
    return '₹${priceMonthly.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  /// Formatted yearly price
  String get formattedYearly {
    if (isEnterprise) return 'Custom';
    if (priceYearly == null) return formattedMonthly;
    return '₹${priceYearly!.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0,
      priceYearly: (json['price_yearly'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 100,
      maxBranches: (json['max_branches'] as num?)?.toInt() ?? 1,
      maxStaff: (json['max_staff'] as num?)?.toInt() ?? 5,
      maxLoans: (json['max_loans'] as num?)?.toInt() ?? 50,
      features: (json['features'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price_monthly': priceMonthly,
    'price_yearly': priceYearly,
    'currency': currency,
    'max_members': maxMembers,
    'max_branches': maxBranches,
    'max_staff': maxStaff,
    'max_loans': maxLoans,
    'features': features,
    'is_popular': isPopular,
    'is_active': isActive,
    'sort_order': sortOrder,
  };

  @override
  List<Object?> get props => [
    id, name, description, priceMonthly, priceYearly, currency,
    maxMembers, maxBranches, maxStaff, maxLoans, features,
    isPopular, isActive, sortOrder,
  ];
}
