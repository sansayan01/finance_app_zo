import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/providers/collection_providers.dart';
import '../../data/providers/live_tracking_providers.dart';

class StaffMapPage extends ConsumerStatefulWidget {
  const StaffMapPage({super.key});

  @override
  ConsumerState<StaffMapPage> createState() => _StaffMapPageState();
}

class _StaffMapPageState extends ConsumerState<StaffMapPage>
    with TickerProviderStateMixin {
  Position? _pos;
  String _filter = 'all';
  bool _showList = true;
  bool _isMapReady = false;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _locate();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService().getCurrentLocation();
      if (mounted) {
        setState(() {
          _pos = p;
        });
        if (_isMapReady && p != null) {
          _mapController.move(LatLng(p.latitude, p.longitude), 14);
        }
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _fitAllStops(List<Map<String, dynamic>> items) {
    if (!_isMapReady) return;
    final points = <LatLng>[];
    if (_pos != null) {
      points.add(LatLng(_pos!.latitude, _pos!.longitude));
    }
    for (final item in items) {
      final m = item['members'] as Map? ?? {};
      final lat = m['gps_lat'];
      final lng = m['gps_lng'];
      if (lat != null && lng != null) {
        points.add(LatLng((lat as num).toDouble(), (lng as num).toDouble()));
      }
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14);
      return;
    }
    final lats = points.map((p) => p.latitude).toList();
    final lngs = points.map((p) => p.longitude).toList();
    final bounds = LatLngBounds(
      LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
      LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
    );
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final agents = ref.watch(liveAgentLocationsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? Colors.white70 : Colors.black87)),
        title: const Text('Route Planner',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          _chip(theme, Icons.sort_rounded, _filter == 'all' ? 'All' : 'Nearby',
              () => _showFilter(theme)),
          const SizedBox(width: 4),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (_pos != null ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (_pos != null ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: _pos != null ? AppColors.success : AppColors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: (_pos != null
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.6),
                            blurRadius: 4)
                      ])),
              const SizedBox(width: 6),
              Text(_pos != null ? 'Live' : 'No GPS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _pos != null
                          ? AppColors.success
                          : AppColors.error)),
            ]),
          ),
        ],
      ),
      body: _content(theme, isDark, agents),
    );
  }

  Widget _content(ThemeData theme, bool isDark,
      Map<String, Map<String, dynamic>> agents) {
    return ref.watch(todayDueEmisProvider).when(
          data: (due) {
            final items = _sortFilter(due);
            if (items.isEmpty) {
              return Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            shape: BoxShape.circle),
                        child: Icon(Icons.explore_outlined,
                            size: 60,
                            color: AppColors.primary.withValues(alpha: 0.2))),
                    const SizedBox(height: 24),
                    Text('No stops today',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.35))),
                    const SizedBox(height: 8),
                    Text('All collections up to date!',
                        style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2))),
                  ]));
            }

            return Stack(
              children: [
                // Map section (top half)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 280,
                  child: _buildMap(theme, isDark, items, agents),
                ),

                // Bottom sheet with stop list
                Positioned(
                  top: 260,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomSheet(theme, isDark, items),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: Text('Failed',
                  style: TextStyle(color: theme.colorScheme.error))),
        );
  }

  Widget _buildMap(ThemeData theme, bool isDark, List<Map<String, dynamic>> items,
      Map<String, Map<String, dynamic>> agents) {
    final markers = <Marker>[];

    // Agent's own location
    if (_pos != null) {
      markers.add(
        Marker(
          point: LatLng(_pos!.latitude, _pos!.longitude),
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.my_location, color: Colors.white, size: 14),
            ),
          ),
        ),
      );
    }

    // Due stop markers
    for (var i = 0; i < items.length; i++) {
      final m = items[i]['members'] as Map? ?? {};
      final lat = m['gps_lat'];
      final lng = m['gps_lng'];
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 6),
              ],
            ),
            child: Center(
              child: Text('${i + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      );
    }

    // Agent's own breadcrumb trail from live tracking
    final breadcrumbPoints = <LatLng>[];
    if (_pos != null) {
      final ownAgent = agents.values.where((a) =>
          a['latitude'] != null &&
          a['longitude'] != null &&
          a['is_active'] == true);
      for (final a in ownAgent) {
        breadcrumbPoints.add(LatLng(
          (a['latitude'] as num).toDouble(),
          (a['longitude'] as num).toDouble(),
        ));
      }
    }

    return GestureDetector(
      onDoubleTap: () => _fitAllStops(items),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _pos != null
                ? LatLng(_pos!.latitude, _pos!.longitude)
                : const LatLng(20.5937, 78.9629),
            initialZoom: 13,
            onMapReady: () {
              setState(() => _isMapReady = true);
              _fitAllStops(items);
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
            if (breadcrumbPoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: breadcrumbPoints,
                    strokeWidth: 3,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(
      ThemeData theme, bool isDark, List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: GestureDetector(
              onTap: () => setState(() => _showList = !_showList),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header: route bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _routeBar(theme, items),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _showList
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      _missionProgress(theme, items.length, 0),
                      ...items
                          .asMap()
                          .entries
                          .map((e) =>
                              _stopCard(theme, isDark, e.key, e.value)),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _routeBar(ThemeData theme, List<Map<String, dynamic>> items) {
    double totalDist = 0;
    int count = 0;
    for (final item in items) {
      final m = item['members'] as Map? ?? {};
      if (_pos != null && m['gps_lat'] != null && m['gps_lng'] != null) {
        totalDist += Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude,
            (m['gps_lat'] as num).toDouble(), (m['gps_lng'] as num).toDouble());
        count++;
      }
    }

    return Row(
      children: [
        Expanded(
            child: _routeBox(
                theme, items.length.toString(), 'STOPS', Icons.place_rounded)),
        const SizedBox(width: 12),
        Expanded(
            child: _routeBox(
                theme,
                count > 0 ? (totalDist / 1000).toStringAsFixed(1) : '-',
                'KM DIST',
                Icons.map_rounded)),
        const SizedBox(width: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6))
            ],
          ),
          child: IconButton(
              onPressed: _openMaps,
              icon: const Icon(Icons.navigation_rounded,
                  color: Colors.white, size: 24)),
        ),
      ],
    );
  }

  Widget _missionProgress(ThemeData theme, int total, int done) {
    final pct = (done / total.clamp(1, 1000)).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF181C24)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MISSION PROGRESS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 1)),
              Text('$done OF $total STOPS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent]),
                      borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeBox(ThemeData theme, String val, String label, IconData icon) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(val,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.1)),
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _stopCard(
      ThemeData theme, bool isDark, int index, Map<String, dynamic> item) {
    final m = item['members'] ?? {};
    final name = m['full_name'] ?? item['member_name'] ?? 'Unknown';
    final area = m['area']?.toString() ?? '';
    final s = item['current_schedule'] ?? {};
    final amount = (s['emi'] as num?)?.toDouble() ?? 0;

    double? dist;
    if (_pos != null && m['gps_lat'] != null && m['gps_lng'] != null) {
      dist = Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude,
          (m['gps_lat'] as num).toDouble(), (m['gps_lng'] as num).toDouble());
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF0F1117)
                            : Colors.white,
                        width: 4)),
              ),
              Expanded(
                  child: Container(
                      width: 2,
                      color: AppColors.primary.withValues(alpha: 0.15))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181C24) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => context.push('/staff/collections'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('STOP #${index + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      letterSpacing: 1)),
                              const SizedBox(height: 6),
                              Text(name,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              if (area.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                      child: Text(area,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                              fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                            if (dist != null)
                              Text(
                                  '${(dist / 1000).toStringAsFixed(1)} km away',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: (index * 60).ms)
                .slideX(begin: 0.04, end: 0),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _sortFilter(List<Map<String, dynamic>> items) {
    final list = List<Map<String, dynamic>>.from(items);
    if (_filter == 'nearby' && _pos != null) {
      list.sort((a, b) {
        final ma = a['members'] as Map? ?? {}, mb = b['members'] as Map? ?? {};
        final da = ma['gps_lat'] != null
            ? Geolocator.distanceBetween(
                _pos!.latitude,
                _pos!.longitude,
                (ma['gps_lat'] as num).toDouble(),
                (ma['gps_lng'] as num).toDouble())
            : double.infinity;
        final db = mb['gps_lat'] != null
            ? Geolocator.distanceBetween(
                _pos!.latitude,
                _pos!.longitude,
                (mb['gps_lat'] as num).toDouble(),
                (mb['gps_lng'] as num).toDouble())
            : double.infinity;
        return da.compareTo(db);
      });
    }
    return list;
  }

  Widget _chip(
      ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
        ]),
      ),
    );
  }

  void _showFilter(ThemeData theme) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(36))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 28),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Route Order',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _filterPill(ctx, 'all', 'Default', Icons.all_inclusive_rounded),
            _filterPill(ctx, 'nearby', 'Nearest First', Icons.near_me_rounded),
          ]),
        ]),
      ),
    );
  }

  Widget _filterPill(
      BuildContext ctx, String value, String label, IconData icon) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sel
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.08),
              width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16,
              color: sel
                  ? Colors.white
                  : AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? Colors.white
                      : AppColors.primary.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }

  Future<void> _openMaps() async {
    if (_pos == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/${_pos!.latitude},${_pos!.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
