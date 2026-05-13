import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/providers/super_admin_providers.dart';

/// Audit Logs Page
class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  String? _actionFilter;
  String? _entityFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(auditLogsProvider({
      'action': _actionFilter,
      'entityType': _entityFilter,
      'limit': 200,
    }));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Audit Logs'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) => setState(() {
                  if (value.startsWith('action:')) {
                    _actionFilter = value.substring(7);
                    if (_actionFilter == 'all') _actionFilter = null;
                  } else if (value.startsWith('entity:')) {
                    _entityFilter = value.substring(7);
                    if (_entityFilter == 'all') _entityFilter = null;
                  }
                }),
                itemBuilder: (context) => [
                  const PopupMenuLabel(label: Text('Actions')),
                  const PopupMenuItem(value: 'action:all', child: Text('All Actions')),
                  const PopupMenuItem(value: 'action:create', child: Text('Create')),
                  const PopupMenuItem(value: 'action:update', child: Text('Update')),
                  const PopupMenuItem(value: 'action:delete', child: Text('Delete')),
                  const PopupMenuDivider(),
                  const PopupMenuLabel(label: Text('Entities')),
                  const PopupMenuItem(value: 'entity:all', child: Text('All Entities')),
                  const PopupMenuItem(value: 'entity:organization', child: Text('Organization')),
                  const PopupMenuItem(value: 'entity:user', child: Text('User')),
                  const PopupMenuItem(value: 'entity:loan', child: Text('Loan')),
                  const PopupMenuItem(value: 'entity:member', child: Text('Member')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _exportLogs,
              ),
            ],
          ),

          logsAsync.when(
            data: (logs) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLogCard(context, logs[index], isDark),
                  childCount: logs.length,
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

  Widget _buildLogCard(BuildContext context, dynamic log, bool isDark) {
    final action = log.action as String;
    final entityType = log.entityType as String;
    final createdAt = log.createdAt;
    final actionColor = _getActionColor(action);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActionIcon(action),
                color: actionColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: actionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          action.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: actionColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entityType,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, y • h:mm:ss a').format(createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _showLogDetails(log),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'login':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'login':
        return Icons.login;
      default:
        return Icons.history;
    }
  }

  void _showLogDetails(dynamic log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${log.action} ${log.entityType}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${log.id}'),
              const SizedBox(height: 8),
              Text('User: ${log.userId ?? 'System'}'),
              const SizedBox(height: 8),
              Text('Organization: ${log.orgId ?? 'N/A'}'),
              const SizedBox(height: 8),
              if (log.oldValues != null) ...[
                const Text('Old Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(log.oldValues.toString()),
                ),
              ],
              if (log.newValues != null) ...[
                const SizedBox(height: 8),
                const Text('New Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(log.newValues.toString()),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _exportLogs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }
}

class PopupMenuLabel extends PopupMenuEntry<Never> {
  final Widget label;

  const PopupMenuLabel({required this.label, super.key});

  @override
  double get height => 40;

  @override
  bool represents(Never? value) => false;

  @override
  State<PopupMenuLabel> createState() => _PopupMenuLabelState();
}

class _PopupMenuLabelState extends State<PopupMenuLabel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
        child: widget.label,
      ),
    );
  }
}
