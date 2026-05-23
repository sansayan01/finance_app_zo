import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class PlatformMapPage extends ConsumerStatefulWidget {
  const PlatformMapPage({super.key});

  @override
  ConsumerState<PlatformMapPage> createState() => _PlatformMapPageState();
}

class _PlatformMapPageState extends ConsumerState<PlatformMapPage> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final metrics = ref.watch(platformMetricsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      D.header(
                          'Platform Map', 'Geographic distribution', isDark),
                      const SizedBox(height: 24),
                    ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              sliver: SliverToBoxAdapter(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(D.radiusLg),
                  child: SizedBox(
                    height: 320,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: const MapOptions(
                            initialCenter: LatLng(20.5937, 78.9629),
                            initialZoom: 4.5,
                            interactionOptions: InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: isDark
                                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                  : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.microflow.pro',
                            ),
                            MarkerLayer(
                              markers: [
                                // India center region
                                _CoverageMarker(LatLng(28.6139, 77.2090),
                                    'North'), // Delhi
                                _CoverageMarker(LatLng(19.0760, 72.8777),
                                    'West'), // Mumbai
                                _CoverageMarker(LatLng(13.0827, 80.2707),
                                    'South'), // Chennai
                                _CoverageMarker(LatLng(22.5726, 88.3639),
                                    'East'), // Kolkata
                                _CoverageMarker(LatLng(12.9716, 77.5946),
                                    'South'), // Bangalore
                                _CoverageMarker(LatLng(17.3850, 78.4867),
                                    'Central'), // Hyderabad
                              ],
                            ),
                          ],
                        ),
                        // Gradient overlay at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    bg.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Platform stats overlay
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: metrics.when(
                              data: (m) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${m.totalOrganizations} organizations',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.totalBranches} branches \u2022 ${m.totalMembers} members',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              loading: () => const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              error: (_, __) => const Text(
                                'No data',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            metrics.when(
              data: (m) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverToBoxAdapter(
                  child: Column(children: [
                    _statCard(
                        context,
                        isDark,
                        cardBg,
                        'Organizations',
                        '${m.totalOrganizations}',
                        '${m.activeOrganizations} active',
                        Icons.business,
                        Colors.blue),
                    const SizedBox(height: 10),
                    _statCard(
                        context,
                        isDark,
                        cardBg,
                        'Branches',
                        '${m.totalBranches}',
                        'Across locations',
                        Icons.account_tree,
                        Colors.orange),
                    const SizedBox(height: 10),
                    _statCard(
                        context,
                        isDark,
                        cardBg,
                        'Members',
                        '${m.totalMembers}',
                        '${m.totalUsers} users',
                        Icons.people,
                        Colors.green),
                    const SizedBox(height: 10),
                    _statCard(
                        context,
                        isDark,
                        cardBg,
                        'Loans',
                        '${m.totalLoans}',
                        '\u20B9${(m.totalLoanAmount / 100000).toStringAsFixed(1)}L disbursed',
                        Icons.account_balance,
                        AppColors.primary),
                    const SizedBox(height: 10),
                    _statCard(
                        context,
                        isDark,
                        cardBg,
                        'Collections',
                        '\u20B9${(m.totalCollections / 100000).toStringAsFixed(1)}L',
                        '${m.totalCollections > 0 ? (m.collectionRate).toStringAsFixed(1) : 0}% collection rate',
                        Icons.payments_rounded,
                        AppColors.success),
                  ]),
                ),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext context, bool isDark, Color cardBg,
      String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(D.radius),
          border: Border.all(color: D.border(context))),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(D.radius)),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: D.subtitleStyle(isDark)),
          const SizedBox(height: 4),
          Text(value, style: D.h2(isDark)),
          Text(sub, style: TextStyle(fontSize: 12, color: color)),
        ])),
      ]),
    );
  }
}

class _CoverageMarker extends Marker {
  _CoverageMarker(LatLng point, String label)
      : super(
          point: point,
          width: 80,
          height: 80,
          child: _CoverageMarkerWidget(label: label),
        );
}

class _CoverageMarkerWidget extends StatelessWidget {
  final String label;
  const _CoverageMarkerWidget({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white)
                .withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
