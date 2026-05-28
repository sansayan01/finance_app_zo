import 'package:equatable/equatable.dart';

enum PeriodType {
  daily,
  weekly,
  monthly,
}

enum TargetStatus {
  active,
  completed,
  failed,
  cancelled;

  /// Maps to DB constraint: pending, achieved, partial, missed
  String get dbValue {
    switch (this) {
      case TargetStatus.active:
        return 'pending';
      case TargetStatus.completed:
        return 'achieved';
      case TargetStatus.failed:
        return 'missed';
      case TargetStatus.cancelled:
        return 'missed';
    }
  }
}

class TargetModel extends Equatable {
  final String id;
  final String staffId;

  // Target period
  final PeriodType periodType;
  final DateTime targetDate;
  final DateTime periodStart;
  final DateTime periodEnd;

  // Targets
  final double targetAmount;
  final int? targetCount;
  final double achievedAmount;
  final int achievedCount;

  // Overdue-specific
  final double overdueTargetAmount;
  final double overdueAchievedAmount;

  // Status
  final TargetStatus status;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const TargetModel({
    required this.id,
    required this.staffId,
    required this.periodType,
    required this.targetDate,
    required this.periodStart,
    required this.periodEnd,
    required this.targetAmount,
    this.targetCount,
    this.achievedAmount = 0.0,
    this.achievedCount = 0,
    this.overdueTargetAmount = 0.0,
    this.overdueAchievedAmount = 0.0,
    this.status = TargetStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TargetModel.fromJson(Map<String, dynamic> json) {
    return TargetModel(
      id: json['id'] as String,
      staffId: json['staff_id'] as String,
      periodType: _parsePeriodType(json['period_type'] as String?),
      targetDate: DateTime.parse(json['target_date'] as String),
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      targetAmount: (json['target_amount'] as num).toDouble(),
      targetCount: json['target_count'] as int?,
      achievedAmount: (json['achieved_amount'] as num?)?.toDouble() ?? 0.0,
      achievedCount: json['achieved_count'] as int? ?? 0,
      overdueTargetAmount:
          (json['overdue_target_amount'] as num?)?.toDouble() ?? 0.0,
      overdueAchievedAmount:
          (json['overdue_achieved_amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseTargetStatus(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'period_type': periodType.name,
      'target_date': targetDate.toIso8601String().split('T').first,
      'period_start': periodStart.toIso8601String().split('T').first,
      'period_end': periodEnd.toIso8601String().split('T').first,
      'target_amount': targetAmount,
      'target_count': targetCount,
      'achieved_amount': achievedAmount,
      'achieved_count': achievedCount,
      'overdue_target_amount': overdueTargetAmount,
      'overdue_achieved_amount': overdueAchievedAmount,
      'status': status.dbValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static PeriodType _parsePeriodType(String? value) {
    switch (value) {
      case 'daily':
        return PeriodType.daily;
      case 'weekly':
        return PeriodType.weekly;
      case 'monthly':
        return PeriodType.monthly;
      default:
        return PeriodType.daily;
    }
  }

  static TargetStatus _parseTargetStatus(String? value) {
    switch (value) {
      case 'pending':
        return TargetStatus.active;
      case 'achieved':
        return TargetStatus.completed;
      case 'partial':
        return TargetStatus.completed;
      case 'missed':
        return TargetStatus.failed;
      case 'active':
        return TargetStatus.active;
      case 'completed':
        return TargetStatus.completed;
      case 'failed':
        return TargetStatus.failed;
      case 'cancelled':
        return TargetStatus.cancelled;
      default:
        return TargetStatus.active;
    }
  }

  double get remainingAmount {
    final remaining = targetAmount - achievedAmount;
    return remaining > 0 ? remaining : 0;
  }

  double get progress {
    if (targetAmount <= 0) return 0;
    final val = achievedAmount / targetAmount;
    return val > 1.0 ? 1.0 : val;
  }

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    final percentage = (achievedAmount / targetAmount) * 100;
    return percentage > 100 ? 100 : percentage;
  }

  bool get isCompleted => achievedAmount >= targetAmount;
  bool get isOverTarget => achievedAmount > targetAmount;
  bool get isActive => status == TargetStatus.active;

  int get daysRemaining {
    return periodEnd.difference(DateTime.now()).inDays;
  }

  TargetModel copyWith({
    String? id,
    String? staffId,
    PeriodType? periodType,
    DateTime? targetDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    double? targetAmount,
    int? targetCount,
    double? achievedAmount,
    int? achievedCount,
    double? overdueTargetAmount,
    double? overdueAchievedAmount,
    TargetStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TargetModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      periodType: periodType ?? this.periodType,
      targetDate: targetDate ?? this.targetDate,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      targetAmount: targetAmount ?? this.targetAmount,
      targetCount: targetCount ?? this.targetCount,
      achievedAmount: achievedAmount ?? this.achievedAmount,
      achievedCount: achievedCount ?? this.achievedCount,
      overdueTargetAmount: overdueTargetAmount ?? this.overdueTargetAmount,
      overdueAchievedAmount:
          overdueAchievedAmount ?? this.overdueAchievedAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        staffId,
        periodType,
        targetDate,
        periodStart,
        periodEnd,
        targetAmount,
        targetCount,
        achievedAmount,
        achievedCount,
        overdueTargetAmount,
        overdueAchievedAmount,
        status,
        createdAt,
        updatedAt,
      ];
}
