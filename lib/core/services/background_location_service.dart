import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_permission_helper.dart';

/// Manages background location tracking using Geolocator.
///
/// On Android, the ACCESS_BACKGROUND_LOCATION permission (declared in manifest)
/// allows the timer to continue running when the app is backgrounded.
/// On iOS, UIBackgroundModes=location (declared in Info.plist) does the same.
///
/// This service manages the permission flow and provides a stream of
/// location updates that survives background transitions.
class BackgroundLocationService {
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  final _locationController = StreamController<Position>.broadcast();

  /// Stream of location updates.
  Stream<Position> get onLocation => _locationController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Request background location permission.
  /// Must be called AFTER foreground permission is granted.
  /// Returns true if background permission was granted.
  static Future<bool> requestBackgroundPermission() async {
    return LocationPermissionHelper.ensureBackgroundPermission();
  }

  /// Start background location tracking.
  ///
  /// [intervalSeconds] — seconds between location fixes. Default 20.
  /// [distanceFilter] — minimum meters between updates for the stream. Default 0 (every update).
  Future<void> start({
    int intervalSeconds = 20,
    int distanceFilter = 0,
  }) async {
    if (_isRunning) return;

    // Ensure we have at least foreground permission
    final hasPermission = await LocationPermissionHelper.ensureForegroundPermission();
    if (!hasPermission) {
      debugPrint('[BackgroundLocation] No location permission.');
      return;
    }

    // Try to upgrade to background permission (non-blocking)
    // On Android 12+, this opens system settings
    final hasBackground = await LocationPermissionHelper.hasBackgroundPermission();
    if (!hasBackground) {
      debugPrint('[BackgroundLocation] Background permission not granted. '
          'Tracking may stop when app is backgrounded.');
      // Continue anyway — foreground permission is sufficient for most use cases
    }

    _isRunning = true;

    // Start timer-based tracking (works in background with proper permissions)
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      await _uploadLocation();
    });

    // Also start a position stream for more efficient updates when moving
    if (distanceFilter > 0) {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilter,
        ),
      ).listen((position) {
        _locationController.add(position);
      });
    }

    debugPrint('[BackgroundLocation] Started (interval: ${intervalSeconds}s, '
        'background: $hasBackground)');
  }

  /// Upload current location and push to stream.
  Future<void> _uploadLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _locationController.add(position);
    } on LocationServiceDisabledException {
      debugPrint('[BackgroundLocation] Location service disabled.');
    } on TimeoutException {
      debugPrint('[BackgroundLocation] Location timeout.');
    } catch (e) {
      debugPrint('[BackgroundLocation] Error getting position: $e');
    }
  }

  /// Stop background tracking.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _isRunning = false;
    debugPrint('[BackgroundLocation] Stopped');
  }

  /// Check if background permission is currently granted.
  Future<bool> hasBackgroundPermission() async {
    return LocationPermissionHelper.hasBackgroundPermission();
  }

  /// Clean up all resources.
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _locationController.close();
  }
}
