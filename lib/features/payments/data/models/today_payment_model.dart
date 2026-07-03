import 'package:flutter/material.dart';

enum PaymentType { emi, savings }

enum PaymentStatus { pending, collected, overdue }

enum PaymentSortBy {
  nameAsc,
  nameDesc,
  amountHigh,
  amountLow,
  dueDateOldest,
  dueDateNewest,
  branchAsc,
  statusPriority,
}

extension PaymentSortByX on PaymentSortBy {
  String get label => switch (this) {
        PaymentSortBy.nameAsc => 'Name (A → Z)',
        PaymentSortBy.nameDesc => 'Name (Z → A)',
        PaymentSortBy.amountHigh => 'Amount (High)',
        PaymentSortBy.amountLow => 'Amount (Low)',
        PaymentSortBy.dueDateOldest => 'Due Date (Oldest)',
        PaymentSortBy.dueDateNewest => 'Due Date (Newest)',
        PaymentSortBy.branchAsc => 'Branch (A → Z)',
        PaymentSortBy.statusPriority => 'Status Priority',
      };
}

enum OverdueBucket {
  days1to7,
  days8to30,
  days30plus,
}

extension OverdueBucketX on OverdueBucket {
  String get label => switch (this) {
    OverdueBucket.days1to7 => '1–7 days',
    OverdueBucket.days8to30 => '8–30 days',
    OverdueBucket.days30plus => '30+ days',
  };

  bool matches(int daysOverdue) => switch (this) {
    OverdueBucket.days1to7 => daysOverdue >= 1 && daysOverdue <= 7,
    OverdueBucket.days8to30 => daysOverdue >= 8 && daysOverdue <= 30,
    OverdueBucket.days30plus => daysOverdue > 30,
  };
}

class TodayPayment {
  final String id;
  final PaymentType type;
  final PaymentStatus status;
  final String memberName;
  final String? memberPhone;
  final String? memberId;
  final String? branchId;
  final String? branchName;
  final String? agentId;
  final String? agentName;
  final double amountExpected;
  final double? amountCollected;
  final double penaltyAmount;
  final DateTime dueDate;
  final String? loanNumber;
  final String? loanId;
  final String? emiNumber;
  final String? planName;
  final String? paymentMode;
  final DateTime? collectedAt;
  final String? remarks;
  final String? collectionId; // collections.id for delete/revert

  const TodayPayment({
    required this.id,
    required this.type,
    required this.status,
    required this.memberName,
    this.memberPhone,
    this.memberId,
    this.branchId,
    this.branchName,
    this.agentId,
    this.agentName,
    required this.amountExpected,
    this.amountCollected,
    this.penaltyAmount = 0,
    required this.dueDate,
    this.loanNumber,
    this.loanId,
    this.emiNumber,
    this.planName,
    this.paymentMode,
    this.collectedAt,
    this.remarks,
    this.collectionId,
  });

  bool get isCollected => status == PaymentStatus.collected;
  bool get isOverdue => status == PaymentStatus.overdue;
  bool get isPending => status == PaymentStatus.pending;

  String get typeLabel => type == PaymentType.emi ? 'EMI' : 'Savings';

  IconData get typeIcon =>
      type == PaymentType.emi ? Icons.receipt_long : Icons.savings;

  // Type-specific colors for visual differentiation
  Color get typeColor =>
      type == PaymentType.emi ? const Color(0xFF5B6ABF) : const Color(0xFF00897B);

  Color get statusColor {
    switch (status) {
      case PaymentStatus.collected:
        return Colors.green;
      case PaymentStatus.overdue:
        return Colors.red;
      case PaymentStatus.pending:
        return type == PaymentType.emi ? Colors.orange : const Color(0xFF00897B);
    }
  }

  String get statusLabel {
    switch (status) {
      case PaymentStatus.collected:
        return 'Collected';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate).inDays;
  }

  String get overdueLabel {
    final days = daysOverdue;
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day overdue';
    return '$days days overdue';
  }

  double get totalWithPenalty => amountExpected + penaltyAmount;
}

class TodayPaymentSummary {
  final double totalDue;
  final double totalCollected;
  final double totalPending;
  final double totalOverdue;
  final double totalPenalty;
  final int countDue;
  final int countCollected;
  final int countPending;
  final int countOverdue;

