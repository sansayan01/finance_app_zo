import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/sync_providers.dart';

class PendingOperationsPage extends ConsumerStatefulWidget {
  const PendingOperationsPage({super.key});

  @override
  ConsumerState<PendingOperationsPage> createState() => _PendingOperationsPageState();
}

class _PendingOperationsPageState extends ConsumerState<PendingOperationsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final syncStatus = ref.watch(syncStatusProvider);
    final pendingOpsAsync = ref.watch(pendingOperationsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : Colors.black87),
        ),
        title: const Text('Pending Operations', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          _buildSyncButton(syncStatus),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(pendingOperationsProvider); await ref.read(syncStatusProvider.notifier).refresh(); await Future.delayed(const Duration(milliseconds: 500)); },
        child: Column(
          children: [
            _buildSummaryCard(syncStatus, theme, isDark),
            Expanded(
              child: pendingOpsAsync.when(
                data: (ops) => ops.isEmpty
                    ? _buildEmptyState(theme, isDark)
                    : _buildOperationsList(ops, theme, isDark),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(SyncUIState syncStatus) {
    return GestureDetector(
      onTap: syncStatus.isSyncing ? null : () => ref.read(syncStatusProvider.notifier).sync(),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            syncStatus.isSyncing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.sync_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(syncStatus.isSyncing ? 'Syncing' : 'Sync', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(SyncUIState syncStatus, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCol('Pending', syncStatus.pending.toString(), Icons.pending_actions_rounded),
              _buildStatCol('Synced', syncStatus.success.toString(), Icons.check_circle_rounded),
              _buildStatCol('Failed', syncStatus.failed.toString(), Icons.error_outline_rounded),
            ],
          ),
          if (syncStatus.lastSync != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('Last sync: ${_formatTime(syncStatus.lastSync!)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStatCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success),
          ),
          const SizedBox(height: 20),
          Text('All Synced!', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          Text('No pending operations', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildOperationsList(List<dynamic> ops, ThemeData theme, bool isDark) {
    final grouped = <String, List<dynamic>>{};
    for (final op in ops) {
      final table = op['table'] as String? ?? 'unknown';
      grouped.putIfAbsent(table, () => []).add(op);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: grouped.length + 1,
      itemBuilder: (ctx, index) {
        if (index == grouped.length) return _buildSyncAllButton(theme);
        final table = grouped.keys.elementAt(index);
        return _buildTableGroup(table, grouped[table]!, theme, isDark, index);
      },
    );
  }

  Widget _buildTableGroup(String table, List<dynamic> ops, ThemeData theme, bool isDark, int groupIndex) {
    final icon = _getTableIcon(table);
    final color = _getTableColor(table);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 10),
                    Text(_formatTableName(table), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('${ops.length}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const Divider(height: 24),
            ...ops.asMap().entries.map((entry) => _buildOperationItem(entry.value, theme, isDark, entry.key)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (groupIndex * 80).ms).slideY(begin: 0.03, end: 0);
  }

  Widget _buildOperationItem(dynamic op, ThemeData theme, bool isDark, int index) {
    final operation = op['operation'] as String? ?? 'unknown';
    final queuedAt = op['queued_at'] as String?;
    final attempts = op['attempts'] as int? ?? 0;
    final opColor = _getOperationColor(operation);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: opColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_getOperationIcon(operation), color: opColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(operation.toUpperCase(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (queuedAt != null)
                  Text(_formatDateTime(queuedAt), style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          if (attempts > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (attempts >= 3 ? AppColors.error : AppColors.warning).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$attempts', style: TextStyle(color: attempts >= 3 ? AppColors.error : AppColors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          GestureDetector(
            onTap: () => _removeOperation(op['id']),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 30).ms);
  }

  Widget _buildSyncAllButton(ThemeData theme) {
    final syncStatus = ref.watch(syncStatusProvider);
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton.icon(
        onPressed: syncStatus.isSyncing ? null : () => ref.read(syncStatusProvider.notifier).sync(),
        icon: syncStatus.isSyncing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.sync_rounded, size: 20),
        label: Text(syncStatus.isSyncing ? 'Syncing...' : 'Sync All Now', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  IconData _getTableIcon(String table) {
    switch (table) {
      case 'collections': return Icons.payments_rounded;
      case 'staff_wallet': return Icons.account_balance_wallet_rounded;
      case 'visit_logs': return Icons.route_rounded;
      case 'staff_breaks': return Icons.coffee_rounded;
      case 'cash_deposits': return Icons.account_balance_rounded;
      default: return Icons.sync_rounded;
    }
  }

  Color _getTableColor(String table) {
    switch (table) {
      case 'collections': return AppColors.primary;
      case 'staff_wallet': return AppColors.success;
      case 'visit_logs': return AppColors.info;
      case 'staff_breaks': return Colors.orangeAccent;
      case 'cash_deposits': return AppColors.indigo;
      default: return Colors.grey;
    }
  }

  IconData _getOperationIcon(String operation) {
    switch (operation) {
      case 'insert': return Icons.add_circle_outline_rounded;
      case 'update': return Icons.edit_outlined;
      case 'delete': return Icons.delete_outline_rounded;
      default: return Icons.sync_rounded;
    }
  }

  Color _getOperationColor(String operation) {
    switch (operation) {
      case 'insert': return AppColors.success;
      case 'update': return AppColors.info;
      case 'delete': return AppColors.error;
      default: return Colors.grey;
    }
  }

  String _formatTableName(String table) {
    switch (table) {
      case 'collections': return 'Collections';
      case 'staff_wallet': return 'Wallet Updates';
      case 'visit_logs': return 'Visit Logs';
      case 'staff_breaks': return 'Break Logs';
      case 'cash_deposits': return 'Cash Deposits';
      default: return table.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(time);
  }

  String _formatDateTime(String isoString) {
    try { return DateFormat('MMM d, h:mm a').format(DateTime.parse(isoString).toLocal()); }
    catch (_) { return isoString; }
  }

  void _removeOperation(String? id) {
    if (id == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove Operation?'),
        content: const Text('This will discard the pending operation permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

final pendingOperationsProvider = FutureProvider<List<dynamic>>((ref) async {
  return [];
});
