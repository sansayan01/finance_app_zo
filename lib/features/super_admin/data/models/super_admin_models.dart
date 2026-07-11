import 'package:equatable/equatable.dart';

/// Platform metrics model
class PlatformMetrics extends Equatable {
  final int totalOrganizations;
  final int activeOrganizations;
  final int totalUsers;
  final int activeUsers;
  final int totalBranches;
  final int totalMembers;
  final int totalLoans;
  final double totalLoanAmount;
  final double totalCollections;
  final double totalSavings;
  final double mrr;
  final DateTime? lastUpdated;

  const PlatformMetrics({
    this.totalOrganizations = 0,
    this.activeOrganizations = 0,
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.totalBranches = 0,
    this.totalMembers = 0,
    this.totalLoans = 0,
    this.totalLoanAmount = 0,
    this.totalCollections = 0,
    this.totalSavings = 0,
    this.mrr = 0,
    this.lastUpdated,
  });

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      totalOrganizations: json['total_organizations'] ?? 0,
      activeOrganizations: json['active_organizations'] ?? 0,
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      totalBranches: json['total_branches'] ?? 0,
      totalMembers: json['total_members'] ?? 0,
      totalLoans: json['total_loans'] ?? 0,
      totalLoanAmount: (json['total_loan_amount'] ?? 0).toDouble(),
      totalCollections: (json['total_collections'] ?? 0).toDouble(),
      totalSavings: (json['total_savings'] ?? 0).toDouble(),
      mrr: (json['mrr'] ?? 0).toDouble(),
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'total_organizations': totalOrganizations,
        'active_organizations': activeOrganizations,
        'total_users': totalUsers,
        'active_users': activeUsers,
        'total_branches': totalBranches,
        'total_members': totalMembers,
        'total_loans': totalLoans,
        'total_loan_amount': totalLoanAmount,
        'total_collections': totalCollections,
        'total_savings': totalSavings,
        'mrr': mrr,
      };

  double get organizationActivationRate => totalOrganizations > 0
      ? (activeOrganizations / totalOrganizations) * 100
      : 0;

  double get userActivationRate =>
      totalUsers > 0 ? (activeUsers / totalUsers) * 100 : 0;

  double get avgLoanAmount => totalLoans > 0 ? totalLoanAmount / totalLoans : 0;

  double get collectionRate =>
      totalLoanAmount > 0 ? (totalCollections / totalLoanAmount) * 100 : 0;

  @override
  List<Object?> get props => [
        totalOrganizations,
        activeOrganizations,
        totalUsers,
        activeUsers,
        totalBranches,
        totalMembers,
        totalLoans,
        totalLoanAmount,
        totalCollections,
        totalSavings,
        mrr,
        lastUpdated,
      ];
}

/// Organization health score model
class OrganizationHealthScore extends Equatable {
  final String id;
  final String orgId;
  final DateTime scoreDate;
  final int overallScore;
  final int collectionEfficiencyScore;
  final int memberGrowthScore;
  final int staffProductivityScore;
  final int financialHealthScore;
  final int complianceScore;
  final Map<String, dynamic> metrics;

  const OrganizationHealthScore({
    required this.id,
    required this.orgId,
    required this.scoreDate,
    this.overallScore = 0,
    this.collectionEfficiencyScore = 0,
    this.memberGrowthScore = 0,
    this.staffProductivityScore = 0,
    this.financialHealthScore = 0,
    this.complianceScore = 0,
    this.metrics = const {},
  });

  factory OrganizationHealthScore.fromJson(Map<String, dynamic> json) {
    return OrganizationHealthScore(
      id: json['id'],
      orgId: json['org_id'],
      scoreDate: DateTime.parse(json['score_date']),
      overallScore: json['overall_score'] ?? 0,
      collectionEfficiencyScore: json['collection_efficiency_score'] ?? 0,
      memberGrowthScore: json['member_growth_score'] ?? 0,
      staffProductivityScore: json['staff_productivity_score'] ?? 0,
      financialHealthScore: json['financial_health_score'] ?? 0,
      complianceScore: json['compliance_score'] ?? 0,
      metrics: json['metrics'] ?? {},
    );
  }

  String get healthLabel {
    if (overallScore >= 80) return 'Excellent';
    if (overallScore >= 60) return 'Good';
    if (overallScore >= 40) return 'Average';
    if (overallScore >= 20) return 'Poor';
    return 'Critical';
  }

