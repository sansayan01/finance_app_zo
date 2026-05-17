class ApiKeyModel {
  final String id;
  final String orgId;
  final String name;
  final String keyPrefix;
  final List<String> scopes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;

  ApiKeyModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.keyPrefix,
    required this.scopes,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
    this.lastUsedAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isValid => isActive && !isExpired;

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ApiKeyModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      keyPrefix: json['key_prefix']?.toString() ?? '',
      scopes: List<String>.from(json['scopes'] ?? []),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
    );
  }
}

class ApiKeyWithSecret extends ApiKeyModel {
  final String fullKey;

  ApiKeyWithSecret({
    required super.id,
    required super.orgId,
    required super.name,
    required super.keyPrefix,
    required super.scopes,
    required super.isActive,
    required super.createdAt,
    super.expiresAt,
    super.lastUsedAt,
    required this.fullKey,
  });

  factory ApiKeyWithSecret.fromJson(Map<String, dynamic> json) {
    return ApiKeyWithSecret(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      keyPrefix: json['key_prefix']?.toString() ?? '',
      scopes: List<String>.from(json['scopes'] ?? []),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'])
          : null,
      fullKey: json['full_key']?.toString() ?? '',
    );
  }
}

class WebhookModel {
  final String id;
  final String orgId;
  final String name;
  final String url;
  final List<String> events;
  final bool isActive;
  final DateTime createdAt;

  WebhookModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.url,
    required this.events,
    required this.isActive,
    required this.createdAt,
  });

  factory WebhookModel.fromJson(Map<String, dynamic> json) {
    return WebhookModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      events: List<String>.from(json['events'] ?? []),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class IntegrationModel {
  final String id;
  final String orgId;
  final String type;
  final String name;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime createdAt;

  IntegrationModel({
    required this.id,
    required this.orgId,
    required this.type,
    required this.name,
    required this.config,
    required this.isActive,
    required this.createdAt,
  });

  factory IntegrationModel.fromJson(Map<String, dynamic> json) {
    return IntegrationModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
