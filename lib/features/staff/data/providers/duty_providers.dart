import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/duty_repository.dart';
import '../providers/staff_providers.dart';
import '../providers/live_tracking_providers.dart';
import '../services/geofence_service.dart';

// ─── Repository Provider ──────────────────────────────────────────────────────

final dutyRepositoryProvider = Provider<DutyRepository>((ref) {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return DutyRepository(ref.watch(supabaseClientProvider), orgId);
});

// ─── On Duty State ────────────────────────────────────────────────────────────

class OnDutyNotifier extends StateNotifier<AsyncValue<bool>> {
  final Ref _ref;

  OnDutyNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    try {
      final profile = await _ref.read(staffProfileProvider.future)
          .timeout(const Duration(seconds: 10));
      if (profile == null) {
        state = const AsyncValue.data(false);
        return;
      }
      final repo = _ref.read(dutyRepositoryProvider);
      final isOnDuty = await repo.isOnDuty(profile.id)
          .timeout(const Duration(seconds: 10));
      state = AsyncValue.data(isOnDuty);
    } catch (e) {
      debugPrint('[Duty] _loadInitialState error: $e');
      // On any error, default to off-duty so the UI is usable
      state = const AsyncValue.data(false);
    }
  }

  Future<void> toggleDuty() async {
    final currentState = state.valueOrNull ?? false;
    state = const AsyncValue.loading();

    try {
      final profile = await _ref.read(staffProfileProvider.future);
      if (profile == null) {
        state = const AsyncValue.data(false);
        return;
      }

      final repo = _ref.read(dutyRepositoryProvider);

      // Try to get current position for duty start/end location
      // Use a hard timeout so GPS issues never block the toggle
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 3),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Position is optional, continue without it
      }

      // Geofence check (non-blocking — warn but allow)
      if (position != null) {
        try {
          final zones = _ref.read(geofenceZonesProvider).valueOrNull ?? [];
          final geofenceService = _ref.read(geofenceServiceProvider);
          final containing = geofenceService.findContainingZones(
            position.latitude, position.longitude, zones,
          );
          if (containing.isEmpty && zones.isNotEmpty) {
            debugPrint('[Duty] Warning: Agent is outside all geofence zones');
          }
        } catch (_) {
          // Geofence check is non-critical
        }
      }

      if (!currentState) {
        // Going ON duty
        await repo.startDuty(
          staffId: profile.id,
          branchId: profile.branchId,
          lat: position?.latitude,
          lng: position?.longitude,
        );

        // Start location tracking (non-blocking — don't let tracking failure block duty)
        try {
          final startTracking = _ref.read(startTrackingProvider);
          await startTracking().timeout(const Duration(seconds: 5));
        } catch (_) {
          debugPrint('[Duty] Warning: Location tracking start failed');
        }

        state = const AsyncValue.data(true);
      } else {
        // Going OFF duty
        await repo.endDuty(
          staffId: profile.id,
          lat: position?.latitude,
          lng: position?.longitude,
        );

        // Stop location tracking (non-blocking)
        try {
          final stopTracking = _ref.read(stopTrackingProvider);
          await stopTracking().timeout(const Duration(seconds: 5));
        } catch (_) {
          debugPrint('[Duty] Warning: Location tracking stop failed');
        }

        state = const AsyncValue.data(false);
      }

      // Refresh duty minutes
      _ref.invalidate(todayDutyMinutesProvider);
      _ref.invalidate(activeDutySessionProvider);
    } catch (e, st) {
      // Revert to previous state on error
      state = AsyncValue.data(currentState);
      // Re-throw for UI to handle
      state = AsyncValue.error(e, st);
    }
  }

  /// Force refresh from server
  Future<void> refresh() async {
    await _loadInitialState();
  }
}

final onDutyProvider =
    StateNotifierProvider<OnDutyNotifier, AsyncValue<bool>>((ref) {
  return OnDutyNotifier(ref);
});

// ─── Active Duty Session ──────────────────────────────────────────────────────

final activeDutySessionProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return null;
  final repo = ref.watch(dutyRepositoryProvider);
  return repo.getActiveDutySession(profile.id);
});

// ─── Today's Duty Minutes ─────────────────────────────────────────────────────

final todayDutyMinutesProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return 0;
  final repo = ref.watch(dutyRepositoryProvider);
  return repo.getTodayDutyMinutes(profile.id);
});

// ─── Today's Duty Sessions List ───────────────────────────────────────────────

final todayDutySessionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null) return [];
  final repo = ref.watch(dutyRepositoryProvider);
  return repo.getTodayDutySessions(profile.id);
});

// ─── Geofence Providers ────────────────────────────────────────────────────

final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  final client = Supabase.instance.client;
  return GeofenceService(client);
});

final geofenceZonesProvider = FutureProvider<List<GeofenceZone>>((ref) async {
  final service = ref.watch(geofenceServiceProvider);
  final profile = await ref.watch(staffProfileProvider.future);
  if (profile == null || profile.orgId == null) return [];
  return service.loadZones(profile.orgId!);
});

final geofenceEventsProvider = StateProvider<List<GeofenceEvent>>((ref) => []);
