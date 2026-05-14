import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/providers/super_admin_providers.dart';
import '../../../../core/widgets/async_value_widget.dart';

/// Organizations Management Page
class OrganizationsManagementPage extends ConsumerStatefulWidget {
  const OrganizationsManagementPage({super.key});

  @override
  ConsumerState<OrganizationsManagementPage> createState() => _OrganizationsManagementPageState();
}

class _OrganizationsManagementPageState extends ConsumerState<OrganizationsManagementPage> {
  final _searchController = TextEditingController();
  String _statusFilter = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Organizations'),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterDialog,
              ),
            ],
          ),
          
          // Search Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search organizations...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                ),
                onChanged: (_) => setState(() {}),
              ).animate().fadeIn().slideY(begin: -0.1),
            ),
          ),
          
          // Organizations List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: AsyncValueSliver(
              value: ref.watch(allOrganizationsProvider({
                'search': _searchController.text,
                'status': _statusFilter,
              })),
              builder: (organizations) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildOrgCard(context, organizations[index], isDark)
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: index * 50))
                      .slideX(begin: 0.1),
                  childCount: organizations.length,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrgDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Organization'),
      ),
    );
  }

  Widget _buildOrgCard(BuildContext context, Map<String, dynamic> org, bool isDark) {
    final status = org['status'] as String? ?? 'inactive';
    final createdAt = DateTime.tryParse(org['created_at'] ?? '') ?? DateTime.now();
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => context.push('/super-admin/organizations/${org['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Created ${DateFormat('MMM d, y').format(createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatItem(context, '${org['profiles']?[0]['count'] ?? 0}', 'Users', Icons.people),
                  const SizedBox(width: 24),
                  _buildStatItem(context, '${org['branches']?[0]['count'] ?? 0}', 'Branches', Icons.account_tree),
                  const SizedBox(width: 24),
                  _buildStatItem(context, '${org['members']?[0]['count'] ?? 0}', 'Members', Icons.people_outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Organizations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text('All'),
              value: '',
              // ignore: deprecated_member_use
              groupValue: _statusFilter,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() {
                _statusFilter = v ?? '';
                Navigator.pop(context);
              }),
            ),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text('Active'),
              value: 'active',
              // ignore: deprecated_member_use
              groupValue: _statusFilter,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() {
                _statusFilter = v ?? '';
                Navigator.pop(context);
              }),
            ),
            // ignore: deprecated_member_use
            RadioListTile<String>(
              title: const Text('Suspended'),
              value: 'suspended',
              // ignore: deprecated_member_use
              groupValue: _statusFilter,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() {
                _statusFilter = v ?? '';
                Navigator.pop(context);
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOrgDialog() {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    String plan = 'free';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  hintText: 'e.g. MicroFlow Global',
                ),
                onChanged: (v) {
                  // Auto-generate slug
                  setState(() {
                    slugController.text = v.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9-]'), '');
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: slugController,
                decoration: const InputDecoration(
                  labelText: 'Slug (URL Identifier)',
                  hintText: 'e.g. microflow-global',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: plan,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                ),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('Free')),
                  DropdownMenuItem(value: 'pro', child: Text('Pro')),
                  DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                ],
                onChanged: (v) => setState(() => plan = v ?? 'free'),
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
                if (nameController.text.isEmpty || slugController.text.isEmpty) {
                  return;
                }

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                
                final success = await ref.read(superAdminActionsProvider.notifier).createOrganization(
                  name: nameController.text,
                  slug: slugController.text,
                  plan: plan,
                );

                if (!mounted) return;
                
                if (success) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Organization created')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}


