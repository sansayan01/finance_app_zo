import 'package:equatable/equatable.dart';

class ApiKeyModel extends Equatable {
  final String id;
  final String orgId;
  final String name;
  final String keyPrefix;
  final List<String> scopes;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const ApiKeyModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.keyPrefix,
    required this.scopes,
    this.lastUsedAt,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  bool get hasWriteAccess => scopes.contains('write') || scopes.contains('admin');
  bool get hasReadAccess => scopes.contains('read') || hasWriteAccess;
  bool get isAdmin => scopes.contains('admin');

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get maskedKey => '$keyPrefix************************';

  String get scopesDisplay {
    return scopes.map((s) => s.toUpperCase()).join(', ');
  }

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ApiKeyModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      keyPrefix: json['key_prefix'] as String? ?? '',
      scopes: (json['scopes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, name, keyPrefix, scopes, lastUsedAt, expiresAt, isActive, createdAt,
  ];
}

class ApiKeyWithSecret extends ApiKeyModel {
  final String fullKey;

  const ApiKeyWithSecret({
    required super.id,
    required super.orgId,
    required super.name,
    required super.keyPrefix,
    required super.scopes,
    super.lastUsedAt,
    super.expiresAt,
    required super.isActive,
    required super.createdAt,
    required this.fullKey,
  });

  factory ApiKeyWithSecret.fromJson(Map<String, dynamic> json) {
    return ApiKeyWithSecret(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      keyPrefix: json['key_prefix'] as String? ?? '',
      scopes: (json['scopes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      fullKey: json['full_key'] as String? ?? '',
    );
  }
}

class WebhookModel extends Equatable {
  final String id;
  final String orgId;
  final String name;
  final String url;
  final List<String> events;
  final bool isActive;
  final DateTime? lastTriggeredAt;
  final int? lastResponseStatus;
  final int failureCount;
  final DateTime createdAt;

  const WebhookModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.url,
    required this.events,
    required this.isActive,
    this.lastTriggeredAt,
    this.lastResponseStatus,
    this.failureCount = 0,
    required this.createdAt,
  });

  bool get isHealthy => failureCount < 3;

  factory WebhookModel.fromJson(Map<String, dynamic> json) {
    return WebhookModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      events: (json['events'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      isActive: json['is_active'] as bool? ?? true,
      lastTriggeredAt: json['last_triggered_at'] != null
          ? DateTime.tryParse(json['last_triggered_at'] as String)
          : null,
      lastResponseStatus: json['last_response_status'] as int?,
      failureCount: (json['failure_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, name, url, events, isActive, lastTriggeredAt,
    lastResponseStatus, failureCount, createdAt,
  ];
}

class IntegrationModel extends Equatable {
  final String id;
  final String orgId;
  final String type;
  final String name;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime? lastSyncAt;
  final String? syncStatus;
  final String? syncError;
  final DateTime createdAt;

  const IntegrationModel({
    required this.id,
    required this.orgId,
    required this.type,
    required this.name,
    required this.config,
    required this.isActive,
    this.lastSyncAt,
    this.syncStatus,
    this.syncError,
    required this.createdAt,
  });

  factory IntegrationModel.fromJson(Map<String, dynamic> json) {
    return IntegrationModel(
      id: json['id'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      config: json['config'] as Map<String, dynamic>? ?? {},
      isActive: json['is_active'] as bool? ?? true,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.tryParse(json['last_sync_at'] as String)
          : null,
      syncStatus: json['sync_status'] as String?,
      syncError: json['sync_error'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id, orgId, type, name, config, isActive, lastSyncAt, syncStatus, syncError, createdAt,
  ];
}
