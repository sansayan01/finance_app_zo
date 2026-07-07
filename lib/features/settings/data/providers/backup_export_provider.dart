import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/org_provider.dart';
import '../../../../providers/supabase_provider.dart';
import '../services/backup_export_service.dart';

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

final backupServiceProvider = Provider.autoDispose<BackupExportService>((ref) {
  return BackupExportService(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// BACKUP PROGRESS (shared state, driven by DriveBackupNotifier)
// ---------------------------------------------------------------------------

enum BackupProgress { idle, fetching, generating, sharing, done, failed }

class BackupProgressState {
  final BackupProgress status;
  final String step;
  final double progress;
  final String? filePath;
  final String? fileSize;

  const BackupProgressState({
    this.status = BackupProgress.idle,
    this.step = '',
    this.progress = 0.0,
    this.filePath,
    this.fileSize,
  });

  BackupProgressState copyWith({
    BackupProgress? status,
    String? step,
    double? progress,
    String? filePath,
    String? fileSize,
  }) {
    return BackupProgressState(
      status: status ?? this.status,
      step: step ?? this.step,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}

// ---------------------------------------------------------------------------
// CATEGORY COUNTS
// ---------------------------------------------------------------------------

final categoryCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final service = ref.watch(backupServiceProvider);
  return service.getCategoryCounts(orgId);
});

// ---------------------------------------------------------------------------
// EXPORT HISTORY (from data_exports table)
// ---------------------------------------------------------------------------

final exportHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final service = ref.watch(backupServiceProvider);
  return service.getExportHistory(orgId);
});

// ---------------------------------------------------------------------------
// SELECTED CATEGORIES — all categories by default (no per-category UI in v1,
// but kept so the count/estimate providers still work and restore can pick
// the list up later).
// ---------------------------------------------------------------------------

final selectedCategoriesProvider =
    StateProvider.autoDispose<Set<String>>((ref) {
  return kBackupCategories.map((c) => c.key).toSet();
});

// ---------------------------------------------------------------------------
// BACKUP PROGRESS STATE
// ---------------------------------------------------------------------------

final backupProgressProvider =
    StateProvider.autoDispose<BackupProgressState>((ref) {
  return const BackupProgressState();
});

// ---------------------------------------------------------------------------
// TOTAL RECORD COUNT
// ---------------------------------------------------------------------------

final totalRecordCountProvider = Provider.autoDispose<int>((ref) {
  final counts = ref.watch(categoryCountsProvider);
  return counts.whenOrNull(data: (m) => m.values.fold<int>(0, (a, b) => a + b)) ?? 0;
});

// ---------------------------------------------------------------------------
// ESTIMATED SIZE
// ---------------------------------------------------------------------------

final estimatedSizeProvider = Provider.autoDispose<String>((ref) {
  final counts = ref.watch(categoryCountsProvider);
  final selected = ref.watch(selectedCategoriesProvider);
  final service = ref.watch(backupServiceProvider);
  return counts.whenOrNull(
    data: (m) => service.estimateFileSize(m, selected, 'json'),
  ) ?? 'Calculating...';
});

// ---------------------------------------------------------------------------
// SCHEDULE SETTINGS (UI removed in v1, but kept for future auto-backup)
// ---------------------------------------------------------------------------

final scheduleSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final service = ref.watch(backupServiceProvider);
  return service.getScheduleSettings(orgId);
});

final scheduleEnabledProvider = Provider.autoDispose<bool>((ref) {
  final settings = ref.watch(scheduleSettingsProvider);
  return settings.whenOrNull(data: (m) => m['enabled'] as bool? ?? false) ?? false;
});

// ---------------------------------------------------------------------------
// BACKUP HEALTH STATUS
// ---------------------------------------------------------------------------

enum BackupHealthStatus { healthy, stale, failed, never }

class BackupHealth {
  final BackupHealthStatus status;
  final String message;
  final String? lastBackupTime;

  const BackupHealth({required this.status, required this.message, this.lastBackupTime});
}

final backupHealthProvider = Provider.autoDispose<BackupHealth>((ref) {
  final history = ref.watch(exportHistoryProvider);
  return history.whenOrNull(data: (items) {
    if (items.isEmpty) {
      return const BackupHealth(status: BackupHealthStatus.never, message: 'No backups yet');
    }
    // Find last completed backup
    final lastCompleted = items.firstWhere(
      (item) => item['status'] == 'completed',
      orElse: () => {},
    );
    if (lastCompleted.isEmpty) {
      return const BackupHealth(status: BackupHealthStatus.failed, message: 'Last backup failed');
    }
    final createdAt = lastCompleted['created_at'] as String?;
    if (createdAt == null) {
      return const BackupHealth(status: BackupHealthStatus.healthy, message: 'Backup exists');
    }
    final date = DateTime.tryParse(createdAt);
    if (date == null) {
      return const BackupHealth(status: BackupHealthStatus.healthy, message: 'Backup exists');
    }
    final hoursAgo = DateTime.now().difference(date).inHours;
    if (hoursAgo < 24) {
      return BackupHealth(status: BackupHealthStatus.healthy, message: 'Last backup ${hoursAgo}h ago', lastBackupTime: createdAt);
    } else if (hoursAgo < 168) { // 7 days
      final daysAgo = (hoursAgo / 24).floor();
      return BackupHealth(status: BackupHealthStatus.stale, message: 'Last backup ${daysAgo}d ago', lastBackupTime: createdAt);
    }
    final daysAgo = (hoursAgo / 24).floor();
    return BackupHealth(status: BackupHealthStatus.failed, message: 'No backup in $daysAgo days', lastBackupTime: createdAt);
  }) ?? const BackupHealth(status: BackupHealthStatus.never, message: 'Loading...');
});

// ---------------------------------------------------------------------------
// BACKUP ANALYTICS
// ---------------------------------------------------------------------------

class BackupAnalytics {
  final int backupsThisWeek;
  final int backupsThisMonth;
  final int totalBackups;
  final int lastRecordCount;
  final int previousRecordCount;

  const BackupAnalytics({
    required this.backupsThisWeek,
    required this.backupsThisMonth,
    required this.totalBackups,
    required this.lastRecordCount,
    required this.previousRecordCount,
  });

  int get recordGrowth => lastRecordCount - previousRecordCount;
}

final backupAnalyticsProvider = Provider.autoDispose<BackupAnalytics>((ref) {
  final history = ref.watch(exportHistoryProvider);
  return history.whenOrNull(data: (items) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    var weekCount = 0;
    var monthCount = 0;
    var lastRecords = 0;
    var prevRecords = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final createdAt = item['created_at'] as String?;
      if (createdAt == null) continue;
      final date = DateTime.tryParse(createdAt);
      if (date == null) continue;

      if (date.isAfter(weekAgo)) weekCount++;
      if (date.isAfter(monthAgo)) monthCount++;

      // Extract record count from filters
      final filters = item['filters'] as Map<String, dynamic>?;
      final records = filters?['total_records'] as int? ?? 0;
      if (i == 0 && records > 0) lastRecords = records;
      if (i == 1 && records > 0) prevRecords = records;
    }

    return BackupAnalytics(
      backupsThisWeek: weekCount,
      backupsThisMonth: monthCount,
      totalBackups: items.length,
      lastRecordCount: lastRecords,
      previousRecordCount: prevRecords,
    );
  }) ?? const BackupAnalytics(
    backupsThisWeek: 0, backupsThisMonth: 0, totalBackups: 0, lastRecordCount: 0, previousRecordCount: 0,
  );
});
