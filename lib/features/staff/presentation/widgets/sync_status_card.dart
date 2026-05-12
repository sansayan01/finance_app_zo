import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/sync_providers.dart';
import 'sync_status_bar.dart' as sync_bar;

class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isOnlineAsync = ref.watch(isOnlineProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        if (isOnline && syncStatus.pending == 0 && !syncStatus.isSyncing) {
          return SizedBox(
            height: 44,
            child: sync_bar.SyncStatusBar(
              status: sync_bar.SyncStatus.synced,
              lastSyncAt: syncStatus.lastSync,
              onSyncTap: () => _triggerSync(ref),
            ),
          );
        }

        if (!isOnline) {
          return SizedBox(
            height: 44,
            child: sync_bar.SyncStatusBar(
              status: sync_bar.SyncStatus.offline,
              pendingCount: syncStatus.pending,
              onSyncTap: () => _triggerSync(ref),
            ),
          );
        }

        if (syncStatus.isSyncing) {
          return SizedBox(
            height: 44,
            child: sync_bar.SyncStatusBar(
              status: sync_bar.SyncStatus.syncing,
              pendingCount: syncStatus.pending,
            ),
          );
        }

        if (syncStatus.error != null) {
          return SizedBox(
            height: 44,
            child: sync_bar.SyncStatusBar(
              status: sync_bar.SyncStatus.error,
              pendingCount: syncStatus.pending,
              onSyncTap: () => _triggerSync(ref),
            ),
          );
        }

        return SizedBox(
          height: 44,
          child: sync_bar.SyncStatusBar(
            status: sync_bar.SyncStatus.pending,
            pendingCount: syncStatus.pending,
            onSyncTap: () => _triggerSync(ref),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _triggerSync(WidgetRef ref) {
    ref.read(syncStatusProvider.notifier).sync();
  }
}
