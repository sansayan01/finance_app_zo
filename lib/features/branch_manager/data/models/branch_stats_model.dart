import 'package:equatable/equatable.dart';

class BranchStats extends Equatable {
  final String branchId;
  final String branchName;
  final String branchAddress;
  final bool isActive;
  final int totalStaff;
  final int totalMembers;
  final int totalLoans;
  final int activeLoansCount;
  final int overdueLoans;
  final double totalCollections;
  final double totalDisbursements;
  final double totalSavings;
  final double outstandingAmount;

  const BranchStats({
    required this.branchId,
    required this.branchName,
    required this.branchAddress,
    this.isActive = true,
    this.totalStaff = 0,
    this.totalMembers = 0,
    this.totalLoans = 0,
    this.activeLoansCount = 0,
    this.overdueLoans = 0,
    this.totalCollections = 0.0,
    this.totalDisbursements = 0.0,
    this.totalSavings = 0.0,
    this.outstandingAmount = 0.0,
  });

  factory BranchStats.fromJson(Map<String, dynamic> json) {
    return BranchStats(
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      branchAddress: json['branch_address']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      totalStaff: (json['total_staff'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalLoans: (json['total_loans'] as num?)?.toInt() ?? 0,
      activeLoansCount: (json['active_loans_count'] as num?)?.toInt() ?? 0,
      overdueLoans: (json['overdue_loans'] as num?)?.toInt() ?? 0,
      totalCollections: (json['total_collections'] as num?)?.toDouble() ?? 0.0,
      totalDisbursements:
          (json['total_disbursements'] as num?)?.toDouble() ?? 0.0,
      totalSavings: (json['total_savings'] as num?)?.toDouble() ?? 0.0,
      outstandingAmount:
          (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        branchId,
        branchName,
        branchAddress,
        isActive,
        totalStaff,
        totalMembers,
        totalLoans,
        activeLoansCount,
        overdueLoans,
        totalCollections,
        totalDisbursements,
        totalSavings,
        outstandingAmount,
      ];
}
