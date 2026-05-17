import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class FeatureAdoptionPage extends ConsumerWidget {
  const FeatureAdoptionPage({super.key});

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
                      D.header('Feature Adoption',
                          'Usage analytics across all orgs', isDark),
                      const SizedBox(height: 24),
                      _adoptionCard(context, 'Collections', 87, '3.2k orgs',
                          Colors.green, cardBg),
                      _adoptionCard(context, 'Loans', 72, '2.6k orgs',
                          Colors.blue, cardBg),
                      _adoptionCard(context, 'Savings', 65, '2.4k orgs',
                          Colors.orange, cardBg),
                      _adoptionCard(context, 'Reports', 43, '1.6k orgs',
                          Colors.purple, cardBg),
                      _adoptionCard(context, 'API Access', 38, '1.4k orgs',
                          Colors.teal, cardBg),
                      _adoptionCard(context, 'Mobile App', 91, '3.4k orgs',
                          Colors.indigo, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Growth vs Last Month', Icons.trending_up, isDark),
                      const SizedBox(height: 14),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: D.card(context),
                          child: Column(children: [
                            _growthRow(context, 'Collections', '+12%', true),
                            _growthRow(context, 'Loans', '+8%', true),
                            _growthRow(context, 'Savings', '+5%', true),
                            _growthRow(context, 'Reports', '-2%', false),
                            _growthRow(context, 'API Access', '+15%', true),
                          ])),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _adoptionCard(BuildContext ctx, String name, int pct, String orgs,
      Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: D.card(ctx),
        child: Row(children: [
          SizedBox(
              width: 48,
              height: 48,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 4,
                        backgroundColor: D.dim(ctx),
                        color: color)),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ])),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name, style: D.titleStyle(isDark)),
                Text(orgs, style: D.labelStyle(isDark))
              ])),
        ]));
  }

  Widget _growthRow(BuildContext ctx, String label, String change, bool up) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: D.valueStyle(isDark))),
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16, color: up ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(change,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: up ? Colors.green : Colors.red)),
        ]));
  }
}
