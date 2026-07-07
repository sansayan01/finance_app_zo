import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/org_provider.dart';
import '../../../../core/config/env_config.dart';
import '../../../../providers/supabase_provider.dart';
import '../services/backup_export_service.dart';
import '../services/google_drive_service.dart';
import 'backup_export_provider.dart';

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

final googleDriveServiceProvider = Provider.autoDispose<GoogleDriveService>((ref) {
  return GoogleDriveService(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// CONNECTION STATE
// ---------------------------------------------------------------------------

/// Stream-like provider that watches the org settings for Drive connection state.
/// Refreshes whenever the org settings change.
final driveConnectionProvider =
    FutureProvider.autoDispose<DriveConnectionState>((ref) async {
  final orgId = ref.watch(currentOrgIdOrNullProvider);
  if (orgId == null) return const DriveConnectionState();
  final service = ref.watch(googleDriveServiceProvider);
  return service.getConnectionState(orgId);
});

/// Whether Google client IDs are configured (needed to show/hide the connect button).
final driveClientIdConfiguredProvider = Provider<bool>((ref) {
  return EnvConfig.googleWebClientId.isNotEmpty;
});

// ---------------------------------------------------------------------------
// BACKUP TRIGGER — orchestrates fetch → serialize → upload
// ---------------------------------------------------------------------------

class DriveBackupNotifier extends StateNotifier<AsyncValue<void>> {
  final GoogleDriveService _driveService;
  final BackupExportService _backupService;
  final Ref _ref;

  DriveBackupNotifier(this._driveService, this._backupService, this._ref)
      : super(const AsyncValue.data(null));

  void _updateProgress(BackupProgressState state) {
    _ref.read(backupProgressProvider.notifier).state = state;
  }

  /// Trigger a full backup: fetch data → build JSON → upload to Drive.
  Future<DriveBackupResult?> triggerBackup({
    required String orgId,
    required String orgName,
  }) async {
    final connection = _ref.read(driveConnectionProvider).valueOrNull;
    if (connection == null || !connection.connected) {
      throw Exception('Google Drive is not connected.');
    }

    state = const AsyncValue.loading();
    _updateProgress(const BackupProgressState(
      status: BackupProgress.fetching,
      step: 'Preparing backup...',
      progress: 0.0,
    ));

    try {
      // 1. Fetch all category data with progress
      final categoryData = <String, List<Map<String, dynamic>>>{};
      final total = kBackupCategories.length;

      for (var i = 0; i < total; i++) {
        final cat = kBackupCategories[i];
        final progress = (i + 1) / total;
        _updateProgress(BackupProgressState(
          status: BackupProgress.fetching,
          step: 'Fetching ${cat.label}...',
          progress: progress * 0.6, // 60% of progress for fetching
        ));
        final data = await _backupService.fetchTableData(
          orgId,
          cat.tableName,
        );
        categoryData[cat.key] = data;
      }

      // 2. Build JSON payload
      _updateProgress(const BackupProgressState(
        status: BackupProgress.generating,
        step: 'Building JSON...',
        progress: 0.65,
      ));

      final totalRecords = categoryData.values.fold<int>(0, (a, b) => a + b.length);
      final rowCounts = <String, int>{};
      for (final entry in categoryData.entries) {
        rowCounts[entry.key] = entry.value.length;
      }

      final backupPayload = {
        'metadata': {
          'org_id': orgId,
          'org_name': orgName,
          'generated_at': DateTime.now().toIso8601String(),
          'app_version': EnvConfig.appVersion,
          'total_records': totalRecords,
          'categories': rowCounts,
          'schema_version': '1.0',
        },
        'data': categoryData,
      };

      // 3. Upload to Google Drive
      _updateProgress(const BackupProgressState(
        status: BackupProgress.generating,
        step: 'Uploading to Google Drive...',
        progress: 0.7,
      ));

      final uploadResult = await _driveService.uploadJsonBackup(
        connection: connection,
        orgName: orgName,
        jsonData: backupPayload,
      );

      // 4. Record in data_exports table
      _updateProgress(const BackupProgressState(
        status: BackupProgress.generating,
        step: 'Recording export...',
        progress: 0.9,
      ));

      final backupService = _ref.read(backupServiceProvider);
      await backupService.createExportRecord(
        orgId: orgId,
        type: 'full_backup',
        format: 'json',
        filters: {
          'categories': kBackupCategories.map((c) => c.key).toList(),
          'total_records': totalRecords,
          'file_id': uploadResult['file_id'],
          'drive_url': uploadResult['drive_url'],
        },
      );

      // 5. Done
      _updateProgress(BackupProgressState(
        status: BackupProgress.done,
        step: 'Backup complete!',
        progress: 1.0,
        filePath: uploadResult['drive_url'],
        fileSize: uploadResult['file_size'] as String?,
      ));

      _ref.invalidate(exportHistoryProvider);
      _ref.invalidate(categoryCountsProvider);

      state = const AsyncValue.data(null);

      return DriveBackupResult(
        fileName: uploadResult['file_name'] as String,
        fileSize: uploadResult['file_size'] as String,
        driveUrl: uploadResult['drive_url'] as String,
        totalRecords: totalRecords,
      );
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
}

class DriveBackupResult {
  final String fileName;
  final String fileSize;
  final String driveUrl;
  final int totalRecords;

  const DriveBackupResult({
    required this.fileName,
    required this.fileSize,
    required this.driveUrl,
    required this.totalRecords,
  });
}

final driveBackupTriggerProvider =
    StateNotifierProvider.autoDispose<DriveBackupNotifier, AsyncValue<void>>(
        (ref) {
  return DriveBackupNotifier(
    ref.watch(googleDriveServiceProvider),
    ref.watch(backupServiceProvider),
    ref,
  );
});

// ---------------------------------------------------------------------------
// DRIVE BACKUPS LIST (from Google Drive directly)
// ---------------------------------------------------------------------------

final driveBackupsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final connection = ref.watch(driveConnectionProvider).valueOrNull;
  if (connection == null || !connection.connected) return const [];
  final service = ref.watch(googleDriveServiceProvider);
  return service.listBackups(connection);
});
