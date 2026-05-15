import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/providers/super_admin_providers.dart';
import '../../data/models/super_admin_models.dart';

class FeatureFlagsPage extends ConsumerStatefulWidget {
  const FeatureFlagsPage({super.key});
  @override
  ConsumerState<FeatureFlagsPage> createState() => _FeatureFlagsPageState();
}

class _FeatureFlagsPageState extends ConsumerState<FeatureFlagsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);
    final flags = ref.watch(featureFlagsProvider);

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
                    D.header('Feature Flags', 'Control platform features', isDark),
                    FloatingActionButton.small(onPressed: _create, backgroundColor: D.accent, foregroundColor: Colors.white, child: const Icon(Icons.add)),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            flags.when(
              data: (f) => SliverPadding(
                padding: D.bodyBottomPad,
                sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => _flagCard(f[i], isDark, cardBg), childCount: f.length)),
              ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flagCard(FeatureFlag f, bool isDark, Color cardBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: D.card(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.name, style: D.titleStyle(isDark)),
            Text(f.key, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: D.muted(context))),
          ])),
          Switch(value: f.isEnabled, onChanged: (v) => _toggle(f.id, v), activeTrackColor: Colors.green),
        ]),
        if (f.description != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(f.description!, style: D.valueStyle(isDark))),
        const SizedBox(height: 10),
        Row(children: [
          _chip('${f.rolloutPercentage}%', Colors.blue),
          if (f.targetOrgs.isNotEmpty) ...[const SizedBox(width: 8), _chip('${f.targetOrgs.length} orgs', Colors.orange)],
          if (f.targetRoles.isNotEmpty) ...[const SizedBox(width: 8), _chip('${f.targetRoles.length} roles', Colors.purple)],
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)));
  }

  void _toggle(String id, bool v) async {
    await ref.read(superAdminActionsProvider.notifier).toggleFeatureFlag(id, v);
  }

  void _create() {
    final keyC = TextEditingController();
    final nameC = TextEditingController();
    final descC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Flag', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: keyC, decoration: const InputDecoration(labelText: 'Key', hintText: 'new_feature', prefixIcon: Icon(Icons.vpn_key), border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name', hintText: 'New Feature', prefixIcon: Icon(Icons.flag), border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (keyC.text.isEmpty || nameC.text.isEmpty) return;
            final flag = FeatureFlag(id: '', key: keyC.text, name: nameC.text, description: descC.text.isEmpty ? null : descC.text, createdAt: DateTime.now(), updatedAt: DateTime.now());
            final repo = ref.read(superAdminRepositoryProvider);
            await repo.upsertFeatureFlag(flag);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            ref.invalidate(featureFlagsProvider);
          }, style: ElevatedButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white), child: const Text('Create')),
        ],
      ),
    );
  }
}
