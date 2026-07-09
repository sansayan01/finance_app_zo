import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Polyline utilities for route simplification and rendering.
class PolylineUtils {
  static const double _earthRadiusMeters = 6371000;

  /// Simplify a polyline using the Douglas-Peucker algorithm.
  /// [toleranceMeters] — max allowed deviation from the original line.
  /// Keeps start and end points always.
  static List<LatLng> simplify(List<LatLng> points, double toleranceMeters) {
    if (points.length <= 2) return List.from(points);

    // Find the point with maximum distance from the line between first and last
    double maxDistance = 0;
    int maxIndex = 0;
    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > toleranceMeters) {
      final left = simplify(points.sublist(0, maxIndex + 1), toleranceMeters);
      final right = simplify(points.sublist(maxIndex), toleranceMeters);
      // Combine (avoid duplicate point at junction)
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      // All intermediate points are within tolerance — just keep endpoints
      return [first, last];
    }
  }

  /// Perpendicular distance from a point to a line segment (in meters).
  static double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final dx = lineEnd.longitude - lineStart.longitude;
    final dy = lineEnd.latitude - lineStart.latitude;
    final lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return _haversine(point.latitude, point.longitude, lineStart.latitude, lineStart.longitude);
    }

    var t = ((point.longitude - lineStart.longitude) * dx +
            (point.latitude - lineStart.latitude) * dy) /
        lenSq;
    t = max(0.0, min(1.0, t));

    final projLat = lineStart.latitude + t * dy;
    final projLng = lineStart.longitude + t * dx;

    return _haversine(point.latitude, point.longitude, projLat, projLng);
  }

  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Calculate total route distance in meters.
  static double totalDistance(List<LatLng> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversine(
        points[i].latitude, points[i].longitude,
        points[i + 1].latitude, points[i + 1].longitude,
      );
    }
    return total;
  }
}
