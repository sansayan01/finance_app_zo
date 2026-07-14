import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:microflow_pro/core/config/env_config.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/features/staff/data/providers/live_tracking_providers.dart';
import 'package:microflow_pro/features/staff/data/services/geofence_service.dart';
import 'package:microflow_pro/core/utils/geofence_utils.dart';
import 'package:microflow_pro/features/branches/data/providers/branch_providers.dart';
import 'package:microflow_pro/features/staff/data/providers/duty_providers.dart';
import 'package:microflow_pro/core/providers/org_provider.dart';
import 'package:microflow_pro/features/branch_manager/presentation/widgets/location_history_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Map Style Definitions ──────────────────────────────────────────────────

enum _MapStyle {
  navNight('Nav Night', 'navigation-night-v1', Icons.nightlight_outlined),
  dark('Dark', 'dark-v11', Icons.dark_mode_outlined),
  streets('Streets', 'streets-v12', Icons.map_outlined),
  satellite('Satellite', 'satellite-streets-v12', Icons.satellite_alt_outlined);

  const _MapStyle(this.label, this.styleId, this.icon);
  final String label;
  final String styleId;
  final IconData icon;
}

// ─── Freshness Enum ─────────────────────────────────────────────────────────

enum _MarkerFreshness { fresh, recent, stale, offline }

// ─── Filter Option ──────────────────────────────────────────────────────────

class _FilterOption {
  final String? key;
  final String label;
  final IconData icon;
  final Color? color;
  const _FilterOption(this.key, this.label, this.icon, this.color);
}

// ─── Ripple Painter ─────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final rippleProgress = ((progress + i * 0.33) % 1.0);
      final radius = rippleProgress * size.width / 2;
      final opacity = (1.0 - rippleProgress).clamp(0.0, 0.6);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - rippleProgress);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── Geofence Zones Provider ───────────────────────────────────────────────

final managerGeofenceZonesProvider = FutureProvider<List<GeofenceZone>>(
    (ref) async {
  final service = ref.watch(geofenceServiceProvider);
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  return service.loadZones(orgId);
});

// ═══════════════════════════════════════════════════════════════════════════════
// ManagerLiveMapPage — Premium Mapbox-powered field agent tracker
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Module-level UI Helpers (shared with _AgentDetailSheet) ──────────

_MarkerFreshness _getMarkerFreshness(DateTime? recordedAt) {
  if (recordedAt == null) return _MarkerFreshness.offline;
  final diff = DateTime.now().difference(recordedAt);
  if (diff.inMinutes < 1) return _MarkerFreshness.fresh;
  if (diff.inMinutes < 5) return _MarkerFreshness.recent;
  return _MarkerFreshness.offline;
}

Color _freshnessColor(_MarkerFreshness freshness) {
  switch (freshness) {
    case _MarkerFreshness.fresh:
      return AppColors.success; // Green <1min
    case _MarkerFreshness.recent:
      return Colors.amber; // Amber 1-5min
    case _MarkerFreshness.stale:
      return AppColors.error; // Red 5-30min
    case _MarkerFreshness.offline:
      return Colors.grey; // Grey >30min
  }
}

Color _activityColor(String type) {
  switch (type) {
    case 'traveling':
      return AppColors.primary;
    case 'collecting':
      return AppColors.accent;
    case 'resting':
      return AppColors.orange;
    case 'idle':
    default:
      return Colors.grey;
  }
}

String _activityLabel(String type) {
  switch (type) {
    case 'traveling':
      return '🚗 Moving';
    case 'collecting':
      return '💰 Collecting';
    case 'resting':
      return '☕ Break';
    case 'idle':
    default:
      return '⏸ Idle';
  }
}

/// Relative "Updated Xs ago" label for the live detail sheet. Recomputed on
/// every rebuild (the sheet owns a 1s timer) so it ticks live.
String _timeAgoLabel(DateTime? ts) {
  if (ts == null) return 'unknown';
  final diff = DateTime.now().difference(ts);
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  return '${diff.inHours}h ago';
}

Widget _sheetStat(String value, String label, Color color) {
  return Column(
    children: [
      Text(value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1)),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7))),
    ],
  );
}

Widget _sheetButton({
  required IconData icon,
  required String label,
  required Color color,
  required bool isDark,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    ),
  );
}

class ManagerLiveMapPage extends ConsumerStatefulWidget {
  /// Optional branch filter. When set (e.g. via a shared deep link), the map
  /// only shows agents belonging to that branch. When null, all agents show.
  final String? branchId;

  const ManagerLiveMapPage({super.key, this.branchId});

  @override
  ConsumerState<ManagerLiveMapPage> createState() => _ManagerLiveMapPageState();
}

