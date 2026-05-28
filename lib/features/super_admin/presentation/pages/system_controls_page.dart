import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class SystemControlsPage extends ConsumerWidget {
  const SystemControlsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);

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
                      D.header('System Controls',
                          'Graceful degradation & service management', isDark),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Service Toggles', Icons.toggle_on, isDark),
                      const SizedBox(height: 14),
                      _toggleRow(context, 'API Service', true, cardBg),
                      _toggleRow(context, 'Background Jobs', true, cardBg),
                      _toggleRow(context, 'Email Notifications', true, cardBg),
                      _toggleRow(context, 'SMS Service', false, cardBg),
                      _toggleRow(context, 'Report Generation', true, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle('Degradation Mode', Icons.speed, isDark),
                      const SizedBox(height: 14),
                      _modeCard(
                          context,
                          'Normal Operation',
                          'All services running at full capacity',
                          Colors.green,
                          true,
                          cardBg),
                      _modeCard(
                          context,
                          'Degraded',
                          'Non-critical services disabled',
                          Colors.orange,
                          false,
                          cardBg),
                      _modeCard(context, 'Maintenance',
                          'All services read-only', Colors.red, false, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle('Cache Management', Icons.storage, isDark),
                      const SizedBox(height: 14),
                      _cacheRow(context, 'API Cache', '2.4 GB', '87% hit rate',
                          cardBg),
                      _cacheRow(context, 'Query Cache', '1.1 GB',
                          '92% hit rate', cardBg),
                      _cacheRow(context, 'Session Cache', '340 MB',
                          '256 active sessions', cardBg),
                      _cacheRow(context, 'Static Assets', '1.8 GB',
                          'CDN cached', cardBg),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(
      BuildContext ctx, String label, bool enabled, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: D.card(ctx),
        child: Row(children: [
          Expanded(child: Text(label, style: D.titleStyle(isDark))),
          Switch(
              value: enabled,
              onChanged: (_) {},
              activeTrackColor: Colors.green),
        ]));
  }

  Widget _modeCard(BuildContext ctx, String title, String desc, Color color,
      bool active, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.05) : cardBg,
        borderRadius: BorderRadius.circular(D.radius),
        border: Border.all(
            color: active ? color.withValues(alpha: 0.3) : D.border(ctx)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? color : Colors.transparent,
              border: Border.all(color: active ? color : D.dim(ctx), width: 2),
            ),
            child: active
                ? Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: D.titleStyle(isDark)),
          Text(desc, style: D.labelStyle(isDark))
        ])),
      ]),
    );
  }

  Widget _cacheRow(BuildContext ctx, String name, String size, String hitRate,
      Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: D.card(ctx),
        child: Row(children: [
          Icon(Icons.cached, size: 18, color: D.iconMuted(ctx)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: D.valueStyle(isDark))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(hitRate,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue))),
          const SizedBox(width: 8),
          Text(size, style: D.labelStyle(isDark)),
        ]));
  }
}
