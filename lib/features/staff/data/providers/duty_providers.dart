import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../repositories/duty_repository.dart';
import '../providers/staff_providers.dart';
import '../providers/live_tracking_providers.dart';

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
      final profile = await _ref.read(staffProfileProvider.future);
      if (profile == null) {
        state = const AsyncValue.data(false);
        return;
      }
      final repo = _ref.read(dutyRepositoryProvider);
      final isOnDuty = await repo.isOnDuty(profile.id);
      state = AsyncValue.data(isOnDuty);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        // Position is optional, continue without it
      }

      if (!currentState) {
        // Going ON duty
        await repo.startDuty(
          staffId: profile.id,
          branchId: profile.branchId,
          lat: position?.latitude,
          lng: position?.longitude,
        );

        // Start location tracking
        final startTracking = _ref.read(startTrackingProvider);
        await startTracking();

        state = const AsyncValue.data(true);
      } else {
        // Going OFF duty
        await repo.endDuty(
          staffId: profile.id,
          lat: position?.latitude,
          lng: position?.longitude,
        );

        // Stop location tracking
        final stopTracking = _ref.read(stopTrackingProvider);
        await stopTracking();

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
