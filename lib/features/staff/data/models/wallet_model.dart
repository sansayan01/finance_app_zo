import 'package:equatable/equatable.dart';

class WalletModel extends Equatable {
  final String id;
  final String staffId;

  // Cash tracking
  final double cashInHand;
  final double digitalBalance;
  final double totalCollectedToday;
  final double totalDepositedToday;

  // Last deposit info
  final double? lastDepositAmount;
  final DateTime? lastDepositAt;
  final String? lastDepositMode;

  // Safe limit (alerts when exceeded)
  final double safeLimit;
  final bool isOverLimit;

  // Timestamps
  final DateTime updatedAt;
  final DateTime createdAt;

  const WalletModel({
    required this.id,
    required this.staffId,
    this.cashInHand = 0.0,
    this.digitalBalance = 0.0,
    this.totalCollectedToday = 0.0,
    this.totalDepositedToday = 0.0,
    this.lastDepositAmount,
    this.lastDepositAt,
    this.lastDepositMode,
    this.safeLimit = 50000.0,
    this.isOverLimit = false,
    required this.updatedAt,
    required this.createdAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      cashInHand: (json['cash_in_hand'] as num?)?.toDouble() ?? 0.0,
      digitalBalance: (json['digital_balance'] as num?)?.toDouble() ?? 0.0,
      totalCollectedToday:
          (json['total_collected_today'] as num?)?.toDouble() ?? 0.0,
      totalDepositedToday:
          (json['total_deposited_today'] as num?)?.toDouble() ?? 0.0,
      lastDepositAmount: (json['last_deposit_amount'] as num?)?.toDouble(),
      lastDepositAt: json['last_deposit_at'] != null
          ? DateTime.parse(json['last_deposit_at'] as String)
          : null,
      lastDepositMode: json['last_deposit_mode'] as String?,
      safeLimit: (json['safe_limit'] as num?)?.toDouble() ?? 50000.0,
      isOverLimit: json['is_over_limit'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'cash_in_hand': cashInHand,
      'digital_balance': digitalBalance,
      'total_collected_today': totalCollectedToday,
      'total_deposited_today': totalDepositedToday,
      'last_deposit_amount': lastDepositAmount,
      'last_deposit_at': lastDepositAt?.toIso8601String(),
      'last_deposit_mode': lastDepositMode,
      'safe_limit': safeLimit,
      'is_over_limit': isOverLimit,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  double get totalBalance => cashInHand + digitalBalance;
  double get availableForDeposit => cashInHand;

  double get safeLimitPercentage =>
      safeLimit > 0 ? (cashInHand / safeLimit) * 100 : 0;

  String get safeLimitStatus {
    if (cashInHand >= safeLimit) return 'danger';
    if (cashInHand >= safeLimit * 0.8) return 'warning';
    return 'safe';
  }

  WalletModel copyWith({
    String? id,
    String? staffId,
    double? cashInHand,
    double? digitalBalance,
    double? totalCollectedToday,
    double? totalDepositedToday,
    double? lastDepositAmount,
    DateTime? lastDepositAt,
    String? lastDepositMode,
    double? safeLimit,
    bool? isOverLimit,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      cashInHand: cashInHand ?? this.cashInHand,
      digitalBalance: digitalBalance ?? this.digitalBalance,
      totalCollectedToday: totalCollectedToday ?? this.totalCollectedToday,
      totalDepositedToday: totalDepositedToday ?? this.totalDepositedToday,
      lastDepositAmount: lastDepositAmount ?? this.lastDepositAmount,
      lastDepositAt: lastDepositAt ?? this.lastDepositAt,
      lastDepositMode: lastDepositMode ?? this.lastDepositMode,
      safeLimit: safeLimit ?? this.safeLimit,
      isOverLimit: isOverLimit ?? this.isOverLimit,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        staffId,
        cashInHand,
        digitalBalance,
        totalCollectedToday,
        totalDepositedToday,
        lastDepositAmount,
        lastDepositAt,
        lastDepositMode,
        safeLimit,
        isOverLimit,
        updatedAt,
        createdAt,
      ];
}
