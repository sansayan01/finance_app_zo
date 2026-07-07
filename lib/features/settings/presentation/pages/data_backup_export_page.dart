import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/org_provider.dart';
import '../../../../core/utils/error_formatter.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/backup_export_provider.dart';
import '../../data/providers/google_drive_provider.dart';
import '../../data/providers/restore_backup_provider.dart';
import '../../data/services/backup_export_service.dart';
import '../../data/services/google_drive_service.dart';

class DataBackupExportPage extends ConsumerStatefulWidget {
  const DataBackupExportPage({super.key});

  @override
  ConsumerState<DataBackupExportPage> createState() =>
      _DataBackupExportPageState();
}

class _DataBackupExportPageState extends ConsumerState<DataBackupExportPage> {
  @override
  void initState() {
    super.initState();
    // Check for OAuth redirect callback on web
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRedirect();
    });
  }

  Future<void> _checkForRedirect() async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return;
    try {
      final service = ref.read(googleDriveServiceProvider);
      final handled = await service.checkForRedirectCode(orgId);
      if (handled && mounted) {
        ref.invalidate(driveConnectionProvider);
        showSuccessSnackBar(context, 'Google Drive connected successfully!');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final connection = ref.watch(driveConnectionProvider);
    final configReady = ref.watch(driveClientIdConfiguredProvider);
    final counts = ref.watch(categoryCountsProvider);
    final totalRecords = ref.watch(totalRecordCountProvider);
    final backupProgress = ref.watch(backupProgressProvider);
    final restoreProgress = ref.watch(restoreProgressProvider);

    final isConnected = connection.valueOrNull?.connected == true;
    final isBackingUp = backupProgress.status == BackupProgress.generating ||
        backupProgress.status == BackupProgress.fetching;
    final isRestoring = restoreProgress.status != RestoreProgress.idle &&
        restoreProgress.status != RestoreProgress.done &&
        restoreProgress.status != RestoreProgress.failed;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Data Backup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ─── HEADER ──────────────────────────────────────
                  _buildHeader(theme),
                  const SizedBox(height: 24),

                  // ─── HERO STATS ──────────────────────────────────
                  _buildHeroStats(theme, counts, totalRecords),
                  const SizedBox(height: 24),

                  // ─── BACKUP PROGRESS ─────────────────────────────
                  if (isBackingUp) ...[
                    _buildBackupProgressCard(theme, backupProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── RESTORE PROGRESS ────────────────────────────
                  if (isRestoring) ...[
                    _buildRestoreProgressCard(theme, restoreProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── RESTORE RESULT ──────────────────────────────
                  if (restoreProgress.status == RestoreProgress.done &&
                      restoreProgress.result != null) ...[
                    _buildRestoreResultCard(theme, restoreProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── CONNECTION + BACKUP CARD ────────────────────
                  _buildConnectionCard(
                    theme,
                    connection,
                    configReady,
                    orgId,
                    user?.fullName ?? 'Admin',
                    isBackingUp,
                    isRestoring,
                  ),
                  const SizedBox(height: 28),

                  // ─── DRIVE BACKUPS LIST (when connected) ─────────
                  if (isConnected) ...[
                    _buildDriveBackupsSection(theme, orgId),
                    const SizedBox(height: 28),
                  ],

                  // ─── LOCAL EXPORT HISTORY ────────────────────────
                  _buildLocalHistorySection(theme),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Google Drive Backup',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Back up and restore your organization data via Google Drive.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }

  // ─── HERO STATS ──────────────────────────────────────────────────────
  Widget _buildHeroStats(
    ThemeData theme,
    AsyncValue<Map<String, int>> counts,
    int totalRecords,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme: theme,
            icon: Icons.storage_rounded,
            label: 'Total Records',
            value: counts.whenOrNull(data: (_) => _formatNumber(totalRecords)) ?? '...',
            gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            icon: Icons.table_rows_rounded,
            label: 'Categories',
            value: '${kBackupCategories.length}',
            gradient: [const Color(0xFF10B981), const Color(0xFF14B8A6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            icon: Icons.cloud_done_rounded,
            label: 'Format',
            value: 'JSON',
            gradient: [const Color(0xFFF59E0B), const Color(0xFFF97316)],
          ),
        ),
      ],
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradient[0].withValues(alpha: 0.08), gradient[1].withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gradient[0].withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: gradient[0]), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  // ─── BACKUP PROGRESS ─────────────────────────────────────────────────
  Widget _buildBackupProgressCard(ThemeData theme, BackupProgressState progress) {
    final color = switch (progress.status) {
      BackupProgress.failed => Colors.red,
      BackupProgress.done => Colors.green,
      _ => AppColors.primary,
    };
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (progress.status == BackupProgress.generating || progress.status == BackupProgress.fetching)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(color)))
            else
              Icon(progress.status == BackupProgress.done ? Icons.check_circle_rounded : Icons.error_rounded, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(progress.step, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color))),
            if (progress.fileSize != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(progress.fileSize!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
          ]),
          if (progress.status == BackupProgress.generating || progress.status == BackupProgress.fetching) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress.progress, minHeight: 6, backgroundColor: theme.dividerColor.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color))),
            const SizedBox(height: 6),
            Text('${(progress.progress * 100).toInt()}%', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ─── RESTORE PROGRESS ────────────────────────────────────────────────
  Widget _buildRestoreProgressCard(ThemeData theme, RestoreProgressState progress) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(progress.step, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary))),
            if (progress.totalTables > 0)
              Text('${progress.currentTable}/${progress.totalTables}', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress.progress, minHeight: 6, backgroundColor: theme.dividerColor.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(AppColors.primary))),
          const SizedBox(height: 6),
          Text('${(progress.progress * 100).toInt()}%', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ─── RESTORE RESULT ──────────────────────────────────────────────────
  Widget _buildRestoreResultCard(ThemeData theme, RestoreProgressState progress) {
    final result = progress.result!;
    final hasErrors = result.tablesFailed > 0;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(hasErrors ? Icons.warning_rounded : Icons.check_circle_rounded, color: hasErrors ? Colors.orange : Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasErrors ? 'Restore completed with warnings' : 'Restore Complete!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: hasErrors ? Colors.orange.shade700 : Colors.green.shade700)),
                  const SizedBox(height: 4),
                  Text('${result.totalRecords} records restored across ${result.tablesRestored} tables', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
                  if (hasErrors) Text('${result.tablesFailed} table(s) failed', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                ],
              ),
            ),
          ]),
          if (hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withValues(alpha: 0.15))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.errors.take(5).map((e) => Text('• $e', style: TextStyle(fontSize: 11, color: Colors.red.shade700))).toList(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ─── CONNECTION + BACKUP CARD ────────────────────────────────────────
  Widget _buildConnectionCard(
    ThemeData theme,
    AsyncValue<DriveConnectionState> connectionAsync,
    bool configReady,
    String? orgId,
    String adminName,
    bool isBackingUp,
    bool isRestoring,
  ) {
    final connection = connectionAsync.valueOrNull;
    final isConnected = connection?.connected == true;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isConnected
                    ? [Colors.green.shade600, Colors.green.shade400]
                    : [Colors.grey.shade400, Colors.grey.shade300]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isConnected ? 'Google Drive Connected' : 'Not Connected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isConnected ? Colors.green.shade700 : null)),
                  Text(isConnected ? '${connection!.email}' : 'Connect your Google account to enable backups',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),

          if (!configReady)
            _buildWarningCard(theme, 'Google Client ID not configured', 'Add GOOGLE_WEB_CLIENT_ID to your .env file.')
          else if (!isConnected)
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _connectDrive(orgId),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                label: const Text('Connect Google Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              ),
            )
          else ...[
            // Backup button
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: (isBackingUp || isRestoring) ? null : () => _triggerBackup(orgId, adminName),
                icon: isBackingUp
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, size: 20),
                label: Text(isBackingUp ? 'Backing Up...' : 'Back Up Now', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              ),
            ),
            const SizedBox(height: 10),
            // Disconnect / Switch account
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isBackingUp || isRestoring) ? null : () => _disconnectDrive(orgId),
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isBackingUp || isRestoring) ? null : () => _switchAccount(orgId),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Switch Account', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ]),
          ],
        ],
      ),
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildWarningCard(ThemeData theme, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(Icons.warning_rounded, color: Colors.orange.shade700, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
        ])),
      ]),
    );
  }

  // ─── DRIVE BACKUPS LIST ──────────────────────────────────────────────
  Widget _buildDriveBackupsSection(ThemeData theme, String? orgId) {
    final driveBackups = ref.watch(driveBackupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('GOOGLE DRIVE BACKUPS', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: () => ref.invalidate(driveBackupsProvider),
            child: Row(children: [
              Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text('Refresh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary.withValues(alpha: 0.6))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        driveBackups.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          error: (e, _) => GlassCard(padding: const EdgeInsets.all(24), child: Center(child: Text('Error: ${errorFormatter(e)}'))),
          data: (files) {
            if (files.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(36),
                child: Center(child: Column(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.primary.withValues(alpha: 0.4))),
                  const SizedBox(height: 16),
                  Text('No backups on Drive', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
                  const SizedBox(height: 4),
                  Text('Create your first backup above', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3))),
                ])),
              );
            }
            return GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < files.length; i++) ...[
                  _buildDriveBackupItem(theme, files[i], orgId),
                  if (i < files.length - 1) Divider(height: 1, indent: 20, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.1)),
                ],
              ]),
            );
          },
        ),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildDriveBackupItem(ThemeData theme, Map<String, dynamic> file, String? orgId) {
    final fileName = file['name'] as String? ?? 'Unknown';
    final fileId = file['id'] as String?;
    final createdTime = file['createdTime'] as String?;
    final sizeBytes = int.tryParse(file['size']?.toString() ?? '') ?? 0;

    return InkWell(
      onTap: fileId == null ? null : () => _showRestoreConfirmDialog(file, orgId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.description_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  if (createdTime != null) Text(_formatDriveDate(createdTime), style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4))),
                  if (sizeBytes > 0) Text(' · ${_formatBytes(sizeBytes)}', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4))),
                ]),
              ],
            ),
          ),
          Icon(Icons.restore_rounded, size: 18, color: AppColors.primary.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  // ─── LOCAL EXPORT HISTORY ────────────────────────────────────────────
  Widget _buildLocalHistorySection(ThemeData theme) {
    final history = ref.watch(exportHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EXPORT HISTORY', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 12),
        history.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          error: (e, _) => GlassCard(padding: const EdgeInsets.all(24), child: Center(child: Text('Error: ${errorFormatter(e)}'))),
          data: (items) {
            if (items.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(36),
                child: Center(child: Column(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.history_rounded, size: 28, color: AppColors.primary.withValues(alpha: 0.4))),
                  const SizedBox(height: 16),
                  Text('No export history', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5))),
                ])),
              );
            }
            return GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < items.length && i < 10; i++) ...[
                  _buildHistoryItem(theme, items[i]),
                  if (i < items.length - 1 && i < 9) Divider(height: 1, indent: 20, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.1)),
                ],
              ]),
            );
          },
        ),
      ],
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildHistoryItem(ThemeData theme, Map<String, dynamic> item) {
    final status = item['status'] as String? ?? 'unknown';
    final format = (item['format'] as String? ?? 'json').toUpperCase();
    final createdAt = item['created_at'] as String?;
    final statusColor = switch (status) { 'completed' => Colors.green, 'pending' => Colors.orange, 'failed' => Colors.red, _ => Colors.grey };
    final statusIcon = switch (status) { 'completed' => Icons.check_circle_rounded, 'pending' => Icons.schedule_rounded, 'failed' => Icons.error_rounded, _ => Icons.help_outline_rounded };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(statusIcon, color: statusColor, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Organization Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(format, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary))),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
            if (createdAt != null) Text(' · ${_relativeDate(createdAt)}', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4))),
          ]),
        ])),
      ]),
    );
  }

  // ─── ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _connectDrive(String? orgId) async {
    if (orgId == null) return;
    try {
      final service = ref.read(googleDriveServiceProvider);
      await service.signIn(orgId);
      ref.invalidate(driveConnectionProvider);
      ref.invalidate(driveBackupsProvider);
      if (mounted) showSuccessSnackBar(context, 'Google Drive connected successfully!');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('__PENDING_REDIRECT__')) return; // Web redirect in progress
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _disconnectDrive(String? orgId) async {
    if (orgId == null) return;
    try {
      final service = ref.read(googleDriveServiceProvider);
      await service.signOut(orgId);
      ref.invalidate(driveConnectionProvider);
      ref.invalidate(driveBackupsProvider);
      if (mounted) showSuccessSnackBar(context, 'Google Drive disconnected.');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _switchAccount(String? orgId) async {
    if (orgId == null) return;
    // Disconnect first, then reconnect with different account
    await _disconnectDrive(orgId);
    await Future.delayed(const Duration(milliseconds: 300));
    await _connectDrive(orgId);
  }

  Future<void> _triggerBackup(String? orgId, String adminName) async {
    if (orgId == null) return;
    final result = await ref.read(driveBackupTriggerProvider.notifier).triggerBackup(
      orgId: orgId,
      orgName: adminName,
    );
    if (!mounted) return;
    if (result != null) {
      ref.invalidate(driveBackupsProvider);
      showSuccessSnackBar(context, 'Backup complete! ${result.totalRecords} records → ${result.fileSize}');
    } else {
      final error = ref.read(driveBackupTriggerProvider).error;
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  void _showRestoreConfirmDialog(Map<String, dynamic> file, String? orgId) {
    final fileName = file['name'] as String? ?? 'Unknown';
    final fileId = file['id'] as String?;
    final createdTime = file['createdTime'] as String?;
    final sizeBytes = int.tryParse(file['size']?.toString() ?? '') ?? 0;

    if (fileId == null || orgId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.restore_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('Restore Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (createdTime != null) Text('Created: ${_formatDriveDate(createdTime)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (sizeBytes > 0) Text('Size: ${_formatBytes(sizeBytes)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.warning_rounded, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text('This will merge/overwrite existing data. Existing records with matching IDs will be updated. No data will be deleted.', style: TextStyle(fontSize: 11, color: Colors.orange.shade800))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerRestore(orgId, fileId, fileName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Restore Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerRestore(String orgId, String fileId, String fileName) async {
    final connection = ref.read(driveConnectionProvider).valueOrNull;
    if (connection == null || !connection.connected) {
      if (mounted) showErrorSnackBar(context, 'Google Drive not connected');
      return;
    }

    final result = await ref.read(restoreTriggerProvider.notifier).triggerRestore(
      orgId: orgId,
      connection: connection,
      fileId: fileId,
      fileName: fileName,
    );

    if (!mounted) return;
    if (result != null) {
      final msg = result.tablesFailed > 0
          ? 'Restored ${result.totalRecords} records (${result.tablesFailed} table(s) failed)'
          : 'Restored ${result.totalRecords} records across ${result.tablesRestored} tables!';
      showSuccessSnackBar(context, msg);
    } else {
      final error = ref.read(restoreProgressProvider).error;
      if (mounted) showErrorSnackBar(context, error ?? 'Restore failed');
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────

  String _relativeDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('dd MMM').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatDriveDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
