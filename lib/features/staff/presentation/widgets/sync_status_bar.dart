import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

enum SyncStatus {
  synced,
  syncing,
  pending,
  offline,
  error,
}

class SyncStatusBar extends StatelessWidget {
  final SyncStatus status;
  final int pendingCount;
  final VoidCallback? onSyncTap;
  final DateTime? lastSyncAt;

  const SyncStatusBar({
    super.key,
    required this.status,
    this.pendingCount = 0,
    this.onSyncTap,
    this.lastSyncAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onSyncTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getBackgroundColor(isDark),
              _getBackgroundColor(isDark).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor().withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getBorderColor().withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status icon
            _buildStatusIcon(),
            const SizedBox(width: 10),

            // Status text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getTextColor(),
                    ),
                  ),
                  if (lastSyncAt != null && status == SyncStatus.synced)
                    Text(
                      'Last sync: ${_formatTime(lastSyncAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),

            // Pending count or action
            if (pendingCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else if (status == SyncStatus.synced)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'All synced',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // Sync button
            if (status == SyncStatus.pending || status == SyncStatus.offline)
              Icon(
                Icons.sync_rounded,
                color: _getTextColor(),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (status) {
      case SyncStatus.synced:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.greenAccent,
            size: 16,
          ),
        );
      case SyncStatus.syncing:
        return SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        );
      case SyncStatus.pending:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.pending_outlined,
            color: Colors.orangeAccent,
            size: 16,
          ),
        );
      case SyncStatus.offline:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.wifi_off_rounded,
            color: Colors.redAccent,
            size: 16,
          ),
        );
      case SyncStatus.error:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 16,
          ),
        );
    }
  }

  Color _getBackgroundColor(bool isDark) {
    if (isDark) return const Color(0xFF1A1A2E).withValues(alpha: 0.5);
    return Colors.white.withValues(alpha: 0.9);
  }

  Color _getBorderColor() {
    switch (status) {
      case SyncStatus.synced:
        return Colors.greenAccent;
      case SyncStatus.syncing:
        return AppColors.primary;
      case SyncStatus.pending:
        return Colors.orangeAccent;
      case SyncStatus.offline:
      case SyncStatus.error:
        return Colors.redAccent;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case SyncStatus.synced:
        return Colors.greenAccent;
      case SyncStatus.syncing:
        return AppColors.primary;
      case SyncStatus.pending:
        return Colors.orangeAccent;
      case SyncStatus.offline:
      case SyncStatus.error:
        return Colors.redAccent;
    }
  }

  String _getStatusText() {
    switch (status) {
      case SyncStatus.synced:
        return 'All data synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.pending:
        return 'Sync pending';
      case SyncStatus.offline:
        return 'You\'re offline';
      case SyncStatus.error:
        return 'Sync failed';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
