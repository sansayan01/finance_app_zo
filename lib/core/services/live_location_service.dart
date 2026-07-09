import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_permission_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../features/staff/data/models/staff_location_model.dart' as staff_model;
import '../../features/staff/data/services/offline_sync_engine.dart';

/// Handles battery-optimized GPS uploads for field agents.
/// Uses distance-based streaming (50m filter) + adaptive heartbeat.
class LiveLocationService {
  final SupabaseClient _client;
  final OfflineSyncEngine? _offlineEngine;

  LiveLocationService(this._client, {OfflineSyncEngine? offlineEngine})
      : _offlineEngine = offlineEngine;

  final Battery _battery = Battery();

  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<dynamic>? _connectivitySub;
  bool _isTracking = false;
  String? _currentStaffId;
  String? _currentOrgId;
  String _sessionId = const Uuid().v4();
  int _pendingUploadCount = 0;

  bool get isTracking => _isTracking;
  int get pendingUploadCount => _pendingUploadCount;

  // ─── Start Tracking ─────────────────────────────────────────────────────────

  Future<void> startTracking({
    required String staffId,
    required String orgId,
    int intervalSeconds = 20,
  }) async {
    if (_isTracking) return;

    final hasPermission =
        await LocationPermissionHelper.ensureForegroundPermission();
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

    // Stream-based tracking: only emit when device moves 50m
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // meters — only emit when device moves 50m
      ),
    ).listen(
      (position) => _uploadCurrentLocation(),
      onError: (e) => debugPrint('[LiveLocation] Position stream error: $e'),
    );

    // Adaptive heartbeat: upload every 5 min even when stationary
    _startHeartbeat();

    // Start connectivity listener for offline sync
    _startConnectivityListener();
  }

  // ─── Adaptive Heartbeat ────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _uploadCurrentLocation(); // Heartbeat even when stationary
    });
  }

  // ─── Stop Tracking ───────────────────────────────────────────────────────────

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;

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
    _pendingUploadCount = 0;
    debugPrint('[LiveLocation] Stopped tracking.');
  }

  // ─── Connectivity Listener (auto-sync when back online) ─────────────────────

  void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && _offlineEngine != null && _pendingUploadCount > 0) {
        debugPrint('[LiveLocation] Back online. Syncing $_pendingUploadCount pending locations...');
        final result = await _offlineEngine.syncAll();
        _pendingUploadCount = 0;
        debugPrint('[LiveLocation] Sync complete: ${result.success} succeeded, ${result.failed} failed');
      }
    });
  }

  // ─── Upload ──────────────────────────────────────────────────────────────────

  Future<void> _uploadCurrentLocation() async {
    if (_currentStaffId == null || _currentOrgId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      // Battery (best-effort; failure shouldn't block location upload)
      int? batteryLevel;
      bool isCharging = false;
      try {
        batteryLevel = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        isCharging = state == BatteryState.charging ||
            state == BatteryState.full;
      } catch (e) {
        debugPrint('[LiveLocation] Battery read failed: $e');
      }

      final model = _buildLocationModel(
        position,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
      );
      final insertData = model.toSupabaseInsert();
      // Session-specific fields are ensured by the model,
      // but force them here for safety.
      insertData['is_active'] = true;
      insertData['session_id'] = _sessionId;

      await _client.from('staff_locations').insert(insertData);

      debugPrint(
          '[LiveLocation] Uploaded: ${position.latitude}, ${position.longitude} [${model.activityType.name}]');
    } on LocationServiceDisabledException {
      debugPrint('[LiveLocation] Location service disabled.');
    } on TimeoutException {
      debugPrint('[LiveLocation] Location timeout.');
    } catch (e) {
      // Queue for retry if it's a network error and offline engine is available
      if (_isNetworkError(e) && _offlineEngine != null) {
        await _queueLocationForRetry();
      } else {
        debugPrint('[LiveLocation] Upload error: $e');
      }
    }
  }

  /// Queue a failed upload for later retry via OfflineSyncEngine.
  /// Re-fetches current position to capture the most recent fix.
  Future<void> _queueLocationForRetry() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      int? batteryLevel;
      bool isCharging = false;
      try {
        batteryLevel = await _battery.batteryLevel;
        final state = await _battery.batteryState;
        isCharging = state == BatteryState.charging ||
            state == BatteryState.full;
      } catch (_) {}

      final model = _buildLocationModel(
        position,
        batteryLevel: batteryLevel,
        isCharging: isCharging,
      );
      final insertData = model.toSupabaseInsert();
      insertData['is_active'] = true;
      insertData['session_id'] = _sessionId;

      await _offlineEngine!.queueOperation(
        operation: 'insert',
        table: 'staff_locations',
        data: insertData,
      );
      _pendingUploadCount++;
      debugPrint('[LiveLocation] Queued offline. Pending: $_pendingUploadCount');
    } catch (e) {
      debugPrint('[LiveLocation] Failed to queue location for retry: $e');
    }
  }

  bool _isNetworkError(dynamic error) {
    return error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException') ||
        error.toString().contains('ClientException') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Network is unreachable');
  }

  staff_model.StaffLocationModel _buildLocationModel(
    Position position, {
    required int? batteryLevel,
    required bool isCharging,
  }) {
    return staff_model.StaffLocationModel(
      id: '', // Generated by DB
      staffId: _currentStaffId!,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      activityType: _detectActivityType(position.speed),
      createdAt: DateTime.now(),
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      recordedAt: DateTime.now(),
      orgId: _currentOrgId,
      sessionId: _sessionId,
      isActive: true,
    );
  }

  staff_model.ActivityType _detectActivityType(double? speedMs) {
    if (speedMs == null || speedMs < 0) return staff_model.ActivityType.idle;
    if (speedMs < 0.5) return staff_model.ActivityType.idle; // Standing still
    if (speedMs < 1.5) return staff_model.ActivityType.collecting; // Walking slowly (visiting)
    if (speedMs < 15) return staff_model.ActivityType.traveling; // Moving on vehicle
    return staff_model.ActivityType.traveling;
  }

  void dispose() {
    stopTracking();
  }
}
