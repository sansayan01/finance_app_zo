import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'org_provider.dart';

/// Organization Branding Configuration
class BrandingConfig {
  final String orgId;
  final String? displayName;
  final String? logoUrl;
  final String? logoDarkUrl;
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String? splashScreenUrl;
  final bool useCustomBranding;
  final bool showPoweredBy;
  final String iconPreset;

  const BrandingConfig({
    required this.orgId,
    this.displayName,
    this.logoUrl,
    this.logoDarkUrl,
    this.primaryColor = '#1976D2',
    this.secondaryColor = '#424242',
    this.accentColor = '#FF5722',
    this.splashScreenUrl,
    this.useCustomBranding = false,
    this.showPoweredBy = true,
    this.iconPreset = 'default',
  });

  factory BrandingConfig.defaultConfig(String orgId) {
    return BrandingConfig(orgId: orgId, iconPreset: 'default');
  }

  factory BrandingConfig.fromJson(Map<String, dynamic>? json, String orgId) {
    if (json == null) return BrandingConfig.defaultConfig(orgId);

    return BrandingConfig(
      orgId: orgId,
      displayName: json['display_name'] as String?,
      logoUrl: json['logo_url'] as String?,
      logoDarkUrl: json['logo_dark_url'] as String?,
      primaryColor: json['primary_color'] as String? ?? '#1976D2',
      secondaryColor: json['secondary_color'] as String? ?? '#424242',
      accentColor: json['accent_color'] as String? ?? '#FF5722',
      splashScreenUrl: json['splash_screen_url'] as String?,
      useCustomBranding: json['use_custom_branding'] as bool? ?? false,
      showPoweredBy: json['show_powered_by'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'org_id': orgId,
      'display_name': displayName,
      'logo_url': logoUrl,
      'logo_dark_url': logoDarkUrl,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'accent_color': accentColor,
      'splash_screen_url': splashScreenUrl,
      'use_custom_branding': useCustomBranding,
      'show_powered_by': showPoweredBy,
    };
  }

  /// Parse hex color to Color value
  static int? parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleanHex = hex.replaceAll('#', '');
    return int.tryParse('FF$cleanHex', radix: 16);
  }
}

/// Branding Notifier
class BrandingNotifier extends StateNotifier<AsyncValue<BrandingConfig>> {
  final Ref ref;
  Uint8List? _cachedLogoBytes;
  Uint8List? _cachedSplashBytes;

  BrandingNotifier(this.ref) : super(const AsyncValue.loading());

  Uint8List? get cachedLogoBytes => _cachedLogoBytes;
  Uint8List? get cachedSplashBytes => _cachedSplashBytes;

  /// Load branding configuration
  Future<void> loadBranding() async {
    state = const AsyncValue.loading();

    try {
      final client = ref.read(supabaseClientProvider);
      final orgId = ref.read(currentOrgIdProvider);

      if (orgId == null) {
        state = AsyncValue.data(BrandingConfig.defaultConfig('default'));
        return;
      }

      // Check cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedBranding = prefs.getString('branding_$orgId');

      if (cachedBranding != null) {
        try {
          final decoded = Map<String, dynamic>.from(
            Map<String, dynamic>.from(
              Uri.decodeComponent(cachedBranding).split('&').asMap().map(
                (i, e) {
                  final parts = e.split('=');
                  if (parts.length == 2) {
                    return MapEntry(
                      Uri.decodeComponent(parts[0]),
                      Uri.decodeComponent(parts[1]),
                    );
                  }
                  return MapEntry('', '');
                },
              ),
            ),
          );
          final cached = BrandingConfig.fromJson(decoded, orgId);
          state = AsyncValue.data(cached);
        } catch (_) {
          // Invalid cache, continue to fetch
        }
      }

      // Fetch from database
      final response = await client.from('organizations').select('''
            id,
            name,
            display_name,
            logo_url,
            brand_color,
            primary_color,
            icon_preset
          ''').eq('id', orgId).maybeSingle();

      if (response != null) {
        final config = BrandingConfig(
          orgId: orgId,
          displayName: response['display_name'] as String? ??
              response['name'] as String?,
          logoUrl: response['logo_url'] as String?,
          primaryColor: response['primary_color'] as String? ??
              response['brand_color'] as String? ??
              '#1976D2',
          secondaryColor: '#424242',
          accentColor: '#FF5722',
          logoDarkUrl: null,
          splashScreenUrl: null,
          useCustomBranding: false,
          showPoweredBy: true,
          iconPreset: response['icon_preset'] as String? ?? 'default',
        );

        // Cache the configuration
        await prefs.setString(
          'branding_$orgId',
          Uri.encodeComponent(
            config.toJson().entries.map((e) => '${e.key}=${e.value}').join('&'),
          ),
        );

        state = AsyncValue.data(config);

        // Preload logo bytes if available
        if (config.logoUrl != null) {
          await preloadLogo(config.logoUrl!);
        }
      } else {
        state = AsyncValue.data(BrandingConfig.defaultConfig(orgId));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Preload logo bytes for faster display
  Future<void> preloadLogo(String logoUrl) async {
    try {
      final client = ref.read(supabaseClientProvider);

      // Check if it's a Supabase storage URL
      if (logoUrl.contains('brand-assets')) {
        final uri = Uri.parse(logoUrl);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('brand-assets');

        if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
          _cachedLogoBytes =
              await client.storage.from('brand-assets').download(filePath);
        }
      }
    } catch (e) {
      // Silently fail - logo will load from URL
    }
  }

  /// Clear branding cache
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('branding_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
    _cachedLogoBytes = null;
    _cachedSplashBytes = null;
  }

  /// Update branding
  Future<void> updateBranding({
    String? displayName,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    bool? useCustomBranding,
    bool? showPoweredBy,
  }) async {
    final currentConfig = state.valueOrNull;
    if (currentConfig == null) return;

    final client = ref.read(supabaseClientProvider);
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return;

    try {
      // Update organization
      if (displayName != null) {
        await client.from('organizations').update({
          'display_name': displayName,
        }).eq('id', orgId);
      }

      // Update organization branding fields
      final updates = <String, dynamic>{};
      if (primaryColor != null) updates['primary_color'] = primaryColor;
      if (updates.isNotEmpty) {
        await client.from('organizations').update(updates).eq('id', orgId);
      }

      // Reload branding
      await loadBranding();
    } catch (e) {
      rethrow;
    }
  }

  /// Upload brand logo
  Future<String?> uploadLogo(Uint8List logoBytes, {bool isDark = false}) async {
    final client = ref.read(supabaseClientProvider);
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return null;

    try {
      final fileName =
          isDark ? 'org_$orgId/logo_dark.png' : 'org_$orgId/logo.png';

      await client.storage.from('brand-assets').uploadBinary(
            fileName,
            logoBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      final logoUrl =
          client.storage.from('brand-assets').getPublicUrl(fileName);

      // Update organization logo
      if (!isDark) {
        await client.from('organizations').update({
          'logo_url': logoUrl,
        }).eq('id', orgId);
      }

      // Update organization
      if (!isDark) {
        await client.from('organizations').update({
          'logo_url': logoUrl,
        }).eq('id', orgId);
      }

      // Update cache
      if (!isDark) {
        _cachedLogoBytes = logoBytes;
      }

      // Reload branding
      await loadBranding();

      return logoUrl;
    } catch (e) {
      return null;
    }
  }
}

/// Branding Provider
final brandingProvider =
    StateNotifierProvider<BrandingNotifier, AsyncValue<BrandingConfig>>((ref) {
  return BrandingNotifier(ref);
});
