import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class BackgroundJobsPage extends ConsumerWidget {
  const BackgroundJobsPage({super.key});

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
                      D.header(
                          'Background Jobs', 'Async job queue monitor', isDark),
                      const SizedBox(height: 24),
                      Row(children: [
                        _statCard(context, 'Queue Depth', '247', 'jobs waiting',
                            Colors.blue, cardBg),
                        const SizedBox(width: 10),
                        _statCard(context, 'Processing', '12', 'active jobs',
                            Colors.green, cardBg),
                        const SizedBox(width: 10),
                        _statCard(context, 'Failed', '3', 'last hour',
                            Colors.red, cardBg),
                        const SizedBox(width: 10),
                        _statCard(context, 'Avg Time', '1.2s', 'per job',
                            Colors.orange, cardBg),
                      ]),
                      const SizedBox(height: 24),
                      D.sectionTitle('Job Queue', Icons.queue, isDark),
                      const SizedBox(height: 14),
                      _jobCard(context, 'Sync Collections', 'Running',
                          'org_123', '45s ago', Colors.green, cardBg),
                      _jobCard(context, 'Generate Reports', 'Queued', 'org_456',
                          '2m ago', Colors.orange, cardBg),
                      _jobCard(context, 'Send Emails', 'Queued', 'bulk',
                          '3m ago', Colors.orange, cardBg),
                      _jobCard(context, 'Process Payments', 'Failed', 'org_789',
                          '5m ago', Colors.red, cardBg),
                      _jobCard(context, 'Backup Database', 'Completed',
                          'system', '10m ago', Colors.green, cardBg),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _statCard(BuildContext ctx, String label, String value, String sub,
      Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: D.card(ctx),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: D.labelStyle(isDark)),
        Text(sub, style: TextStyle(fontSize: 9, color: D.mutedColor(isDark))),
      ]),
    ));
  }

  Widget _jobCard(BuildContext ctx, String name, String status, String target,
      String time, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: D.card(ctx),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(_jobIcon(status), color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: D.titleStyle(isDark)),
          Text('$target • $time', style: D.labelStyle(isDark)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }

  IconData _jobIcon(String status) {
    switch (status) {
      case 'Running':
        return Icons.play_circle;
      case 'Queued':
        return Icons.hourglass_empty;
      case 'Failed':
        return Icons.error;
      default:
        return Icons.check_circle;
    }
  }
}
