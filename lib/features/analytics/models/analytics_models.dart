import 'package:equatable/equatable.dart';

/// Org metrics model for analytics
class OrgMetricsModel extends Equatable {
  final String id;
  final String orgId;
  
  // Collections
  final double totalCollections;
  final double collectionsThisMonth;
  final double collectionsGrowth;
  final double collectionEfficiency;
  
  // Loans
  final double totalLoansDisbursed;
  final int activeLoans;
  final int overdueLoans;
  final int npaCount;
  final double npaPercentage;
  
  // Members
  final int totalMembers;
  final int activeMembers;
  final int newMembersThisMonth;
  final double memberRetentionRate;
  
  // Staff
  final int totalStaff;
  final int activeStaff;
  final double staffProductivity;
  
  // Financial
  final double totalRevenue;
  final double revenueThisMonth;
  final double revenueGrowth;
  
  final DateTime computedAt;

  const OrgMetricsModel({
    required this.id,
    required this.orgId,
    this.totalCollections = 0,
    this.collectionsThisMonth = 0,
    this.collectionsGrowth = 0,
    this.collectionEfficiency = 0,
    this.totalLoansDisbursed = 0,
    this.activeLoans = 0,
    this.overdueLoans = 0,
    this.npaCount = 0,
    this.npaPercentage = 0,
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.newMembersThisMonth = 0,
    this.memberRetentionRate = 0,
    this.totalStaff = 0,
    this.activeStaff = 0,
    this.staffProductivity = 0,
    this.totalRevenue = 0,
    this.revenueThisMonth = 0,
    this.revenueGrowth = 0,
    required this.computedAt,
  });

  factory OrgMetricsModel.fromJson(Map<String, dynamic> json) {
    return OrgMetricsModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      totalCollections: (json['total_collections'] as num?)?.toDouble() ?? 0,
      collectionsThisMonth: (json['collections_this_month'] as num?)?.toDouble() ?? 0,
      collectionsGrowth: (json['collections_growth'] as num?)?.toDouble() ?? 0,
      collectionEfficiency: (json['collection_efficiency'] as num?)?.toDouble() ?? 0,
      totalLoansDisbursed: (json['total_loans_disbursed'] as num?)?.toDouble() ?? 0,
      activeLoans: json['active_loans'] as int? ?? 0,
      overdueLoans: json['overdue_loans'] as int? ?? 0,
      npaCount: json['npa_count'] as int? ?? 0,
      npaPercentage: (json['npa_percentage'] as num?)?.toDouble() ?? 0,
      totalMembers: json['total_members'] as int? ?? 0,
      activeMembers: json['active_members'] as int? ?? 0,
      newMembersThisMonth: json['new_members_this_month'] as int? ?? 0,
      memberRetentionRate: (json['member_retention_rate'] as num?)?.toDouble() ?? 0,
      totalStaff: json['total_staff'] as int? ?? 0,
      activeStaff: json['active_staff'] as int? ?? 0,
      staffProductivity: (json['staff_productivity'] as num?)?.toDouble() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      revenueThisMonth: (json['revenue_this_month'] as num?)?.toDouble() ?? 0,
      revenueGrowth: (json['revenue_growth'] as num?)?.toDouble() ?? 0,
      computedAt: DateTime.parse(json['computed_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, totalCollections, collectionsThisMonth, collectionsGrowth,
    collectionEfficiency, totalLoansDisbursed, activeLoans, overdueLoans,
    npaCount, npaPercentage, totalMembers, activeMembers, newMembersThisMonth,
    memberRetentionRate, totalStaff, activeStaff, staffProductivity,
    totalRevenue, revenueThisMonth, revenueGrowth, computedAt
  ];
}

/// Custom report model
class CustomReportModel extends Equatable {
  final String id;
  final String orgId;
  final String? createdBy;
  final String name;
  final String? description;
  final String reportType;
  final Map<String, dynamic> filters;
  final List<dynamic> columns;
  final Map<String, dynamic> aggregations;
  final String? scheduleFrequency;
  final List<String>? scheduleRecipients;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomReportModel({
    required this.id,
    required this.orgId,
    this.createdBy,
    required this.name,
    this.description,
    required this.reportType,
    this.filters = const {},
    this.columns = const [],
    this.aggregations = const {},
    this.scheduleFrequency,
    this.scheduleRecipients,
    this.lastRunAt,
    this.nextRunAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomReportModel.fromJson(Map<String, dynamic> json) {
    return CustomReportModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      createdBy: json['created_by'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      reportType: json['report_type'] as String,
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      columns: json['columns'] as List<dynamic>? ?? [],
      aggregations: json['aggregations'] as Map<String, dynamic>? ?? {},
      scheduleFrequency: json['schedule_frequency'] as String?,
      scheduleRecipients: (json['schedule_recipients'] as List<dynamic>?)?.cast<String>(),
      lastRunAt: json['last_run_at'] != null
          ? DateTime.parse(json['last_run_at'] as String)
          : null,
      nextRunAt: json['next_run_at'] != null
          ? DateTime.parse(json['next_run_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, createdBy, name, description, reportType, filters, columns,
    aggregations, scheduleFrequency, scheduleRecipients, lastRunAt, nextRunAt,
    createdAt, updatedAt
  ];
}
