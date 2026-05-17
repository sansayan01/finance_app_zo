import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});
  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  @override
  Widget build(BuildContext context) {
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
                      D.header('Notification Center',
                          'Multi-channel broadcast & analytics', isDark),
                      const SizedBox(height: 24),
                      Row(children: [
                        _channelCard(context, Icons.email, 'Email', '12.4k',
                            '92% open', Colors.blue, cardBg),
                        const SizedBox(width: 10),
                        _channelCard(context, Icons.sms, 'SMS', '8.2k',
                            '88% delivered', Colors.green, cardBg),
                        const SizedBox(width: 10),
                        _channelCard(context, Icons.notifications, 'Push',
                            '6.7k', '76% tapped', Colors.orange, cardBg),
                      ]),
                      const SizedBox(height: 24),
                      D.sectionTitle(
                          'Recent Broadcasts', Icons.campaign, isDark),
                      const SizedBox(height: 14),
                      _broadcast(context, 'System Update v2.5', 'All orgs',
                          '2h ago', 'Sent', Colors.green, cardBg),
                      _broadcast(context, 'Payment Reminder', '12 orgs',
                          '1d ago', 'Sent', Colors.green, cardBg),
                      _broadcast(context, 'Maintenance Notice', 'Enterprise',
                          '3d ago', 'Scheduled', Colors.orange, cardBg),
                      const SizedBox(height: 24),
                      D.sectionTitle('Templates', Icons.description, isDark),
                      const SizedBox(height: 14),
                      _template(context, 'Welcome Email', 'New org onboarding',
                          'Email', cardBg),
                      _template(context, 'Weekly Digest', 'Platform summary',
                          'Email', cardBg),
                      _template(context, 'Alert Notification',
                          'Critical alerts', 'SMS + Push', cardBg),
                    ]))),
          ],
        ),
      ),
    );
  }

  Widget _channelCard(BuildContext ctx, IconData icon, String label,
      String sent, String rate, Color color, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: D.card(ctx),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(sent,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A))),
        Text(label, style: D.labelStyle(isDark)),
        Text(rate, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ));
  }

  Widget _broadcast(BuildContext ctx, String title, String target, String time,
      String status, Color statusColor, Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: D.card(ctx),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: D.titleStyle(isDark)),
          Text('$target • $time', style: D.labelStyle(isDark)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor))),
      ]),
    );
  }

  Widget _template(BuildContext ctx, String name, String desc, String channel,
      Color cardBg) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: D.card(ctx),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: D.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.description, color: D.accent, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: D.titleStyle(isDark)),
          Text(desc, style: D.labelStyle(isDark)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text(channel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey))),
      ]),
    );
  }
}
