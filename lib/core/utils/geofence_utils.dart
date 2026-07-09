import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Pure Dart geofencing utilities.
/// No database dependencies — all calculations are in-memory.
class GeofenceUtils {
  static const double _earthRadiusMeters = 6371000;

  /// Calculate haversine distance between two points in meters.
  static double haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Check if a point is inside a circular geofence.
  static bool isInsideCircle(
    double pointLat,
    double pointLng,
    double centerLat,
    double centerLng,
    double radiusMeters,
  ) {
    return haversineDistance(pointLat, pointLng, centerLat, centerLng) <=
        radiusMeters;
  }

  /// Check if a point is inside a polygon using ray-casting algorithm.
  static bool isInsidePolygon(double lat, double lng, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    final point = LatLng(lat, lng);
    final n = polygon.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final vi = polygon[i];
      final vj = polygon[j];

      if (((vi.latitude > point.latitude) !=
              (vj.latitude > point.latitude)) &&
          (point.longitude <
              (vj.longitude - vi.longitude) *
                      (point.latitude - vi.latitude) /
                      (vj.latitude - vi.latitude) +
                  vi.longitude)) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// Calculate distance from point to nearest edge of a polygon in meters.
  /// Returns 0 if the point is inside the polygon.
  static double distanceToPolygonEdge(
      double lat, double lng, List<LatLng> polygon) {
    if (isInsidePolygon(lat, lng, polygon)) return 0;

    double minDistance = double.infinity;
    final point = LatLng(lat, lng);

    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final distance =
          _pointToSegmentDistance(point, polygon[i], polygon[j]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Distance from a point to the nearest point on a line segment.
  static double _pointToSegmentDistance(
      LatLng point, LatLng segStart, LatLng segEnd) {
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      // Segment is a point
      return haversineDistance(point.latitude, point.longitude,
          segStart.latitude, segStart.longitude);
    }

    var t = ((point.longitude - segStart.longitude) * dx +
            (point.latitude - segStart.latitude) * dy) /
        lenSq;
    t = max(0, min(1, t));

    final projLat = segStart.latitude + t * dy;
    final projLng = segStart.longitude + t * dx;

    return haversineDistance(
        point.latitude, point.longitude, projLat, projLng);
  }

  /// Approximate a circle as a polygon with [numVertices] points.
  static List<LatLng> circleToPolygon(
    double centerLat,
    double centerLng,
    double radiusMeters, {
    int numVertices = 36,
  }) {
    final points = <LatLng>[];
    for (int i = 0; i < numVertices; i++) {
      final angle = (2 * pi * i) / numVertices;
      final latOffset =
          (radiusMeters / _earthRadiusMeters) * (180 / pi);
      final lngOffset = latOffset / cos(_toRadians(centerLat));
      points.add(LatLng(
        centerLat + latOffset * cos(angle),
        centerLng + lngOffset * sin(angle),
      ));
    }
    return points;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
