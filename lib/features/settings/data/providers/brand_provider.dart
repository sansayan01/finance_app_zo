import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brand_model.dart';
import 'activity_log_repository_provider.dart';
import '../models/activity_log_model.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import 'package:microflow_pro/core/services/app_icon_service.dart';

class BrandNotifier extends StateNotifier<BrandModel> {
  final Ref _ref;

  BrandNotifier(this._ref) : super(BrandModel(name: 'MicroFlow Pro')) {
    _loadBrand();
  }

  Future<void> _loadBrand() async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        final profile = await client
            .from('profiles')
            .select('org_id')
            .eq('user_id', currentUser.id)
            .maybeSingle();
        if (profile != null && profile['org_id'] != null) {
          final org = await client
              .from('organizations')
              .select('display_name, name, icon_preset')
              .eq('id', profile['org_id'])
              .maybeSingle();
          if (org != null) {
            final iconPreset = org['icon_preset'] as String? ?? 'default';
            state = BrandModel(
              name: org['display_name'] as String? ??
                  org['name'] as String? ??
                  'MicroFlow Pro',
              iconPreset: iconPreset,
            );
            // Apply the org's icon preset to this device
            _applyIconPreset(iconPreset);
            return;
          }
        }
      }
      final response = await client
          .from('system_settings')
          .select()
          .eq('key', 'branding')
          .maybeSingle();
      if (response != null) {
        final brand = BrandModel.fromJson(response['value']);
        state = brand;
        _applyIconPreset(brand.iconPreset);
      }
    } catch (e) {
      // Keep default
    }
  }

  /// Apply the icon preset on the device (non-blocking).
  Future<void> _applyIconPreset(String presetId) async {
    try {
      final supported = await AppIconService.isSupported();
      if (!supported) return;

      final current = await AppIconService.getCurrentIcon();
      if (current != presetId) {
        await AppIconService.setIcon(presetId);
        debugPrint('🎨 App icon switched to: $presetId');
      }
    } catch (e) {
      debugPrint('⚠️ Icon switch failed: $e');
    }
  }

  /// Update brand settings including icon preset.
  /// Called by the executive admin from the organization settings page.
  Future<void> updateBrand({
    String? name,
    String? iconPreset,
  }) async {
    final oldName = state.name;
    final oldPreset = state.iconPreset;
    final newState = state.copyWith(
      name: name,
      iconPreset: iconPreset,
    );
    state = newState;

    try {
      final client = _ref.read(supabaseClientProvider);
      final currentUser = client.auth.currentUser;

      // Persist to system_settings (legacy)
      await client.from('system_settings').upsert({
        'key': 'branding',
        'value': newState.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also persist icon_preset to the organizations table
      // so all org members get it on next login
      if (currentUser != null) {
        final profile = await client
            .from('profiles')
            .select('org_id')
            .eq('user_id', currentUser.id)
            .maybeSingle();
        if (profile != null && profile['org_id'] != null) {
          final orgId = profile['org_id'] as String;
          final updateData = <String, dynamic>{
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (name != null) updateData['display_name'] = name;
          if (iconPreset != null) updateData['icon_preset'] = iconPreset;

          await client.from('organizations').update(updateData).eq('id', orgId);
        }
      }

      // Apply icon change on this device
      if (iconPreset != null && iconPreset != oldPreset) {
        await _applyIconPreset(iconPreset);
      }

      // Log the activity
      final changes = <String>[];
      if (name != null && name != oldName) {
        changes.add('brand name from "$oldName" to "$name"');
      }
      if (iconPreset != null && iconPreset != oldPreset) {
        changes.add('home screen icon to "$iconPreset"');
      }

      if (changes.isNotEmpty) {
        await _ref.read(activityLogRepositoryProvider).log(
              action: 'System Branding Updated',
              details: 'Changed ${changes.join(", ")}',
              type: ActivityType.systemUpdate,
            );
      }
    } catch (e) {
      // Local only if DB fails
    }
  }
}

final brandProvider = StateNotifierProvider<BrandNotifier, BrandModel>((ref) {
  return BrandNotifier(ref);
});
