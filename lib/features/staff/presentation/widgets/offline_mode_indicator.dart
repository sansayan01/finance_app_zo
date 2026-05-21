import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/sync_providers.dart';

/// Offline mode indicator widget that shows sync status
/// Displays at the top of the screen when offline or syncing
class OfflineModeIndicator extends ConsumerWidget {
  final bool showPendingCount;

  const OfflineModeIndicator({
    super.key,
    this.showPendingCount = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnlineAsync = ref.watch(isOnlineProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        if (isOnline && syncStatus.pending == 0 && !syncStatus.isSyncing) {
          return const SizedBox.shrink();
        }

        return _buildIndicator(context, theme, isOnline, syncStatus);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildIndicator(
    BuildContext context,
    ThemeData theme,
    bool isOnline,
    SyncUIState syncStatus,
  ) {
    final (color, icon, message) = _getStatusInfo(isOnline, syncStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (syncStatus.isSyncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showPendingCount && syncStatus.pending > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${syncStatus.pending} pending',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (!isOnline || syncStatus.pending > 0)
              TextButton(
                onPressed: () => _showSyncOptions(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Sync'),
              ),
          ],
        ),
      ),
    );
  }

  (Color, IconData, String) _getStatusInfo(
      bool isOnline, SyncUIState syncStatus) {
    if (syncStatus.isSyncing) {
      return (Colors.blue, Icons.sync, 'Syncing data...');
    }

    if (!isOnline) {
      return (
        Colors.orange,
        Icons.wifi_off,
        'You are offline. Changes will sync when connected.'
      );
    }

    if (syncStatus.pending > 0) {
      return (
        Colors.amber,
        Icons.sync_problem,
        '${syncStatus.pending} operations pending sync'
      );
    }

    if (syncStatus.error != null) {
      return (Colors.red, Icons.error, 'Sync error: ${syncStatus.error}');
    }

    return (Colors.green, Icons.check_circle, 'All data synced');
  }

  void _showSyncOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final syncStatus = ref.watch(syncStatusProvider);
            final pendingOps = syncStatus.pending;

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildStatusRow(
                    context,
                    Icons.cloud,
                    'Last Sync',
                    syncStatus.lastSync != null
                        ? _formatTime(syncStatus.lastSync!)
                        : 'Never',
                  ),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    context,
                    Icons.pending_actions,
                    'Pending Operations',
                    pendingOps.toString(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: syncStatus.isSyncing
                          ? null
                          : () {
                              ref.read(syncStatusProvider.notifier).sync();
                              Navigator.pop(context);
                            },
                      icon: syncStatus.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        syncStatus.isSyncing ? 'Syncing...' : 'Sync Now',
                      ),
                    ),
                  ),
                  if (pendingOps > 0) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // Navigate to pending operations page
                          Navigator.pop(context);
                        },
                        child: const Text('View Pending Operations'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
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
      return '${diff.inDays}d ago';
    }
  }
}
