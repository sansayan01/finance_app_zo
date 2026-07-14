import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/geofence_utils.dart';
import '../../../../core/utils/json_normalize.dart';

/// Represents a geofence zone (typically a branch location).
class GeofenceZone {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final List<LatLng>? polygonVertices;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    this.radiusMeters = 500,
    this.polygonVertices,
  });

  /// Check if a point is inside this zone.
  bool contains(double lat, double lng) {
    if (polygonVertices != null && polygonVertices!.length >= 3) {
      return GeofenceUtils.isInsidePolygon(lat, lng, polygonVertices!);
    }
    return GeofenceUtils.isInsideCircle(
        lat, lng, centerLat, centerLng, radiusMeters);
  }

  /// Get the polygon representation (circle -> polygon approximation).
  List<LatLng> get polygon =>
      polygonVertices ??
      GeofenceUtils.circleToPolygon(centerLat, centerLng, radiusMeters);
}

/// A geofence entry/exit event.
class GeofenceEvent {
  final String zoneId;
  final String zoneName;
  final String type; // 'enter' | 'exit'
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  const GeofenceEvent({
    required this.zoneId,
    required this.zoneName,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => 'GeofenceEvent($type: $zoneName at $timestamp)';
}

/// Status of position relative to geofence zones.
enum GeofencePositionStatus { inside, outside, unknown }

class GeofenceService {
  final SupabaseClient _client;

  GeofenceService(this._client);

  /// Load geofence zones from the branches table.
  /// Each branch becomes a zone with its location_lat/location_lng as center.
  Future<List<GeofenceZone>> loadZones(String orgId) async {
    try {
      final data = await _client
          .from('branches')
          .select('id, name, location_lat, location_lng')
          .eq('org_id', orgId)
          .not('location_lat', 'is', null)
          .not('location_lng', 'is', null);

      final rows = normalizeRows(data);
      return rows.map<GeofenceZone>((row) {
        return GeofenceZone(
          id: row['id'] as String,
          name: row['name'] as String? ?? 'Unknown',
          centerLat: (row['location_lat'] as num).toDouble(),
          centerLng: (row['location_lng'] as num).toDouble(),
          radiusMeters: 500, // Default 500m radius
        );
      }).toList();
    } catch (e) {
      debugPrint('[Geofence] Error loading zones: $e');
      return [];
    }
  }

  /// Check which zone(s) a position falls inside.
  List<GeofenceZone> findContainingZones(
      double lat, double lng, List<GeofenceZone> zones) {
    return zones.where((zone) => zone.contains(lat, lng)).toList();
  }

  /// Find the nearest zone to a position.
  GeofenceZone? findNearestZone(
      double lat, double lng, List<GeofenceZone> zones) {
    if (zones.isEmpty) return null;

    GeofenceZone? nearest;
    double minDistance = double.infinity;

    for (final zone in zones) {
      final distance = GeofenceUtils.haversineDistance(
        lat,
        lng,
        zone.centerLat,
        zone.centerLng,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = zone;
      }
    }

    return nearest;
  }

  /// Detect geofence entry/exit events by comparing previous and current positions.
  List<GeofenceEvent> detectEvents(
    double prevLat,
    double prevLng,
    double currLat,
    double currLng,
    List<GeofenceZone> zones,
  ) {
    final events = <GeofenceEvent>[];
    final now = DateTime.now();

    final prevZones = findContainingZones(prevLat, prevLng, zones);
    final currZones = findContainingZones(currLat, currLng, zones);

    final prevIds = prevZones.map((z) => z.id).toSet();
    final currIds = currZones.map((z) => z.id).toSet();

    // Detect exits: was in zone before, not anymore
    for (final zone in prevZones) {
      if (!currIds.contains(zone.id)) {
        events.add(GeofenceEvent(
          zoneId: zone.id,
          zoneName: zone.name,
          type: 'exit',
          timestamp: now,
          latitude: currLat,
          longitude: currLng,
        ));
      }
    }

    // Detect entries: was not in zone before, now is
    for (final zone in currZones) {
      if (!prevIds.contains(zone.id)) {
        events.add(GeofenceEvent(
          zoneId: zone.id,
          zoneName: zone.name,
          type: 'enter',
          timestamp: now,
          latitude: currLat,
          longitude: currLng,
        ));
      }
    }

    return events;
  }
}
