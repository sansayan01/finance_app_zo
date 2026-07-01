import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/services/backup_export_service.dart';

// Category visual metadata (icons + colors) mapped by key
const Map<String, _CatVisual> _catVisuals = {
  'members': _CatVisual(Icons.people_rounded, Color(0xFF6366F1)),
  'loans': _CatVisual(Icons.account_balance_rounded, Color(0xFF10B981)),
  'emi_schedule': _CatVisual(Icons.calendar_month_rounded, Color(0xFFF59E0B)),
  'savings': _CatVisual(Icons.savings_rounded, Color(0xFF3B82F6)),
  'savings_plans': _CatVisual(Icons.stacked_line_chart_rounded, Color(0xFF8B5CF6)),
  'transactions': _CatVisual(Icons.receipt_long_rounded, Color(0xFFEF4444)),
  'collections': _CatVisual(Icons.payments_rounded, Color(0xFF14B8A6)),
  'savings_collections': _CatVisual(Icons.savings_outlined, Color(0xFF06B6D4)),
  'branches': _CatVisual(Icons.domain_rounded, Color(0xFF7C3AED)),
  'staff_profiles': _CatVisual(Icons.badge_rounded, Color(0xFFEC4899)),
  'activity_logs': _CatVisual(Icons.history_rounded, Color(0xFF64748B)),
  'visit_logs': _CatVisual(Icons.location_on_rounded, Color(0xFFF97316)),
  'cash_deposits': _CatVisual(Icons.account_balance_wallet_rounded, Color(0xFF84CC16)),
  'wallet_transactions': _CatVisual(Icons.wallet_rounded, Color(0xFF0EA5E9)),
  'staff_streaks': _CatVisual(Icons.local_fire_department_rounded, Color(0xFFF43F5E)),
  'achievements': _CatVisual(Icons.emoji_events_rounded, Color(0xFFEAB308)),
  'offline_queue': _CatVisual(Icons.cloud_off_rounded, Color(0xFF9CA3AF)),
  'sync_conflicts': _CatVisual(Icons.sync_problem_rounded, Color(0xFFDC2626)),
};

class _CatVisual {
  final IconData icon;
  final Color color;
  const _CatVisual(this.icon, this.color);
}

_CatVisual _getCatVisual(String key) =>
    _catVisuals[key] ?? const _CatVisual(Icons.folder_rounded, Colors.grey);

class DataBackupExportPage extends ConsumerStatefulWidget {
  const DataBackupExportPage({super.key});

  @override
  ConsumerState<DataBackupExportPage> createState() =>
      _DataBackupExportPageState();
}

