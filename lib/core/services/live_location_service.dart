import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles periodic GPS uploads for field agents.
/// Uploads every [intervalSeconds] seconds while tracking is active.
class LiveLocationService {
  final SupabaseClient _client;

  LiveLocationService(this._client);

  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  bool _isTracking = false;
  String? _currentStaffId;
  String? _currentOrgId;
  String _sessionId = const Uuid().v4();

  bool get isTracking => _isTracking;

  // ─── Start Tracking ─────────────────────────────────────────────────────────

  Future<void> startTracking({
    required String staffId,
    required String orgId,
    int intervalSeconds = 20,
  }) async {
    if (_isTracking) return;

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      debugPrint('[LiveLocation] No location permission.');
      return;
    }

    _currentStaffId = staffId;
    _currentOrgId = orgId;
    _sessionId = const Uuid().v4();
    _isTracking = true;

    debugPrint('[LiveLocation] Started tracking. Session: $_sessionId');

    // Upload immediately on start
    await _uploadCurrentLocation();

    // Then upload on a timer
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      await _uploadCurrentLocation();
    });
  }

  // ─── Stop Tracking ───────────────────────────────────────────────────────────

  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    // Mark last location as inactive
    if (_currentStaffId != null && _currentOrgId != null) {
      try {
        await _client
            .from('staff_locations')
            .update({'is_active': false})
            .eq('staff_id', _currentStaffId!)
            .eq('session_id', _sessionId);
      } catch (e) {
        debugPrint('[LiveLocation] Error marking inactive: $e');
      }
    }

    _isTracking = false;
    _currentStaffId = null;
    _currentOrgId = null;
    debugPrint('[LiveLocation] Stopped tracking.');
  }

  // ─── Upload ──────────────────────────────────────────────────────────────────

  Future<void> _uploadCurrentLocation() async {
    if (_currentStaffId == null || _currentOrgId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      // Determine activity type based on speed
      final String activityType = _detectActivity(position.speed);

      await _client.from('staff_locations').insert({
        'staff_id': _currentStaffId,
        'org_id': _currentOrgId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'activity_type': activityType,
        'is_active': true,
        'session_id': _sessionId,
        'recorded_at': DateTime.now().toIso8601String(),
      });

      debugPrint(
          '[LiveLocation] Uploaded: ${position.latitude}, ${position.longitude} [$activityType]');
    } on LocationServiceDisabledException {
      debugPrint('[LiveLocation] Location service disabled.');
    } on TimeoutException {
      debugPrint('[LiveLocation] Location timeout.');
    } catch (e) {
      debugPrint('[LiveLocation] Upload error: $e');
    }
  }

  String _detectActivity(double? speedMs) {
    if (speedMs == null || speedMs < 0) return 'idle';
    if (speedMs < 0.5) return 'idle'; // Standing still
    if (speedMs < 1.5) return 'collecting'; // Walking slowly (visiting)
    if (speedMs < 15) return 'traveling'; // Moving on vehicle
    return 'traveling';
  }

  // ─── Permissions ─────────────────────────────────────────────────────────────

  Future<bool> _ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  void dispose() {
    stopTracking();
  }
}
