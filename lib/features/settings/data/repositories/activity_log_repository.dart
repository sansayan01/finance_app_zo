import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log_model.dart';

class ActivityLogRepository {
  final SupabaseClient _client;
  final String _orgId;

  ActivityLogRepository(this._client,
      [this._orgId = '00000000-0000-0000-0000-000000000001']);

  Future<void> log({
    required String action,
    required String details,
    required ActivityType type,
    String? userId,
    String? userName,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      await _client.from('activity_logs').insert({
        'user_id': userId ?? currentUser?.id ?? 'system',
        'user_name':
            userName ?? currentUser?.userMetadata?['full_name'] ?? 'System',
        'action': action,
        'details': details,
        'type': type.name,
        'org_id': _orgId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silently fail logging in dev if table missing
    }
  }

  Future<List<ActivityLogModel>> fetchLogs() async {
    final response = await _client
        .from('activity_logs')
        .select()
        .eq('org_id', _orgId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((e) => ActivityLogModel.fromJson(e)).toList();
  }
}
