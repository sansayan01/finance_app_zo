import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/super_admin_providers.dart';
import '../../data/models/super_admin_models.dart';

/// Feature Flags Management Page
class FeatureFlagsPage extends ConsumerStatefulWidget {
  const FeatureFlagsPage({super.key});

  @override
  ConsumerState<FeatureFlagsPage> createState() => _FeatureFlagsPageState();
}

class _FeatureFlagsPageState extends ConsumerState<FeatureFlagsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flagsAsync = ref.watch(featureFlagsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Feature Flags'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreateFlagDialog,
              ),
            ],
          ),

          // Description
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                color: Colors.blue.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Control platform features globally or per organization',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Flags List
          flagsAsync.when(
            data: (flags) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFlagCard(context, flags[index], isDark),
                  childCount: flags.length,
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagCard(BuildContext context, FeatureFlag flag, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flag.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flag.key,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: flag.isEnabled,
                  onChanged: (value) => _toggleFlag(flag.id, value),
                  activeColor: Colors.green,
                ),
              ],
            ),
            if (flag.description != null) ...[
              const SizedBox(height: 12),
              Text(
                flag.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('${flag.rolloutPercentage}% rollout'),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                if (flag.targetOrgs.isNotEmpty)
                  Chip(
                    label: Text('${flag.targetOrgs.length} orgs'),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                if (flag.targetRoles.isNotEmpty)
                  Chip(
                    label: Text('${flag.targetRoles.length} roles'),
                    backgroundColor: Colors.purple.withOpacity(0.1),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  void _toggleFlag(String flagId, bool isEnabled) async {
    final success = await ref.read(superAdminActionsProvider.notifier).toggleFeatureFlag(flagId, isEnabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Feature ${isEnabled ? 'enabled' : 'disabled'}' 
              : 'Failed to update feature flag'),
        ),
      );
    }
  }

  void _showCreateFlagDialog() {
    final keyController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Feature Flag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Key',
                hintText: 'e.g., new_dashboard',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., New Dashboard',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (keyController.text.isEmpty || nameController.text.isEmpty) {
                return;
              }

              final flag = FeatureFlag(
                id: '',
                key: keyController.text,
                name: nameController.text,
                description: descController.text.isEmpty ? null : descController.text,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              final repo = ref.read(superAdminRepositoryProvider);
              final success = await repo.upsertFeatureFlag(flag);

              if (mounted) {
                Navigator.pop(context);
                ref.invalidate(featureFlagsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                        ? 'Feature flag created' 
                        : 'Failed to create feature flag'),
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