  @override
  List<Object?> get props => [id, orgId, scoreDate, overallScore];
}

/// Feature flag model
class FeatureFlag extends Equatable {
  final String id;
  final String key;
  final String name;
  final String? description;
  final bool isEnabled;
  final int rolloutPercentage;
  final List<String> targetOrgs;
  final List<String> targetRoles;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeatureFlag({
    required this.id,
    required this.key,
    required this.name,
    this.description,
    this.isEnabled = false,
    this.rolloutPercentage = 100,
    this.targetOrgs = const [],
    this.targetRoles = const [],
    this.config = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      id: json['id'],
      key: json['key'],
      name: json['name'],
      description: json['description'],
      isEnabled: json['is_enabled'] ?? false,
      rolloutPercentage: json['rollout_percentage'] ?? 100,
      targetOrgs: List<String>.from(json['target_orgs'] ?? []),
      targetRoles: List<String>.from(json['target_roles'] ?? []),
      config: json['config'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'description': description,
        'is_enabled': isEnabled,
        'rollout_percentage': rolloutPercentage,
        'target_orgs': targetOrgs,
        'target_roles': targetRoles,
        'config': config,
      };

  @override
  List<Object?> get props => [id, key, isEnabled];
}

/// Platform announcement model
class PlatformAnnouncement extends Equatable {
  final String id;
  final String title;
  final String message;
  final String type;
  final String targetAudience;
  final List<String> targetOrgs;
  final bool isActive;
  final DateTime? showFrom;
  final DateTime? showUntil;
  final DateTime createdAt;
  final bool isRead;

  const PlatformAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.targetAudience = 'all',
    this.targetOrgs = const [],
    this.isActive = true,
    this.showFrom,
    this.showUntil,
    required this.createdAt,
    this.isRead = false,
  });

