import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/polyline_utils.dart';

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

  // ─── Realtime: Stream of new location inserts/updates for this org ─────────

  RealtimeChannel subscribeToAgentLocations({
    required void Function(Map<String, dynamic> payload) onUpdate,
    void Function(Map<String, dynamic>)? onDeactivate,
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'staff_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'org_id',
            value: orgId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              if (record['is_active'] == false) {
                onDeactivate?.call(record);
              } else {
                onUpdate(record);
              }
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

  /// Get breadcrumbs for a date range with smart downsampling.
  /// For long time ranges, applies Douglas-Peucker simplification to reduce point count.
  Future<List<Map<String, dynamic>>> getBreadcrumbsForDateRange(
    String staffId,
    DateTime start,
    DateTime end, {
    int maxPoints = 2000,
  }) async {
    try {
      final data = await _client
          .from('staff_locations')
          .select('latitude, longitude, recorded_at, activity_type, speed')
          .eq('staff_id', staffId)
          .eq('org_id', orgId)
          .gte('recorded_at', start.toIso8601String())
          .lte('recorded_at', end.toIso8601String())
          .order('recorded_at', ascending: true);

      if (data.isEmpty) return data;

      // If we have more points than maxPoints, apply downsampling
      if (data.length > maxPoints) {
        final points = data.map((r) => LatLng(
          (r['latitude'] as num).toDouble(),
          (r['longitude'] as num).toDouble(),
        )).toList();

        // Calculate appropriate tolerance based on data density
        final timeRange = end.difference(start).inHours;
        final tolerance = timeRange > 24 ? 50.0 : 20.0; // meters

        final simplified = PolylineUtils.simplify(points, tolerance);

        // Map back to original data structure using nearest points
        final result = <Map<String, dynamic>>[];
        for (final sPoint in simplified) {
          // Find the closest original point
          Map<String, dynamic>? closest;
          double minDist = double.infinity;
          for (final original in data) {
            final lat = (original['latitude'] as num).toDouble();
            final lng = (original['longitude'] as num).toDouble();
            final dist = _quickDistance(sPoint.latitude, sPoint.longitude, lat, lng);
            if (dist < minDist) {
              minDist = dist;
              closest = original;
            }
          }
          if (closest != null && !result.any((r) => r['recorded_at'] == closest!['recorded_at'])) {
            result.add(closest);
          }
        }
        return result;
      }

      return data;
    } catch (e) {
      debugPrint('[LiveTracking] Error fetching date range breadcrumbs: $e');
      return [];
    }
  }

  /// Quick approximate distance for sorting (not precise, but fast).
  double _quickDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat2 - lat1;
    final dLng = (lng2 - lng1) * cos((lat1 + lat2) / 2 * pi / 180);
    return sqrt(dLat * dLat + dLng * dLng) * 111320; // rough meters
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

  // ─── On-Duty Agents: Get agents currently on duty ───────────────────────────

  Future<List<Map<String, dynamic>>> getOnDutyAgents() async {
    try {
      final response = await _client
          .from('duty_sessions')
          .select('staff_id, start_time, branch_id')
          .eq('org_id', orgId)
          .eq('status', 'active');

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[LiveTracking] Error fetching on-duty agents: $e');
      return [];
    }
  }

  void dispose() {}
}
