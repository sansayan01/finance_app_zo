import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../models/org_branding_model.dart';
import '../repositories/branding_repository.dart';

/// Branding repository provider
final brandingRepositoryProvider = Provider<BrandingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BrandingRepository(client);
});

/// Current organization branding
final orgBrandingProvider =
    FutureProvider.family<OrgBrandingModel?, String>((ref, orgId) async {
  final repository = ref.watch(brandingRepositoryProvider);
  return repository.getBranding(orgId);
});

/// Branding notifier for updates
class BrandingNotifier extends StateNotifier<AsyncValue<OrgBrandingModel?>> {
  final BrandingRepository _repository;
  final String _orgId;

  BrandingNotifier(this._repository, this._orgId)
      : super(const AsyncValue.loading()) {
    loadBranding();
  }

  Future<void> loadBranding() async {
    state = const AsyncValue.loading();
    try {
      final branding = await _repository.getBranding(_orgId);
      state = AsyncValue.data(branding);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateBranding(Map<String, dynamic> updates) async {
    try {
      final currentBranding = state.value;
      if (currentBranding == null) return;

      state = const AsyncValue.loading();
      final updated = await _repository.updateBranding(_orgId, updates);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> uploadLogo(String filePath, List<int> bytes,
      {bool isDark = false}) async {
    try {
      final url =
          await _repository.uploadLogo(_orgId, filePath, bytes, isDark: isDark);
      await loadBranding();
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> setCustomDomain(String domain) async {
    try {
      await _repository.setCustomDomain(_orgId, domain);
      await loadBranding();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> verifyCustomDomain() async {
    try {
      return await _repository.verifyCustomDomain(_orgId);
    } catch (e) {
      return false;
    }
  }

  Future<void> updateFeatures(Map<String, dynamic> features) async {
    try {
      await _repository.updateFeatures(_orgId, features);
      await loadBranding();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Branding notifier provider
final brandingNotifierProvider = StateNotifierProvider.family<BrandingNotifier,
    AsyncValue<OrgBrandingModel?>, String>((ref, orgId) {
  final repository = ref.watch(brandingRepositoryProvider);
  return BrandingNotifier(repository, orgId);
});

/// Check if feature is enabled
final featureEnabledProvider =
    Provider.family<bool, (String orgId, String feature)>((ref, params) {
  final brandingAsync = ref.watch(orgBrandingProvider(params.$1));
  return brandingAsync.maybeWhen(
    data: (branding) => branding?.hasFeature(params.$2) ?? false,
    orElse: () => false,
  );
});
