import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/services/live_location_service.dart';
import '../repositories/live_tracking_repository.dart';
import '../providers/staff_providers.dart';

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
  final service = LiveLocationService(client);
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

  /// Stores previous positions for smooth interpolation
  final Map<String, Map<String, dynamic>> _previousPositions = {};

  /// Get previous position for an agent (used for animation)
  Map<String, dynamic>? getPreviousPosition(String staffId) =>
      _previousPositions[staffId];

  void seedFromSnapshot(List<Map<String, dynamic>> locations) {
    final map = <String, Map<String, dynamic>>{};
    for (final loc in locations) {
      final staffId = loc['staff_id'] as String?;
      if (staffId != null) map[staffId] = loc;
    }
    state = map;
  }

  void applyRealtimeUpdate(Map<String, dynamic> payload) {
    final staffId = payload['staff_id'] as String?;
    if (staffId == null) return;

    // Store previous position for smooth animation
    final existing = state[staffId];
    if (existing != null) {
      _previousPositions[staffId] = Map.from(existing);
    }

    // Merge new location into existing agent data (keep name/phone from snapshot)
    final existingData = existing ?? {};
    state = {
      ...state,
      staffId: {
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
      },
    };
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
