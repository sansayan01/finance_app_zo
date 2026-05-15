import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class SecurityScorecardPage extends ConsumerWidget {
  const SecurityScorecardPage({super.key});

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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  D.header('Security Scorecard', 'Platform security health overview', isDark),
                  const SizedBox(height: 24),
                  Row(children: [
                    _gauge(context, 'Overall', 87, Colors.green, cardBg),
                    const SizedBox(width: 12),
                    _gauge(context, 'Data', 92, Colors.teal, cardBg),
                    const SizedBox(width: 12),
                    _gauge(context, 'Access', 78, Colors.orange, cardBg),
                  ]),
                  const SizedBox(height: 20),
                  D.sectionTitle('Findings', Icons.shield, isDark),
                  const SizedBox(height: 14),
                  _finding(context, '2FA not enforced on 12 accounts', 'Medium', Colors.orange, cardBg),
                  const SizedBox(height: 8),
                  _finding(context, 'API keys expired for 5 orgs', 'Low', Colors.green, cardBg),
                  const SizedBox(height: 8),
                  _finding(context, 'Suspicious login attempts detected', 'High', Colors.red, cardBg),
                  const SizedBox(height: 24),
                  D.sectionTitle('Recent Events', Icons.history, isDark),
                  const SizedBox(height: 14),
                  _event(context, 'Password changed', 'admin@org.com', '2h ago', cardBg),
                  _event(context, '2FA enabled', 'user@org.com', '5h ago', cardBg),
                  _event(context, 'API key rotated', 'system', '1d ago', cardBg),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gauge(BuildContext ctx, String label, int score, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: D.card(ctx),
        child: Column(children: [
          SizedBox(
            width: 56, height: 56,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 56, height: 56, child: CircularProgressIndicator(value: score / 100, strokeWidth: 5, backgroundColor: D.dim(ctx), color: color)),
              Text('$score%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(label, style: D.labelStyle(isDark)),
        ]),
      ),
    );
  }

  Widget _finding(BuildContext ctx, String text, String severity, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: D.card(ctx),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: D.valueStyle(isDark))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(severity, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }

  Widget _event(BuildContext ctx, String action, String user, String time, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: D.card(ctx),
        child: Row(children: [
          Icon(Icons.security, size: 18, color: D.iconMuted(ctx)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(action, style: D.titleStyle(isDark)),
            Text(user, style: D.labelStyle(isDark)),
          ])),
          Text(time, style: D.labelStyle(isDark)),
        ]),
      ),
    );
  }
}
