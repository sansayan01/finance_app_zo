import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unknown,
}

/// Single source of truth for all location permission logic.
/// Replaces the 5 duplicated permission-check implementations across the codebase.
class LocationPermissionHelper {
  /// Check permission status without prompting the user.
  static Future<LocationPermissionStatus> checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      default:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Ensure foreground location permission is granted.
  /// Returns true if permission is available (prompts if needed).
  static Future<bool> ensureForegroundPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationPerm] Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationPerm] Location permissions denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationPerm] Location permissions permanently denied.');
      return false;
    }

    return true;
  }

  /// Check if background permission should be requested.
  /// Only call AFTER foreground permission is granted.
  /// Returns true if the current permission is 'always' (background-capable).
  static Future<bool> hasBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  /// Request background location permission.
  /// Should only be called AFTER foreground permission is granted.
  /// On Android 12+, this opens system settings for background location.
  static Future<bool> ensureBackgroundPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return false;
    }

    if (permission == LocationPermission.always) return true;

    // Request "always" permission — on Android 12+ this requires
    // ACCESS_BACKGROUND_LOCATION to be declared in manifest
    final result = await Geolocator.requestPermission();
    return result == LocationPermission.always;
  }
}
