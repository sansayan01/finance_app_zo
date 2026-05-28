import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/duty_providers.dart';
import '../../data/providers/live_tracking_providers.dart';
import '../../data/providers/staff_map_providers.dart';
import '../../data/providers/staff_providers.dart';
import '../widgets/on_duty_toggle.dart';

class StaffMapPage extends ConsumerStatefulWidget {
  const StaffMapPage({super.key});

  @override
  ConsumerState<StaffMapPage> createState() => _StaffMapPageState();
}

class _StaffMapPageState extends ConsumerState<StaffMapPage>
    with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  bool _loadingLocation = true;
  String? _locationError;
  int _styleIndex = 0; // 0=streets, 1=dark, 2=satellite-streets
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _customerPinManager;
  Timer? _breadcrumbRefreshTimer;
  bool _showCustomerPins = true;
  late AnimationController _pulseCtrl;

  static const _styles = [
    MapboxStyles.STANDARD,
    MapboxStyles.DARK,
    MapboxStyles.SATELLITE_STREETS,
    MapboxStyles.STANDARD_SATELLITE,
  ];
  static const _styleLabels = ['Standard', 'Dark', 'Satellite', 'Hybrid'];
  static const _styleIcons = [
    Icons.auto_awesome_rounded,
    Icons.dark_mode_rounded,
    Icons.satellite_alt_rounded,
    Icons.layers_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initLocation();
    _breadcrumbRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshBreadcrumbs(),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _breadcrumbRefreshTimer?.cancel();
    super.dispose();
  }

  void _refreshBreadcrumbs() {
    final profile = ref.read(staffProfileProvider).valueOrNull;
    if (profile != null) {
      ref.invalidate(agentBreadcrumbsProvider(profile.id));
    }
  }

  Future<void> _initLocation() async {
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            _loadingLocation = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
          _locationError =
              'Location permanently denied. Enable in Settings.';
        });
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _loadingLocation = false;
      });
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates:
                Position(position.longitude, position.latitude),
          ),
          zoom: 17.0,
          pitch: 60.0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 2800),
      );
      _drawBreadcrumbTrail();
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _drawBreadcrumbTrail() async {
    if (_mapboxMap == null) return;
    final profile = ref.read(staffProfileProvider).valueOrNull;
    if (profile == null) return;
    final breadcrumbs =
        ref.read(agentBreadcrumbsProvider(profile.id)).valueOrNull;
    if (breadcrumbs == null || breadcrumbs.length < 2) return;
    try {
      _polylineManager ??=
          await _mapboxMap!.annotations.createPolylineAnnotationManager();
      await _polylineManager!.deleteAll();
      final coordinates = breadcrumbs
          .where((p) => p['latitude'] != null && p['longitude'] != null)
          .map((p) => Position(
                (p['longitude'] as num).toDouble(),
                (p['latitude'] as num).toDouble(),
              ))
          .toList();
      if (coordinates.length >= 2) {
        await _polylineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: AppColors.primary.toARGB32(),
          lineWidth: 4.0,
          lineOpacity: 0.85,
        ));
      }
    } catch (e) {
      debugPrint('[StaffMap] Error drawing breadcrumb: $e');
    }
  }

  Future<void> _drawCustomerPins() async {
    if (_mapboxMap == null || !_showCustomerPins) return;
    final customers =
        ref.read(todayDueCustomerLocationsProvider).valueOrNull;
    if (customers == null || customers.isEmpty) return;
    try {
      _customerPinManager ??=
          await _mapboxMap!.annotations.createPointAnnotationManager();
      await _customerPinManager!.deleteAll();
      for (final customer in customers) {
        final lat = (customer['latitude'] as num?)?.toDouble();
        final lng = (customer['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final name = customer['full_name'] as String? ?? '';
        final amount =
            (customer['emi_amount'] as num?)?.toDouble() ?? 0;
        final label = amount > 0
            ? '${name.split(' ').first}\n₹${amount.toStringAsFixed(0)}'
            : name.split(' ').first;
        await _customerPinManager!.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(lng, lat)),
          iconSize: 1.0,
          textField: label,
          textSize: 10.0,
          textOffset: [0, 2.2],
          textColor: Colors.white.toARGB32(),
          textHaloColor: const Color(0xFF4F46E5).toARGB32(),
          textHaloWidth: 2.0,
          iconColor: const Color(0xFF4F46E5).toARGB32(),
          iconImage: 'marker-15',
        ));
      }
    } catch (e) {
      debugPrint('[StaffMap] Error drawing customer pins: $e');
    }
  }

  void _toggleCustomerPins() {
    setState(() => _showCustomerPins = !_showCustomerPins);
    if (_showCustomerPins) {
      _drawCustomerPins();
    } else {
      _customerPinManager?.deleteAll();
    }
  }

  Future<void> _enhanceMapStyle() async {
    if (_mapboxMap == null) return;
    try {
      final style = _mapboxMap!.style;
      // Add 3D building extrusion for non-Standard styles
      if (!await style.styleLayerExists('3d-buildings')) {
        final buildingLayer = FillExtrusionLayer(
          id: '3d-buildings',
          sourceId: 'composite',
          sourceLayer: 'building',
          minZoom: 14.0,
          maxZoom: 18.0,
          fillExtrusionColor: const Color(0xFFA0AAB5).toARGB32(),
          fillExtrusionOpacity: 0.7,
          fillExtrusionHeightExpression: ['get', 'height'],
          fillExtrusionBaseExpression: ['get', 'min_height'],
          fillExtrusionVerticalGradient: true,
          fillExtrusionCastShadows: true,
        );
        await style.addLayer(buildingLayer);
      }
    } catch (e) {
      debugPrint('[StaffMap] Style enhancement error: $e');
    }
  }

  void _cycleMapStyle() {
    setState(() => _styleIndex = (_styleIndex + 1) % _styles.length);
    _mapboxMap?.loadStyleURI(_styles[_styleIndex]);
    Future.delayed(const Duration(milliseconds: 800), () {
      _enhanceMapStyle();
      _drawBreadcrumbTrail();
      if (_showCustomerPins) _drawCustomerPins();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dutyState = ref.watch(onDutyProvider);
    final isOnDuty = dutyState.valueOrNull ?? false;
    final dutyMinutesAsync = ref.watch(todayDutyMinutesProvider);
    final isTracking = ref.watch(isTrackingProvider);

    // Watch breadcrumbs
    final profile = ref.watch(staffProfileProvider).valueOrNull;
    if (profile != null) {
      ref.watch(agentBreadcrumbsProvider(profile.id)).whenData((_) {
        Future.microtask(() => _drawBreadcrumbTrail());
      });
    }
    // Watch customer locations
    final customerAsync = ref.watch(todayDueCustomerLocationsProvider);
    customerAsync.whenData((_) {
      if (_showCustomerPins) Future.microtask(() => _drawCustomerPins());
    });
    final customerCount = customerAsync.valueOrNull?.length ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _styleIndex == 1
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Full-bleed Mapbox Map ──
            Positioned.fill(child: _buildMap()),

            // ── Top frosted header ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildFrostedHeader(isDark, isOnDuty, isTracking,
                  dutyMinutesAsync),
            ),

            // ── Right FAB column ──
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 140,
              child: _buildFabColumn(isDark, customerCount),
            ),

            // ── Bottom status bar ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(isDark, isOnDuty, isTracking),
            ),

            // ── Error banner ──
            if (_locationError != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 100,
                child: _buildErrorBanner(),
              ),

            // ── Loading overlay ──
            if (_loadingLocation) _buildLoadingOverlay(isDark),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMap() {
    return MapWidget(
      key: const ValueKey('staff_mapbox_premium'),
      viewport: CameraViewportState(
        center: Point(
          coordinates: _currentPosition != null
              ? Position(
                  _currentPosition!.longitude, _currentPosition!.latitude)
              : Position(77.2090, 28.6139),
        ),
        zoom: 15.0,
        pitch: 45.0,
      ),
      styleUri: _styles[_styleIndex],
      onMapCreated: (map) {
        _mapboxMap = map;
        map.location.updateSettings(LocationComponentSettings(
          enabled: true,
          showAccuracyRing: true,
          puckBearingEnabled: true,
          pulsingEnabled: true,
          pulsingColor: AppColors.primary.toARGB32(),
        ));
        _enhanceMapStyle();
        Future.delayed(const Duration(milliseconds: 600), () {
          _drawBreadcrumbTrail();
          _drawCustomerPins();
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FROSTED HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFrostedHeader(bool isDark, bool isOnDuty, bool isTracking,
      AsyncValue<int> dutyMinutesAsync) {
    final dutyMinutes = dutyMinutesAsync.valueOrNull ?? 0;
    final hours = dutyMinutes ~/ 60;
    final mins = dutyMinutes % 60;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 12, 20, 14),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0A0A0C) : Colors.white)
                .withValues(alpha: 0.75),
            border: Border(
              bottom: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button
              _glassIconButton(Icons.arrow_back_rounded, isDark, () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              }),
              const SizedBox(width: 12),
              // On Duty toggle
              const OnDutyToggle(),
              const Spacer(),
              // Duty time pill
              _infoPill(
                icon: Icons.timer_outlined,
                label: '${hours}h ${mins.toString().padLeft(2, '0')}m',
                color: AppColors.primary,
                isDark: isDark,
              ),
              if (isTracking) ...[
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => _infoPill(
                    icon: Icons.gps_fixed_rounded,
                    label: 'LIVE',
                    color: AppColors.success,
                    isDark: isDark,
                    glowAlpha: 0.1 + _pulseCtrl.value * 0.15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FAB COLUMN
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFabColumn(bool isDark, int customerCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _premiumFab(
          icon: Icons.my_location_rounded,
          isDark: isDark,
          onTap: _goToMyLocation,
          tooltip: 'My Location',
        ),
        const SizedBox(height: 10),
        _premiumFab(
          icon: _styleIcons[_styleIndex],
          isDark: isDark,
          onTap: _cycleMapStyle,
          tooltip: _styleLabels[_styleIndex],
          badge: _styleLabels[_styleIndex][0],
        ),
        const SizedBox(height: 10),
        _premiumFab(
          icon: Icons.route_rounded,
          isDark: isDark,
          onTap: () {
            _drawBreadcrumbTrail();
            HapticFeedback.lightImpact();
          },
          tooltip: 'My Route',
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: 10),
        _premiumFab(
          icon: _showCustomerPins
              ? Icons.person_pin_circle_rounded
              : Icons.person_pin_circle_outlined,
          isDark: isDark,
          onTap: () {
            _toggleCustomerPins();
            HapticFeedback.lightImpact();
          },
          tooltip: 'Customers',
          accentColor: const Color(0xFFF97316),
          badgeCount: customerCount,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM STATUS BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(bool isDark, bool isOnDuty, bool isTracking) {
    if (_currentPosition == null) return const SizedBox.shrink();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0A0A0C) : Colors.white)
                .withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              // Status icon with glow
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOnDuty
                          ? [
                              AppColors.success.withValues(alpha: 0.2),
                              AppColors.success.withValues(
                                  alpha: 0.08 + _pulseCtrl.value * 0.08),
                            ]
                          : [
                              AppColors.primary.withValues(alpha: 0.12),
                              AppColors.primary.withValues(alpha: 0.06),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isOnDuty ? AppColors.success : AppColors.primary)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    isOnDuty
                        ? Icons.directions_walk_rounded
                        : Icons.explore_rounded,
                    size: 20,
                    color: isOnDuty ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Location text with speed
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          isOnDuty ? 'On Duty · Tracking' : 'Your Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (_currentPosition!.speed > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOnDuty
                        ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
                        : [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isOnDuty ? AppColors.success : AppColors.primary)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isOnDuty ? 'ON DUTY' : 'READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR BANNER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_locationError!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
              GestureDetector(
                onTap: () => setState(() => _locationError = null),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOADING OVERLAY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingOverlay(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0A0A0B), const Color(0xFF1A1A2E)]
              : [const Color(0xFFF0F4FF), Colors.white],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (_, scale, __) => Column(
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
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Acquiring GPS...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Getting your precise location',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REUSABLE COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _glassIconButton(
      IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.06),
          ),
        ),
        child: Icon(icon,
            size: 18, color: isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    double glowAlpha = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08 + glowAlpha),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumFab({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    String? badge,
    int badgeCount = 0,
    Color? accentColor,
  }) {
    final hasAccent = accentColor != null;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1E28).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasAccent
                    ? accentColor.withValues(alpha: 0.25)
                    : (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: (hasAccent ? accentColor : Colors.black)
                      .withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon,
                size: 20,
                color: hasAccent
                    ? accentColor
                    : (isDark ? Colors.white70 : Colors.black87)),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor ?? AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1A1E28)
                        : Colors.white,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _goToMyLocation() {
    HapticFeedback.lightImpact();
    if (_currentPosition != null) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 17.0,
          pitch: 55.0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 1200),
      );
    } else {
      _initLocation();
    }
  }
}
