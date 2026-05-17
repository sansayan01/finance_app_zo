import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class OnboardingManagementPage extends ConsumerWidget {
  const OnboardingManagementPage({super.key});

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
                          'Onboarding', 'Organization setup progress', isDark),
                      const SizedBox(height: 24),
                      Row(children: [
                        _stat(context, 'Total', '24', 'orgs', Colors.blue,
                            cardBg),
                        const SizedBox(width: 10),
                        _stat(context, 'Complete', '18', '75%', Colors.green,
                            cardBg),
                        const SizedBox(width: 10),
                        _stat(context, 'In Progress', '4', '16%', Colors.orange,
                            cardBg),
                        const SizedBox(width: 10),
                        _stat(context, 'Stuck', '2', '9%', Colors.red, cardBg),
                      ]),
                      const SizedBox(height: 24),
                      D.sectionTitle('Setup Progress', Icons.checklist, isDark),
                      const SizedBox(height: 14),
                      _orgProgress(context, 'ABC Finance', 100, 'Completed',
                          Colors.green, cardBg),
                      _orgProgress(context, 'XYZ Credit', 65, 'Step 3/5',
                          Colors.orange, cardBg),
                      _orgProgress(context, 'LMN Corp', 30, 'Step 2/5',
                          Colors.orange, cardBg),
                      _orgProgress(context, 'PQR Bank', 90, 'Step 4/5',
                          Colors.blue, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Setup Steps', Icons.view_timeline, isDark),
                      const SizedBox(height: 14),
                      _step(context, 'Organization Profile', '24/24 complete',
                          true, cardBg),
                      _step(context, 'Staff Setup', '22/24 complete', true,
                          cardBg),
                      _step(context, 'Branch Configuration', '20/24 complete',
                          true, cardBg),
                      _step(context, 'Product Setup', '18/24 complete', true,
                          cardBg),
                      _step(
                          context, 'Go Live', '18/24 complete', false, cardBg),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext ctx, String label, String value, String sub,
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
              Text(sub,
                  style: TextStyle(fontSize: 9, color: D.mutedColor(isDark))),
            ])));
  }

  Widget _orgProgress(BuildContext ctx, String name, int progress,
      String status, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: D.card(ctx),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(name, style: D.titleStyle(isDark))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: D.dim(ctx),
                  color: color,
                  minHeight: 6)),
        ]));
  }

  Widget _step(
      BuildContext ctx, String name, String count, bool done, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: D.card(ctx),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : D.iconMuted(ctx), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: D.titleStyle(isDark))),
          Text(count, style: D.labelStyle(isDark)),
        ]));
  }
}
