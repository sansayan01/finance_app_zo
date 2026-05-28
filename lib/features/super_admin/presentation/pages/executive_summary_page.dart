import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class ExecutiveSummaryPage extends ConsumerWidget {
  const ExecutiveSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final metrics = ref.watch(platformMetricsProvider);
    final revenue = ref.watch(revenueSummaryProvider);
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

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
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            D.header('Executive Summary',
                                'Auto-generated platform report', isDark),
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () {},
                              style: IconButton.styleFrom(
                                  backgroundColor: cardBg,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                          color: D.border(context)))),
                            ),
                          ]),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: D.accent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(D.radius),
                            border: Border.all(
                                color: D.accent.withValues(alpha: 0.15))),
                        child: Row(children: [
                          Icon(Icons.auto_awesome, color: D.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Platform is healthy with ${metrics.valueOrNull?.activeOrganizations ?? 0} active organizations. Revenue growing at 18% month-over-month. 2 organizations flagged for attention.',
                                  style: TextStyle(
                                      fontSize: 13, color: D.accent))),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      D.sectionTitle('Key Highlights', Icons.star, isDark),
                      const SizedBox(height: 14),
                      _highlight(
                          context,
                          'Total Organizations',
                          '${metrics.valueOrNull?.totalOrganizations ?? 0}',
                          '+${metrics.valueOrNull?.activeOrganizations ?? 0} active',
                          Icons.business,
                          cardBg),
                      _highlight(
                          context,
                          'Monthly Revenue',
                          fmt.format(
                              revenue.valueOrNull?['total_revenue'] ?? 0),
                          '+18% vs last month',
                          Icons.trending_up,
                          cardBg),
                      _highlight(
                          context,
                          'Platform Users',
                          '${metrics.valueOrNull?.totalUsers ?? 0}',
                          '${metrics.valueOrNull?.activeUsers ?? 0} active',
                          Icons.people,
                          cardBg),
                      _highlight(
                          context,
                          'Total Collections',
                          fmt.format(
                              metrics.valueOrNull?.totalCollections ?? 0),
                          'Across all orgs',
                          Icons.payments,
                          cardBg),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _highlight(BuildContext ctx, String title, String value, String sub,
      IconData icon, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: D.card(ctx),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: D.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: D.accent, size: 24)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: D.labelStyle(isDark)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(sub, style: TextStyle(fontSize: 12, color: D.accent)),
              ])),
        ]));
  }
}
