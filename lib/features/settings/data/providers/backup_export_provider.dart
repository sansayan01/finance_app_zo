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
// DATA MODELS
// ---------------------------------------------------------------------------

enum BackupFormat { csv, excel, pdf }

class BackupOptions {
  final BackupFormat format;
  final bool encrypt;
  final bool compress;
  final bool includeSoftDeleted;
  final String? filenamePrefix;

  const BackupOptions({
    this.format = BackupFormat.csv,
    this.encrypt = false,
    this.compress = false,
    this.includeSoftDeleted = false,
    this.filenamePrefix,
  });

  BackupOptions copyWith({
    BackupFormat? format,
    bool? encrypt,
    bool? compress,
    bool? includeSoftDeleted,
    String? filenamePrefix,
    bool clearPrefix = false,
  }) {
    return BackupOptions(
      format: format ?? this.format,
      encrypt: encrypt ?? this.encrypt,
      compress: compress ?? this.compress,
      includeSoftDeleted: includeSoftDeleted ?? this.includeSoftDeleted,
      filenamePrefix: clearPrefix ? null : (filenamePrefix ?? this.filenamePrefix),
    );
  }
}

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
// EXPORT HISTORY
// ---------------------------------------------------------------------------

final exportHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(currentOrgIdOrThrowProvider);
  final service = ref.watch(backupServiceProvider);
  return service.getExportHistory(orgId);
});

// ---------------------------------------------------------------------------
// SELECTED CATEGORIES
// ---------------------------------------------------------------------------

final selectedCategoriesProvider =
    StateProvider.autoDispose<Set<String>>((ref) {
  return kBackupCategories.map((c) => c.key).toSet();
});

// ---------------------------------------------------------------------------
// BACKUP OPTIONS
// ---------------------------------------------------------------------------

final backupOptionsProvider =
    StateProvider.autoDispose<BackupOptions>((ref) {
  return const BackupOptions();
});

// ---------------------------------------------------------------------------
// BACKUP PROGRESS
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
  final options = ref.watch(backupOptionsProvider);
  final service = ref.watch(backupServiceProvider);
  return counts.whenOrNull(
    data: (m) => service.estimateFileSize(m, selected, options.format.name),
  ) ?? 'Calculating...';
});

// ---------------------------------------------------------------------------
// SCHEDULE SETTINGS
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
// TRIGGER BACKUP NOTIFIER
// ---------------------------------------------------------------------------

class BackupTriggerNotifier extends StateNotifier<AsyncValue<void>> {
  final BackupExportService _service;
  final Ref _ref;

  BackupTriggerNotifier(this._service, this._ref)
      : super(const AsyncValue.data(null));

  void _updateProgress(BackupProgressState state) {
    _ref.read(backupProgressProvider.notifier).state = state;
  }

  Future<String?> triggerBackup({
    required String orgId,
    required String orgName,
    required Set<String> categories,
    required BackupOptions options,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    _updateProgress(const BackupProgressState(
      status: BackupProgress.fetching,
      step: 'Preparing export...',
      progress: 0.0,
    ));

    try {
      // Create export record
      _updateProgress(const BackupProgressState(
        status: BackupProgress.fetching,
        step: 'Creating export record...',
        progress: 0.05,
      ));

      await _service.createExportRecord(
        orgId: orgId,
        type: 'full_backup',
        format: options.format.name,
        filters: {
          'categories': categories.toList(),
          if (startDate != null) 'start_date': startDate.toIso8601String(),
          if (endDate != null) 'end_date': endDate.toIso8601String(),
          'encrypt': options.encrypt,
          'compress': options.compress,
        },
      );

      // Generate backup with progress
      _updateProgress(const BackupProgressState(
        status: BackupProgress.generating,
        step: 'Fetching data...',
        progress: 0.1,
      ));

      final filePath = await _service.generateFullBackup(
        orgId: orgId,
        orgName: orgName,
        selectedCategories: categories,
        format: options.format.name,
        startDate: startDate,
        endDate: endDate,
        filenamePrefix: options.filenamePrefix,
        onProgress: (step, progress) {
          _updateProgress(BackupProgressState(
            status: BackupProgress.generating,
            step: step,
            progress: 0.1 + (progress * 0.8),
          ));
        },
      );

      // Get file size
      _updateProgress(const BackupProgressState(
        status: BackupProgress.generating,
        step: 'Finalizing...',
        progress: 0.95,
      ));

      final fileSize = await _service.getFileSize(filePath);

      _updateProgress(BackupProgressState(
        status: BackupProgress.done,
        step: 'Backup complete!',
        progress: 1.0,
        filePath: filePath,
        fileSize: fileSize,
      ));

      _ref.invalidate(exportHistoryProvider);
      _ref.invalidate(categoryCountsProvider);

      state = const AsyncValue.data(null);
      return filePath;
    } catch (e, st) {
      _updateProgress(const BackupProgressState(
        status: BackupProgress.failed,
        step: 'Backup failed',
        progress: 0,
      ));
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateSchedule({
    required String orgId,
    required Map<String, dynamic> schedule,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateScheduleSettings(orgId, schedule);
      _ref.invalidate(scheduleSettingsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final backupTriggerProvider =
    StateNotifierProvider.autoDispose<BackupTriggerNotifier, AsyncValue<void>>(
        (ref) {
  return BackupTriggerNotifier(ref.watch(backupServiceProvider), ref);
});
