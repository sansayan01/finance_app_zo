import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class PlatformHealthPage extends ConsumerWidget {
  const PlatformHealthPage({super.key});

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
            SliverPadding(padding: D.bodyPad, sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              D.header('Platform Health', 'SLA, uptime & service status', isDark),
              const SizedBox(height: 24),
              Row(children: [
                _healthGauge(context, 'Uptime', '99.97%', Colors.green, cardBg),
                const SizedBox(width: 10),
                _healthGauge(context, 'SLA', '98.5%', Colors.blue, cardBg),
                const SizedBox(width: 10),
                _healthGauge(context, 'Response', '<2m', Colors.green, cardBg),
              ]),
              const SizedBox(height: 24),
              D.sectionTitle('Service Status', Icons.miscellaneous_services, isDark),
              const SizedBox(height: 14),
              _serviceRow(context, 'API Server', 'Operational', '99.99% uptime', Colors.green, cardBg),
              _serviceRow(context, 'Database', 'Operational', '99.99% uptime', Colors.green, cardBg),
              _serviceRow(context, 'Storage', 'Operational', '99.95% uptime', Colors.green, cardBg),
              _serviceRow(context, 'Email Service', 'Degraded', 'Responding slowly', Colors.orange, cardBg),
              _serviceRow(context, 'SMS Gateway', 'Operational', '99.9% uptime', Colors.green, cardBg),
              const SizedBox(height: 24),
              D.sectionTitle('Incidents (Last 30 days)', Icons.warning_amber, isDark),
              const SizedBox(height: 14),
              _incident(context, 'Database latency spike', 'Resolved', '15m', '2 days ago', cardBg),
              _incident(context, 'Email delivery delay', 'Resolved', '45m', '5 days ago', cardBg),
            ]))),
          ],
        ),
      ),
    );
  }

  Widget _healthGauge(BuildContext ctx, String label, String value, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: D.card(ctx), child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4), Text(label, style: D.labelStyle(isDark)),
    ])));
  }

  Widget _serviceRow(BuildContext ctx, String name, String status, String detail, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: D.card(ctx), child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: D.titleStyle(isDark)), Text(detail, style: D.labelStyle(isDark))])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
    ]));
  }

  Widget _incident(BuildContext ctx, String title, String status, String duration, String date, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: D.card(ctx), child: Row(children: [
      Icon(Icons.circle, size: 8, color: Colors.green),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: D.valueStyle(isDark))),
      Text('$duration • $date', style: D.labelStyle(isDark)),
    ]));
  }
}
