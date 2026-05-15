import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});
  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final windows = ref.watch(maintenanceWindowsProvider);

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
                    D.header('Maintenance', 'Schedule downtime windows', isDark),
                    FloatingActionButton.small(onPressed: _create, backgroundColor: D.accent, foregroundColor: Colors.white, child: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            windows.when(
              data: (w) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: w.isEmpty
                    ? SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(48), child: Column(children: [Icon(Icons.build_outlined, size: 48, color: D.dim(context)), const SizedBox(height: 12), Text('No maintenance scheduled', style: D.subtitleStyle(isDark))]))))
                    : SliverList(delegate: SliverChildBuilderDelegate((_, i) => _card(w[i], isDark, cardBg), childCount: w.length)),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(dynamic w, bool isDark, Color cardBg) {
    final now = DateTime.now();
    final ongoing = now.isAfter(w.scheduledStart) && now.isBefore(w.scheduledEnd);
    final upcoming = w.scheduledStart.isAfter(now);
    final statusColor = ongoing ? Colors.orange : upcoming ? Colors.blue : D.mutedColor(isDark);
    final statusLabel = ongoing ? 'ONGOING' : upcoming ? 'UPCOMING' : 'COMPLETED';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(D.radius),
        border: Border.all(color: w.isActive ? Colors.orange.withValues(alpha: 0.3) : D.borderColor(isDark), width: w.isActive ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (w.isActive ? Colors.orange : D.mutedColor(isDark)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(D.radius)), child: Icon(Icons.build_outlined, color: w.isActive ? Colors.orange : D.mutedColor(isDark), size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.title, style: D.titleStyle(isDark)),
            Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ])),
          Switch(value: w.isActive, onChanged: (v) => _toggle(w.id, v), activeTrackColor: Colors.orange),
        ]),
        if (w.description != null) ...[const SizedBox(height: 10), Text(w.description!, style: D.valueStyle(isDark))],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: D.fill(context), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.schedule, size: 16, color: D.iconMuted(context)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Start: ${DateFormat('MMM d, y • h:mm a').format(w.scheduledStart)}', style: D.subtitleStyle(isDark)),
              Text('End: ${DateFormat('MMM d, y • h:mm a').format(w.scheduledEnd)}', style: D.subtitleStyle(isDark)),
            ])),
            Text('${w.duration.inHours}h', style: D.titleStyle(isDark)),
          ]),
        ),
        if (w.affectedServices.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 4, children: w.affectedServices.map<Widget>((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.purple)))).toList())],
      ]),
    );
  }

  void _toggle(String id, bool v) async {
    final repo = ref.read(superAdminRepositoryProvider);
    await repo.toggleMaintenanceMode(id, v);
    ref.invalidate(maintenanceWindowsProvider);
  }

  void _create() {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 2, minute: 0);
    int durationHours = 2;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Schedule Maintenance', style: TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', hintText: 'System Upgrade', prefixIcon: Icon(Icons.title), border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 14),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Start Date'), subtitle: Text(DateFormat('MMM d, y').format(startDate)), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setS(() => startDate = d); }),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Start Time'), subtitle: Text(startTime.format(context)), trailing: const Icon(Icons.access_time), onTap: () async { final t = await showTimePicker(context: context, initialTime: startTime); if (t != null) setS(() => startTime = t); }),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(initialValue: durationHours, decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()), items: [1, 2, 3, 4, 6, 8, 12, 24].map((h) => DropdownMenuItem(value: h, child: Text('$h ${h == 1 ? 'hour' : 'hours'}'))).toList(), onChanged: (v) => setS(() => durationHours = v ?? 2)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (titleC.text.isEmpty) return;
            final start = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
            await ref.read(superAdminActionsProvider.notifier).createMaintenanceWindow(title: titleC.text, description: descC.text.isEmpty ? null : descC.text, scheduledStart: start, scheduledEnd: start.add(Duration(hours: durationHours)));
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white), child: const Text('Schedule')),
        ],
      )),
    );
  }
}
