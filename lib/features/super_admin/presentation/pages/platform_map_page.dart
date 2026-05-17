import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class PlatformMapPage extends ConsumerWidget {
  const PlatformMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(D.radiusLg),
                      border: Border.all(color: D.border(context))),
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(Icons.map,
                            size: 56, color: D.accent.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('Interactive Map', style: D.titleStyle(isDark)),
                        const SizedBox(height: 4),
                        Text('Map visualization coming soon',
                            style: D.subtitleStyle(isDark)),
                      ])),
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
