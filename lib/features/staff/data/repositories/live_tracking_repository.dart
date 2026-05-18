import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the live field agent tracking feature.
/// - Fetches latest location snapshot per staff
/// - Subscribes to Supabase Realtime for live updates
/// - Fetches today's breadcrumb trail for a specific agent
class LiveTrackingRepository {
  final SupabaseClient _client;
  final String orgId;

  LiveTrackingRepository(this._client, this.orgId);

  // ─── Snapshot: Latest location per agent ────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLatestAgentLocations() async {
    try {
      final response = await _client.rpc(
        'get_latest_staff_locations',
        params: {'p_org_id': orgId},
      );
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[LiveTracking] Error fetching latest locations: $e');
      return [];
    }
  }

  // ─── Realtime: Stream of new location inserts for this org ──────────────────

  RealtimeChannel subscribeToAgentLocations({
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channel = _client
        .channel('staff_locations_$orgId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'staff_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: orgId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              onUpdate(newRecord);
            }
          },
        )
        .subscribe();

    return channel;
  }

  // ─── Breadcrumb: Today's path for a specific agent ───────────────────────────

  Future<List<Map<String, dynamic>>> getTodayBreadcrumbs(
      String staffId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();

      final response = await _client
          .from('staff_locations')
          .select('latitude, longitude, recorded_at, activity_type, speed')
          .eq('staff_id', staffId)
          .eq('org_id', orgId)
          .gte('recorded_at', startOfDay)
          .order('recorded_at', ascending: true)
          .limit(500);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[LiveTracking] Error fetching breadcrumbs: $e');
      return [];
    }
  }

  // ─── Agent detail: Stats for a specific agent today ──────────────────────────

  Future<Map<String, dynamic>> getAgentDailyStats(String staffProfileId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();

      // Collections count today
      final collections = await _client
          .from('collections')
          .select('id, amount_collected')
          .eq('staff_id', staffProfileId)
          .gte('created_at', startOfDay);

      final collectionList = List<Map<String, dynamic>>.from(collections as List);
      final totalCollected = collectionList.fold<double>(
          0, (sum, c) => sum + ((c['amount_collected'] as num?)?.toDouble() ?? 0));

      // Visits today
      final visits = await _client
          .from('visit_logs')
          .select('id')
          .eq('staff_id', staffProfileId)
          .gte('created_at', startOfDay);

      return {
        'collections_count': collectionList.length,
        'total_collected': totalCollected,
        'visits_count': (visits as List).length,
      };
    } catch (e) {
      debugPrint('[LiveTracking] Error fetching agent stats: $e');
      return {'collections_count': 0, 'total_collected': 0.0, 'visits_count': 0};
    }
  }

  void dispose() {}
}