  factory PlatformAnnouncement.fromJson(Map<String, dynamic> json) {
    return PlatformAnnouncement(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'] ?? 'info',
      targetAudience: json['target_audience'] ?? 'all',
      targetOrgs: List<String>.from(json['target_orgs'] ?? []),
      isActive: json['is_active'] ?? true,
      showFrom: json['show_from'] != null
          ? DateTime.tryParse(json['show_from'])
          : null,
      showUntil: json['show_until'] != null
          ? DateTime.tryParse(json['show_until'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, isActive, isRead];
}

/// System audit log model
class SystemAuditLog extends Equatable {
  final String id;
  final String? orgId;
  final String? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? ipAddress;
  final DateTime createdAt;

  const SystemAuditLog({
    required this.id,
    this.orgId,
    this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.ipAddress,
    required this.createdAt,
  });

  factory SystemAuditLog.fromJson(Map<String, dynamic> json) {
    return SystemAuditLog(
      id: json['id'],
      orgId: json['org_id'],
      userId: json['user_id'],
      action: json['action'],
      entityType: json['entity_type'],
      entityId: json['entity_id'],
      oldValues: json['old_values'],
      newValues: json['new_values'],
      ipAddress: json['ip_address'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, action, entityType, createdAt];
}

/// Support ticket model
class SupportTicket extends Equatable {
  final String id;
  final String? orgId;
  final String? userId;
  final String subject;
  final String? description;
  final String category;
  final String priority;
  final String status;
  final String? assignedTo;
  final List<Map<String, dynamic>> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const SupportTicket({
    required this.id,
    this.orgId,
    this.userId,
    required this.subject,
    this.description,
    this.category = 'general',
    this.priority = 'normal',
    this.status = 'open',
    this.assignedTo,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'],
      orgId: json['org_id'],
      userId: json['user_id'],
      subject: json['subject'],
      description: json['description'],
      category: json['category'] ?? 'general',
      priority: json['priority'] ?? 'normal',
      status: json['status'] ?? 'open',
      assignedTo: json['assigned_to'],
      messages: List<Map<String, dynamic>>.from(json['messages'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, subject, status, createdAt];
}

/// Maintenance window model
class MaintenanceWindow extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final bool isActive;
  final List<String> affectedServices;
  final DateTime createdAt;

  const MaintenanceWindow({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.isActive = false,
    this.affectedServices = const [],
    required this.createdAt,
  });

  factory MaintenanceWindow.fromJson(Map<String, dynamic> json) {
    return MaintenanceWindow(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      scheduledStart: DateTime.parse(json['scheduled_start']),
      scheduledEnd: DateTime.parse(json['scheduled_end']),
      isActive: json['is_active'] ?? false,
      affectedServices: List<String>.from(json['affected_services'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Duration get duration => scheduledEnd.difference(scheduledStart);

  bool get isUpcoming => scheduledStart.isAfter(DateTime.now());

  bool get isOngoing =>
      DateTime.now().isAfter(scheduledStart) &&
      DateTime.now().isBefore(scheduledEnd);

  @override
  List<Object?> get props => [id, title, scheduledStart, scheduledEnd];
}

/// Platform revenue model
class PlatformRevenue extends Equatable {
  final String id;
  final String? orgId;
  final double amount;
  final String currency;
  final String? paymentMethod;
  final String status;
  final String? invoiceNumber;
  final DateTime createdAt;

  const PlatformRevenue({
    required this.id,
    this.orgId,
    required this.amount,
    this.currency = 'INR',
    this.paymentMethod,
    this.status = 'pending',
    this.invoiceNumber,
    required this.createdAt,
  });

  factory PlatformRevenue.fromJson(Map<String, dynamic> json) {
    return PlatformRevenue(
      id: json['id'],
      orgId: json['org_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'INR',
      paymentMethod: json['payment_method'],
      status: json['status'] ?? 'pending',
      invoiceNumber: json['invoice_number'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, amount, status, createdAt];
}

// =====================================================
// ORGANIZATION DETAIL — typed model for the detail page
// =====================================================

/// Full organization detail data — assembled from 6 parallel queries.
/// Used by [orgDetailFullProvider] and the admin org detail page.
class OrgDetailData {
  /// Core org record (27 columns).
  final Map<String, dynamic> org;

  /// All profiles (staff/users) belonging to this org.
  final List<Map<String, dynamic>> profiles;

  /// All branches belonging to this org.
  final List<Map<String, dynamic>> branches;

  /// Recent activity logs for this org (last 15).
  final List<Map<String, dynamic>> activityLogs;

  /// Total member count.
  final int memberCount;

  /// Total loan count.
  final int loanCount;

  /// Active loan count.
  final int activeLoanCount;

  /// Total loan amount disbursed.
  final double totalLoanAmount;

  /// Total collections in last 30 days.
  final double recentCollections;

  /// Collection count in last 30 days.
  final int recentCollectionCount;

  /// Pending approval count.
  final int pendingApprovalCount;

  const OrgDetailData({
    required this.org,
    this.profiles = const [],
    this.branches = const [],
    this.activityLogs = const [],
    this.memberCount = 0,
    this.loanCount = 0,
    this.activeLoanCount = 0,
    this.totalLoanAmount = 0,
    this.recentCollections = 0,
    this.recentCollectionCount = 0,
    this.pendingApprovalCount = 0,
  });

  /// Shorthand accessors for commonly used org fields.
  String get id => org['id'] as String? ?? '';
  String get name => org['name'] as String? ?? '';
  String get displayName => org['display_name'] as String? ?? name;
  String get slug => org['slug'] as String? ?? '';
  String get status => org['status'] as String? ?? 'unknown';
  String get plan => org['plan'] as String? ?? 'free';
  String? get phone => org['phone'] as String?;
  String? get email => org['email'] as String?;
  String? get address => org['address'] as String?;
  String? get city => org['city'] as String?;
  String? get state => org['state'] as String?;
  String? get pincode => org['pincode'] as String?;
  String? get gstNumber => org['gst_number'] as String?;
  String? get logoUrl => org['logo_url'] as String?;
  int get maxBranches => (org['max_branches'] as num?)?.toInt() ?? 10;
  int get maxStaff => (org['max_staff'] as num?)?.toInt() ?? 20;
  int get maxMembers => (org['max_members'] as num?)?.toInt() ?? 500;
  DateTime? get createdAt => DateTime.tryParse(org['created_at'] as String? ?? '');
  DateTime? get trialEndsAt => DateTime.tryParse(org['trial_ends_at'] as String? ?? '');

  /// Staff count (executiveAdmin + manager + collectionAgent).
  int get staffCount => profiles.where((p) {
    final role = p['role'] as String? ?? '';
    return role == 'executiveAdmin' || role == 'manager' || role == 'collectionAgent';
  }).length;

  bool get hasContactInfo => phone != null || email != null || address != null;
}
