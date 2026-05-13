import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brand_model.dart';
import 'activity_log_repository_provider.dart';
import '../models/activity_log_model.dart';
import '../../../../providers/supabase_provider.dart';

class BrandNotifier extends StateNotifier<BrandModel> {
  final Ref _ref;

  BrandNotifier(this._ref)
      : super(BrandModel(name: 'MicroFlow Pro')) {
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
              .select('name, logo_url, primary_color, settings')
              .eq('id', profile['org_id'])
              .maybeSingle();
          if (org != null) {
            state = BrandModel(
              name: org['name'] as String? ?? 'MicroFlow Pro',
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

  Future<void> updateBrand({String? name, String? logoUrl}) async {
    final oldName = state.name;
    final newState = state.copyWith(name: name, logoUrl: logoUrl);
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
            details: 'Changed brand name from "$oldName" to "${newState.name}"',
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
