import 'package:equatable/equatable.dart';

/// Audit log model for enterprise
class AuditLogModel extends Equatable {
  final String id;
  final String orgId;
  final String userId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String ipAddress;
  final String userAgent;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.oldValues,
    this.newValues,
    required this.ipAddress,
    required this.userAgent,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      userId: json['user_id'] as String,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String,
      userAgent: json['user_agent'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, orgId, userId, action, entityType, entityId, oldValues, newValues, ipAddress, userAgent, createdAt];
}

/// Organization settings model
class OrgSettingsModel extends Equatable {
  final String id;
  final String orgId;
  final bool twoFactorRequired;
  final bool sessionTimeout;
  final int sessionTimeoutMinutes;
  final bool passwordPolicy;
  final int passwordMinLength;
  final bool passwordRequireUppercase;
  final bool passwordRequireNumbers;
  final bool passwordRequireSymbols;
  final bool dataEncryption;
  final bool auditLogging;
  final int auditRetentionDays;
  final bool ssoEnabled;
  final String? ssoProvider;
  final String? ssoDomain;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrgSettingsModel({
    required this.id,
    required this.orgId,
    this.twoFactorRequired = false,
    this.sessionTimeout = true,
    this.sessionTimeoutMinutes = 30,
    this.passwordPolicy = true,
    this.passwordMinLength = 8,
    this.passwordRequireUppercase = true,
    this.passwordRequireNumbers = true,
    this.passwordRequireSymbols = false,
    this.dataEncryption = true,
    this.auditLogging = true,
    this.auditRetentionDays = 90,
    this.ssoEnabled = false,
    this.ssoProvider,
    this.ssoDomain,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrgSettingsModel.fromJson(Map<String, dynamic> json) {
    return OrgSettingsModel(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      twoFactorRequired: json['two_factor_required'] as bool? ?? false,
      sessionTimeout: json['session_timeout'] as bool? ?? true,
      sessionTimeoutMinutes: json['session_timeout_minutes'] as int? ?? 30,
      passwordPolicy: json['password_policy'] as bool? ?? true,
      passwordMinLength: json['password_min_length'] as int? ?? 8,
      passwordRequireUppercase: json['password_require_uppercase'] as bool? ?? true,
      passwordRequireNumbers: json['password_require_numbers'] as bool? ?? true,
      passwordRequireSymbols: json['password_require_symbols'] as bool? ?? false,
      dataEncryption: json['data_encryption'] as bool? ?? true,
      auditLogging: json['audit_logging'] as bool? ?? true,
      auditRetentionDays: json['audit_retention_days'] as int? ?? 90,
      ssoEnabled: json['sso_enabled'] as bool? ?? false,
      ssoProvider: json['sso_provider'] as String?,
      ssoDomain: json['sso_domain'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, twoFactorRequired, sessionTimeout, sessionTimeoutMinutes,
    passwordPolicy, passwordMinLength, passwordRequireUppercase,
    passwordRequireNumbers, passwordRequireSymbols, dataEncryption,
    auditLogging, auditRetentionDays, ssoEnabled, ssoProvider, ssoDomain,
    createdAt, updatedAt
  ];
}
