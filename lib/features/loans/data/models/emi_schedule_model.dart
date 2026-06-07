import '../../../../core/constants/enums.dart';

/// Extension helpers that derive the *effective* state of an EMI from both
/// the stored [EMIStatus] and the [dueDate].
///
/// The database `status` column is only updated to `paid` (via the
/// `update_schedule_on_collection` trigger) or `overdue` (rarely, manually).
/// It is **not** reliably set to `overdue` as the due date passes, so the UI
/// must compute overdue from the date — the same way `todayAgendaProvider`
/// does in `payment_providers.dart`.
extension EMIScheduleModelX on EMIScheduleModel {
  /// `true` when the EMI is unpaid AND its due date is strictly before today.
  /// "Today" is computed in the device's local timezone.
  bool get isOverdue {
    if (status == EMIStatus.paid) return false;
    if (status == EMIStatus.waived) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate.isBefore(today);
  }

  /// `true` when the EMI is due today (date matches today, not yet paid).
  bool get isDueToday {
    if (status == EMIStatus.paid) return false;
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  /// `true` when the EMI is still in the future.
  bool get isUpcoming => !isOverdue && !isDueToday && status != EMIStatus.paid;

  /// Effective status — the *displayed* status, computed from the date when
  /// the stored status is stale. Paid and waived are always honoured.
  EMIStatus get effectiveStatus {
    if (status == EMIStatus.paid) return EMIStatus.paid;
    if (status == EMIStatus.waived) return EMIStatus.waived;
    if (isOverdue) return EMIStatus.overdue;
    if (isDueToday) return status; // 'pending' or 'pendingPayment'
    return status;
  }

  /// Number of whole days past the due date. Negative if not yet due.
  /// Returns 0 for paid/waived EMIs.
  int get daysOverdue {
    if (status == EMIStatus.paid || status == EMIStatus.waived) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(dueDate).inDays;
  }
}

class EMIScheduleModel {
  final String id;
  final String loanId;
  final int emiNumber;
  final DateTime dueDate;
  final double emiAmount;
  final double principal;
  final double interest;
  final double balanceAfter;
  final EMIStatus status;
  final DateTime? paidOn;
  final PaymentMode? paymentMode;
  final String? transactionId;
  final double penaltyAmount;
  final bool penaltyPaid;
  final DateTime createdAt;

  EMIScheduleModel({
    required this.id,
    required this.loanId,
    required this.emiNumber,
    required this.dueDate,
    required this.emiAmount,
    required this.principal,
    required this.interest,
    required this.balanceAfter,
    required this.status,
    this.paidOn,
    this.paymentMode,
    this.transactionId,
    required this.penaltyAmount,
    required this.penaltyPaid,
    required this.createdAt,
  });

  factory EMIScheduleModel.fromJson(Map<String, dynamic> json) {
    return EMIScheduleModel(
      id: json['id']?.toString() ?? '',
      loanId: json['loan_id']?.toString() ?? '',
      emiNumber: json['emi_number'] as int? ?? 0,
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      emiAmount: (json['emi_amount'] as num?)?.toDouble() ?? 0,
      principal: (json['principal'] as num?)?.toDouble() ?? 0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
      status: EMIStatus.values.firstWhere(
        (e) => e.name == json['status'] || _toSnake(e.name) == json['status'],
        orElse: () => EMIStatus.pending,
      ),
      paidOn: json['paid_on'] != null
          ? DateTime.tryParse(json['paid_on'] as String)
          : null,
      paymentMode: json['payment_mode'] != null
          ? PaymentMode.values.firstWhere(
              (e) =>
                  e.name == json['payment_mode'] ||
                  _toSnake(e.name) == json['payment_mode'],
              orElse: () => PaymentMode.cash,
            )
          : null,
      transactionId: json['transaction_id'] as String?,
      penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0,
      penaltyPaid: json['penalty_paid'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static String _toSnake(String s) {
    return s.replaceAllMapped(
        RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_id': loanId,
      'emi_number': emiNumber,
      'due_date': dueDate.toIso8601String(),
      'emi_amount': emiAmount,
      'principal': principal,
      'interest': interest,
      'balance_after': balanceAfter,
      'status': status.name,
      'paid_on': paidOn?.toIso8601String(),
      'payment_mode': paymentMode?.name,
      'transaction_id': transactionId,
      'penalty_amount': penaltyAmount,
      'penalty_paid': penaltyPaid,
    };
  }
}