class _ManagerLiveMapPageState extends ConsumerState<ManagerLiveMapPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ─── Controllers ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _radarCtrl;
  late AnimationController _markerMoveCtrl;
  late AnimationController _cameraAnimCtrl;
  late MapController _mapController;
  late TextEditingController _searchCtrl;

  // ─── State ──────────────────────────────────────────────────────────────
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  Timer? _ageOutTimer;
  String? _selectedStaffId;
  bool _showList = true;
  bool _isMapReady = false;
  bool _isFollowing = true;
  bool _showBreadcrumbTrail = false;
  _MapStyle _currentStyle = _MapStyle.streets;
  bool _isLoading = true;
  String? _activityFilter;
  // Branch filter applied via deep-link share. null = show all branches.
  String? _filterBranchId;
  // Cached branch name for the active filter (resolved from branchesProvider).
  String? _filterBranchName;
  String _searchQuery = '';
  LatLng? _flyFrom;
  LatLng? _flyTo;
  double _flyZoomFrom = 5;
  double _flyZoomTarget = 16;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _searchCtrl = TextEditingController();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _markerMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _cameraAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initRealtime();
    WidgetsBinding.instance.addObserver(this);

    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshSnapshot());

    _ageOutTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {}); // Dynamic age-out local rebuild trigger
      }
    });

    _cameraAnimCtrl.addListener(_onCameraAnimate);
    _markerMoveCtrl.addListener(_onMarkerMove);

    // Apply branch filter passed via deep-link (GoRouter query param).
    if (widget.branchId != null && widget.branchId!.isNotEmpty) {
      _filterBranchId = widget.branchId;
      _resolveBranchName(_filterBranchId!);
    }
  }

  /// Resolves a branch_id into its human name (for the filter chip + share
  /// link). The live-location RPC only returns `branch_name`, not `branch_id`,
  /// so we map id→name via the branches list (no backend change required).
  Future<void> _resolveBranchName(String branchId) async {
    try {
      final branches = await ref.read(branchesProvider.future);
      final match = branches.where((b) => b.id == branchId).firstOrNull;
      if (mounted && match != null) {
        setState(() => _filterBranchName = match.name);
      }
    } catch (_) {
      // Non-fatal: we still filter by id; name is only cosmetic.
    }
  }

  // ─── Realtime Init ──────────────────────────────────────────────────────

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    final channel =
        ref.read(liveTrackingRepositoryProvider).subscribeToAgentLocations(
      onUpdate: (payload) {
        if (!mounted) return;
        final notifier =
            ref.read(liveAgentLocationsProvider.notifier);
        final staffId = payload['staff_id'] as String?;
        notifier.applyRealtimeUpdate(payload);
        // Drive a single shared marker-move controller whose duration matches
        // the real elapsed time between GPS fixes (clamped 400–1500ms) so the
        // marker glides continuously instead of teleporting.
        final durMs = staffId != null
            ? notifier.getDurationForFix(staffId)
            : 1000;
        _markerMoveCtrl.duration = Duration(milliseconds: durMs);
        _markerMoveCtrl.forward(from: 0);
        // Auto-follow the selected agent's latest position
        if (mounted && _isMapReady && _isFollowing && _selectedStaffId != null) {
          final agent =
              ref.read(liveAgentLocationsProvider)[_selectedStaffId];
          if (agent != null && agent['latitude'] != null) {
            _mapController.move(
              LatLng(
                (agent['latitude'] as num).toDouble(),
                (agent['longitude'] as num).toDouble(),
              ),
              _mapController.camera.zoom,
            );
          }
        }
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
    ref.read(liveAgentLocationsProvider.notifier).setChannel(channel);
    _channel = channel;
  }

  Future<void> _initRealtime() async {
    final snapshot = await ref
        .read(liveTrackingRepositoryProvider)
        .getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(snapshot);

    setState(() => _isLoading = false);

    if (snapshot.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToAgents());
    }

    _subscribeRealtime();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    debugPrint('[LiveMap] App resumed. Refreshing live map...');
    await _refreshSnapshot();
    _subscribeRealtime();
  }

  Future<void> _refreshSnapshot() async {
    final snapshot = await ref
        .read(liveTrackingRepositoryProvider)
        .getLatestAgentLocations();
    if (!mounted) return;
    ref.read(liveAgentLocationsProvider.notifier).seedFromSnapshot(snapshot);
  }

  // ─── Camera Helpers ─────────────────────────────────────────────────────

  void _fitMapToAgents() {
    if (!_isMapReady) return;
    final agents = ref.read(liveAgentLocationsProvider);
    final active = agents.values
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .where((a) {
          if (_filterBranchId == null) return true;
          final name = a['branch_name'] as String? ?? '';
          return _filterBranchName != null &&
              _filterBranchName!.isNotEmpty &&
              name == _filterBranchName;
        })
        .toList();

    if (active.isEmpty) return;

    if (active.length == 1) {
      final a = active.first;
      _flyCameraTo(
        LatLng((a['latitude'] as num).toDouble(),
            (a['longitude'] as num).toDouble()),
        zoom: 14,
        durationMs: 1000,
      );
      return;
    }

    final lats = active.map((a) => (a['latitude'] as num).toDouble()).toList();
    final lngs = active.map((a) => (a['longitude'] as num).toDouble()).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _flyCameraTo(LatLng dest, {double zoom = 16, int durationMs = 1200}) {
    if (!_isMapReady) return;
    _cameraAnimCtrl.stop();
    _flyFrom = _mapController.camera.center;
    _flyTo = dest;
    _flyZoomFrom = _mapController.camera.zoom;
    _flyZoomTarget = zoom;
    _cameraAnimCtrl.duration = Duration(milliseconds: durationMs);
    _cameraAnimCtrl.forward(from: 0);
  }

  void _onCameraAnimate() {
    if (_flyFrom == null || _flyTo == null) return;
    final t = Curves.easeInOut.transform(_cameraAnimCtrl.value);
    final lat = _flyFrom!.latitude + (_flyTo!.latitude - _flyFrom!.latitude) * t;
    final lng = _flyFrom!.longitude + (_flyTo!.longitude - _flyFrom!.longitude) * t;
    final z = _flyZoomFrom + (_flyZoomTarget - _flyZoomFrom) * t;
    _mapController.move(LatLng(lat, lng), z);
  }

  // Keep the camera locked on the selected agent while the marker animates
  // between positions (only when follow mode is active).
  void _onMarkerMove() {
    if (!mounted || !_isMapReady || !_isFollowing || _selectedStaffId == null) {
      return;
    }
    final agent = ref.read(liveAgentLocationsProvider)[_selectedStaffId];
    if (agent != null && agent['latitude'] != null) {
      _mapController.move(
        LatLng(
          (agent['latitude'] as num).toDouble(),
          (agent['longitude'] as num).toDouble(),
        ),
        _mapController.camera.zoom,
      );
    }
  }

  void _focusAgent(Map<String, dynamic> agent) {
    if (!_isMapReady) return;
    final lat = (agent['latitude'] as num?)?.toDouble();
    final lng = (agent['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    HapticFeedback.mediumImpact();
    _flyCameraTo(LatLng(lat, lng), zoom: 17, durationMs: 1400);
    setState(() {
      _selectedStaffId = agent['staff_id'] as String?;
      _showBreadcrumbTrail = false;
      _isFollowing = true;
    });
    _showAgentDetailSheet(agent);
  }

  void _cycleMapStyle() {
    HapticFeedback.lightImpact();
    setState(() {
      final idx = _MapStyle.values.indexOf(_currentStyle);
      _currentStyle = _MapStyle.values[(idx + 1) % _MapStyle.values.length];
    });
  }

  // Resume follow mode and re-center on the selected agent (or fit all).
  void _recenter() {
    HapticFeedback.mediumImpact();
    setState(() => _isFollowing = true);
    final current = _selectedStaffId != null
        ? ref.read(liveAgentLocationsProvider)[_selectedStaffId]
        : null;
    if (current != null) {
      _focusAgent(current);
    } else {
      _fitMapToAgents();
    }
  }

  void _zoomBy(double delta) {
    if (!_isMapReady) return;
    HapticFeedback.lightImpact();
    _mapController.move(
      _mapController.camera.center,
      (_mapController.camera.zoom + delta).clamp(1.0, 22.0),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _radarCtrl.dispose();
    _markerMoveCtrl.dispose();
    _cameraAnimCtrl.dispose();
    _mapController.dispose();
    _searchCtrl.dispose();
    _refreshTimer?.cancel();
    _ageOutTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final agents = ref.watch(liveAgentLocationsProvider);
    // Filter to a single branch when a deep-link filter is active. The location
    // data carries `branch_name` (not `branch_id`), so compare against the
    // resolved name; fall back to id contains-match if the name is unknown.
    final agentList = agents.values
        .where((a) {
          if (_filterBranchId == null) return true;
          final name = a['branch_name'] as String? ?? '';
          if (_filterBranchName != null && _filterBranchName!.isNotEmpty) {
            return name == _filterBranchName;
          }
          return false;
        })
        .toList();
    final activeCount = agentList.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return a['is_active'] == true &&
          _getMarkerFreshness(recordedAt) != _MarkerFreshness.offline;
    }).length;
    final geofenceZonesAsync = ref.watch(managerGeofenceZonesProvider);
    final geofenceZones = geofenceZonesAsync.valueOrNull ?? [];

    if (_isLoading) {
      return _buildLoadingState(isDark);
    }

    final isWide = MediaQuery.sizeOf(context).width > 900;

    if (isWide) {
      // ── Desktop: left side panel + full-width map ──
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF0F4FF),
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              _buildSidePanel(theme, isDark, agentList, geofenceZones),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _markerMoveCtrl,
                      builder: (_, __) =>
                          _buildMap(isDark, agentList, geofenceZones),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildFrostedHeader(
                          theme, isDark, activeCount, agentList.length),
                    ),
                    Positioned(
                      top: 74,
                      left: 16,
                      right: 16,
                      child: _buildFrostedStatsBar(theme, isDark, agentList),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: _buildPremiumFABs(agentList),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF0F4FF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // ── Full-screen map (rebuilds during marker animation) ──
            AnimatedBuilder(
              animation: _markerMoveCtrl,
              builder: (_, __) => _buildMap(isDark, agentList, geofenceZones),
            ),

            // ── Header overlay ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFrostedHeader(theme, isDark, activeCount, agentList.length),
            ),

            // ── Stats strip overlay ────────────────────────────
            Positioned(
              top: 74,
              left: 16,
              right: 16,
              child: _buildFrostedStatsBar(theme, isDark, agentList),
            ),

            // ── Bottom sheet: agent list ───────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomSheet(theme, isDark, agentList, geofenceZones),
            ),

            // ── Premium FABs ───────────────────────────────────
            Positioned(
              bottom: _showList ? 420 : 24,
              right: 16,
              child: _buildPremiumFABs(agentList),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Premium Loading State ──────────────────────────────────────────────

  Widget _buildLoadingState(bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF0F4FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.satellite_alt_rounded,
                color: Colors.white,
                size: 36,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.05, 1.05), duration: 1200.ms)
                .shimmer(duration: 1800.ms),
            const SizedBox(height: 24),
            Text(
              'Connecting to field agents...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Full-screen Map with Mapbox Tiles ──────────────────────────────────

  Widget _buildMap(bool isDark, List<Map<String, dynamic>> agentList, List<GeofenceZone> geofenceZones) {
    final markers = agentList
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .map((agent) => _buildPremiumMarker(agent))
        .toList();

    // Build speed-colored breadcrumb trail
    final breadcrumbsAsync = (_selectedStaffId != null && _showBreadcrumbTrail)
        ? ref.watch(agentBreadcrumbsProvider(_selectedStaffId!))
        : null;

    final breadcrumbPolylines =
        _buildSpeedColoredTrail(breadcrumbsAsync?.valueOrNull);

    // Determine tile URL — Mapbox raster tiles with style
    String tileUrl;
    if (EnvConfig.mapboxAccessToken.isNotEmpty) {
      tileUrl =
          'https://api.mapbox.com/styles/v1/mapbox/${_currentStyle.styleId}/tiles/{z}/{x}/{y}@2x?access_token=${EnvConfig.mapboxAccessToken}';
    } else {
      // Fallback to Carto
      tileUrl = isDark
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
          : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }

    final useMapbox = EnvConfig.mapboxAccessToken.isNotEmpty;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(20.5937, 78.9629),
        initialZoom: 5,
        onMapReady: () => setState(() {
          _isMapReady = true;
          _fitMapToAgents();
        }),
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && _isFollowing) {
            setState(() => _isFollowing = false);
          }
        },
      ),
      children: [
        // Base tile layer — Mapbox raster or Carto fallback
        TileLayer(
          urlTemplate: tileUrl,
          subdomains: useMapbox ? const [] : const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.microflow.pro',
          tileDimension: useMapbox ? 512 : 256,
          zoomOffset: useMapbox ? -1 : 0,
          maxZoom: 22,
          retinaMode: !useMapbox,
        ),

        // Speed-colored breadcrumb trail segments
        if (breadcrumbPolylines.isNotEmpty)
          PolylineLayer(polylines: breadcrumbPolylines),

        // Geofence zone overlays
        if (geofenceZones.isNotEmpty)
          PolygonLayer(
            polygons: geofenceZones
                .map((zone) => Polygon(
                      points: zone.polygon,
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderColor: Colors.blue.withValues(alpha: 0.3),
                      borderStrokeWidth: 1.5,
                    ))
                .toList(),
          ),

        // Agent markers
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ─── Speed-Colored Breadcrumb Trail (Premium) ─────────────────────────

  List<Polyline> _buildSpeedColoredTrail(
      List<Map<String, dynamic>>? breadcrumbs) {
    if (breadcrumbs == null || breadcrumbs.length < 2) return [];

    final polylines = <Polyline>[];
    var segmentPoints = <LatLng>[];
    String currentActivity =
        breadcrumbs.first['activity_type'] as String? ?? 'idle';

    for (int i = 0; i < breadcrumbs.length; i++) {
      final point = LatLng(
        (breadcrumbs[i]['latitude'] as num).toDouble(),
        (breadcrumbs[i]['longitude'] as num).toDouble(),
      );
      final activity =
          breadcrumbs[i]['activity_type'] as String? ?? 'idle';

      if (activity != currentActivity && segmentPoints.isNotEmpty) {
        segmentPoints.add(point);
        _addTrailSegment(polylines, segmentPoints, currentActivity);
        segmentPoints = [point];
        currentActivity = activity;
      } else {
        segmentPoints.add(point);
      }
    }

    // Final segment
    if (segmentPoints.length > 1) {
      _addTrailSegment(polylines, segmentPoints, currentActivity);
    }

    // Add glow underlay for the last segment (most recent)
    if (segmentPoints.length > 1) {
      final glowColor = _trailColorForActivity(currentActivity);
      polylines.add(Polyline(
        points: segmentPoints,
        strokeWidth: 12,
        color: glowColor.withValues(alpha: 0.08),
      ));
    }

    return polylines;
  }

  void _addTrailSegment(List<Polyline> polylines,
      List<LatLng> points, String activity) {
    final color = _trailColorForActivity(activity);
    // Glow underlay
    polylines.add(Polyline(
      points: List.from(points),
      strokeWidth: 10,
      color: color.withValues(alpha: 0.12),
    ));
    // Main trail
    polylines.add(Polyline(
      points: List.from(points),
      strokeWidth: 4,
      color: color,
      borderColor: color.withValues(alpha: 0.3),
      borderStrokeWidth: 6,
    ));
    // Dashed accent overlay
    polylines.add(Polyline(
      points: List.from(points),
      strokeWidth: 1.5,
      color: Colors.white.withValues(alpha: 0.15),
    ));
  }

  Color _trailColorForActivity(String activity) {
    switch (activity) {
      case 'traveling':
        return AppColors.orange; // Orange for traveling
      case 'collecting':
        return AppColors.success; // Green for collecting/walking
      case 'idle':
      default:
        return AppColors.primary; // Blue for idle/stopped
    }
  }

  // ─── Premium Animated Marker with Ripple ────────────────────────────────

  Marker _buildPremiumMarker(Map<String, dynamic> agent) {
    final targetLat = (agent['latitude'] as num).toDouble();
    final targetLng = (agent['longitude'] as num).toDouble();
    final name = agent['full_name'] as String? ?? 'A';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final isSelected = _selectedStaffId == agent['staff_id'];
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;

    final freshness = _getMarkerFreshness(recordedAt);
    final Color color;
    final bool showPulse;
    if (isActive && freshness != _MarkerFreshness.offline) {
      color = _freshnessColor(freshness);
      showPulse = true;
    } else if (freshness == _MarkerFreshness.offline) {
      color = Colors.grey;
      showPulse = false;
    } else {
      color = _activityColor(activityType);
      showPulse = isActive;
    }

    // Smooth position + heading interpolation, driven per-frame by the shared
    // marker-move controller. The notifier lerps prev→target by `t` and also
    // lerps heading with 359°→0° wraparound handling.
    final staffId = agent['staff_id'] as String?;
    final rawHeading = (agent['heading'] as num?)?.toDouble() ?? 0;
    final t = Curves.easeInOut.transform(_markerMoveCtrl.value);
    final interp = staffId != null
        ? ref
            .read(liveAgentLocationsProvider.notifier)
            .getInterpolatedPosition(staffId, t, agent)
        : {
            'lat': targetLat,
            'lng': targetLng,
            'heading': rawHeading,
          };
    final lat = interp['lat']!;
    final lng = interp['lng']!;
    final heading = interp['heading']!;

    // Accuracy circle radius in px (6px per 50m, capped at 40px). Skipped when
    // accuracy is unknown.
    final accuracyM = (agent['accuracy'] as num?)?.toDouble();
    final accuracyPx =
        accuracyM != null ? (accuracyM / 50 * 6).clamp(0.0, 40.0) : null;

    // Signal-lost badge overlay for offline agents.
    final isOffline = freshness == _MarkerFreshness.offline;

    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 80 : 60,
      height: isSelected ? 90 : 70,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () => _focusAgent(agent),
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseCtrl, _rippleCtrl]),
          builder: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ripple effect container
              SizedBox(
                width: isSelected ? 60 : 48,
                height: isSelected ? 60 : 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Accuracy circle (drawn behind the ripple/marker)
                    if (accuracyPx != null)
                      Container(
                        width: accuracyPx * 2,
                        height: accuracyPx * 2,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                      ),
                    // Ripple rings (only for active, non-offline agents)
                    if (showPulse)
                      CustomPaint(
                        size: Size(isSelected ? 60 : 48, isSelected ? 60 : 48),
                        painter: _RipplePainter(
                          progress: _rippleCtrl.value,
                          color: color,
                        ),
                      ),
                    // Main marker circle with directional indicator
                    Transform.rotate(
                      angle: heading * (math.pi / 180),
                      child: Container(
                        width: isSelected ? 44 : 34,
                        height: isSelected ? 44 : 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.85),
                              color,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: showPulse
                                      ? 0.3 + _pulseCtrl.value * 0.4
                                      : 0.15),
                              blurRadius: isSelected ? 20 : 10,
                              spreadRadius: isSelected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Direction arrow (top of circle)
                            if (isActive && heading > 0)
                              Positioned(
                                top: 2,
                                child: Icon(
                                  Icons.navigation_rounded,
                                  size: isSelected ? 12 : 9,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            // Agent initial
                            Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSelected ? 16 : 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Signal-lost badge (top-right) for offline agents
                    if (isOffline)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: isSelected ? 18 : 14,
                          height: isSelected ? 18 : 14,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 2 : 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSelected ? 11 : 9,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Pin tail
              Container(
                width: 2,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A compact red "Signal lost" pill used in list rows.
  Widget _signalLostBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              size: 11, color: Colors.red),
          const SizedBox(width: 3),
          const Text(
            'Signal lost',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Frosted Glass Header ───────────────────────────────────────────────

  Widget _buildFrostedHeader(
      ThemeData theme, bool isDark, int active, int total) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0A0A0C) : Colors.white)
                .withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Field Agent Tracker',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black87)),
                    Text('$active active · $total agents',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              // Live indicator
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success
                        .withValues(alpha: 0.08 + _pulseCtrl.value * 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.success.withValues(
                                  alpha: 0.5 + _pulseCtrl.value * 0.5),
                              blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                            letterSpacing: 0.5)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _refreshSnapshot();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: AppColors.primary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              // Share / deep-link to the live map (scoped to current branch)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showShareSheet();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: AppColors.accent, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Frosted Glass Stats Bar ────────────────────────────────────────────

  Widget _buildFrostedStatsBar(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> agents) {
    final active = agents.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return a['is_active'] == true &&
          _getMarkerFreshness(recordedAt) != _MarkerFreshness.offline;
    }).length;
    final traveling = agents.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return a['is_active'] == true &&
          _getMarkerFreshness(recordedAt) != _MarkerFreshness.offline &&
          a['activity_type'] == 'traveling';
    }).length;
    final collecting = agents.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return a['is_active'] == true &&
          _getMarkerFreshness(recordedAt) != _MarkerFreshness.offline &&
          a['activity_type'] == 'collecting';
    }).length;
    final offline = agents.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return a['is_active'] != true ||
          _getMarkerFreshness(recordedAt) == _MarkerFreshness.offline;
    }).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0A0A0C) : Colors.white)
                .withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip(active.toString(), 'ACTIVE', AppColors.success),
              _divider(),
              _statChip(traveling.toString(), 'MOVING', AppColors.primary),
              _divider(),
              _statChip(collecting.toString(), 'COLLECT', AppColors.accent),
              _divider(),
              _statChip(offline.toString(), 'OFFLINE', Colors.grey),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _statChip(String val, String label, Color color) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1)),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 0.3)),
        ],
      );

  Widget _divider() => Container(
      width: 1, height: 24, color: AppColors.primary.withValues(alpha: 0.1));

  // ─── Premium FABs with Glass Morphism ───────────────────────────────────

  Widget _buildPremiumFABs(List<Map<String, dynamic>> agentList) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Re-center (only shown while NOT following)
        if (!_isFollowing)
          _recenterButton(),
        if (!_isFollowing) const SizedBox(height: 10),
        // Cycle map style
        if (EnvConfig.mapboxAccessToken.isNotEmpty)
          _glassFAB(
            heroTag: 'mapStyle',
            icon: _currentStyle.icon,
            color: AppColors.accent,
            onTap: _cycleMapStyle,
            tooltip: _currentStyle.label,
          ),
        if (EnvConfig.mapboxAccessToken.isNotEmpty) const SizedBox(height: 10),
        // Fit all agents
        _glassFAB(
          heroTag: 'fit',
          icon: Icons.fit_screen_rounded,
          color: AppColors.primary,
          onTap: () {
            HapticFeedback.lightImpact();
            _fitMapToAgents();
          },
        ),
        const SizedBox(height: 10),
        // Toggle list
        _glassFAB(
          heroTag: 'list',
          icon: _showList ? Icons.expand_more_rounded : Icons.people_rounded,
          color: AppColors.success,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showList = !_showList);
          },
        ),
        const SizedBox(height: 10),
        // Zoom controls
        _glassFAB(
          heroTag: 'zoomIn',
          icon: Icons.add_rounded,
          color: AppColors.primary,
          onTap: () => _zoomBy(1),
        ),
        const SizedBox(height: 10),
        _glassFAB(
          heroTag: 'zoomOut',
          icon: Icons.remove_rounded,
          color: AppColors.primary,
          onTap: () => _zoomBy(-1),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideX(begin: 0.2, end: 0);
  }

  // Prominent pill that re-centers and resumes follow mode.
  Widget _recenterButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: _recenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Re-center',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassFAB({
    required String heroTag,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  // ─── Desktop Side Panel ─────────────────────────────────────────────────

  // Left panel shown on wide screens (Row layout) instead of the bottom sheet.
  // Reuses the same filter chips, stats and horizontal agent cards.
  Widget _buildSidePanel(ThemeData theme, bool isDark,
      List<Map<String, dynamic>> agentList, List<GeofenceZone> geofenceZones) {
    final filteredList = _filterAgents(agentList);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        border: Border(
          right: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Field Agents',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${filteredList.length}/${agentList.length}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            _buildSearchField(theme, isDark),
            const SizedBox(height: 8),
            _buildFilterChips(theme, isDark),
            const SizedBox(height: 8),
            _buildFrostedStatsBar(theme, isDark, agentList),
            const SizedBox(height: 8),
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            agentList.isEmpty
                                ? Icons.location_off_rounded
                                : Icons.search_off_rounded,
                            size: 34,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            agentList.isEmpty
                                ? 'No agents reporting location'
                                : 'No agents match filter',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                          if (agentList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Ask staff to start duty to appear here',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.2),
                                    fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildAgentRow(
                        theme,
                        isDark,
                        filteredList[i],
                        geofenceZones,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Sheet: Agent List ─────────────────────────────────────────────

  Widget _buildBottomSheet(
    ThemeData theme,
    bool isDark,
    List<Map<String, dynamic>> agentList,
    List<GeofenceZone> geofenceZones,
  ) {
    final filteredList = _filterAgents(agentList);

    return AnimatedContainer(
      duration: 300.ms,
      height: _showList ? 440 : 0,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 32,
              offset: const Offset(0, -8)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Field Agents',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${filteredList.length} / ${agentList.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Search field
          _buildSearchField(theme, isDark),
          const SizedBox(height: 6),
          // Filter chips
          _buildFilterChips(theme, isDark),
          const SizedBox(height: 6),
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          agentList.isEmpty
                              ? Icons.location_off_rounded
                              : Icons.search_off_rounded,
                          size: 34,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          agentList.isEmpty
                              ? 'No agents reporting location'
                              : 'No agents match filter',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        if (agentList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Ask staff to start duty to appear here',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.2),
                                  fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) => _buildAgentCard(
                      theme,
                      isDark,
                      filteredList[i],
                      i,
                      geofenceZones,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    final filters = <_FilterOption>[
      _FilterOption(null, 'All', Icons.all_inclusive_rounded, null),
      _FilterOption('traveling', 'Moving', Icons.directions_car_rounded, AppColors.primary),
      _FilterOption('collecting', 'Collect', Icons.payments_rounded, AppColors.accent),
      _FilterOption('idle', 'Idle', Icons.coffee_rounded, Colors.grey),
      _FilterOption('offline', 'Offline', Icons.cloud_off_rounded, null),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSelected = _activityFilter == f.key;
          final chipColor = f.color ?? AppColors.primary;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() =>
                  _activityFilter = isSelected ? null : f.key);
            },
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [chipColor, chipColor.withValues(alpha: 0.8)],
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? chipColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.icon,
                    size: 13,
                    color: isSelected ? Colors.white : chipColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : chipColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _agentMatchesFilter(Map<String, dynamic> agent) {
    if (_activityFilter == null) return true;
    if (_activityFilter == 'offline') {
      final recordedAt = agent['recorded_at'] != null
          ? DateTime.tryParse(agent['recorded_at'] as String)
          : null;
      return _getMarkerFreshness(recordedAt) == _MarkerFreshness.offline;
    }
    final activity = agent['activity_type'] as String? ?? 'idle';
    if (_activityFilter == 'idle') {
      return activity == 'idle' || activity == 'resting';
    }
    return activity == _activityFilter;
  }

  /// Combined activity-filter + free-text search (name / staff code).
  List<Map<String, dynamic>> _filterAgents(
      List<Map<String, dynamic>> agentList) {
    final q = _searchQuery;
    return agentList.where((a) {
      if (!_agentMatchesFilter(a)) return false;
      if (q.isEmpty) return true;
      final name = (a['full_name'] as String? ?? '').toLowerCase();
      final code = (a['staff_code'] as String? ?? '').toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  /// Straight-line distance (km) from an agent to its assigned branch.
  /// Uses the agent's own branch coordinates when present, otherwise matches
  /// the agent's `branch_name` against the geofence zone centers.
  double? _distanceToBranchKm(
      Map<String, dynamic> agent, List<GeofenceZone> zones) {
    final lat = (agent['latitude'] as num?)?.toDouble();
    final lng = (agent['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || zones.isEmpty) return null;

    GeofenceZone? zone;
    final branchLat = (agent['branch_lat'] as num?)?.toDouble();
    final branchLng = (agent['branch_lng'] as num?)?.toDouble();
    if (branchLat != null && branchLng != null) {
      zone = GeofenceZone(
          id: '', name: '', centerLat: branchLat, centerLng: branchLng);
    } else {
      final branchName = agent['branch_name'] as String? ?? '';
      zone = zones.where((z) => z.name == branchName).firstOrNull;
    }
    if (zone == null) return null;

    final meters = GeofenceUtils.haversineDistance(
        lat, lng, zone.centerLat, zone.centerLng);
    return meters / 1000;
  }

  /// Compact "from branch" distance label (e.g. "1.2 km from branch").
  String _distanceLabel(double? km) {
    if (km == null) return '—';
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m from branch';
    return '${km.toStringAsFixed(1)} km from branch';
  }

  // ─── Search Field ──────────────────────────────────────────────────────

  Widget _buildSearchField(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (value) =>
              setState(() => _searchQuery = value.trim().toLowerCase()),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: InputBorder.none,
            hintText: 'Search name or staff code',
            hintStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // ─── Agent Card in Bottom Sheet ─────────────────────────────────────────

  Widget _buildAgentCard(ThemeData theme, bool isDark,
      Map<String, dynamic> agent, int index, List<GeofenceZone> geofenceZones) {
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final battery = (agent['battery_level'] as num?)?.toInt();
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;
    final branchName = agent['branch_name'] as String? ?? '';
    final distanceKm = _distanceToBranchKm(agent, geofenceZones);
    final color = _activityColor(activityType);
    final isSelected = _selectedStaffId == agent['staff_id'];
    final freshness = _getMarkerFreshness(recordedAt);
    final freshnessColor = _freshnessColor(freshness);
    final isOffline = freshness == _MarkerFreshness.offline;
    final speed = (agent['speed'] as num?)?.toDouble() ?? 0;
    final heading = (agent['heading'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => _focusAgent(agent),
      child: AnimatedContainer(
        duration: 250.ms,
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with freshness ring
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: freshnessColor, width: 2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.8),
                              color,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF0F1117)
                                      : Colors.white,
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(
                                      alpha: 0.4 + _pulseCtrl.value * 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.split(' ').first,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (speed > 0)
                        Text(
                          '${speed.toStringAsFixed(1)} km/h',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                if (battery != null)
                  Icon(
                    battery > 50
                        ? Icons.battery_full_rounded
                        : battery > 20
                            ? Icons.battery_4_bar_rounded
                            : Icons.battery_alert_rounded,
                    size: 13,
                    color: battery < 20
                        ? Colors.red
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (staffCode.isNotEmpty)
              Text(staffCode,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            if (branchName.isNotEmpty)
              Text(branchName,
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.near_me_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 3),
                Text(_distanceLabel(distanceKm),
                    style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                if (isOffline)
                  _signalLostBadge(isDark)
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      _activityLabel(activityType),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ),
                const Spacer(),
                if (recordedAt != null)
                  Text(
                    _timeAgoLabel(recordedAt),
                    style: TextStyle(
                        fontSize: 9,
                        color: isOffline
                            ? Colors.red.withValues(alpha: 0.9)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.35),
                        fontWeight: FontWeight.w600),
                  )
                else if (heading > 0)
                  Icon(
                    Icons.navigation_rounded,
                    size: 12,
                    color: color.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: (index * 40).ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  // ─── Agent Row (desktop side panel: vertical list) ────────────────────────

  Widget _buildAgentRow(ThemeData theme, bool isDark,
      Map<String, dynamic> agent, List<GeofenceZone> geofenceZones) {
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final battery = (agent['battery_level'] as num?)?.toInt();
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;
    final branchName = agent['branch_name'] as String? ?? '';
    final distanceKm = _distanceToBranchKm(agent, geofenceZones);
    final color = _activityColor(activityType);
    final isSelected = _selectedStaffId == agent['staff_id'];
    final freshness = _getMarkerFreshness(recordedAt);
    final freshnessColor = _freshnessColor(freshness);
    final isOffline = freshness == _MarkerFreshness.offline;

    return GestureDetector(
      onTap: () => _focusAgent(agent),
      child: AnimatedContainer(
        duration: 250.ms,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : theme.colorScheme.onSurface.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: freshnessColor,
                shape: BoxShape.circle,
                boxShadow: isActive && !isOffline
                    ? [
                        BoxShadow(
                          color: freshnessColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: freshnessColor, width: 2),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (battery != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              battery > 50
                                  ? Icons.battery_full_rounded
                                  : battery > 20
                                      ? Icons.battery_4_bar_rounded
                                      : Icons.battery_alert_rounded,
                              size: 14,
                              color: battery < 20
                                  ? Colors.red
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$battery%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: battery < 20
                                    ? Colors.red
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (staffCode.isNotEmpty)
                    Text(staffCode,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  if (staffCode.isNotEmpty) const SizedBox(height: 2),
                  Text(
                    '${_activityLabel(activityType)} · Updated ${_timeAgoLabel(recordedAt)}',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.near_me_rounded,
                          size: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(_distanceLabel(distanceKm),
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (branchName.isNotEmpty)
                        Expanded(
                          child: Text(branchName,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a shareable deep link to this live map. When a branch filter is
  /// active the link carries `?branch=<id>` so opening it jumps straight to
  /// that branch's live view. Reuses the app's existing router base
  /// (`/live-map`), so no new backend or relay server is needed.
  String _buildShareLink() {
    final base = GoRouterState.of(context).uri.replace(
          path: '/live-map',
          queryParameters: _filterBranchId != null && _filterBranchId!.isNotEmpty
              ? {'branch': _filterBranchId!}
              : const <String, String>{},
        );
    return base.toString();
  }

  void _showShareSheet() {
    final link = _buildShareLink();
    final isFiltered = _filterBranchId != null && _filterBranchId!.isNotEmpty;
    final subtitle = isFiltered
        ? (_filterBranchName != null && _filterBranchName!.isNotEmpty
            ? _filterBranchName!
            : 'branch ${_filterBranchId!}')
        : 'All branches';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF141820) : Colors.white)
                    .withValues(alpha: 0.94),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.share_location_rounded,
                            color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Share live map',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87)),
                            Text('Link shows: $subtitle',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            link,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _sheetButton(
                          icon: Icons.copy_rounded,
                          label: 'Copy link',
                          color: AppColors.primary,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(ctx);
                            _copyLink(link);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _sheetButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: AppColors.accent,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(ctx);
                            _shareLink(link);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareLink(String link) async {
    try {
      await SharePlus.instance.share(ShareParams(text: link, subject: 'Live agent map'));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share link: $e')),
        );
      }
    }
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── Agent Detail Bottom Sheet ──────────────────────────────────────────

  void _showAgentDetailSheet(Map<String, dynamic> agent) {
    final staffId = agent['staff_id'] as String?;
    if (staffId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AgentDetailSheet(
        agent: agent,
        showBreadcrumbTrail: _showBreadcrumbTrail,
        onToggleTrail: () {
          Navigator.pop(ctx);
          setState(() => _showBreadcrumbTrail = !_showBreadcrumbTrail);
        },
        onHistory: () {
          HapticFeedback.lightImpact();
          Navigator.pop(ctx);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => LocationHistorySheet(
              staffId: agent['staff_id'],
              staffName: agent['name'] ?? 'Unknown',
            ),
          );
        },
      ),
    );
  }
}

// ─── Agent Detail Bottom Sheet (live-updating) ─────────────────────────
// A standalone ConsumerStatefulWidget so it can own a 1s Timer that drives
// the "Updated Xs ago" countdown and the live freshness/accuracy readout.
// The timer is cancelled in [dispose].

class _AgentDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> agent;
  final bool showBreadcrumbTrail;
  final VoidCallback onToggleTrail;
  final VoidCallback onHistory;

  const _AgentDetailSheet({
    required this.agent,
    required this.showBreadcrumbTrail,
    required this.onToggleTrail,
    required this.onHistory,
  });

  @override
  ConsumerState<_AgentDetailSheet> createState() => _AgentDetailSheetState();
}

class _AgentDetailSheetState extends ConsumerState<_AgentDetailSheet> {
  late Timer _tickTimer;

  // Re-parsed on every build from the (possibly updated) recorded_at.
  DateTime? get _recordedAt => widget.agent['recorded_at'] != null
      ? DateTime.tryParse(widget.agent['recorded_at'] as String)
      : null;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}), // re-render the relative time label
    );
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final agent = widget.agent;
    final staffId = agent['staff_id'] as String? ?? '';
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final branchName = agent['branch_name'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final battery = (agent['battery_level'] as num?)?.toInt();
    final isCharging = agent['is_charging'] == true;
    final recordedAt = _recordedAt;
    final freshness = _getMarkerFreshness(recordedAt);
    final freshnessColor = _freshnessColor(freshness);
    final isOffline = freshness == _MarkerFreshness.offline;
    final speed = (agent['speed'] as num?)?.toDouble() ?? 0;
    final heading = (agent['heading'] as num?)?.toDouble() ?? 0;
    final accuracyM = (agent['accuracy'] as num?)?.toDouble();

    final statsAsync = ref.watch(agentDailyStatsProvider(staffId));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF141820) : Colors.white)
                .withValues(alpha: 0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Agent header row
              Row(
                children: [
                  // Avatar with freshness ring
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: freshnessColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: freshnessColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _activityColor(activityType)
                                .withValues(alpha: 0.8),
                            _activityColor(activityType),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            )),
                        if (staffCode.isNotEmpty)
                          Text(staffCode,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        if (branchName.isNotEmpty)
                          Text(branchName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  // Activity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _activityColor(activityType)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _activityLabel(activityType),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _activityColor(activityType),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Signal-lost banner (replaces the updated-timestamp row).
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Signal lost',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red,
                                )),
                            Text('No location update in over 30s',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Info row: battery + speed + last update
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (battery != null) ...[
                        Icon(
                          isCharging
                              ? Icons.battery_charging_full_rounded
                              : battery > 50
                                  ? Icons.battery_full_rounded
                                  : battery > 20
                                      ? Icons.battery_4_bar_rounded
                                      : Icons.battery_alert_rounded,
                          size: 16,
                          color: battery < 20
                              ? Colors.red
                              : (isCharging
                                  ? AppColors.success
                                  : (isDark
                                      ? Colors.white54
                                      : Colors.black45)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$battery%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: battery < 20
                                ? Colors.red
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (speed > 0) ...[
                        Icon(Icons.speed_rounded, size: 14,
                            color: isDark ? Colors.white54 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          '${speed.toStringAsFixed(1)} km/h',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (heading > 0) ...[
                        Transform.rotate(
                          angle: heading * (math.pi / 180),
                          child: Icon(Icons.navigation_rounded, size: 14,
                              color: isDark ? Colors.white54 : Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${heading.toStringAsFixed(0)}°',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.access_time_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        'Updated ${_timeAgoLabel(recordedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: freshnessColor,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: freshnessColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: freshnessColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        freshness == _MarkerFreshness.fresh
                            ? 'Live'
                            : freshness == _MarkerFreshness.recent
                                ? 'Recent'
                                : freshness == _MarkerFreshness.stale
                                    ? 'Stale'
                                    : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: freshnessColor,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Accuracy readout (GPS precision).
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded,
                        size: 16,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 8),
                    Text(
                      accuracyM != null
                          ? 'Accuracy: ±${accuracyM.round()}m'
                          : 'Accuracy: unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accuracyM != null
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : (isDark
                                ? Colors.white38
                                : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Today's stats
              statsAsync.when(
                data: (stats) {
                  final collections =
                      stats['collections_count'] as int? ?? 0;
                  final totalCollected =
                      (stats['total_collected'] as num?)?.toDouble() ?? 0;
                  final visits = stats['visits_count'] as int? ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _sheetStat(collections.toString(),
                            'Collections', AppColors.primary),
                        _sheetStat(
                            '₹${NumberFormat.compact().format(totalCollected)}',
                            'Collected',
                            AppColors.success),
                        _sheetStat(visits.toString(), 'Visits',
                            AppColors.accent),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _sheetButton(
                      icon: Icons.route_rounded,
                      label: widget.showBreadcrumbTrail
                          ? 'Hide Trail'
                          : 'View Trail',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: widget.onToggleTrail,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sheetButton(
                      icon: Icons.history,
                      label: 'History',
                      color: AppColors.primary,
                      isDark: isDark,
                      onTap: widget.onHistory,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sheetButton(
                      icon: Icons.phone_rounded,
                      label: 'Call',
                      color: AppColors.success,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        final phone = agent['phone']?.toString() ??
                            agent['phone_number']?.toString();
                        if (phone != null && phone.isNotEmpty) {
                          launchUrl(Uri.parse('tel:$phone'));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Phone number not available')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
