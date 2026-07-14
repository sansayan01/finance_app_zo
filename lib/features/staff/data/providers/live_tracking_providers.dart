import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/services/live_location_service.dart';
import '../repositories/live_tracking_repository.dart';
import '../providers/staff_providers.dart';
import 'sync_providers.dart';

// ─── Repository Provider ──────────────────────────────────────────────────────

final liveTrackingRepositoryProvider =
    Provider<LiveTrackingRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return LiveTrackingRepository(ref.watch(supabaseClientProvider), orgId);
});

// ─── Live Location Service (for staff agents) ─────────────────────────────────

final liveLocationServiceProvider =
    Provider<LiveLocationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final offlineEngine = ref.watch(syncEngineProvider);
  final service = LiveLocationService(client, offlineEngine: offlineEngine);
  ref.onDispose(() => service.dispose());
  return service;
});

// ─── Is Tracking Notifier ─────────────────────────────────────────────────────

class IsTrackingNotifier extends StateNotifier<bool> {
  IsTrackingNotifier() : super(false);

  void setTracking(bool value) => state = value;
}

final isTrackingProvider =
    StateNotifierProvider<IsTrackingNotifier, bool>((ref) {
  return IsTrackingNotifier();
});

// ─── Start/Stop Tracking Action ───────────────────────────────────────────────

final startTrackingProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(liveLocationServiceProvider);
    final profile = await ref.read(staffProfileProvider.future);
    if (profile == null) return;

    final orgId = ref.read(currentOrgIdOrThrowProvider);
    await service.startTracking(staffId: profile.id, orgId: orgId);
    ref.read(isTrackingProvider.notifier).setTracking(true);
  };
});

final stopTrackingProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final service = ref.read(liveLocationServiceProvider);
    await service.stopTracking();
    ref.read(isTrackingProvider.notifier).setTracking(false);
  };
});

// ─── Latest Agent Locations (for manager/admin map view) ─────────────────────

final latestAgentLocationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(liveTrackingRepositoryProvider);
  return repo.getLatestAgentLocations();
});

// ─── Live Tracking State (updated via Realtime) ───────────────────────────────

