import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_drive_service.dart';

/// Progress callback for restore operations.
typedef RestoreProgressCallback = void Function(String step, double progress, int currentTable, int totalTables);

/// Result of a restore operation.
class RestoreResult {
  final int totalRecords;
  final int tablesRestored;
  final int tablesFailed;
  final List<String> errors;

  const RestoreResult({
    required this.totalRecords,
    required this.tablesRestored,
    required this.tablesFailed,
    required this.errors,
  });
}

/// Service for restoring organization data from a Google Drive backup.
class RestoreBackupService {
  final SupabaseClient _client;
  final GoogleDriveService _driveService;

  RestoreBackupService(this._client, this._driveService);

  // ── Table order (foreign key dependencies) ────────────────────────────
  //
  // Tables must be restored in dependency order: parents before children.
  // This list determines the upsert sequence.

  static const _restoreOrder = [
    'branches',
    'profiles',
    'org_branding',
    'members',
    'loans',
    'emi_schedule',
    'savings',
    'savings_plans',
    'transactions',
    'collections',
    'savings_collections',
    'cash_deposits',
    'wallet_transactions',
    'staff_profiles',
    'activity_logs',
    'visit_logs',
    'staff_streaks',
    'achievements',
    'offline_queue',
  ];

  // ── Download backup from Drive ────────────────────────────────────────

  /// Download and parse a backup JSON from Google Drive.
  Future<Map<String, dynamic>> downloadBackup({
    required DriveConnectionState connection,
    required String fileId,
  }) async {
    final accessToken = await _driveService.getAccessToken(connection);

    final resp = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId'
        '?alt=media',
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to download backup: ${resp.statusCode}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ── Validate backup structure ─────────────────────────────────────────

  /// Validate the backup JSON has the expected structure.
  /// Returns a summary of what's in the backup.
  Map<String, dynamic> validateBackup(Map<String, dynamic> backup) {
    final metadata = backup['metadata'] as Map<String, dynamic>?;
    final data = backup['data'] as Map<String, dynamic>?;

    if (metadata == null || data == null) {
      throw Exception('Invalid backup format: missing metadata or data');
    }

    final schemaVersion = metadata['schema_version'] as String?;
    if (schemaVersion == null) {
      throw Exception('Invalid backup: missing schema_version');
    }

    final totalRecords = metadata['total_records'] as int? ?? 0;
    final categories = metadata['categories'] as Map<String, dynamic>? ?? {};
    final orgName = metadata['org_name'] as String? ?? 'Unknown';
    final generatedAt = metadata['generated_at'] as String? ?? '';

    return {
      'org_name': orgName,
      'generated_at': generatedAt,
      'total_records': totalRecords,
      'categories': categories,
      'schema_version': schemaVersion,
      'table_count': data.keys.length,
    };
  }

  // ── Restore (upsert all tables) ──────────────────────────────────────

  /// Restore data from a parsed backup JSON into the database.
  ///
  /// Uses Supabase `upsert` (INSERT ... ON CONFLICT DO UPDATE) so:
  /// - Existing records (matching `id`) are updated
  /// - New records are inserted
  /// - No data is deleted
  Future<RestoreResult> restoreBackup({
    required String orgId,
    required Map<String, dynamic> backup,
    RestoreProgressCallback? onProgress,
  }) async {
    final data = backup['data'] as Map<String, dynamic>? ?? {};
    final errors = <String>[];
    var totalRecords = 0;
    var tablesRestored = 0;
    var tablesFailed = 0;

    // Get only the tables that exist in both the backup and our restore order
    final tablesToRestore = _restoreOrder
        .where((t) => data.containsKey(t) && (data[t] as List).isNotEmpty)
        .toList();

    // Also include any tables in the backup that aren't in our order
    // (forward compatibility with newer backup versions)
    for (final key in data.keys) {
      if (!tablesToRestore.contains(key)) {
        final rows = data[key] as List? ?? [];
        if (rows.isNotEmpty) tablesToRestore.add(key);
      }
    }

    final total = tablesToRestore.length;

    for (var i = 0; i < total; i++) {
      final tableName = tablesToRestore[i];
      final rows = (data[tableName] as List?)?.cast<Map<String, dynamic>>() ?? [];

      onProgress?.call(
        'Restoring $tableName...',
        (i + 1) / total,
        i + 1,
        total,
      );

      try {
        // Filter rows to only include columns that exist in the target table.
        // This handles schema drift (backup has columns the DB doesn't, or vice versa).
        final filteredRows = await _filterToValidColumns(tableName, rows);

        if (filteredRows.isEmpty) {
          debugPrint('restore: $tableName — no valid rows after filtering');
          continue;
        }

        // Upsert in batches of 500 (Supabase recommended limit)
        const batchSize = 500;
        for (var batch = 0; batch < filteredRows.length; batch += batchSize) {
          final end = (batch + batchSize).clamp(0, filteredRows.length);
          final chunk = filteredRows.sublist(batch, end);

          await _client.from(tableName).upsert(
                chunk,
                onConflict: 'id',
              );

          totalRecords += chunk.length;
        }

        tablesRestored++;
        debugPrint('restore: $tableName — ${filteredRows.length} rows restored');
      } catch (e) {
        tablesFailed++;
        final msg = '$tableName: $e';
        errors.add(msg);
        debugPrint('restore: FAILED — $msg');
        // Continue with next table — don't abort the entire restore
      }
    }

    onProgress?.call('Restore complete!', 1.0, total, total);

    return RestoreResult(
      totalRecords: totalRecords,
      tablesRestored: tablesRestored,
      tablesFailed: tablesFailed,
      errors: errors,
    );
  }

  // ── Column filtering ──────────────────────────────────────────────────

  /// Filter backup rows to only include columns that exist in the target table.
  /// Prevents Postgrest errors from schema drift.
  Future<List<Map<String, dynamic>>> _filterToValidColumns(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    try {
      // Get the table's column names by querying a single row with minimal data
      final sample = await _client
          .from(tableName)
          .select()
          .limit(1);

      if (sample.isEmpty) {
        // Table is empty — use the backup's column names as-is
        // (they'll be validated by Supabase on insert)
        return rows;
      }

      // Get column names from the sample row
      final validColumns = sample.first.keys.toSet();

      // Filter each row to only valid columns
      return rows.map((row) {
        final filtered = <String, dynamic>{};
        for (final entry in row.entries) {
          if (validColumns.contains(entry.key)) {
            filtered[entry.key] = entry.value;
          }
        }
        return filtered;
      }).toList();
    } catch (e) {
      debugPrint('restore: column filtering failed for $tableName: $e');
      // If we can't determine columns, return rows as-is and let Supabase validate
      return rows;
    }
  }
}
