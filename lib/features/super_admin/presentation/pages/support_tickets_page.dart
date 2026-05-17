import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key});
  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final tickets = ref.watch(supportTicketsProvider({'status': _status}));

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
                      D.header('Support', 'Manage support tickets', isDark),
                      const SizedBox(height: 20),
                      tickets.when(
                        data: (t) => _stats(t, isDark, cardBg),
                        loading: () => const SizedBox(height: 70),
                        error: (_, __) => const SizedBox(height: 70),
                      ),
                      const SizedBox(height: 16),
                      _filterRow(isDark),
                      const SizedBox(height: 20),
                    ]),
              ),
            ),
            tickets.when(
              data: (t) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (_, i) => _ticketCard(t[i], isDark, cardBg),
                        childCount: t.length)),
              ),
              loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(List<dynamic> t, bool isDark, Color cardBg) {
    return Row(children: [
      _statCard('Open', t.where((x) => x.status == 'open').length, Colors.red,
          isDark, cardBg),
      const SizedBox(width: 10),
      _statCard('In Progress', t.where((x) => x.status == 'in_progress').length,
          Colors.orange, isDark, cardBg),
      const SizedBox(width: 10),
      _statCard('Resolved', t.where((x) => x.status == 'resolved').length,
          Colors.green, isDark, cardBg),
      const SizedBox(width: 10),
      _statCard('Critical', t.where((x) => x.priority == 'critical').length,
          Colors.red.shade700, isDark, cardBg),
    ]);
  }

  Widget _statCard(
      String label, int count, Color color, bool isDark, Color cardBg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(D.radius),
            border: Border.all(color: D.border(context))),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: D.labelStyle(isDark)),
        ]),
      ),
    );
  }

  Widget _filterRow(bool isDark) {
    final f = ['All', 'open', 'in_progress', 'resolved'];
    return Row(
        children: f.map((s) {
      final sel = (s == 'All' && _status == null) || _status == s;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _status = s == 'All' ? null : s),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? D.accent.withValues(alpha: 0.1) : Colors.transparent,
              border: Border(
                  bottom: BorderSide(
                      color: sel ? D.accent : Colors.transparent, width: 2)),
            ),
            child: Text(
                s == 'All'
                    ? 'All'
                    : s
                        .replaceAll('_', ' ')
                        .split(' ')
                        .map((e) => e[0].toUpperCase() + e.substring(1))
                        .join(' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sel ? D.accent : D.muted(context))),
          ),
        ),
      );
    }).toList());
  }

  Widget _ticketCard(dynamic t, bool isDark, Color cardBg) {
    final pc = t.priority == 'critical'
        ? Colors.red
        : t.priority == 'high'
            ? Colors.orange
            : t.priority == 'normal'
                ? Colors.blue
                : Colors.green;
    final sc = t.status == 'open'
        ? Colors.red
        : t.status == 'in_progress'
            ? Colors.orange
            : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: D.card(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(D.radius),
          onTap: () => _details(t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: pc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(t.priority.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: pc))),
                const SizedBox(width: 8),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(t.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sc))),
                const Spacer(),
                Text(DateFormat('MMM d').format(t.createdAt),
                    style: D.subtitleStyle(isDark)),
              ]),
              const SizedBox(height: 12),
              Text(t.subject, style: D.titleStyle(isDark)),
              if (t.description != null) ...[
                const SizedBox(height: 6),
                Text(t.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: D.valueStyle(isDark))
              ],
            ]),
          ),
        ),
      ),
    );
  }

  void _details(dynamic t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (ctx, sc) => Container(
                decoration: BoxDecoration(
                  color: D.surface(context),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                        child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                                color: D.dim(context),
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),
                    Text(t.subject, style: D.h2(isDark)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () => _update(t.id, 'in_progress'),
                              icon: const Icon(Icons.engineering, size: 18),
                              label: const Text('Take'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () => _update(t.id, 'resolved'),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Resolve'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))))),
                    ]),
                    if (t.description != null) ...[
                      const SizedBox(height: 20),
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: D.fill(context),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(t.description!,
                              style: const TextStyle(fontSize: 14)))
                    ],
                    const SizedBox(height: 20),
                    const Text('Messages',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if ((t.messages as List?)?.isEmpty ?? true)
                      Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No messages',
                                  style: D.subtitleStyle(isDark))))
                    else
                      ...t.messages.map<Widget>((m) {
                        final msg = m['content'] ?? '';
                        final time = DateFormat('MMM d, h:mm a')
                            .format(DateTime.parse(m['created_at']));
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: D.fill(context),
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(msg,
                                            style:
                                                const TextStyle(fontSize: 13))),
                                    if (m['is_internal'] == true)
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: const Text('Internal',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange)))
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(time, style: D.subtitleStyle(isDark)),
                                ]));
                      }),
                  ],
                ),
              ),
            ));
  }

  void _update(String id, String status) async {
    await ref
        .read(superAdminActionsProvider.notifier)
        .updateTicketStatus(id, status);
    if (mounted) Navigator.pop(context);
  }
}