class LiveAgentLocationsNotifier
    extends StateNotifier<Map<String, Map<String, dynamic>>> {
  LiveAgentLocationsNotifier() : super({});

  RealtimeChannel? _channel;

  /// Render state per agent: keeps the last rendered position ('prev') and the
  /// freshly received GPS fix ('target'), each tagged with a timestamp (`_ts`).
  /// This lets the page interpolate smoothly between fixes.
  final Map<String, Map<String, dynamic>> _renderState = {};

  /// Get previous position for an agent (used for animation).
  /// Kept for backward compatibility — returns the 'prev' render state.
  Map<String, dynamic>? getPreviousPosition(String staffId) {
    final prev = _renderState[staffId]?['prev'];
    return prev is Map ? Map<String, dynamic>.from(prev) : null;
  }

  /// Timestamp (ms) of the previous target fix, used to derive the animation
  /// duration so movement matches the real elapsed time between GPS fixes.
  int? getPreviousTargetTs(String staffId) {
    final target = _renderState[staffId]?['target'];
    final map = target is Map ? Map<String, dynamic>.from(target) : null;
    return map?['_ts'] as int?;
  }

  void seedFromSnapshot(List<Map<String, dynamic>> locations) {
    final map = <String, Map<String, dynamic>>{};
    for (final loc in locations) {
      final staffId = loc['staff_id'] as String?;
      if (staffId != null) map[staffId] = loc;
    }
    state = map;
    // Reset render state so the first realtime fix starts a fresh glide.
    _renderState.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in map.entries) {
      final pos = Map<String, dynamic>.from(entry.value);
      pos['_ts'] = now;
      _renderState[entry.key] = <String, dynamic>{'prev': Map<String, dynamic>.from(pos), 'target': pos};
    }
  }

  void applyRealtimeUpdate(Map<String, dynamic> payload) {
    final staffId = payload['staff_id'] as String?;
    if (staffId == null) return;

    // Merge new location into existing agent data (keep name/phone from snapshot)
    final existing = state[staffId];
    final existingData = existing ?? {};
    final merged = <String, dynamic>{
      ...existingData,
      'latitude': payload['latitude'],
      'longitude': payload['longitude'],
      'speed': payload['speed'],
      'heading': payload['heading'],
      'activity_type': payload['activity_type'],
      'battery_level': payload['battery_level'],
      'is_charging': payload['is_charging'],
      'is_active': payload['is_active'],
      'recorded_at': payload['recorded_at'],
      'accuracy': payload['accuracy'],
    };

    // Build the new target fix with a timestamp.
    final target = Map<String, dynamic>.from(merged);
    target['_ts'] = DateTime.now().millisecondsSinceEpoch;

    // The current rendered position becomes the new 'prev'. Fall back to the
    // previous target if we have no render state yet (e.g. first fix).
    final render = _renderState[staffId];
    final prev = (render != null
        ? Map<String, dynamic>.from(render['target'] is Map ? render['target'] as Map : {})
        : Map<String, dynamic>.from(merged))
      ..['_ts'] = ((render?['target'] is Map ? Map<String, dynamic>.from(render!['target'] as Map) : null)?['_ts'] as int?) ??
          target['_ts'];

    _renderState[staffId] = <String, dynamic>{'prev': prev, 'target': target};
    state = {...state, staffId: merged};
  }

  /// Compute elapsed-time-based animation duration (ms) between the previous
  /// target fix and a new target fix. Clamped so movement always glides
  /// (400–1500ms) regardless of GPS report cadence.
  int getDurationForFix(String staffId) {
    final render = _renderState[staffId];
    if (render == null) return 1000;
    final prevTs =
        (render['prev'] is Map ? (render['prev'] as Map)['_ts'] : null) as int? ?? 0;
    final targetTs =
        (render['target'] is Map ? (render['target'] as Map)['_ts'] : null) as int? ?? 0;
    final delta = targetTs - prevTs;
    if (delta <= 0) return 1000;
    return delta.clamp(400, 1500);
  }

  /// Returns an interpolated render position for [staffId] at fraction [t]
  /// (0..1) between the previous and target fixes. Latitude/longitude are
  /// linearly interpolated; heading is interpolated with 359°→0° wraparound.
  ///
  /// Returns `{lat, lng, heading}`. When no render state exists the merged
  /// agent record is used directly (no movement needed).
  Map<String, double> getInterpolatedPosition(
      String staffId, double t, Map<String, dynamic> fallback) {
    final render = _renderState[staffId];
    if (render == null) {
      return {
        'lat': _toDouble(fallback['latitude']),
        'lng': _toDouble(fallback['longitude']),
        'heading': _toDouble(fallback['heading']),
      };
    }

    final prev = render['prev'] is Map ? Map<String, dynamic>.from(render['prev'] as Map) : <String, dynamic>{};
    final target = render['target'] is Map ? Map<String, dynamic>.from(render['target'] as Map) : <String, dynamic>{};

    final prevLat = _toDouble(prev['latitude']);
    final prevLng = _toDouble(prev['longitude']);
    final targetLat = _toDouble(target['latitude']);
    final targetLng = _toDouble(target['longitude']);

    final lat = prevLat + (targetLat - prevLat) * t;
    final lng = prevLng + (targetLng - prevLng) * t;

    // Effective heading per fix: use the device-reported heading when it is
    // available (>0), otherwise derive the travel direction from the movement
    // vector (atan2(dLng, dLat), 0° = North, clockwise).
    final prevHeading = _effectiveHeading(staffId, prev, prevLng, prevLat);
    final targetHeading =
        _effectiveHeading(staffId, target, targetLng, targetLat);

    // Heading interpolation with shortest-path wraparound.
    final heading = _lerpAngle(prevHeading, targetHeading, t);

    return {'lat': lat, 'lng': lng, 'heading': heading};
  }

  double _toDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;

  /// Effective heading (degrees, 0 = North, clockwise) for a fix. Uses the
  /// device-reported heading when available, otherwise the bearing from the
  /// previous rendered position (`_renderState[staffId]['prev']`) to this fix.
  double _effectiveHeading(String staffId,
      Map<String, dynamic> fix, double lng, double lat) {
    final deviceHeading = _toDouble(fix['heading']);
    if (deviceHeading > 0) return deviceHeading;
    final rawPrev = _renderState[staffId]?['prev'];
    final prev = rawPrev is Map ? Map<String, dynamic>.from(rawPrev) : null;
    final prevLng = prev != null ? _toDouble(prev['longitude']) : 0.0;
    final prevLat = prev != null ? _toDouble(prev['latitude']) : 0.0;
    final dLat = lat - prevLat;
    final dLng = lng - prevLng;
    if (dLat == 0 && dLng == 0) return deviceHeading;
    return (math.atan2(dLng, dLat) * 180 / math.pi) % 360;
  }

  /// Linearly interpolate two angles in degrees along the shortest arc,
  /// handling the 359°→0° (and 0°→359°) wrap.
  double _lerpAngle(double from, double to, double t) {
    double diff = (to - from) % 360;
    if (diff < -180) diff += 360;
    if (diff > 180) diff -= 360;
    return (from + diff * t) % 360;
  }


  void setChannel(RealtimeChannel? channel) {
    _channel = channel;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final liveAgentLocationsProvider = StateNotifierProvider<
    LiveAgentLocationsNotifier, Map<String, Map<String, dynamic>>>((ref) {
  return LiveAgentLocationsNotifier();
});

// ─── Breadcrumb Trail Provider ────────────────────────────────────────────────

final agentBreadcrumbsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, staffId) async {
  final repo = ref.watch(liveTrackingRepositoryProvider);
  return repo.getTodayBreadcrumbs(staffId);
});

// ─── Agent Daily Stats Provider ───────────────────────────────────────────────

final agentDailyStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, staffProfileId) async {
  final repo = ref.watch(liveTrackingRepositoryProvider);
  return repo.getAgentDailyStats(staffProfileId);
});

// ─── On-Duty Agents Provider ──────────────────────────────────────────────────

final onDutyAgentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(liveTrackingRepositoryProvider);
  return repo.getOnDutyAgents();
});
