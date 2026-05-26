import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/providers/staff_branch_providers.dart';

class StaffMapPage extends ConsumerStatefulWidget {
  const StaffMapPage({super.key});

  @override
  ConsumerState<StaffMapPage> createState() => _StaffMapPageState();
}

class _StaffMapPageState extends ConsumerState<StaffMapPage> {
  MapboxMap? _mapboxMap;
  geo.Position? _currentPosition;
  bool _loadingLocation = true;
  String? _locationError;
  bool _isDarkStyle = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
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
          _locationError = 'Location permanently denied. Enable in Settings.';
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
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Failed to get location: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchAsync = ref.watch(staffBranchIdProvider);
    final branchId = branchAsync.valueOrNull;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // Mapbox Map
          _buildMap(),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark
                            ? const Color(0xFF0A0A0C)
                            : const Color(0xFFF2F2F7))
                        .withValues(alpha: 0.95),
                    (isDark
                            ? const Color(0xFF0A0A0C)
                            : const Color(0xFFF2F2F7))
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _headerButton(
                    isDark,
                    Icons.arrow_back_rounded,
                    () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Live Map',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _headerButton(
                    isDark,
                    Icons.refresh_rounded,
                    () {
                      ref.invalidate(
                          staffCollectionHistoryProvider(branchId ?? ''));
                      _initLocation();
                    },
                  ),
                ],
              ),
            ),
          ),

          // FABs
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _mapFab(Icons.my_location_rounded, isDark, _goToMyLocation),
                const SizedBox(height: 12),
                _mapFab(Icons.layers_rounded, isDark, _toggleMapStyle),
              ],
            ),
          ),

          // Location error banner
          if (_locationError != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _locationError = null),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(isDark),
          ),

          // Loading overlay
          if (_loadingLocation)
            Container(
              color: isDark
                  ? const Color(0xFF0A0A0C).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Getting your location...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return MapWidget(
      key: const ValueKey('staff_mapbox'),
      viewport: CameraViewportState(
        center: Point(
          coordinates: _currentPosition != null
              ? Position(
                  _currentPosition!.longitude, _currentPosition!.latitude)
              : Position(77.2090, 28.6139),
        ),
        zoom: 14.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: (map) {
        _mapboxMap = map;
        map.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            showAccuracyRing: true,
            puckBearingEnabled: true,
          ),
        );
      },
    );
  }

  Widget _headerButton(bool isDark, IconData icon, VoidCallback onTap) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Icon(icon,
              color: isDark ? Colors.white : Colors.black87, size: 20),
        ),
      ),
    );
  }

  Widget _mapFab(IconData icon, bool isDark, VoidCallback onTap) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E2A).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Icon(icon,
              color: isDark ? Colors.white70 : Colors.black87, size: 22),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7))
                .withValues(alpha: 0.0),
            (isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7))
                .withValues(alpha: 0.95),
            (isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF2F2F7))
                .withValues(alpha: 1.0),
          ],
        ),
      ),
      child: _currentPosition != null
          ? GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.my_location_rounded,
                        size: 20, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Location',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  void _goToMyLocation() {
    if (_currentPosition != null) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 16.0,
          pitch: 45.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } else {
      _initLocation();
    }
  }

  void _toggleMapStyle() {
    _isDarkStyle = !_isDarkStyle;
    _mapboxMap?.loadStyleURI(
      _isDarkStyle ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
    );
  }
}