class _DataBackupExportPageState extends ConsumerState<DataBackupExportPage>
    with SingleTickerProviderStateMixin {
  DateTimeRange? _dateRange;
  bool _showAdvanced = false;
  bool _showAllCategories = false;
  final _prefixController = TextEditingController();

  late AnimationController _progressAnimController;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _progressAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final orgId = ref.watch(currentOrgIdProvider);
    final counts = ref.watch(categoryCountsProvider);
    final history = ref.watch(exportHistoryProvider);
    final selected = ref.watch(selectedCategoriesProvider);
    final options = ref.watch(backupOptionsProvider);
    final progress = ref.watch(backupProgressProvider);
    final totalRecords = ref.watch(totalRecordCountProvider);
    final estimatedSize = ref.watch(estimatedSizeProvider);

    // Animate progress bar
    if (progress.status == BackupProgress.generating ||
        progress.status == BackupProgress.fetching) {
      _progressAnimController.forward(from: progress.progress);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Data Backup & Export'),
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
                  _buildHeroStats(theme, counts, totalRecords, history),
                  const SizedBox(height: 24),

                  // ─── PROGRESS CARD (when active) ─────────────────
                  if (progress.status != BackupProgress.idle) ...[
                    _buildProgressCard(theme, progress),
                    const SizedBox(height: 24),
                  ],

                  // ─── FULL BACKUP CARD ────────────────────────────
                  _buildFullBackupCard(
                    theme, selected, options, progress, orgId,
                    user?.fullName ?? 'Admin', estimatedSize, counts,
                  ),
                  const SizedBox(height: 28),

                  // ─── DATA CATEGORIES ─────────────────────────────
                  _buildCategoriesSection(theme, counts, selected),
                  const SizedBox(height: 28),

                  // ─── QUICK ACTIONS ───────────────────────────────
                  _buildQuickActionsSection(theme, orgId, user?.fullName ?? 'Admin'),
                  const SizedBox(height: 28),

                  // ─── SCHEDULED BACKUPS ───────────────────────────
                  _buildScheduleSection(theme, orgId),
                  const SizedBox(height: 28),

                  // ─── EXPORT HISTORY ──────────────────────────────
                  _buildHistorySection(theme, history),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization Backup',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Full-scope data export with format selection, scheduling, and audit trail.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }

  // ─── HERO STATS ──────────────────────────────────────────────────────
  Widget _buildHeroStats(
    ThemeData theme,
    AsyncValue<Map<String, int>> counts,
    int totalRecords,
    AsyncValue<List<Map<String, dynamic>>> history,
  ) {
    final exportCount = history.whenOrNull(data: (l) => l.length) ?? 0;
    final lastBackup = history.whenOrNull(data: (l) {
      if (l.isEmpty) return null;
      return l.first['created_at'] as String?;
    });

    return Row(
      children: [
        Expanded(
          child: _buildGradientStatCard(
            theme: theme,
            icon: Icons.storage_rounded,
            label: 'Total Records',
            value: counts.whenOrNull(data: (_) => _formatNumber(totalRecords)) ?? '...',
            gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildGradientStatCard(
            theme: theme,
            icon: Icons.history_rounded,
            label: 'Exports',
            value: '$exportCount',
            gradient: [const Color(0xFF10B981), const Color(0xFF14B8A6)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildGradientStatCard(
            theme: theme,
            icon: Icons.access_time_rounded,
            label: 'Last Export',
            value: lastBackup != null ? _relativeDate(lastBackup) : 'Never',
            gradient: [const Color(0xFFF59E0B), const Color(0xFFF97316)],
          ),
        ),
      ],
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildGradientStatCard({
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
        border: Border.all(
          color: gradient[0].withValues(alpha: 0.15),
        ),
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

  // ─── PROGRESS CARD ───────────────────────────────────────────────────
  Widget _buildProgressCard(ThemeData theme, BackupProgressState progress) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  // ─── FULL BACKUP CARD ────────────────────────────────────────────────
  Widget _buildFullBackupCard(
    ThemeData theme,
    Set<String> selected,
    BackupOptions options,
    BackupProgressState progress,
    String? orgId,
    String adminName,
    String estimatedSize,
    AsyncValue<Map<String, int>> counts,
  ) {
    final isRunning = progress.status == BackupProgress.generating ||
        progress.status == BackupProgress.fetching;
    final isDone = progress.status == BackupProgress.done;

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDone
                        ? [Colors.green.shade600, Colors.green.shade400]
                        : [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.backup_rounded,
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
                      isDone ? 'Backup Complete' : 'Full Organization Backup',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${selected.length} of ${kBackupCategories.length} categories · Est. $estimatedSize',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
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

          // Format Selection
          _buildSectionLabel(theme, 'Export Format'),
          const SizedBox(height: 8),
          SegmentedButton<BackupFormat>(
            segments: const [
              ButtonSegment(
                value: BackupFormat.csv,
                label: Text('CSV'),
                icon: Icon(Icons.description_rounded, size: 16),
              ),
              ButtonSegment(
                value: BackupFormat.excel,
                label: Text('Excel'),
                icon: Icon(Icons.table_chart_rounded, size: 16),
              ),
              ButtonSegment(
                value: BackupFormat.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf_rounded, size: 16),
              ),
            ],
            selected: {options.format},
            onSelectionChanged: isRunning
                ? null
                : (s) {
                    HapticFeedback.lightImpact();
                    ref.read(backupOptionsProvider.notifier).state =
                        options.copyWith(format: s.first);
                  },
          ),
          const SizedBox(height: 18),

          // Date Range
          _buildSectionLabel(theme, 'Date Range (Optional)'),
          const SizedBox(height: 8),
          _buildDateRangePicker(theme),
          const SizedBox(height: 18),

          // Advanced Options Toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showAdvanced = !_showAdvanced);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Options',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showAdvanced ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showAdvanced
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        _buildToggleRow(
                          theme: theme,
                          icon: Icons.lock_outline_rounded,
                          label: 'Encrypt export file',
                          description: 'AES-256 encryption for sensitive data',
                          value: options.encrypt,
                          onChanged: (v) {
                            ref.read(backupOptionsProvider.notifier).state =
                                options.copyWith(encrypt: v);
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildToggleRow(
                          theme: theme,
                          icon: Icons.compress_rounded,
                          label: 'Compress (ZIP)',
                          description: 'Reduce file size by ~60%',
                          value: options.compress,
                          onChanged: (v) {
                            ref.read(backupOptionsProvider.notifier).state =
                                options.copyWith(compress: v);
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildToggleRow(
                          theme: theme,
                          icon: Icons.delete_outline_rounded,
                          label: 'Include soft-deleted',
                          description: 'Recover archived records',
                          value: options.includeSoftDeleted,
                          onChanged: (v) {
                            ref.read(backupOptionsProvider.notifier).state =
                                options.copyWith(includeSoftDeleted: v);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _prefixController,
                          onChanged: (v) {
                            ref.read(backupOptionsProvider.notifier).state =
                                options.copyWith(
                              filenamePrefix: v.isEmpty ? null : v,
                              clearPrefix: v.isEmpty,
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'Custom filename prefix',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                            ),
                            prefixIcon: Icon(Icons.text_fields_rounded,
                                size: 18, color: AppColors.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: theme.dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),

          // Backup Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: selected.isEmpty || isRunning
                  ? null
                  : () => _triggerBackup(orgId, adminName),
              icon: isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isDone ? Icons.share_rounded : Icons.cloud_upload_rounded, size: 20),
              label: Text(
                isRunning
                    ? 'Generating...'
                    : isDone
                        ? 'Share Backup File'
                        : 'Start Backup (${selected.length} categories)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone
                    ? Colors.green.shade600
                    : AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildDateRangePicker(ThemeData theme) {
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _dateRange != null
                    ? '${DateFormat('dd MMM yyyy').format(_dateRange!.start)} — ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}'
                    : 'All time (no filter)',
                style: TextStyle(
                  fontSize: 13,
                  color: _dateRange != null
                      ? theme.textTheme.bodyMedium?.color
                      : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (_dateRange != null)
              GestureDetector(
                onTap: () => setState(() => _dateRange = null),
                child: Icon(Icons.close_rounded,
                    size: 16, color: theme.textTheme.bodySmall?.color),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withValues(alpha: 0.05) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.2)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? AppColors.primary : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ─── CATEGORIES SECTION ──────────────────────────────────────────────
  Widget _buildCategoriesSection(
    ThemeData theme,
    AsyncValue<Map<String, int>> counts,
    Set<String> selected,
  ) {
    final displayCount = _showAllCategories ? kBackupCategories.length : 8;
    final selectedCount = selected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'DATA CATEGORIES',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Text(
              '$selectedCount/${kBackupCategories.length} selected',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                final all = kBackupCategories.map((c) => c.key).toSet();
                final current = ref.read(selectedCategoriesProvider);
                ref.read(selectedCategoriesProvider.notifier).state =
                    current.length == all.length ? {} : all;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  selectedCount == kBackupCategories.length ? 'Deselect All' : 'Select All',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.0,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final cat = kBackupCategories[index];
            final isSelected = selected.contains(cat.key);
            final count = counts.whenOrNull(data: (m) => m[cat.key]) ?? 0;

            return _buildCategoryCard(theme, cat, isSelected, count);
          },
        ),
        if (kBackupCategories.length > 8) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showAllCategories = !_showAllCategories);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAllCategories ? 'Show Less' : 'Show All ${kBackupCategories.length} Categories',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showAllCategories
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ],
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildCategoryCard(
      ThemeData theme, BackupCategoryDef cat, bool isSelected, int count) {
    final visual = _getCatVisual(cat.key);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final current = ref.read(selectedCategoriesProvider);
        ref.read(selectedCategoriesProvider.notifier).state =
            isSelected ? ({...current}..remove(cat.key)) : ({...current, cat.key});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected
              ? visual.color.withValues(alpha: 0.06)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? visual.color.withValues(alpha: 0.35)
                : theme.dividerColor.withValues(alpha: 0.15),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? visual.color.withValues(alpha: 0.15)
                    : theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(visual.icon, color: isSelected ? visual.color : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isSelected
                          ? theme.textTheme.bodyMedium?.color
                          : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$count records',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: isSelected
                  ? visual.color
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK ACTIONS ───────────────────────────────────────────────────
  Widget _buildQuickActionsSection(ThemeData theme, String? orgId, String adminName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                theme: theme,
                icon: Icons.people_rounded,
                label: 'Members Only',
                color: const Color(0xFF6366F1),
                onTap: () => _quickExport(orgId, adminName, 'members'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionCard(
                theme: theme,
                icon: Icons.account_balance_rounded,
                label: 'Loans Only',
                color: const Color(0xFF10B981),
                onTap: () => _quickExport(orgId, adminName, 'loans'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionCard(
                theme: theme,
                icon: Icons.receipt_long_rounded,
                label: 'Transactions',
                color: const Color(0xFFEF4444),
                onTap: () => _quickExport(orgId, adminName, 'transactions'),
              ),
            ),
          ],
        ),
      ],
    ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildQuickActionCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SCHEDULE SECTION ────────────────────────────────────────────────
  Widget _buildScheduleSection(ThemeData theme, String? orgId) {
    final scheduleAsync = ref.watch(scheduleSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCHEDULED BACKUPS',
          style: theme.textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: scheduleAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: ${errorFormatter(e)}')),
            data: (settings) {
              final enabled = settings['enabled'] as bool? ?? false;
              final frequency = settings['frequency'] as String? ?? 'weekly';
              final hour = settings['time_hour'] as int? ?? 2;
              final minute = settings['time_minute'] as int? ?? 0;
              final dayOfWeek = settings['day_of_week'] as int? ?? 1;
              final notifyOnComplete = settings['notify_on_complete'] as bool? ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: enabled
                                ? [const Color(0xFF7C3AED), const Color(0xFFA78BFA)]
                                : [Colors.grey.shade400, Colors.grey.shade300],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.schedule_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Automated Backup',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              enabled
                                  ? '${frequency[0].toUpperCase()}${frequency.substring(1)} at ${_formatTime(hour, minute)}'
                                  : 'Disabled',
                              style: TextStyle(
                                fontSize: 12,
                                color: enabled
                                    ? Colors.green.shade600
                                    : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: enabled,
                        onChanged: (v) => _toggleSchedule(v, orgId, settings),
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (enabled) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),

                    // Frequency
                    Text(
                      'Frequency',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'daily', label: Text('Daily')),
                        ButtonSegment(value: 'weekly', label: Text('Weekly')),
                        ButtonSegment(value: 'monthly', label: Text('Monthly')),
                      ],
                      selected: {frequency},
                      onSelectionChanged: (s) {
                        HapticFeedback.lightImpact();
                        _updateScheduleField(orgId, settings, 'frequency', s.first);
                      },
                    ),

                    // Day of week (for weekly)
                    if (frequency == 'weekly') ...[
                      const SizedBox(height: 14),
                      Text(
                        'Day of Week',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var i = 1; i <= 7; i++)
                            _buildDayChip(
                              theme,
                              day: i,
                              label: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i - 1],
                              isSelected: dayOfWeek == i,
                              onTap: () => _updateScheduleField(orgId, settings, 'day_of_week', i),
                            ),
                        ],
                      ),
                    ],

                    // Time
                    const SizedBox(height: 14),
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickTime(hour, minute, orgId, settings),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Text(_formatTime(hour, minute), style: const TextStyle(fontSize: 13)),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded,
                                size: 18,
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),

                    // Notify on complete
                    const SizedBox(height: 12),
                    _buildToggleRow(
                      theme: theme,
                      icon: Icons.notifications_outlined,
                      label: 'Notify when complete',
                      description: 'Push notification after backup',
                      value: notifyOnComplete,
                      onChanged: (v) => _updateScheduleField(orgId, settings, 'notify_on_complete', v),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildDayChip(
    ThemeData theme, {
    required int day,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  // ─── HISTORY SECTION ─────────────────────────────────────────────────
  Widget _buildHistorySection(
      ThemeData theme, AsyncValue<List<Map<String, dynamic>>> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'EXPORT HISTORY',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            history.whenOrNull(data: (l) => l.isNotEmpty) == true
                ? GestureDetector(
                    onTap: () => ref.invalidate(exportHistoryProvider),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
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
                  )
                : const SizedBox.shrink(),
          ],
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
            child: Center(
              child: Text('Failed to load history: ${errorFormatter(e)}'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _buildEmptyHistory(theme);
            }
            return GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _buildHistoryItem(theme, items[i]),
                    if (i < items.length - 1)
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
    ).animate(delay: 380.ms).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildEmptyHistory(ThemeData theme) {
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
              child: Icon(Icons.cloud_upload_outlined,
                  size: 28, color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text(
              'No exports yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your backup exports will appear here',
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ThemeData theme, Map<String, dynamic> item) {
    final status = item['status'] as String? ?? 'unknown';
    final format = (item['format'] as String? ?? 'csv').toUpperCase();
    final createdAt = item['created_at'] as String?;
    final filters = item['filters'] as Map<String, dynamic>?;

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

    final categoryCount = filters != null ? (filters['categories'] as List?)?.length : null;

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
                    Text(
                      'Organization Backup',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    if (categoryCount != null)
                      Text(
                        ' · $categoryCount categories',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                        ),
                      ),
                    if (createdAt != null)
                      Text(
                        ' · ${_relativeDate(createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
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

  // ─── ACTIONS ──────────────────────────────────────────────────────────

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _pickTime(
      int currentHour, int currentMinute, String? orgId, Map<String, dynamic> settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
    );
    if (picked != null && orgId != null) {
      _updateScheduleField(orgId, settings, 'time_hour', picked.hour);
      _updateScheduleField(orgId, settings, 'time_minute', picked.minute);
    }
  }

  void _updateScheduleField(
      String? orgId, Map<String, dynamic> settings, String field, dynamic value) {
    if (orgId == null) return;
    final updated = {...settings, field: value};
    ref.read(backupTriggerProvider.notifier).updateSchedule(orgId: orgId, schedule: updated);
  }

  Future<void> _triggerBackup(String? orgId, String adminName) async {
    if (orgId == null) return;

    final selected = ref.read(selectedCategoriesProvider);
    final options = ref.read(backupOptionsProvider);

    final filePath = await ref.read(backupTriggerProvider.notifier).triggerBackup(
          orgId: orgId,
          orgName: adminName,
          categories: selected,
          options: options,
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        );

    if (!mounted) return;

    if (filePath != null) {
      final service = ref.read(backupServiceProvider);
      await service.shareFile(filePath, options.format.name);
      if (mounted) showSuccessSnackBar(context, 'Backup exported successfully!');
    } else {
      final error = ref.read(backupTriggerProvider).error;
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _quickExport(String? orgId, String adminName, String categoryKey) async {
    if (orgId == null) return;

    final options = ref.read(backupOptionsProvider);

    try {
      final service = ref.read(backupServiceProvider);
      final filePath = await service.exportSingleCategory(
        orgId: orgId,
        orgName: adminName,
        categoryKey: categoryKey,
        format: options.format.name,
        start: _dateRange?.start,
        end: _dateRange?.end,
      );

      if (!mounted) return;
      await service.shareFile(filePath, options.format.name);
      if (mounted) showSuccessSnackBar(context, 'Category exported!');
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  void _toggleSchedule(bool enabled, String? orgId, Map<String, dynamic> current) {
    if (orgId == null) return;
    final updated = {...current, 'enabled': enabled};
    ref.read(backupTriggerProvider.notifier).updateSchedule(orgId: orgId, schedule: updated);
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(ThemeData theme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
      ),
    );
  }

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

  String _formatTime(int hour, int minute) {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
