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
  // ─── Schedule state ────────────────────────────────────────────────
  bool _scheduleLoaded = false;
  bool _scheduleEnabled = false;
  String _scheduleFrequency = 'weekly';
  int _scheduleDayOfWeek = 1;
  int _scheduleTimeHour = 2;
  int _scheduleTimeMinute = 0;
  bool _retentionEnabled = false;
  String _retentionMode = 'count';
  int _retentionCount = 10;
  int _retentionDays = 30;
  bool _scheduleSaving = false;
  final _numberController = TextEditingController(text: '10');

  // ─── Comparison state ──────────────────────────────────────────────
  final List<Map<String, dynamic>> _compareSelected = [];
  Map<String, dynamic>? _comparisonResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForRedirect();
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  // ─── Schedule helpers ──────────────────────────────────────────────

  void _loadScheduleFromProvider(Map<String, dynamic> data) {
    if (_scheduleLoaded) return;
    _scheduleLoaded = true;
    _scheduleEnabled = data['enabled'] as bool? ?? false;
    _scheduleFrequency = data['frequency'] as String? ?? 'weekly';
    _scheduleDayOfWeek = data['day_of_week'] as int? ?? 1;
    _scheduleTimeHour = data['time_hour'] as int? ?? 2;
    _scheduleTimeMinute = data['time_minute'] as int? ?? 0;
    _retentionEnabled = data['retention_enabled'] as bool? ?? false;
    _retentionMode = data['retention_mode'] as String? ?? 'count';
    _retentionCount = data['retention_count'] as int? ?? 10;
    _retentionDays = data['retention_days'] as int? ?? 30;
    final val = _retentionMode == 'count' ? _retentionCount : _retentionDays;
    _numberController.text = '$val';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _saveSchedule() async {
    if (_scheduleSaving) return;
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId == null) return;
    setState(() => _scheduleSaving = true);
    try {
      final service = ref.read(backupServiceProvider);
      final schedule = <String, dynamic>{
        'enabled': _scheduleEnabled,
        'frequency': _scheduleFrequency,
        'day_of_week': _scheduleDayOfWeek,
        'time_hour': _scheduleTimeHour,
        'time_minute': _scheduleTimeMinute,
        'categories': kBackupCategories.map((c) => c.key).toList(),
        'notify_on_complete': true,
        'retention_enabled': _retentionEnabled,
        'retention_mode': _retentionMode,
        'retention_count': _retentionCount,
        'retention_days': _retentionDays,
      };
      await service.updateScheduleSettings(orgId, schedule);
      ref.invalidate(scheduleSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _scheduleSaving = false);
    }
  }

  // ─── OAuth redirect check ─────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

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
    final health = ref.watch(backupHealthProvider);
    final analytics = ref.watch(backupAnalyticsProvider);

    // Load schedule settings once
    ref.listen<AsyncValue<Map<String, dynamic>>>(scheduleSettingsProvider, (
      prev,
      next,
    ) {
      next.whenData(_loadScheduleFromProvider);
    });
    final scheduleAsync = ref.watch(scheduleSettingsProvider);
    scheduleAsync.whenData(_loadScheduleFromProvider);

    final isConnected = connection.valueOrNull?.connected == true;
    final isBackingUp =
        backupProgress.status == BackupProgress.generating ||
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
                  // ─── HEADER ──────────────────────────────────
                  _buildHeader(theme),
                  const SizedBox(height: 24),

                  // ─── HERO STATS ──────────────────────────────
                  _buildHeroStats(theme, counts, totalRecords),
                  const SizedBox(height: 24),

                  // ─── BACKUP PROGRESS ─────────────────────────
                  if (isBackingUp) ...[
                    _buildBackupProgressCard(theme, backupProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── RESTORE PROGRESS ────────────────────────
                  if (isRestoring) ...[
                    _buildRestoreProgressCard(theme, restoreProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── RESTORE RESULT ──────────────────────────
                  if (restoreProgress.status == RestoreProgress.done &&
                      restoreProgress.result != null) ...[
                    _buildRestoreResultCard(theme, restoreProgress),
                    const SizedBox(height: 24),
                  ],

                  // ─── HEALTH STATUS ───────────────────────────
                  _buildHealthStatusCard(theme, health),
                  const SizedBox(height: 24),

                  // ─── CONNECTION + BACKUP CARD ────────────────
                  _buildConnectionCard(
                    theme,
                    connection,
                    configReady,
                    orgId,
                    user?.fullName ?? 'Admin',
                    isBackingUp,
                    isRestoring,
                  ),

                  // ─── SCHEDULE SECTION ────────────────────────
                  if (isConnected) ...[
                    const SizedBox(height: 24),
                    _buildScheduleSection(theme, orgId),
                  ],

                  // ─── ANALYTICS ──────────────────────────────
                  if (isConnected) ...[
                    const SizedBox(height: 24),
                    _buildAnalyticsSection(theme, analytics),
                  ],

                  // ─── DRIVE BACKUPS LIST ─────────────────────
                  if (isConnected) ...[
                    const SizedBox(height: 28),
                    _buildDriveBackupsSection(theme, orgId),
                  ],

                  // ─── COMPARISON VIEW ────────────────────────
                  if (_comparisonResult != null) ...[
                    const SizedBox(height: 24),
                    _buildComparisonView(theme),
                    const SizedBox(height: 24),
                  ],

                  // ─── LOCAL EXPORT HISTORY ────────────────────
                  _buildLocalHistorySection(theme),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 1. HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 22,
          ),
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
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 2. HERO STATS
  // ═══════════════════════════════════════════════════════════════════════

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
            value:
                counts.whenOrNull(data: (_) => _formatNumber(totalRecords)) ??
                '...',
            gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            icon: Icons.table_rows_rounded,
            label: 'Categories',
            value: '${kBackupCategories.length}',
            gradient: const [Color(0xFF10B981), Color(0xFF14B8A6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            icon: Icons.cloud_done_rounded,
            label: 'Format',
            value: 'JSON',
            gradient: const [Color(0xFFF59E0B), Color(0xFFF97316)],
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
          colors: [
            gradient[0].withValues(alpha: 0.08),
            gradient[1].withValues(alpha: 0.04),
          ],
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
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: gradient[0],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 3. BACKUP PROGRESS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBackupProgressCard(
    ThemeData theme,
    BackupProgressState progress,
  ) {
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
          Row(
            children: [
              if (progress.status == BackupProgress.generating ||
                  progress.status == BackupProgress.fetching)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              else
                Icon(
                  progress.status == BackupProgress.done
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: color,
                  size: 20,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.step,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              if (progress.fileSize != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    progress.fileSize!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          if (progress.status == BackupProgress.generating ||
              progress.status == BackupProgress.fetching) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 6,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress.progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 4. RESTORE PROGRESS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRestoreProgressCard(
    ThemeData theme,
    RestoreProgressState progress,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.step,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (progress.totalTables > 0)
                Text(
                  '${progress.currentTable}/${progress.totalTables}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 6,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress.progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 5. RESTORE RESULT
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRestoreResultCard(
    ThemeData theme,
    RestoreProgressState progress,
  ) {
    final result = progress.result!;
    final hasErrors = result.tablesFailed > 0;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: hasErrors ? Colors.orange : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasErrors
                          ? 'Restore completed with warnings'
                          : 'Restore Complete!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: hasErrors
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.totalRecords} records restored across ${result.tablesRestored} tables',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    if (hasErrors)
                      Text(
                        '${result.tablesFailed} table(s) failed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: result.errors
                    .take(5)
                    .map(
                      (e) => Text(
                        '• $e',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 6. HEALTH STATUS (NEW)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHealthStatusCard(ThemeData theme, BackupHealth health) {
    final (color, bgColor, icon) = switch (health.status) {
      BackupHealthStatus.healthy => (
        Colors.green.shade700,
        Colors.green.withValues(alpha: 0.08),
        Icons.check_circle_rounded,
      ),
      BackupHealthStatus.stale => (
        Colors.orange.shade700,
        Colors.orange.withValues(alpha: 0.08),
        Icons.schedule_rounded,
      ),
      BackupHealthStatus.failed => (
        Colors.red.shade700,
        Colors.red.withValues(alpha: 0.08),
        Icons.error_rounded,
      ),
      BackupHealthStatus.never => (
        Colors.grey.shade600,
        Colors.grey.withValues(alpha: 0.08),
        Icons.help_outline_rounded,
      ),
    };

    final statusLabel = switch (health.status) {
      BackupHealthStatus.healthy => 'Healthy',
      BackupHealthStatus.stale => 'Stale',
      BackupHealthStatus.failed => 'Failed',
      BackupHealthStatus.never => 'Never',
    };

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup Health',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  health.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 7. CONNECTION CARD
  // ═══════════════════════════════════════════════════════════════════════

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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isConnected
                        ? [Colors.green.shade600, Colors.green.shade400]
                        : [Colors.grey.shade400, Colors.grey.shade300],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'Google Drive Connected'
                          : 'Not Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isConnected ? Colors.green.shade700 : null,
                      ),
                    ),
                    Text(
                      isConnected
                          ? '${connection!.email}'
                          : 'Connect your Google account to enable backups',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          if (!configReady)
            _buildWarningCard(
              theme,
              'Google Client ID not configured',
              'Add GOOGLE_WEB_CLIENT_ID to your .env file.',
            )
          else if (!isConnected)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _connectDrive(orgId),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                label: const Text(
                  'Connect Google Drive',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: (isBackingUp || isRestoring)
                    ? null
                    : () => _triggerBackup(orgId, adminName),
                icon: isBackingUp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded, size: 20),
                label: Text(
                  isBackingUp ? 'Backing Up...' : 'Back Up Now',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isBackingUp || isRestoring)
                        ? null
                        : () => _disconnectDrive(orgId),
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: const Text(
                      'Disconnect',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (isBackingUp || isRestoring)
                        ? null
                        : () => _switchAccount(orgId),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text(
                      'Switch Account',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildWarningCard(ThemeData theme, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 8. SCHEDULE SECTION (NEW)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildScheduleSection(ThemeData theme, String? orgId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUTO-BACKUP SCHEDULE',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Enable toggle ─────────────────────────────
              Row(
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    color: _scheduleEnabled
                        ? AppColors.primary
                        : theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.3,
                          ),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Auto-Backup',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Automatically back up data on schedule',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _scheduleEnabled,
                    onChanged: (v) {
                      setState(() => _scheduleEnabled = v);
                      _saveSchedule();
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),

              if (_scheduleEnabled) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // ── Frequency ───────────────────────────────
                Text(
                  'Frequency',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFreqChip(
                      theme,
                      'Daily',
                      Icons.today_rounded,
                      _scheduleFrequency == 'daily',
                      () {
                        setState(() => _scheduleFrequency = 'daily');
                        _saveSchedule();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFreqChip(
                      theme,
                      'Weekly',
                      Icons.view_week_rounded,
                      _scheduleFrequency == 'weekly',
                      () {
                        setState(() => _scheduleFrequency = 'weekly');
                        _saveSchedule();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildFreqChip(
                      theme,
                      'Monthly',
                      Icons.calendar_month_rounded,
                      _scheduleFrequency == 'monthly',
                      () {
                        setState(() => _scheduleFrequency = 'monthly');
                        _saveSchedule();
                      },
                    ),
                  ],
                ),

                // ── Day of week (weekly only) ───────────────
                if (_scheduleFrequency == 'weekly') ...[
                  const SizedBox(height: 18),
                  Text(
                    'Day of Week',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDayChips(theme),
                ],

                // ── Time picker ─────────────────────────────
                const SizedBox(height: 18),
                Text(
                  'Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _scheduleTimeHour,
                        minute: _scheduleTimeMinute,
                      ),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(
                              context,
                            ).colorScheme.copyWith(primary: AppColors.primary),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _scheduleTimeHour = picked.hour;
                        _scheduleTimeMinute = picked.minute;
                      });
                      _saveSchedule();
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_scheduleTimeHour.toString().padLeft(2, '0')}:${_scheduleTimeMinute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Retention sub-section ──────────────────────
              if (_scheduleEnabled) ...[
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: _retentionEnabled
                          ? Colors.orange
                          : theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.3,
                            ),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Retention Policy',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Automatically clean old backups',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _retentionEnabled,
                      onChanged: (v) {
                        setState(() => _retentionEnabled = v);
                        _saveSchedule();
                      },
                      activeThumbColor: Colors.orange,
                    ),
                  ],
                ),

                if (_retentionEnabled) ...[
                  const SizedBox(height: 16),
                  // Mode selector
                  Row(
                    children: [
                      Expanded(
                        child: _buildRetModeChip(
                          theme,
                          'Keep last N',
                          _retentionMode == 'count',
                          () {
                            setState(() {
                              _retentionMode = 'count';
                              _numberController.text = '$_retentionCount';
                            });
                            _saveSchedule();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRetModeChip(
                          theme,
                          'Older than X days',
                          _retentionMode == 'days',
                          () {
                            setState(() {
                              _retentionMode = 'days';
                              _numberController.text = '$_retentionDays';
                            });
                            _saveSchedule();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Number input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numberController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v) ?? 0;
                            if (_retentionMode == 'count') {
                              _retentionCount = n;
                            } else {
                              _retentionDays = n;
                            }
                          },
                          onSubmitted: (_) => _saveSchedule(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _retentionMode == 'count' ? 'backups' : 'days',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Helper text
                  Text(
                    _retentionMode == 'count'
                        ? 'Will keep the $_retentionCount most recent backups'
                        : 'Will delete backups older than $_retentionDays days',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ],

              // ── Saving indicator ───────────────────────────
              if (_scheduleSaving) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saving...',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildFreqChip(
    ThemeData theme,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: selected ? null : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChips(ThemeData theme) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayIndex = i + 1;
        final selected = _scheduleDayOfWeek == dayIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _scheduleDayOfWeek = dayIndex);
            _saveSchedule();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              color: selected ? null : theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : theme.dividerColor.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: Text(
                days[i].substring(0, 1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRetModeChip(
    ThemeData theme,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    Colors.orange,
                    Colors.orange.withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: selected ? null : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? Colors.orange
                : theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 10. ANALYTICS SECTION (NEW)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAnalyticsSection(ThemeData theme, BackupAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BACKUP ANALYTICS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticTile(
                      theme,
                      Icons.date_range_rounded,
                      'This Week',
                      '${analytics.backupsThisWeek}',
                      const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalyticTile(
                      theme,
                      Icons.calendar_month_rounded,
                      'This Month',
                      '${analytics.backupsThisMonth}',
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAnalyticTile(
                      theme,
                      Icons.cloud_done_rounded,
                      'Total',
                      '${analytics.totalBackups}',
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              if (analytics.lastRecordCount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 16,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Records: ${_formatNumber(analytics.lastRecordCount)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      if (analytics.recordGrowth != 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: analytics.recordGrowth > 0
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${analytics.recordGrowth > 0 ? '+' : ''}${_formatNumber(analytics.recordGrowth)} this week',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: analytics.recordGrowth > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildAnalyticTile(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 11. DRIVE BACKUPS LIST (with Compare)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildDriveBackupsSection(ThemeData theme, String? orgId) {
    final driveBackups = ref.watch(driveBackupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'GOOGLE DRIVE BACKUPS',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            if (_compareSelected.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _compareSelected.clear();
                    _comparisonResult = null;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear (${_compareSelected.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            if (_compareSelected.isEmpty)
              GestureDetector(
                onTap: () => ref.invalidate(driveBackupsProvider),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        driveBackups.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error: ${errorFormatter(e)}')),
          ),
          data: (files) {
            if (files.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          size: 28,
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No backups on Drive',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create your first backup above',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < files.length; i++) ...[
                    _buildDriveBackupItem(theme, files[i], orgId),
                    if (i < files.length - 1)
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildDriveBackupItem(
    ThemeData theme,
    Map<String, dynamic> file,
    String? orgId,
  ) {
    final fileName = file['name'] as String? ?? 'Unknown';
    final fileId = file['id'] as String?;
    final createdTime = file['createdTime'] as String?;
    final sizeBytes = int.tryParse(file['size']?.toString() ?? '') ?? 0;

    // Check if this file is in the compare selection
    final isSelected = _compareSelected.any((f) => f['id'] == fileId);

    return InkWell(
      onTap: fileId == null
          ? null
          : () => _showSelectiveRestoreDialog(file, orgId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 3),
                ),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.description_rounded,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.6),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (createdTime != null)
                        Text(
                          _formatDriveDate(createdTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      if (sizeBytes > 0)
                        Text(
                          ' · ${_formatBytes(sizeBytes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Compare button
            GestureDetector(
              onTap: fileId == null
                  ? null
                  : () => _onCompareTap(file),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.compare_arrows_rounded,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.4,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.restore_rounded,
              size: 18,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 12. COMPARISON VIEW (NEW)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildComparisonView(ThemeData theme) {
    final result = _comparisonResult!;
    final backupA = result['backup_a'] as Map<String, dynamic>;
    final backupB = result['backup_b'] as Map<String, dynamic>;
    final diffs = result['diffs'] as List<dynamic>;
    final totalChange = result['total_change'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'BACKUP COMPARISON',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _comparisonResult = null),
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.red.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Dismiss',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Older',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateShort(backupA['date'] as String? ?? ''),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_formatNumber(backupA['total_records'] as int? ?? 0)} records',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: totalChange >= 0
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Newer',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateShort(backupB['date'] as String? ?? ''),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_formatNumber(backupB['total_records'] as int? ?? 0)} records',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: totalChange >= 0
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total change: ${totalChange >= 0 ? '+' : ''}$totalChange records',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: totalChange >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),

              // ── Diff table ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      'Old',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 50,
                    child: Text(
                      'New',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 50,
                    child: Text(
                      'Diff',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < diffs.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                _buildDiffRow(theme, diffs[i] as Map<String, dynamic>),
              ],
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.05, end: 0),
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildDiffRow(ThemeData theme, Map<String, dynamic> diff) {
    final cat = diff['category'] as String? ?? '';
    final countA = diff['count_a'] as int? ?? 0;
    final countB = diff['count_b'] as int? ?? 0;
    final change = diff['change'] as int? ?? 0;

    // Find the label from kBackupCategories
    final def = kBackupCategories.cast<BackupCategoryDef?>().firstWhere(
      (c) => c?.key == cat,
      orElse: () => null,
    );
    final label = def?.label ?? cat;

    final color = change > 0
        ? Colors.green.shade700
        : change < 0
            ? Colors.red.shade700
            : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4);

    final bgColor = change > 0
        ? Colors.green.withValues(alpha: 0.06)
        : change < 0
            ? Colors.red.withValues(alpha: 0.06)
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: bgColor,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '$countA',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            child: Text(
              '$countB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            child: Text(
              change > 0 ? '+$change' : '$change',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM, HH:mm').format(date);
    } catch (_) {
      return isoDate.isNotEmpty ? isoDate : '—';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 13. SELECTIVE RESTORE DIALOG (NEW)
  // ═══════════════════════════════════════════════════════════════════════

  void _showSelectiveRestoreDialog(Map<String, dynamic> file, String? orgId) {
    final fileId = file['id'] as String?;
    final fileName = file['name'] as String? ?? 'Unknown';
    if (fileId == null || orgId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => _SelectiveRestoreDialog(
        fileId: fileId,
        fileName: fileName,
        orgId: orgId,
      ),
    );
  }

  Future<void> _triggerRestore(
    String orgId,
    String fileId,
    String fileName, {
    Set<String>? selectedCategories,
  }) async {
    final connection = ref.read(driveConnectionProvider).valueOrNull;
    if (connection == null || !connection.connected) {
      if (mounted) showErrorSnackBar(context, 'Google Drive not connected');
      return;
    }

    final result = await ref
        .read(restoreTriggerProvider.notifier)
        .triggerRestore(
          orgId: orgId,
          connection: connection,
          fileId: fileId,
          fileName: fileName,
          selectedCategories: selectedCategories,
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

  // ═══════════════════════════════════════════════════════════════════════
  // COMPARE HANDLER
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _onCompareTap(Map<String, dynamic> file) async {
    final fileId = file['id'] as String?;
    if (fileId == null) return;

    setState(() {
      // Toggle selection
      final idx = _compareSelected.indexWhere((f) => f['id'] == fileId);
      if (idx >= 0) {
        _compareSelected.removeAt(idx);
        return;
      }
      if (_compareSelected.length >= 2) {
        _compareSelected.removeAt(0);
      }
      _compareSelected.add(file);
    });

    // If two selected, run comparison
    if (_compareSelected.length == 2) {
      final connection = ref.read(driveConnectionProvider).valueOrNull;
      if (connection == null || !connection.connected) {
        if (mounted) showErrorSnackBar(context, 'Google Drive not connected');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 10),
              Text('Downloading backups for comparison...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      try {
        final service = ref.read(restoreBackupServiceProvider);
        final backupA = await service.downloadBackup(
          connection: connection,
          fileId: _compareSelected[0]['id'] as String,
        );
        final backupB = await service.downloadBackup(
          connection: connection,
          fileId: _compareSelected[1]['id'] as String,
        );

        final result = service.compareBackups(backupA, backupB);

        if (mounted) {
          setState(() {
            _comparisonResult = result;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showErrorSnackBar(context, e);
          setState(() => _compareSelected.clear());
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 14. LOCAL EXPORT HISTORY
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLocalHistorySection(ThemeData theme) {
    final history = ref.watch(exportHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPORT HISTORY',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        history.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Error: ${errorFormatter(e)}')),
          ),
          data: (items) {
            if (items.isEmpty) {
              return GlassCard(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No export history',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < items.length && i < 10; i++) ...[
                    _buildHistoryItem(theme, items[i]),
                    if (i < items.length - 1 && i < 9)
                      Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                  ],
                ],
              ),
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
    final statusColor = switch (status) {
      'completed' => Colors.green,
      'pending' => Colors.orange,
      'failed' => Colors.red,
      _ => Colors.grey,
    };
    final statusIcon = switch (status) {
      'completed' => Icons.check_circle_rounded,
      'pending' => Icons.schedule_rounded,
      'failed' => Icons.error_rounded,
      _ => Icons.help_outline_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Organization Backup',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        format,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        ' · ${_relativeDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DRIVE ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

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
      if (msg.contains('__PENDING_REDIRECT__')) return;
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
      showSuccessSnackBar(
        context,
        'Backup complete! ${result.totalRecords} records → ${result.fileSize}',
      );
    } else {
      final error = ref.read(driveBackupTriggerProvider).error;
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════════════
// SELECTIVE RESTORE DIALOG (separate StatefulWidget for multi-step state)
// ═══════════════════════════════════════════════════════════════════════════

class _SelectiveRestoreDialog extends ConsumerStatefulWidget {
  final String fileId;
  final String fileName;
  final String orgId;

  const _SelectiveRestoreDialog({
    required this.fileId,
    required this.fileName,
    required this.orgId,
  });

  @override
  ConsumerState<_SelectiveRestoreDialog> createState() =>
      _SelectiveRestoreDialogState();
}

class _SelectiveRestoreDialogState
    extends ConsumerState<_SelectiveRestoreDialog> {
  int _step = 0; // 0=loading, 1=metadata, 2=categories, 3=confirm
  Map<String, dynamic>? _backupSummary;
  Map<String, int> _recordCounts = {};
  late Set<String> _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start with all categories selected
    _selected = kBackupCategories.map((c) => c.key).toSet();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final connection = ref.read(driveConnectionProvider).valueOrNull;
    if (connection == null || !connection.connected) {
      setState(() => _error = 'Google Drive not connected');
      return;
    }
    try {
      final service = ref.read(restoreBackupServiceProvider);
      final backup = await service.downloadBackup(
        connection: connection,
        fileId: widget.fileId,
      );
      final summary = service.validateBackup(backup);
      final cats = summary['categories'] as Map<String, dynamic>? ?? {};
      final counts = <String, int>{};
      for (final entry in cats.entries) {
        counts[entry.key] = entry.value as int? ?? 0;
      }
      if (mounted) {
        setState(() {
          _backupSummary = summary;
          _recordCounts = counts;
          _step = 1;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _toggleCategory(String key) {
    final def = kBackupCategories.cast<BackupCategoryDef?>().firstWhere(
      (c) => c?.key == key,
      orElse: () => null,
    );
    if (def == null) return;

    final isCurrentlySelected = _selected.contains(key);
    final newSelected = applyDependencies(
      _selected,
      key,
      !isCurrentlySelected,
      restoreDependencies,
    );
    setState(() => _selected = newSelected);
  }

  Future<void> _executeRestore() async {
    setState(() => _step = 4); // showing progress
    Navigator.of(context).pop(); // Close dialog
    // Trigger restore from the parent page context
    // We use a post-frame callback to ensure the dialog is closed first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access the page state through the parent context
      final pageState = context
          .findAncestorStateOfType<_DataBackupExportPageState>();
      pageState?._triggerRestore(
        widget.orgId,
        widget.fileId,
        widget.fileName,
        selectedCategories: _selected,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 420,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog header ────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restore_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restore Backup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.fileName,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Content ──────────────────────────────────
            Flexible(
              child: _error != null
                  ? _buildErrorView(theme)
                  : _step == 0
                      ? _buildLoadingView(theme)
                      : _step == 1
                          ? _buildMetadataView(theme)
                          : _step == 2
                              ? _buildCategoryView(theme)
                              : _buildConfirmView(theme),
            ),

            // ── Actions ──────────────────────────────────
            if (_step >= 1 && _step <= 3)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_step > 1)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_step < 3) {
                          setState(() => _step++);
                        } else {
                          _executeRestore();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _step == 3 ? 'Restore Now' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Downloading backup metadata...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 40),
          const SizedBox(height: 12),
          Text(
            'Failed to load backup',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataView(ThemeData theme) {
    if (_backupSummary == null) return const SizedBox.shrink();
    final totalRecords = _backupSummary!['total_records'] as int? ?? 0;
    final tableCount = _backupSummary!['table_count'] as int? ?? 0;
    final orgName = _backupSummary!['org_name'] as String? ?? '';
    final generatedAt = _backupSummary!['generated_at'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          _buildStepIndicator(1),
          const SizedBox(height: 18),

          Text(
            'Backup Summary',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),

          _buildInfoRow(theme, Icons.business_rounded, 'Organization', orgName),
          const SizedBox(height: 8),
          _buildInfoRow(
            theme,
            Icons.storage_rounded,
            'Total Records',
            '$totalRecords',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            theme,
            Icons.table_rows_rounded,
            'Tables',
            '$tableCount',
          ),
          if (generatedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              theme,
              Icons.access_time_rounded,
              'Created',
              _formatDialogDate(generatedAt),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This will merge/overwrite existing data. Matching records will be updated.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(2),
          const SizedBox(height: 14),

          Row(
            children: [
              Text(
                'Select Categories',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selected.length == kBackupCategories.length) {
                      _selected = {};
                    } else {
                      _selected = kBackupCategories.map((c) => c.key).toSet();
                    }
                  });
                },
                child: Text(
                  _selected.length == kBackupCategories.length
                      ? 'Deselect All'
                      : 'Select All',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_selected.length} of ${kBackupCategories.length} categories selected',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kBackupCategories.length,
              itemBuilder: (context, index) {
                final cat = kBackupCategories[index];
                final isSelected = _selected.contains(cat.key);
                final deps = restoreDependencies[cat.key];
                final recordCount = _recordCounts[cat.key] ?? 0;

                return InkWell(
                  onTap: () => _toggleCategory(cat.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleCategory(cat.key),
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? null : Colors.grey,
                                ),
                              ),
                              if (deps != null && deps.isNotEmpty)
                                Text(
                                  'Requires: ${deps.join(', ')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '$recordCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmView(ThemeData theme) {
    var totalRecords = 0;
    for (final key in _selected) {
      totalRecords += _recordCounts[key] ?? 0;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepIndicator(3),
          const SizedBox(height: 18),

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green,
                  Colors.green.withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restore_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Ready to Restore',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Restoring ${_selected.length} categories',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '~$totalRecords records will be upserted',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Text(
            'Records with matching IDs will be updated. No data will be deleted.',
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i + 1 <= _step;
        final isCurrent = i + 1 == _step;
        return Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary : Colors.grey.shade200,
                border: isCurrent
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            if (i < 2)
              Container(
                width: 30,
                height: 2,
                color: isActive ? AppColors.primary : Colors.grey.shade200,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDialogDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return isoDate;
    }
  }
}
