import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});
  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final announcements = ref.watch(platformAnnouncementsProvider);

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
                    D.header('Announcements', 'Broadcast to platform users', isDark),
                    FloatingActionButton.small(onPressed: _create, backgroundColor: D.accent, foregroundColor: Colors.white, child: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            announcements.when(
              data: (a) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: a.isEmpty
                    ? SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(48), child: Column(children: [Icon(Icons.campaign_outlined, size: 48, color: D.dim(context)), const SizedBox(height: 12), Text('No announcements', style: D.subtitleStyle(isDark))]))))
                    : SliverList(delegate: SliverChildBuilderDelegate((_, i) => _card(a[i], isDark, cardBg), childCount: a.length)),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(dynamic a, bool isDark, Color cardBg) {
    final tc = a.type == 'warning' ? Colors.orange : a.type == 'critical' ? Colors.red : a.type == 'maintenance' ? Colors.purple : Colors.blue;
    final ti = a.type == 'warning' ? Icons.warning_amber : a.type == 'critical' ? Icons.error_outline : a.type == 'maintenance' ? Icons.build_outlined : Icons.info_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: D.card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(ti, color: tc, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: D.titleStyle(isDark)),
            Text(DateFormat('MMM d, y').format(a.createdAt), style: D.subtitleStyle(isDark)),
          ])),
          if (!a.isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: D.dim(context), borderRadius: BorderRadius.circular(6)), child: Text('DRAFT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: D.mutedColor(isDark)))),
        ]),
        const SizedBox(height: 12),
        Text(a.message, style: D.valueStyle(isDark)),
        const SizedBox(height: 10),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(a.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: tc))),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _edit(a);
              if (v == 'toggle') _toggle(a.id, !a.isActive);
              if (v == 'delete') _delete(a.id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text('Edit'), dense: true)),
              PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(a.isActive ? Icons.visibility_off : Icons.visibility, size: 18), title: Text(a.isActive ? 'Deactivate' : 'Activate'), dense: true)),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), dense: true)),
            ],
          ),
        ]),
      ]),
    );
  }

  void _create() {
    final titleC = TextEditingController();
    final msgC = TextEditingController();
    String type = 'info';
    String audience = 'all';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Announcement', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.title), border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: msgC, decoration: const InputDecoration(labelText: 'Message', prefixIcon: Icon(Icons.message), border: OutlineInputBorder()), maxLines: 3),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()), items: ['info', 'warning', 'critical', 'maintenance'].map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(), onChanged: (v) => setS(() => type = v ?? 'info')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: audience, decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()), items: ['all', 'admins', 'managers', 'agents'].map((a) => DropdownMenuItem(value: a, child: Text(a[0].toUpperCase() + a.substring(1)))).toList(), onChanged: (v) => setS(() => audience = v ?? 'all')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (titleC.text.isEmpty || msgC.text.isEmpty) return;
            await ref.read(superAdminActionsProvider.notifier).createAnnouncement(title: titleC.text, message: msgC.text, type: type, targetAudience: audience);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white), child: const Text('Create')),
        ],
      )),
    );
  }

  void _edit(dynamic a) {
    final titleC = TextEditingController(text: a.title);
    final msgC = TextEditingController(text: a.message);
    String type = a.type ?? 'info';
    String audience = a.targetAudience ?? 'all';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Announcement', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: msgC, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()), maxLines: 3),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()), items: ['info', 'warning', 'critical', 'maintenance'].map((t) => DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)))).toList(), onChanged: (v) => setS(() => type = v ?? 'info')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(initialValue: audience, decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()), items: ['all', 'admins', 'managers', 'agents'].map((a) => DropdownMenuItem(value: a, child: Text(a[0].toUpperCase() + a.substring(1)))).toList(), onChanged: (v) => setS(() => audience = v ?? 'all')),
        ])),
        actions: [
          TextButton(onPressed: () => _delete(a.id), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (titleC.text.isEmpty || msgC.text.isEmpty) return;
            await ref.read(superAdminActionsProvider.notifier).updateAnnouncement(id: a.id, title: titleC.text, message: msgC.text, type: type, targetAudience: audience);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white), child: const Text('Save')),
        ],
      )),
    );
  }

  void _toggle(String id, bool v) async {
    await ref.read(superAdminActionsProvider.notifier).updateAnnouncement(id: id, isActive: v);
  }

  void _delete(String id) async {
    await ref.read(superAdminActionsProvider.notifier).deleteAnnouncement(id);
    if (mounted) Navigator.pop(context);
  }
}
