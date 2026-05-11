import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/sync_providers.dart';

class PendingOperationsPage extends ConsumerStatefulWidget {
  const PendingOperationsPage({super.key});

  @override
  ConsumerState<PendingOperationsPage> createState() => _PendingOperationsPageState();
}

class _PendingOperationsPageState extends ConsumerState<PendingOperationsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingOpsAsync = ref.watch(pendingOperationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Operations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: syncStatus.isSyncing
                ? null
                : () => ref.read(syncStatusProvider.notifier).sync(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(syncStatus, theme),
          Expanded(
            child: pendingOpsAsync.when(
              data: (ops) => ops.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildOperationsList(ops, theme),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SyncState syncStatus, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                'Pending',
                syncStatus.pending.toString(),
                Icons.pending_actions,
              ),
              _buildStatColumn(
                'Synced',
                syncStatus.success.toString(),
                Icons.check_circle,
              ),
              _buildStatColumn(
                'Failed',
                syncStatus.failed.toString(),
                Icons.error,
              ),
            ],
          ),
          if (syncStatus.lastSyncTime != null) ...[
            const SizedBox(height: 16),
            Text(
              'Last sync: ${_formatTime(syncStatus.lastSyncTime!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'All Synced!',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No pending operations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsList(List<dynamic> ops, ThemeData theme) {
    // Group by table
    final grouped = <String, List<dynamic>>{};
    for (final op in ops) {
      final table = op['table'] as String? ?? 'unknown';
      grouped.putIfAbsent(table, () => []).add(op);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length + 1,
      itemBuilder: (context, index) {
        if (index == grouped.length) {
          return _buildSyncAllButton(theme);
        }

        final table = grouped.keys.elementAt(index);
        final tableOps = grouped[table]!;

        return _buildTableGroup(table, tableOps, theme);
      },
    );
  }

  Widget _buildTableGroup(
    String table,
    List<dynamic> ops,
    ThemeData theme,
  ) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTableName(table),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${ops.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...ops.map((op) => _buildOperationItem(op, theme)),
        ],
      ),
    );
  }

  Widget _buildOperationItem(dynamic op, ThemeData theme) {
    final operation = op['operation'] as String? ?? 'unknown';
    final queuedAt = op['queued_at'] as String?;
    final attempts = op['attempts'] as int? ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getOperationColor(operation).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getOperationIcon(operation),
          color: _getOperationColor(operation),
          size: 20,
        ),
      ),
      title: Text(
        operation.toUpperCase(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        queuedAt != null
            ? 'Queued: ${_formatDateTime(queuedAt)}'
            : 'Unknown time',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attempts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: attempts >= 3 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$attempts attempts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: attempts >= 3 ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeOperation(op['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncAllButton(ThemeData theme) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: FilledButton.icon(
        onPressed: syncStatus.isSyncing
            ? null
            : () => ref.read(syncStatusProvider.notifier).sync(),
        icon: syncStatus.isSyncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.sync),
        label: Text(syncStatus.isSyncing ? 'Syncing...' : 'Sync All Now'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  String _formatTableName(String table) {
    switch (table) {
      case 'collections':
        return 'Collections';
      case 'staff_wallet':
        return 'Wallet Updates';
      case 'visit_logs':
        return 'Visit Logs';
      case 'staff_breaks':
        return 'Break Logs';
      case 'cash_deposits':
        return 'Cash Deposits';
      default:
        return table.replaceAll('_', ' ').split(' ').map((word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
    }
  }

  IconData _getOperationIcon(String operation) {
    switch (operation) {
      case 'insert':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      default:
        return Icons.sync;
    }
  }

  Color _getOperationColor(String operation) {
    switch (operation) {
      case 'insert':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(time);
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  void _removeOperation(String? id) {
    if (id != null) {
      // Show confirmation and remove
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Operation?'),
          content: const Text(
            'This will discard the pending operation. The data will not be synced to the server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // Remove operation
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    }
  }
}

// Provider for pending operations list
final pendingOperationsProvider = FutureProvider<List<dynamic>>((ref) async {
  // This would fetch from local database
  return [];
});
