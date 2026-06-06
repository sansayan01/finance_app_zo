import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log_model.dart';

class ActivityLogRepository {
  final SupabaseClient _client;
  final String? _orgId;

  /// [_orgId] is the tenant scope. It MUST be supplied by callers that
  /// operate inside a tenant — leaving it null is the safe default and
  /// prevents accidentally logging to a sentinel UUID row.
  ActivityLogRepository(this._client, [this._orgId]);

  Future<void> log({
    required String action,
    required String details,
    required ActivityType type,
    String? userId,
    String? userName,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;

      // If the caller didn't pass an orgId, try to pull it from the
      // currently-authenticated user's profile. This keeps the
      // `activity_logs` table properly tenant-scoped without forcing
      // every call-site to plumb the orgId.
      String? resolvedOrgId = _orgId;
      if (resolvedOrgId == null && currentUser != null) {
        try {
          final profile = await _client
              .from('profiles')
              .select('org_id')
              .eq('user_id', currentUser.id)
              .maybeSingle();
          resolvedOrgId = profile?['org_id'] as String?;
        } catch (e) {
          debugPrint('ActivityLogRepository: profile lookup failed: $e');
        }
      }

      await _client.from('activity_logs').insert({
        'user_id': userId ?? currentUser?.id ?? 'system',
        'user_name':
            userName ?? currentUser?.userMetadata?['full_name'] ?? 'System',
        'action': action,
        'details': details,
        'type': type.name,
        if (resolvedOrgId != null) 'org_id': resolvedOrgId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('ActivityLogRepository.log failed: $e');
    }
  }

  Future<List<ActivityLogModel>> fetchLogs() async {
    final orgId = _orgId;
    if (orgId == null) {
      // No org scope — return empty list instead of fetching all logs
      // across all tenants (a privacy bug).
      return const [];
    }
    final response = await _client
        .from('activity_logs')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((e) => ActivityLogModel.fromJson(e)).toList();
  }
}
