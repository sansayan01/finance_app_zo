import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class PlatformAnalyticsPage extends ConsumerWidget {
  const PlatformAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final metrics = ref.watch(platformMetricsProvider);
    final revenue = ref.watch(revenueSummaryProvider);
    final apiStats = ref.watch(apiUsageStatsProvider);
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  D.header('Analytics', 'Platform-wide metrics', isDark),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
            metrics.when(
              data: (m) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                sliver: SliverToBoxAdapter(child: _metricGrid(context, m, fmt, isDark, cardBg)),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            revenue.when(
              data: (r) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                sliver: SliverToBoxAdapter(child: _revCard(context, r, fmt, isDark, cardBg)),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            apiStats.when(
              data: (a) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                sliver: SliverToBoxAdapter(child: _apiCard(context, a, isDark, cardBg)),
              ),
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricGrid(BuildContext context, dynamic m, NumberFormat fmt, bool isDark, Color cardBg) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.8),
      itemCount: 8,
      itemBuilder: (_, i) {
        final items = [
          ('Organizations', '${m.totalOrganizations}', Icons.business, Colors.blue),
          ('Users', '${m.totalUsers}', Icons.people, Colors.green),
          ('Loans', fmt.format(m.totalLoanAmount), Icons.account_balance, Colors.orange),
          ('Collections', fmt.format(m.totalCollections), Icons.payments, Colors.teal),
          ('Savings', fmt.format(m.totalSavings), Icons.savings, Colors.indigo),
          ('MRR', fmt.format(m.mrr), Icons.trending_up, Colors.amber),
          ('Branches', '${m.totalBranches}', Icons.account_tree, Colors.purple),
          ('Members', '${m.totalMembers}', Icons.person, Colors.pink),
        ];
        final (l, v, ic, c) = items[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(D.radius), border: Border.all(color: D.border(context))),
          child: Row(children: [
            Icon(ic, size: 24, color: c),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c)),
              Text(l, style: D.subtitleStyle(isDark)),
            ])),
          ]),
        );
      },
    );
  }

  Widget _revCard(BuildContext context, Map<String, dynamic> r, NumberFormat fmt, bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(D.radiusLg), border: Border.all(color: D.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.trending_up, size: 18, color: Colors.green), const SizedBox(width: 8), Text('Revenue', style: D.titleStyle(isDark))]),
        const SizedBox(height: 20),
        Row(children: [
          _rItem(context, 'Total', fmt.format(r['total_revenue'] ?? 0), Colors.green),
          _rItem(context, 'Avg Monthly', fmt.format(r['avg_monthly_revenue'] ?? 0), Colors.blue),
          _rItem(context, 'Transactions', '${r['transaction_count'] ?? 0}', Colors.orange),
        ].expand((w) => [w, Container(width: 1, height: 30, color: D.border(context))]).toList()..removeLast()),
      ]),
    );
  }

  Widget _rItem(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: Column(children: [Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)), Text(label, style: D.subtitleStyle(isDark))]));
  }

  Widget _apiCard(BuildContext context, Map<String, dynamic> a, bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(D.radiusLg), border: Border.all(color: D.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.api, size: 18, color: Colors.indigo), const SizedBox(width: 8), Text('API Usage (7 days)', style: D.titleStyle(isDark))]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(children: [Text('${a['total_requests'] ?? 0}', style: D.h2(isDark)), Text('Requests', style: D.subtitleStyle(isDark))])),
          Expanded(child: Column(children: [Text('${a['unique_endpoints'] ?? 0}', style: D.h2(isDark)), Text('Endpoints', style: D.subtitleStyle(isDark))])),
          Expanded(child: Column(children: [Text('${(a['avg_response_time'] ?? 0).toStringAsFixed(0)}ms', style: D.h2(isDark)), Text('Avg Response', style: D.subtitleStyle(isDark))])),
        ]),
      ]),
    );
  }
}
