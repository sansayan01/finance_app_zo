import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class ReportCenterPage extends ConsumerWidget {
  const ReportCenterPage({super.key});

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
              D.header('Report Center', 'Build, schedule & export reports', isDark),
              const SizedBox(height: 24),
              D.sectionTitle('Quick Reports', Icons.bolt, isDark),
              const SizedBox(height: 14),
              _reportCard(context, 'Platform Summary', 'All metrics overview', Icons.dashboard, 'PDF', cardBg),
              _reportCard(context, 'Organization Report', 'Per-org detailed stats', Icons.business, 'CSV', cardBg),
              _reportCard(context, 'Revenue Analysis', 'Revenue trends & forecasts', Icons.trending_up, 'PDF', cardBg),
              _reportCard(context, 'User Activity', 'Login & engagement report', Icons.people, 'CSV', cardBg),
              const SizedBox(height: 24),
              D.sectionTitle('Scheduled Reports', Icons.schedule, isDark),
              const SizedBox(height: 14),
              _scheduledCard(context, 'Weekly Platform Digest', 'Every Monday 9 AM', 'Active', Colors.green, cardBg),
              _scheduledCard(context, 'Monthly Revenue Report', '1st of month 12 PM', 'Active', Colors.green, cardBg),
              _scheduledCard(context, 'Quarterly Audit Export', 'Jan 1, Apr 1', 'Paused', Colors.orange, cardBg),
              const SizedBox(height: 24),
              D.sectionTitle('Export History', Icons.history, isDark),
              const SizedBox(height: 14),
              _exportItem(context, 'Platform Report Q1 2026', 'PDF', '2 days ago', cardBg),
              _exportItem(context, 'User Data Export', 'CSV', '1 week ago', cardBg),
            ]))),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext ctx, String title, String desc, IconData icon, String format, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: D.card(ctx), child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: D.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: D.accent, size: 22)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: D.titleStyle(isDark)), Text(desc, style: D.labelStyle(isDark))])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(format, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue))),
      const SizedBox(width: 8),
      Icon(Icons.download, size: 18, color: D.iconMuted(ctx)),
    ]));
  }

  Widget _scheduledCard(BuildContext ctx, String title, String schedule, String status, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: D.card(ctx), child: Row(children: [
      Icon(Icons.schedule, size: 20, color: D.iconMuted(ctx)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: D.titleStyle(isDark)), Text(schedule, style: D.labelStyle(isDark))])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
    ]));
  }

  Widget _exportItem(BuildContext ctx, String name, String format, String date, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: D.card(ctx), child: Row(children: [
      Icon(Icons.insert_drive_file, size: 18, color: D.iconMuted(ctx)),
      const SizedBox(width: 12),
      Expanded(child: Text(name, style: D.valueStyle(isDark))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(format, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey))),
      const SizedBox(width: 8),
      Text(date, style: D.labelStyle(isDark)),
    ]));
  }
}
