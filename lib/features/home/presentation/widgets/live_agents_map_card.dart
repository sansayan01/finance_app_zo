import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../staff/data/providers/live_tracking_providers.dart';

/// Compact live agents map shown on the executive admin dashboard.
/// Tap the card to open the full-screen [ManagerLiveMapPage] at /live-map.
class LiveAgentsMapCard extends ConsumerStatefulWidget {
  const LiveAgentsMapCard({super.key});

  @override
  ConsumerState<LiveAgentsMapCard> createState() => _LiveAgentsMapCardState();
}

class _LiveAgentsMapCardState extends ConsumerState<LiveAgentsMapCard>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  Timer? _ageOutTimer;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    final repo = ref.read(liveTrackingRepositoryProvider);
    _channel = repo.subscribeToAgentLocations(
      onUpdate: (payload) {
        if (!mounted) return;
        ref
            .read(liveAgentLocationsProvider.notifier)
            .applyRealtimeUpdate(payload);
      },
      onDeactivate: (record) {
        if (!mounted) return;
        final agentId = record['staff_id']?.toString();
        if (agentId != null) {
          ref.read(liveAgentLocationsProvider.notifier).applyRealtimeUpdate({
            ...record,
            'is_active': false,
          });
        }
      },
    );
  }

  Future<void> _init() async {
    if (!mounted) return;
    final repo = ref.read(liveTrackingRepositoryProvider);
    final snapshot = await repo.getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(snapshot);

    _subscribeRealtime();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      final fresh = await repo.getLatestAgentLocations();
      if (!mounted) return;
      ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(fresh);
    });

    _ageOutTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {}); // Dynamic age-out local rebuild trigger
      }
    });

    if (_mapReady) _fitToAgents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    debugPrint('[LiveMapCard] App resumed. Refreshing locations snapshot...');
    if (!mounted) return;
    final repo = ref.read(liveTrackingRepositoryProvider);
    final fresh = await repo.getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(fresh);

    _subscribeRealtime();

    if (_mapReady) _fitToAgents();
  }

  bool _isAgentOffline(Map<String, dynamic> agent) {
    final isActive = agent['is_active'] == true;
    if (!isActive) return true;
    final recordedAtStr = agent['recorded_at'] as String?;
    if (recordedAtStr == null) return true;
    final recordedAt = DateTime.tryParse(recordedAtStr);
    if (recordedAt == null) return true;
    final diff = DateTime.now().difference(recordedAt);
    return diff.inMinutes >= 15;
  }

  void _fitToAgents() {
    if (!_mapReady) return;
    final agents = ref.read(liveAgentLocationsProvider).values.where((a) {
      return a['latitude'] != null && a['longitude'] != null;
    }).toList();
    if (agents.isEmpty) return;

    if (agents.length == 1) {
      final a = agents.first;
      _mapController.move(
        LatLng((a['latitude'] as num).toDouble(),
            (a['longitude'] as num).toDouble()),
        13,
      );
      return;
    }

    final lats = agents.map((a) => (a['latitude'] as num).toDouble()).toList();
    final lngs = agents.map((a) => (a['longitude'] as num).toDouble()).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _ageOutTimer?.cancel();
    _channel?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final agents = ref.watch(liveAgentLocationsProvider).values.toList();
    final active = agents.where((a) => !_isAgentOffline(a)).length;

    final markers = agents
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .map((a) => _marker(a))
        .toList();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/live-map');
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(20.5937, 78.9629),
                  initialZoom: 5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    _fitToAgents();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.microflow.pro',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Title + active count overlay
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white)
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE AGENTS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$active active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Empty hint
              if (agents.isEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No agents reporting location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),

              // Tap hint
              Positioned(
                bottom: 10,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white)
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View full map',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(Map<String, dynamic> agent) {
    final lat = (agent['latitude'] as num).toDouble();
    final lng = (agent['longitude'] as num).toDouble();
    final name = (agent['full_name'] as String?) ?? 'A';
    final isOffline = _isAgentOffline(agent);
    final color = !isOffline ? AppColors.success : Colors.grey;

    return Marker(
      point: LatLng(lat, lng),
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
