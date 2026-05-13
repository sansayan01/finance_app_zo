import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

final adminOrgDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, orgId) async {
  final client = ref.read(supabaseClientProvider);
  return client.from('organizations').select().eq('id', orgId).single();
});

class AdminOrgDetailPage extends ConsumerWidget {
  final String orgId;
  const AdminOrgDetailPage({super.key, required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminOrgDetailProvider(orgId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Organization Detail')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (org) {
          if (org == null) return const Center(child: Text('Not found'));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(org['name'] as String? ?? '', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _infoRow('Status', org['status'] as String? ?? ''),
              _infoRow('Slug', org['slug'] as String? ?? ''),
              _infoRow('Created', org['created_at'] as String? ?? ''),
              _infoRow('Max Branches', '${org['max_branches'] ?? 5}'),
              _infoRow('Max Staff', '${org['max_staff'] ?? 20}'),
              _infoRow('Max Members', '${org['max_members'] ?? 500}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _suspendOrg(context, orgId),
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Suspend'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteOrg(context, orgId),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _suspendOrg(BuildContext context, String id) async {
    try {
      final client = Supabase.instance.client;
      await client.from('organizations').update({
        'status': 'suspended',
      }).eq('id', id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization suspended')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteOrg(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Organization?'),
        content: const Text('This will permanently delete all data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final client = Supabase.instance.client;
        await client.from('organizations').delete().eq('id', id);
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
