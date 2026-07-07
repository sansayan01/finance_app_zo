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
