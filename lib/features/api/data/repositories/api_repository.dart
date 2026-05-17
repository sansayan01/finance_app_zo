import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/api_key_model.dart';

class ApiRepository {
  final SupabaseClient _client;

  ApiRepository(this._client);

  // ==================== API KEYS ====================

  /// Get all API keys for org
  Future<List<ApiKeyModel>> getApiKeys(String orgId) async {
    final response = await _client
        .from('api_keys')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);

    return response
        .map<ApiKeyModel>((json) => ApiKeyModel.fromJson(json))
        .toList();
  }

  /// Generate new API key
  Future<ApiKeyWithSecret?> generateApiKey({
    required String orgId,
    required String name,
    List<String> scopes = const ['read'],
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _client.rpc(
        'generate_api_key',
        params: {
          'p_org_id': orgId,
          'p_name': name,
          'p_scopes': scopes,
          'p_expires_at': expiresAt?.toIso8601String(),
        },
      );

      if (response == null) return null;

      final data = response as List<dynamic>;
      if (data.isEmpty) return null;

      final first = data.first as Map<String, dynamic>;
      return ApiKeyWithSecret.fromJson({
        'id': first['id'],
        'org_id': orgId,
        'name': name,
        'key_prefix': first['key_prefix'],
        'scopes': scopes,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'full_key': first['full_key'],
      });
    } catch (e) {
      return null;
    }
  }

  /// Revoke API key
  Future<bool> revokeApiKey(String keyId) async {
    try {
      await _client
          .from('api_keys')
          .update({'is_active': false}).eq('id', keyId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete API key
  Future<bool> deleteApiKey(String keyId) async {
    try {
      await _client.from('api_keys').delete().eq('id', keyId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== WEBHOOKS ====================

  /// Get all webhooks for org
  Future<List<WebhookModel>> getWebhooks(String orgId) async {
    final response = await _client
        .from('webhooks')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);

    return response
        .map<WebhookModel>((json) => WebhookModel.fromJson(json))
        .toList();
  }

  /// Create webhook
  Future<WebhookModel?> createWebhook({
    required String orgId,
    required String name,
    required String url,
    required List<String> events,
  }) async {
    try {
      final response = await _client
          .from('webhooks')
          .insert({
            'org_id': orgId,
            'name': name,
            'url': url,
            'events': events,
          })
          .select()
          .single();

      return WebhookModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update webhook
  Future<bool> updateWebhook({
    required String webhookId,
    String? name,
    String? url,
    List<String>? events,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (url != null) updates['url'] = url;
      if (events != null) updates['events'] = events;
      if (isActive != null) updates['is_active'] = isActive;

      await _client.from('webhooks').update(updates).eq('id', webhookId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete webhook
  Future<bool> deleteWebhook(String webhookId) async {
    try {
      await _client.from('webhooks').delete().eq('id', webhookId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get webhook deliveries
  Future<List<Map<String, dynamic>>> getWebhookDeliveries(
    String webhookId, {
    int limit = 20,
  }) async {
    final response = await _client
        .from('webhook_deliveries')
        .select()
        .eq('webhook_id', webhookId)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== INTEGRATIONS ====================

  /// Get all integrations for org
  Future<List<IntegrationModel>> getIntegrations(String orgId) async {
    final response =
        await _client.from('integrations').select().eq('org_id', orgId);

    return response
        .map<IntegrationModel>((json) => IntegrationModel.fromJson(json))
        .toList();
  }

  /// Create integration
  Future<IntegrationModel?> createIntegration({
    required String orgId,
    required String type,
    required String name,
    Map<String, dynamic>? config,
    Map<String, dynamic>? credentials,
  }) async {
    try {
      final response = await _client
          .from('integrations')
          .insert({
            'org_id': orgId,
            'type': type,
            'name': name,
            'config': config ?? {},
            'credentials': credentials ?? {},
          })
          .select()
          .single();

      return IntegrationModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update integration
  Future<bool> updateIntegration({
    required String integrationId,
    Map<String, dynamic>? config,
    Map<String, dynamic>? credentials,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (config != null) updates['config'] = config;
      if (credentials != null) updates['credentials'] = credentials;
      if (isActive != null) updates['is_active'] = isActive;

      await _client
          .from('integrations')
          .update(updates)
          .eq('id', integrationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete integration
  Future<bool> deleteIntegration(String integrationId) async {
    try {
      await _client.from('integrations').delete().eq('id', integrationId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== DATA EXPORTS ====================

  /// Create export request
  Future<Map<String, dynamic>?> createExport({
    required String orgId,
    required String type,
    String format = 'csv',
    Map<String, dynamic>? filters,
  }) async {
    try {
      final response = await _client
          .from('data_exports')
          .insert({
            'org_id': orgId,
            'type': type,
            'format': format,
            'filters': filters ?? {},
          })
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get exports for org
  Future<List<Map<String, dynamic>>> getExports(String orgId) async {
    final response = await _client
        .from('data_exports')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }
}
