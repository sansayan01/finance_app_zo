import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../utils/location_permission_helper.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    final hasPermission =
        await LocationPermissionHelper.ensureForegroundPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
