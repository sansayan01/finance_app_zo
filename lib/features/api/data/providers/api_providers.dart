import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../models/api_key_model.dart';
import '../repositories/api_repository.dart';

// Repository provider
final apiRepositoryProvider = Provider<ApiRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ApiRepository(client);
});

// API Keys
final apiKeysProvider = FutureProvider<List<ApiKeyModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(apiRepositoryProvider);
  return repository.getApiKeys(orgId);
});

// Webhooks
final webhooksProvider = FutureProvider<List<WebhookModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(apiRepositoryProvider);
  return repository.getWebhooks(orgId);
});

// Integrations
final integrationsProvider = FutureProvider<List<IntegrationModel>>((ref) async {
  final orgId = ref.watch(currentOrgIdProvider);
  if (orgId == null) return [];

  final repository = ref.watch(apiRepositoryProvider);
  return repository.getIntegrations(orgId);
});

// API actions notifier
class ApiNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiRepository _repository;
  final Ref _ref;

  ApiNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  /// Generate API key
  Future<ApiKeyWithSecret?> generateApiKey({
    required String name,
    List<String> scopes = const ['read'],
    DateTime? expiresAt,
  }) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      final key = await _repository.generateApiKey(
        orgId: orgId,
        name: name,
        scopes: scopes,
        expiresAt: expiresAt,
      );

      _ref.invalidate(apiKeysProvider);
      state = const AsyncValue.data(null);
      return key;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Revoke API key
  Future<bool> revokeApiKey(String keyId) async {
    final success = await _repository.revokeApiKey(keyId);
    if (success) _ref.invalidate(apiKeysProvider);
    return success;
  }

  /// Delete API key
  Future<bool> deleteApiKey(String keyId) async {
    final success = await _repository.deleteApiKey(keyId);
    if (success) _ref.invalidate(apiKeysProvider);
    return success;
  }

  /// Create webhook
  Future<WebhookModel?> createWebhook({
    required String name,
    required String url,
    required List<String> events,
  }) async {
    state = const AsyncValue.loading();
    try {
      final orgId = _ref.read(currentOrgIdProvider);
      if (orgId == null) throw Exception('No organization selected');

      final webhook = await _repository.createWebhook(
        orgId: orgId,
        name: name,
        url: url,
        events: events,
      );

      _ref.invalidate(webhooksProvider);
      state = const AsyncValue.data(null);
      return webhook;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Delete webhook
  Future<bool> deleteWebhook(String webhookId) async {
    final success = await _repository.deleteWebhook(webhookId);
    if (success) _ref.invalidate(webhooksProvider);
    return success;
  }

  /// Create integration
  Future<IntegrationModel?> createIntegration({
    required String type,
    required String name,
    Map<String, dynamic>? config,
    Map<String, dynamic>? credentials,
  }) async {
    final orgId = _ref.read(currentOrgIdProvider);
    if (orgId == null) return null;

    final integration = await _repository.createIntegration(
      orgId: orgId,
      type: type,
      name: name,
      config: config,
      credentials: credentials,
    );

    if (integration != null) _ref.invalidate(integrationsProvider);
    return integration;
  }

  /// Delete integration
  Future<bool> deleteIntegration(String integrationId) async {
    final success = await _repository.deleteIntegration(integrationId);
    if (success) _ref.invalidate(integrationsProvider);
    return success;
  }
}

final apiNotifierProvider = StateNotifierProvider<ApiNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(apiRepositoryProvider);
  return ApiNotifier(repository, ref);
});

