import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../providers/supabase_provider.dart';

final adminOrgListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final orgs = await client.from('organizations').select('id, name, slug, status, created_at').order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(orgs);
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(adminOrgListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.dashboard, size: 18),
            label: const Text('My Org'),
          ),
        ],
      ),
      body: orgsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orgs) {
          final totalOrgs = orgs.length;
          final activeOrgs = orgs.where((o) => o['status'] == 'active').length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Super Admin Panel', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              _buildStatsRow(theme, totalOrgs, activeOrgs),
              const SizedBox(height: 24),
              Text('Organizations (${orgs.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...orgs.map((org) => _buildOrgCard(context, theme, org)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, int total, int active) {
    return Row(
      children: [
        _statCard(theme, 'Organizations', total.toString(), Icons.business, Colors.indigo),
        _statCard(theme, 'Active', active.toString(), Icons.check_circle, Colors.green),
        _statCard(theme, 'Suspended', (total - active).toString(), Icons.pause_circle, Colors.orange),
        _statCard(theme, 'New', '0', Icons.fiber_new, Colors.blue),
      ].map((c) => Expanded(child: c)).toList(),
    );
  }

  Widget _statCard(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgCard(BuildContext context, ThemeData theme, Map<String, dynamic> org) {
    final status = org['status'] as String? ?? 'unknown';
    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green.shade50 : Colors.orange.shade50,
          child: Icon(
            isActive ? Icons.check_circle : Icons.pause_circle,
            color: isActive ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(org['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${org['slug']}  •  ${org['created_at']?.toString().substring(0, 10) ?? ''}'),
        trailing: Chip(
          label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
          backgroundColor: isActive ? Colors.green : Colors.orange,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onTap: () => context.go('/admin/org/${org['id']}'),
      ),
    );
  }
}
