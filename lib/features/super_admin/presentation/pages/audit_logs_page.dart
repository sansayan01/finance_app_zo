import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});
  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final logs = ref.watch(auditLogsProvider({'limit': 200}));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    D.header('Audit Logs', 'Track all system changes', isDark),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting audit logs...'))),
                      style: IconButton.styleFrom(backgroundColor: cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(D.radius), side: BorderSide(color: D.border(context)))),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
            logs.when(
              data: (l) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => _logCard(l[i], isDark, cardBg), childCount: l.length)),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logCard(dynamic l, bool isDark, Color cardBg) {
    final ac = l.action == 'create' ? Colors.green : l.action == 'update' ? Colors.blue : l.action == 'delete' ? Colors.red : Colors.grey;
    final ai = l.action == 'create' ? Icons.add_circle_outline : l.action == 'update' ? Icons.edit_outlined : l.action == 'delete' ? Icons.delete_outline : Icons.history;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(D.radius), border: Border.all(color: D.borderColor(isDark).withValues(alpha: 0.6))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(D.radius),
          onTap: () => _details(l),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ac.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(ai, color: ac, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ac.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(l.action.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ac))),
                const SizedBox(width: 8),
                Text(l.entityType, style: D.valueStyle(isDark)),
              ]),
              Text(DateFormat('MMM d, y • h:mm a').format(l.createdAt), style: D.subtitleStyle(isDark)),
            ])),
            Icon(Icons.chevron_right, size: 18, color: D.dim(context)),
          ]),
        ),
      ),
    );
  }

  void _details(dynamic l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Audit Log Detail', style: D.h2(isDark)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailLine('Entity', '${l.entityType} (${l.entityId ?? 'N/A'})', isDark),
          _detailLine('Action', l.action, isDark),
          _detailLine('User', l.userId ?? 'System', isDark),
          _detailLine('Organization', l.orgId ?? 'N/A', isDark),
          _detailLine('Date', DateFormat('MMM d, y • h:mm a').format(l.createdAt), isDark),
          if (l.oldValues != null && (l.oldValues as Map).isNotEmpty) ...[const SizedBox(height: 8), Text('Old Values:', style: D.labelStyle(isDark)), Text('${l.oldValues}', style: D.valueStyle(isDark))],
          if (l.newValues != null && (l.newValues as Map).isNotEmpty) ...[const SizedBox(height: 8), Text('New Values:', style: D.labelStyle(isDark)), Text('${l.newValues}', style: D.valueStyle(isDark))],
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _detailLine(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: D.labelStyle(isDark))),
        Expanded(child: Text(value, style: D.valueStyle(isDark))),
      ]),
    );
  }
}
