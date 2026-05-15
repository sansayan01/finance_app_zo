import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class NPSSurveyPage extends ConsumerWidget {
  const NPSSurveyPage({super.key});

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
              D.header('NPS Survey', 'Net Promoter Score management', isDark),
              const SizedBox(height: 24),
              Row(children: [
                _npsCard(context, 'Score', '72', 'Excellent', Colors.green, cardBg),
                const SizedBox(width: 12),
                _npsCard(context, 'Promoters', '45%', '9-10 rating', Colors.green, cardBg),
                const SizedBox(width: 12),
                _npsCard(context, 'Detractors', '12%', '0-6 rating', Colors.red, cardBg),
              ]),
              const SizedBox(height: 24),
              D.sectionTitle('Recent Responses', Icons.feedback, isDark),
              const SizedBox(height: 14),
              _response(context, 'ABC Finance', 9, 'Great platform! Very intuitive.', '2h ago', cardBg),
              _response(context, 'XYZ Credit', 6, 'Need better reporting tools.', '5h ago', cardBg),
              _response(context, 'LMN Corp', 10, 'Excellent support team!', '1d ago', cardBg),
              const SizedBox(height: 24),
              D.sectionTitle('Trend', Icons.trending_up, isDark),
              const SizedBox(height: 14),
              Container(padding: const EdgeInsets.all(16), decoration: D.card(context), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _monthBar(context, 'Jan', 68, Colors.blue),
                _monthBar(context, 'Feb', 72, Colors.blue),
                _monthBar(context, 'Mar', 70, Colors.blue),
                _monthBar(context, 'Apr', 74, Colors.blue),
                _monthBar(context, 'May', 72, D.accent),
              ])),
            ]))),
          ],
        ),
      ),
    );
  }

  Widget _npsCard(BuildContext ctx, String label, String value, String sub, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16), decoration: D.card(ctx), child: Column(children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: D.labelStyle(isDark)),
        Text(sub, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ));
  }

  Widget _response(BuildContext ctx, String org, int score, String comment, String time, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: D.card(ctx),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: score >= 9 ? Colors.green.withValues(alpha: 0.1) : score >= 7 ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('$score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: score >= 9 ? Colors.green : score >= 7 ? Colors.orange : Colors.red))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(org, style: D.titleStyle(isDark)),
          Text(comment, style: D.labelStyle(isDark), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Text(time, style: D.labelStyle(isDark)),
      ]),
    );
  }

  Widget _monthBar(BuildContext ctx, String month, int score, Color color) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Column(children: [
      Container(width: 32, height: 60, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(height: 60 * score / 100, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
      ])),
      const SizedBox(height: 6),
      Text(month, style: D.labelStyle(isDark)),
    ]);
  }
}
