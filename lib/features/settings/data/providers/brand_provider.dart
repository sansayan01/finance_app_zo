import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brand_model.dart';
import 'activity_log_repository_provider.dart';
import '../models/activity_log_model.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

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
              .select('display_name, name, logo_url, primary_color')
              .eq('id', profile['org_id'])
              .maybeSingle();
          if (org != null) {
            state = BrandModel(
              name: org['display_name'] as String? ??
                  org['name'] as String? ??
                  'MicroFlow Pro',
              logoUrl: org['logo_url'] as String?,
              primaryColor: org['primary_color'] as String?,
            );
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
        state = BrandModel.fromJson(response['value']);
      }
    } catch (e) {
      // Keep default
    }
  }

  Future<void> updateBrand({String? name, String? logoUrl, String? primaryColor}) async {
    final oldName = state.name;
    final newState = state.copyWith(
      name: name,
      logoUrl: logoUrl,
      primaryColor: primaryColor,
    );
    state = newState;

    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('system_settings').upsert({
        'key': 'branding',
        'value': newState.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Log the activity
      await _ref.read(activityLogRepositoryProvider).log(
            action: 'System Branding Updated',
            details: 'Changed brand name from "$oldName" to "${newState.name}" and color to "${newState.primaryColor}"',
            type: ActivityType.systemUpdate,
          );
    } catch (e) {
      // Local only if DB fails
    }
  }
}

final brandProvider = StateNotifierProvider<BrandNotifier, BrandModel>((ref) {
  return BrandNotifier(ref);
});
