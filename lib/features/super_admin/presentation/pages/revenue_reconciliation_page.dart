import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class RevenueReconciliationPage extends ConsumerWidget {
  const RevenueReconciliationPage({super.key});

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
                      D.header('Revenue Reconciliation',
                          'Payment matching & discrepancy management', isDark),
                      const SizedBox(height: 24),
                      Row(children: [
                        _stat(context, 'Expected', '₹12,45,000', Colors.blue,
                            cardBg),
                        const SizedBox(width: 10),
                        _stat(context, 'Received', '₹12,32,890', Colors.green,
                            cardBg),
                        const SizedBox(width: 10),
                        _stat(
                            context, 'Variance', '₹12,110', Colors.red, cardBg),
                      ]),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Pending Reconciliation', Icons.receipt_long, isDark),
                      const SizedBox(height: 14),
                      _invoiceCard(context, 'INV-2026-001', 'ABC Finance',
                          '₹45,000', 'Paid', Colors.green, cardBg),
                      _invoiceCard(context, 'INV-2026-002', 'XYZ Credit',
                          '₹85,000', 'Unpaid', Colors.orange, cardBg),
                      _invoiceCard(context, 'INV-2026-003', 'LMN Corp',
                          '₹1,20,000', 'Matched', Colors.green, cardBg),
                      _invoiceCard(context, 'INV-2026-004', 'PQR Bank',
                          '₹62,000', 'Discrepancy', Colors.red, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Monthly Trend', Icons.trending_up, isDark),
                      const SizedBox(height: 14),
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: D.card(context),
                          child: Column(children: [
                            _monthRow(context, 'January', '₹11,20,000',
                                '₹11,15,000', '99.5%'),
                            _monthRow(context, 'February', '₹11,80,000',
                                '₹11,72,000', '99.3%'),
                            _monthRow(context, 'March', '₹12,10,000',
                                '₹12,05,000', '99.6%'),
                            _monthRow(context, 'April', '₹12,45,000',
                                '₹12,32,890', '99.0%'),
                          ])),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _stat(
      BuildContext ctx, String label, String value, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: D.card(ctx),
            child: Column(children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: D.labelStyle(isDark))
            ])));
  }

  Widget _invoiceCard(BuildContext ctx, String inv, String org, String amount,
      String status, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: D.card(ctx),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(inv, style: D.titleStyle(isDark)),
                Text(org, style: D.labelStyle(isDark))
              ])),
          Text(amount,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(width: 12),
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
        ]));
  }

  Widget _monthRow(BuildContext ctx, String month, String expected,
      String actual, String rate) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 80, child: Text(month, style: D.valueStyle(isDark))),
          Expanded(
              child: Text('Expected: $expected', style: D.labelStyle(isDark))),
          Text('Actual: $actual', style: D.labelStyle(isDark)),
          const SizedBox(width: 8),
          Text(rate,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green)),
        ]));
  }
}