  const TodayPaymentSummary({
    required this.totalDue,
    required this.totalCollected,
    required this.totalPending,
    required this.totalOverdue,
    required this.totalPenalty,
    required this.countDue,
    required this.countCollected,
    required this.countPending,
    required this.countOverdue,
  });

  double get collectionRate =>
      totalDue > 0 ? (totalCollected / totalDue * 100) : 0;

  int get completionPercent =>
      countDue > 0 ? ((countCollected / countDue) * 100).round() : 0;

  factory TodayPaymentSummary.fromPayments(List<TodayPayment> payments) {
    double totalDue = 0;
    double totalCollected = 0;
    double totalPending = 0;
    double totalOverdue = 0;
    double totalPenalty = 0;
    int countDue = 0;
    int countCollected = 0;
    int countPending = 0;
    int countOverdue = 0;

    for (final p in payments) {
      totalDue += p.amountExpected;
      totalPenalty += p.penaltyAmount;
      if (p.isCollected) {
        totalCollected += p.amountCollected ?? p.amountExpected;
        countCollected++;
      } else if (p.isOverdue) {
        totalOverdue += p.amountExpected;
        countOverdue++;
      } else {
        totalPending += p.amountExpected;
        countPending++;
      }
      countDue++;
    }

    return TodayPaymentSummary(
      totalDue: totalDue,
      totalCollected: totalCollected,
      totalPending: totalPending,
      totalOverdue: totalOverdue,
      totalPenalty: totalPenalty,
      countDue: countDue,
      countCollected: countCollected,
      countPending: countPending,
      countOverdue: countOverdue,
    );
  }
}

class GroupedOverduePayment {
  final String memberId;
  final String memberName;
  final String? memberPhone;
  final String? branchId;
  final String? agentId;
  final List<TodayPayment> payments;

  const GroupedOverduePayment({
    required this.memberId,
    required this.memberName,
    this.memberPhone,
    this.branchId,
    this.agentId,
    required this.payments,
  });

  int get overdueCount => payments.length;

  double get totalAmount =>
      payments.fold(0.0, (sum, p) => sum + p.amountExpected);

  double get totalPenalty =>
      payments.fold(0.0, (sum, p) => sum + p.penaltyAmount);

  DateTime get earliestDueDate =>
      payments.map((p) => p.dueDate).reduce((a, b) => a.isBefore(b) ? a : b);

  int get maxDaysOverdue =>
      payments.map((p) => p.daysOverdue).reduce((a, b) => a > b ? a : b);

  String get overdueLabel {
    final days = maxDaysOverdue;
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day overdue';
    return '$days days overdue';
  }

  String get typeLabel => payments.first.typeLabel;
  IconData get typeIcon => payments.first.typeIcon;
  Color get typeColor => payments.first.typeColor;

  /// Unique loan numbers across all payments in this group
  List<String> get loanNumbers =>
      payments.map((p) => p.loanNumber).whereType<String>().toSet().toList()
        ..sort();

  String get loanLabel {
    final nums = loanNumbers;
    if (nums.isEmpty) return '';
    if (nums.length == 1) return nums.first;
    return '${nums.length} loans';
  }

  static List<GroupedOverduePayment> group(List<TodayPayment> overdues) {
    final map = <String, List<TodayPayment>>{};
    for (final p in overdues) {
      final key = '${p.memberId ?? p.id}_${p.type.name}';
      map.putIfAbsent(key, () => []).add(p);
    }
    final groups = map.entries.map((e) {
      final payments = e.value;
      final first = payments.first;
      return GroupedOverduePayment(
        memberId: first.memberId ?? first.id,
        memberName: first.memberName,
        memberPhone: first.memberPhone,
        branchId: first.branchId,
        agentId: first.agentId,
        payments: payments,
      );
    }).toList();
    groups.sort((a, b) => a.earliestDueDate.compareTo(b.earliestDueDate));
    return groups;
  }
}

class BranchSummary {
  final String branchId;
  final String branchName;
  final double totalDue;
  final double totalCollected;
  final int countDue;
  final int countCollected;
  final int countPending;

  const BranchSummary({
    required this.branchId,
    required this.branchName,
    required this.totalDue,
    required this.totalCollected,
    required this.countDue,
    required this.countCollected,
    required this.countPending,
  });

  double get collectionRate =>
      totalDue > 0 ? (totalCollected / totalDue * 100) : 0;
}
