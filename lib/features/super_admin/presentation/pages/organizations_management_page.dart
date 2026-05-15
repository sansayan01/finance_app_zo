import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../data/providers/super_admin_providers.dart';

class OrganizationsManagementPage extends ConsumerStatefulWidget {
  const OrganizationsManagementPage({super.key});
  @override
  ConsumerState<OrganizationsManagementPage> createState() => _OrganizationsManagementPageState();
}

class _OrganizationsManagementPageState extends ConsumerState<OrganizationsManagementPage> {
  final _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  D.header('Organizations', 'Manage all organizations on the platform', isDark),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _search,
                    decoration: D.searchInput(context, _search, () { _search.clear(); setState(() {}); }),
                    style: TextStyle(fontSize: 14, color: D.text(context)),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _filterRow(isDark),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            SliverPadding(
              padding: D.bodyBottomPad,
              sliver: AsyncValueSliver(
                value: ref.watch(allOrganizationsProvider({'search': _search.text, 'status': _filter})),
                builder: (orgs) => SliverList(delegate: SliverChildBuilderDelegate((_, i) => _orgCard(orgs[i], isDark, cardBg, i), childCount: orgs.length)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: D.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterRow(bool isDark) {
    final filters = ['All', 'Active', 'Suspended', 'Inactive'];
    return Row(children: filters.map((f) {
      final sel = (f == 'All' && _filter.isEmpty) || _filter == f.toLowerCase();
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = f == 'All' ? '' : f.toLowerCase()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? D.accent.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? D.accent.withValues(alpha: 0.3) : D.borderColor(isDark)),
            ),
            child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? D.accent : D.muted(context))),
          ),
        ),
      );
    }).toList());
  }

  Widget _orgCard(Map<String, dynamic> org, bool isDark, Color cardBg, int i) {
    final status = org['status'] as String? ?? 'inactive';
    final active = status == 'active';
    final c = active ? Colors.green : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: D.card(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(D.radius),
          onTap: () => context.push('/super-admin/organizations/${org['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(D.radius)),
                child: Icon(Icons.business, color: c, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(org['name'] as String? ?? '', style: D.titleStyle(isDark)),
                const SizedBox(height: 3),
                Text('${org['slug'] ?? ''}  ·  ${org['plan'] ?? 'free'}', style: D.subtitleStyle(isDark)),
              ])),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: D.dim(context)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _create() {
    final nameC = TextEditingController();
    final slugC = TextEditingController();
    String plan = 'free';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Organization', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.business), border: OutlineInputBorder()), onChanged: (v) => setS(() => slugC.text = v.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), ''))),
          const SizedBox(height: 16),
          TextField(controller: slugC, decoration: const InputDecoration(labelText: 'Slug', prefixIcon: Icon(Icons.link), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: plan, decoration: const InputDecoration(labelText: 'Plan', prefixIcon: Icon(Icons.workspace_premium), border: OutlineInputBorder()), items: ['free', 'pro', 'enterprise'].map((p) => DropdownMenuItem(value: p, child: Text(p[0].toUpperCase() + p.substring(1)))).toList(), onChanged: (v) => setS(() => plan = v ?? 'free')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (nameC.text.isEmpty || slugC.text.isEmpty) return;
            await ref.read(superAdminActionsProvider.notifier).createOrganization(name: nameC.text, slug: slugC.text, plan: plan);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: D.accent, foregroundColor: Colors.white), child: const Text('Create')),
        ],
      )),
    );
  }
}
