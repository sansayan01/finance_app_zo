import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../data/providers/collection_providers.dart';

class StaffMapPage extends ConsumerStatefulWidget {
  const StaffMapPage({super.key});

  @override
  ConsumerState<StaffMapPage> createState() => _StaffMapPageState();
}

class _StaffMapPageState extends ConsumerState<StaffMapPage> with SingleTickerProviderStateMixin {
  Position? _pos;
  String _filter = 'all';
  late AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _locate();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService().getCurrentLocation();
      if (mounted) setState(() { _pos = p; });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87)),
        title: const Text('Route Planner', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          _chip(theme, Icons.sort_rounded, _filter == 'all' ? 'All' : 'Nearby', () => _showFilter(theme)),
          const SizedBox(width: 4),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (_pos != null ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (_pos != null ? AppColors.success : AppColors.error).withValues(alpha: 0.15)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _pos != null ? AppColors.success : AppColors.error, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (_pos != null ? AppColors.success : AppColors.error).withValues(alpha: 0.6), blurRadius: 4)])),
              const SizedBox(width: 6),
              Text(_pos != null ? 'Live' : 'No GPS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _pos != null ? AppColors.success : AppColors.error)),
            ]),
          ),
        ],
      ),
      body: _content(theme, isDark),
    );
  }

  Widget _content(ThemeData theme, bool isDark) {
    return ref.watch(todayDueEmisProvider).when(
      data: (due) {
        final items = _sortFilter(due);
        if (items.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.explore_outlined, size: 60, color: AppColors.primary.withValues(alpha: 0.2))),
            const SizedBox(height: 24),
            Text('No stops today', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.35))),
            const SizedBox(height: 8),
            Text('All collections up to date!', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.2))),
          ]));
        }

        return RefreshIndicator(
          onRefresh: () async { ref.invalidate(todayDueEmisProvider); await _locate(); },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              _radar(theme, isDark, items),
              const SizedBox(height: 24),
              _routeBar(theme, items),
              const SizedBox(height: 24),
              _missionProgress(theme, items.length, 0), // Mocking 0 for now as we don't have 'done' flag in items
              ...items.asMap().entries.map((e) => _stopCard(theme, isDark, e.key, e.value)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('Failed', style: TextStyle(color: theme.colorScheme.error))),
    );
  }

  Widget _radar(ThemeData theme, bool isDark, List<Map<String, dynamic>> items) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _radarCtrl,
              builder: (_, __) => CustomPaint(
                size: const Size(180, 180),
                painter: _RadarPainter(isDark: isDark, angle: _radarCtrl.value * 2 * math.pi),
              ),
            ),
          ),
          ...items.take(6).toList().asMap().entries.map((e) {
            final a = (e.key * 60.0 + 30.0) * math.pi / 180.0;
            final r = 40.0 + (e.key % 2) * 25.0;
            return Positioned(
              left: 180 / 2 + r * math.cos(a) + (MediaQuery.of(context).size.width - 40) / 2 - 180 / 2 - 12,
              top: 120 + r * math.sin(a) - 12,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)]),
                child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
              ),
            );
          }),
          Positioned(
            left: 24, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('SCANNING AREA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('6 points detected in 5km radius', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: 0.3), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Positioned(
            right: 24, bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.fullscreen_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
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
        totalDist += Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, (m['gps_lat'] as num).toDouble(), (m['gps_lng'] as num).toDouble());
        count++;
      }
    }

    return Row(
      children: [
        Expanded(child: _routeBox(theme, items.length.toString(), 'STOPS', Icons.place_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _routeBox(theme, count > 0 ? (totalDist / 1000).toStringAsFixed(1) : '-', 'KM DIST', Icons.map_rounded)),
        const SizedBox(width: 12),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6))],
          ),
          child: IconButton(onPressed: _openMaps, icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 28)),
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
        color: theme.brightness == Brightness.dark ? const Color(0xFF181C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MISSION PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 1)),
              Text('$done OF $total STOPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(3)),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.1)),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface.withValues(alpha: 0.35), letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _stopCard(ThemeData theme, bool isDark, int index, Map<String, dynamic> item) {
    final m = item['members'] ?? {};
    final name = m['full_name'] ?? item['member_name'] ?? 'Unknown';
    final area = m['area']?.toString() ?? '';
    final s = item['current_schedule'] ?? {};
    final amount = (s['emi'] as num?)?.toDouble() ?? 0;

    double? dist;
    if (_pos != null && m['gps_lat'] != null && m['gps_lng'] != null) {
      dist = Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, (m['gps_lat'] as num).toDouble(), (m['gps_lng'] as num).toDouble());
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE), width: 4)),
              ),
              Expanded(child: Container(width: 2, color: AppColors.primary.withValues(alpha: 0.15))),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181C24) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 15, offset: const Offset(0, 8))],
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
                              Text('STOP #${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
                              const SizedBox(height: 6),
                              Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (area.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.location_on_rounded, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(area, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                            if (dist != null)
                              Text('${(dist / 1000).toStringAsFixed(1)} km away', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: (index * 60).ms).slideX(begin: 0.04, end: 0),
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
        final da = ma['gps_lat'] != null ? Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, (ma['gps_lat'] as num).toDouble(), (ma['gps_lng'] as num).toDouble()) : double.infinity;
        final db = mb['gps_lat'] != null ? Geolocator.distanceBetween(_pos!.latitude, _pos!.longitude, (mb['gps_lat'] as num).toDouble(), (mb['gps_lng'] as num).toDouble()) : double.infinity;
        return da.compareTo(db);
      });
    }
    return list;
  }

  Widget _chip(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 2), Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
        ]),
      ),
    );
  }

  void _showFilter(ThemeData theme) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 48, height: 5, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 28),
          Align(alignment: Alignment.centerLeft, child: Text('Route Order', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _filterPill(ctx, 'all', 'Default', Icons.all_inclusive_rounded),
            _filterPill(ctx, 'nearby', 'Nearest First', Icons.near_me_rounded),
          ]),
        ]),
      ),
    );
  }

  Widget _filterPill(BuildContext ctx, String value, String label, IconData icon) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); Navigator.pop(ctx); },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08), width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.primary.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }

  Future<void> _openMaps() async {
    if (_pos == null) return;
    final uri = Uri.parse('https://www.google.com/maps/dir/${_pos!.latitude},${_pos!.longitude}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _RadarPainter extends CustomPainter {
  final bool isDark;
  final double angle;
  _RadarPainter({required this.isDark, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final p = Paint()..color = AppColors.primary.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    
    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(c, radius * (i / 3), p);
    }
    
    // Draw sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0)],
        stops: const [0.0, 0.2],
        transform: GradientRotation(angle - 1.2),
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    
    canvas.drawCircle(c, radius, sweepPaint..style = PaintingStyle.fill);
    
    // Draw crosshair
    final crossPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.15)..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - radius, c.dy), Offset(c.dx + radius, c.dy), crossPaint);
    canvas.drawLine(Offset(c.dx, c.dy - radius), Offset(c.dx, c.dy + radius), crossPaint);
    
    // Center point
    canvas.drawCircle(c, 6, Paint()..color = AppColors.primary..style = PaintingStyle.fill);
    canvas.drawCircle(c, 10, Paint()..color = AppColors.primary.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter o) => true;
}
