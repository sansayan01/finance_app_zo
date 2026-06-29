import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/models/app_update.dart';

class AppUpdateApi {
  final SupabaseClient _client;
  AppUpdateApi(this._client);

  Future<AppUpdate?> fetchLatestActiveForAndroid() async {
    final response = await _client
        .from('app_updates')
        .select()
        .eq('platform', 'android')
        .eq('status', 'active')
        .order('published_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return AppUpdate.fromJson(response);
  }

  Future<List<AppUpdate>> fetchActiveForAndroid({int limit = 20}) async {
    final response = await _client
        .from('app_updates')
        .select()
        .eq('platform', 'android')
        .eq('status', 'active')
        .order('published_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((e) => AppUpdate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUpdate> createAppUpdate({
    required String version,
    required String downloadUrl,
    String platform = 'android',
    String? releaseNotes,
    bool isCritical = false,
    String? minSupportedVersion,
    double? fileSizeMb,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = <String, dynamic>{
      'version': version,
      'platform': platform,
      'download_url': downloadUrl,
      'is_critical': isCritical,
      'min_supported_version': minSupportedVersion ?? version,
      'release_notes': releaseNotes,
      'file_size_mb': fileSizeMb,
      'published_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('app_updates')
        .insert(data)
        .select()
        .single();

    return AppUpdate.fromJson(response);
  }
}

final appUpdateApiProvider = Provider<AppUpdateApi>((ref) {
  final client = Supabase.instance.client;
  return AppUpdateApi(client);
});
