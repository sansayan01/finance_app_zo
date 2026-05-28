import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:microflow_pro/core/config/env_config.dart';
import 'package:microflow_pro/core/constants/app_colors.dart';
import 'package:microflow_pro/features/staff/data/providers/live_tracking_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// ═══════════════════════════════════════════════════════════════════════════════
// ManagerLiveMapPage — Premium Mapbox-powered field agent tracker
// ═══════════════════════════════════════════════════════════════════════════════

class ManagerLiveMapPage extends ConsumerStatefulWidget {
  const ManagerLiveMapPage({super.key});

  @override
  ConsumerState<ManagerLiveMapPage> createState() => _ManagerLiveMapPageState();
}

class _ManagerLiveMapPageState extends ConsumerState<ManagerLiveMapPage>
    with TickerProviderStateMixin {
  // ─── Controllers ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _radarCtrl;
  late AnimationController _markerMoveCtrl;
  late AnimationController _cameraAnimCtrl;
  late MapController _mapController;

  // ─── State ──────────────────────────────────────────────────────────────
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  String? _selectedStaffId;
  bool _showList = true;
  bool _isMapReady = false;
  bool _showBreadcrumbTrail = false;
  _MapStyle _currentStyle = _MapStyle.navNight;
  bool _isLoading = true;
  String? _activityFilter;
  LatLng? _flyFrom;
  LatLng? _flyTo;
  double _flyZoomFrom = 5;
  double _flyZoomTarget = 16;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

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
      duration: const Duration(milliseconds: 2000),
    );

    _cameraAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initRealtime();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshSnapshot());

    _cameraAnimCtrl.addListener(_onCameraAnimate);
  }

  // ─── Realtime Init ──────────────────────────────────────────────────────

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

    final channel =
        ref.read(liveTrackingRepositoryProvider).subscribeToAgentLocations(
      onUpdate: (payload) {
        if (!mounted) return;
        ref
            .read(liveAgentLocationsProvider.notifier)
            .applyRealtimeUpdate(payload);
        // Trigger smooth marker movement animation
        _markerMoveCtrl.forward(from: 0);
      },
    );
    ref.read(liveAgentLocationsProvider.notifier).setChannel(channel);
    _channel = channel;
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

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _radarCtrl.dispose();
    _markerMoveCtrl.dispose();
    _cameraAnimCtrl.dispose();
    _mapController.dispose();
    _refreshTimer?.cancel();
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
    final agentList = agents.values.toList();
    final activeCount = agentList.where((a) => a['is_active'] == true).length;

    if (_isLoading) {
      return _buildLoadingState(isDark);
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
              builder: (_, __) => _buildMap(isDark, agentList),
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
              child: _buildBottomSheet(theme, isDark, agentList),
            ),

            // ── Premium FABs ───────────────────────────────────
            Positioned(
              bottom: _showList ? 320 : 24,
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

  Widget _buildMap(bool isDark, List<Map<String, dynamic>> agentList) {
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
    final heading = (agent['heading'] as num?)?.toDouble() ?? 0;

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

    // Smooth position interpolation
    final staffId = agent['staff_id'] as String?;
    final prevPos = staffId != null
        ? ref.read(liveAgentLocationsProvider.notifier).getPreviousPosition(staffId)
        : null;
    final prevLat = (prevPos?['latitude'] as num?)?.toDouble() ?? targetLat;
    final prevLng = (prevPos?['longitude'] as num?)?.toDouble() ?? targetLng;

    // Interpolate using animation value (easeInOut curve)
    final t = Curves.easeInOut.transform(_markerMoveCtrl.value);
    final lat = prevLat + (targetLat - prevLat) * t;
    final lng = prevLng + (targetLng - prevLng) * t;

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
                    // Ripple rings (only for active agents)
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
            ],
          ),
        ),
      ),
    );
  }

  // ─── Frosted Glass Stats Bar ────────────────────────────────────────────

  Widget _buildFrostedStatsBar(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> agents) {
    final active = agents.where((a) => a['is_active'] == true).length;
    final traveling = agents
        .where((a) =>
            a['is_active'] == true && a['activity_type'] == 'traveling')
        .length;
    final collecting = agents
        .where((a) =>
            a['is_active'] == true && a['activity_type'] == 'collecting')
        .length;
    final offline = agents.where((a) {
      final recordedAt = a['recorded_at'] != null
          ? DateTime.tryParse(a['recorded_at'] as String)
          : null;
      return _getMarkerFreshness(recordedAt) == _MarkerFreshness.offline;
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
      children: [
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
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideX(begin: 0.2, end: 0);
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

  // ─── Bottom Sheet: Agent List ─────────────────────────────────────────────

  Widget _buildBottomSheet(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> agentList) {
    final filteredList = _activityFilter == null
        ? agentList
        : agentList.where((a) => _agentMatchesFilter(a)).toList();

    return AnimatedContainer(
      duration: 300.ms,
      height: _showList ? 340 : 0,
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
          // Filter chips
          _buildFilterChips(theme, isDark),
          const SizedBox(height: 6),
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Text('No agents match filter',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) =>
                        _buildAgentCard(theme, isDark, filteredList[i], i),
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

  // ─── Agent Card in Bottom Sheet ─────────────────────────────────────────

  Widget _buildAgentCard(ThemeData theme, bool isDark,
      Map<String, dynamic> agent, int index) {
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final isActive = agent['is_active'] == true;
    final battery = (agent['battery_level'] as num?)?.toInt();
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;
    final branchName = agent['branch_name'] as String? ?? '';
    final color = _activityColor(activityType);
    final isSelected = _selectedStaffId == agent['staff_id'];
    final freshness = _getMarkerFreshness(recordedAt);
    final freshnessColor = _freshnessColor(freshness);
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
            const Spacer(),
            Row(
              children: [
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
                if (heading > 0)
                  Icon(
                    Icons.navigation_rounded,
                    size: 12,
                    color: color.withValues(alpha: 0.5),
                  ),
              ],
            ),
            if (recordedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _timeAgo(recordedAt),
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.35),
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms, delay: (index * 40).ms)
          .slideY(begin: 0.1, end: 0),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  _MarkerFreshness _getMarkerFreshness(DateTime? recordedAt) {
    if (recordedAt == null) return _MarkerFreshness.offline;
    final diff = DateTime.now().difference(recordedAt);
    if (diff.inMinutes < 1) return _MarkerFreshness.fresh;
    if (diff.inMinutes < 5) return _MarkerFreshness.recent;
    if (diff.inMinutes < 30) return _MarkerFreshness.stale;
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return DateFormat('HH:mm').format(dt);
  }

  // ─── Agent Detail Bottom Sheet ──────────────────────────────────────────

  void _showAgentDetailSheet(Map<String, dynamic> agent) {
    final staffId = agent['staff_id'] as String?;
    if (staffId == null) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = agent['full_name'] as String? ?? 'Unknown';
    final staffCode = agent['staff_code'] as String? ?? '';
    final branchName = agent['branch_name'] as String? ?? '';
    final activityType = agent['activity_type'] as String? ?? 'idle';
    final battery = (agent['battery_level'] as num?)?.toInt();
    final isCharging = agent['is_charging'] == true;
    final recordedAt = agent['recorded_at'] != null
        ? DateTime.tryParse(agent['recorded_at'] as String)
        : null;
    final freshness = _getMarkerFreshness(recordedAt);
    final freshnessColor = _freshnessColor(freshness);
    final speed = (agent['speed'] as num?)?.toDouble() ?? 0;
    final heading = (agent['heading'] as num?)?.toDouble() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) {
          final statsAsync = sheetRef.watch(agentDailyStatsProvider(staffId));

          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
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
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.12),
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
                            border: Border.all(
                                color: freshnessColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    freshnessColor.withValues(alpha: 0.3),
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
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
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

                    // Info row: battery + speed + last update
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
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54),
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
                              color:
                                  isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            recordedAt != null
                                ? _timeAgo(recordedAt)
                                : 'N/A',
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
                                  color: freshnessColor
                                      .withValues(alpha: 0.5),
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

                    // Today's stats
                    statsAsync.when(
                      data: (stats) {
                        final collections =
                            stats['collections_count'] as int? ?? 0;
                        final totalCollected =
                            (stats['total_collected'] as num?)?.toDouble() ??
                                0;
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
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
                            label: _showBreadcrumbTrail
                                ? 'Hide Trail'
                                : 'View Trail',
                            color: AppColors.primary,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _showBreadcrumbTrail =
                                  !_showBreadcrumbTrail);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sheetButton(
                            icon: Icons.phone_rounded,
                            label: 'Call',
                            color: AppColors.success,
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Call feature coming soon'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
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
      ),
    );
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
}
