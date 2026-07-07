import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/supabase_provider.dart';
import '../services/google_drive_service.dart';
import '../services/restore_backup_service.dart';
import 'backup_export_provider.dart';
import 'google_drive_provider.dart';

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

final restoreBackupServiceProvider = Provider.autoDispose<RestoreBackupService>((ref) {
  return RestoreBackupService(
    ref.watch(supabaseClientProvider),
    ref.watch(googleDriveServiceProvider),
  );
});

// ---------------------------------------------------------------------------
// RESTORE PROGRESS
// ---------------------------------------------------------------------------

enum RestoreProgress { idle, downloading, parsing, restoring, done, failed }

class RestoreProgressState {
  final RestoreProgress status;
  final String step;
  final double progress;
  final int currentTable;
  final int totalTables;
  final RestoreResult? result;
  final String? error;

  const RestoreProgressState({
    this.status = RestoreProgress.idle,
    this.step = '',
    this.progress = 0.0,
    this.currentTable = 0,
    this.totalTables = 0,
    this.result,
    this.error,
  });

  RestoreProgressState copyWith({
    RestoreProgress? status,
    String? step,
    double? progress,
    int? currentTable,
    int? totalTables,
    RestoreResult? result,
    String? error,
  }) {
    return RestoreProgressState(
      status: status ?? this.status,
      step: step ?? this.step,
      progress: progress ?? this.progress,
      currentTable: currentTable ?? this.currentTable,
      totalTables: totalTables ?? this.totalTables,
      result: result ?? this.result,
      error: error,
    );
  }
}

final restoreProgressProvider =
    StateProvider.autoDispose<RestoreProgressState>((ref) {
  return const RestoreProgressState();
});

// ---------------------------------------------------------------------------
// SELECTED BACKUP (for detail/confirm view)
// ---------------------------------------------------------------------------

class SelectedBackupInfo {
  final String fileId;
  final String fileName;
  final String? createdTime;
  final int? fileSize;

  const SelectedBackupInfo({
    required this.fileId,
    required this.fileName,
    this.createdTime,
    this.fileSize,
  });
}

final selectedBackupProvider =
    StateProvider.autoDispose<SelectedBackupInfo?>((ref) => null);

// ---------------------------------------------------------------------------
// RESTORE TRIGGER NOTIFIER
// ---------------------------------------------------------------------------

class RestoreTriggerNotifier extends StateNotifier<AsyncValue<void>> {
  final RestoreBackupService _restoreService;
  final Ref _ref;

  RestoreTriggerNotifier(this._restoreService, this._ref)
      : super(const AsyncValue.data(null));

  void _updateProgress(RestoreProgressState state) {
    _ref.read(restoreProgressProvider.notifier).state = state;
  }

  /// Restore from a Google Drive backup file.
  Future<RestoreResult?> triggerRestore({
    required String orgId,
    required DriveConnectionState connection,
    required String fileId,
    required String fileName,
    Set<String>? selectedCategories,
  }) async {
    state = const AsyncValue.loading();
    _updateProgress(const RestoreProgressState(
      status: RestoreProgress.downloading,
      step: 'Downloading backup from Google Drive...',
      progress: 0.0,
    ));

    try {
      // 1. Download backup JSON
      final backup = await _restoreService.downloadBackup(
        connection: connection,
        fileId: fileId,
      );

      // 2. Validate structure
      _updateProgress(const RestoreProgressState(
        status: RestoreProgress.parsing,
        step: 'Validating backup structure...',
        progress: 0.1,
      ));

      final summary = _restoreService.validateBackup(backup);
      debugPrint('Restore: backup from ${summary['org_name']}, '
          '${summary['total_records']} records, '
          '${summary['table_count']} tables');

      // 3. Restore with progress
      _updateProgress(RestoreProgressState(
        status: RestoreProgress.restoring,
        step: 'Restoring data...',
        progress: 0.15,
      ));

      final result = await _restoreService.restoreBackup(
        orgId: orgId,
        backup: backup,
        selectedCategories: selectedCategories,
        onProgress: (step, progress, current, total) {
          _updateProgress(RestoreProgressState(
            status: RestoreProgress.restoring,
            step: step,
            progress: 0.15 + (progress * 0.8),
            currentTable: current,
            totalTables: total,
          ));
        },
      );

      // 4. Done
      _updateProgress(RestoreProgressState(
        status: RestoreProgress.done,
        step: 'Restore complete!',
        progress: 1.0,
        result: result,
      ));

      // Refresh data providers
      _ref.invalidate(categoryCountsProvider);
      _ref.invalidate(exportHistoryProvider);

      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      _updateProgress(RestoreProgressState(
        status: RestoreProgress.failed,
        step: 'Restore failed',
        progress: 0,
        error: e.toString(),
      ));
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final restoreTriggerProvider =
    StateNotifierProvider.autoDispose<RestoreTriggerNotifier, AsyncValue<void>>(
        (ref) {
  return RestoreTriggerNotifier(
    ref.watch(restoreBackupServiceProvider),
    ref,
  );
});

// ---------------------------------------------------------------------------
// SELECTIVE RESTORE
// ---------------------------------------------------------------------------

/// FK dependency graph — children require parents
const Map<String, List<String>> restoreDependencies = {
  'loans': ['members', 'branches'],
  'emi_schedule': ['loans', 'members'],
  'savings': ['members', 'branches'],
  'savings_plans': ['members'],
  'transactions': ['loans', 'members'],
  'collections': ['loans', 'members', 'branches'],
  'savings_collections': ['savings', 'members'],
  'cash_deposits': ['staff_profiles'],
  'wallet_transactions': ['staff_profiles'],
  'visit_logs': ['staff_profiles'],
  'staff_streaks': ['staff_profiles'],
  'achievements': ['staff_profiles'],
};

/// All categories in the backup (read from backup metadata)
final backupCategoriesProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

/// Selected categories for restore (default: all)
final selectedCategoriesForRestoreProvider = StateProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(backupCategoriesProvider);
});

/// Auto-toggle dependencies when user selects/deselects a category
Set<String> applyDependencies(Set<String> selected, String category, bool add, Map<String, List<String>> deps) {
  final result = Set<String>.from(selected);
  if (add) {
    // Add category and all its parents
    result.add(category);
    for (final parent in deps[category] ?? []) {
      result.add(parent);
    }
  } else {
    // Remove category and all its children that depend on it
    result.remove(category);
    for (final entry in deps.entries) {
      if (entry.value.contains(category)) {
        // Check if any other parent of this child is still selected
        final otherParentsSelected = entry.value.any((p) => p != category && result.contains(p));
        if (!otherParentsSelected) {
          result.remove(entry.key);
        }
      }
    }
  }
  return result;
}
