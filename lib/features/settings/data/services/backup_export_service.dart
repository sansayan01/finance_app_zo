import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env_config.dart';

// ---------------------------------------------------------------------------
// CATEGORY DEFINITIONS (no Flutter UI types — icons/colors live in the page)
// ---------------------------------------------------------------------------

class BackupCategoryDef {
  final String key;
  final String tableName;
  final String label;

  const BackupCategoryDef({
    required this.key,
    required this.tableName,
    required this.label,
  });
}

class BackupCategory {
  static const members = 'members';
  static const loans = 'loans';
  static const emiSchedule = 'emi_schedule';
  static const savings = 'savings';
  static const savingsPlans = 'savings_plans';
  static const transactions = 'transactions';
  static const collections = 'collections';
  static const savingsCollections = 'savings_collections';
  static const branches = 'branches';
  static const staffProfiles = 'staff_profiles';
  static const activityLogs = 'activity_logs';
  static const visitLogs = 'visit_logs';
  static const cashDeposits = 'cash_deposits';
  static const walletTransactions = 'wallet_transactions';
  static const staffStreaks = 'staff_streaks';
  static const achievements = 'achievements';
  static const offlineQueue = 'offline_sync_queue';
  // NOTE: `sync_conflicts` is intentionally excluded — it has no `org_id`
  // column and holds transient conflict records, not restorable data.
}

/// All backup-eligible categories. Backed up in this order.
/// Tables are ordered by dependency (parent before child).
const List<BackupCategoryDef> kBackupCategories = [
  // Core identity & config
  BackupCategoryDef(key: 'profiles', tableName: 'profiles', label: 'User Profiles'),
  BackupCategoryDef(key: 'branches', tableName: 'branches', label: 'Branches'),
  BackupCategoryDef(key: 'org_branding', tableName: 'org_branding', label: 'Branding'),

  // Customers & financial products
  BackupCategoryDef(key: 'members', tableName: 'members', label: 'Members'),
  BackupCategoryDef(key: 'loans', tableName: 'loans', label: 'Loans'),
  BackupCategoryDef(key: 'emi_schedule', tableName: 'emi_schedule', label: 'EMI Schedule'),
  BackupCategoryDef(key: 'savings', tableName: 'savings', label: 'Savings'),
  BackupCategoryDef(key: 'savings_plans', tableName: 'savings_plans', label: 'Savings Plans'),

  // Transactions & collections
  BackupCategoryDef(key: 'transactions', tableName: 'transactions', label: 'Transactions'),
  BackupCategoryDef(key: 'collections', tableName: 'collections', label: 'Collections'),
  BackupCategoryDef(key: 'savings_collections', tableName: 'savings_collections', label: 'Savings Coll.'),
  BackupCategoryDef(key: 'cash_deposits', tableName: 'cash_deposits', label: 'Cash Deposits'),
  BackupCategoryDef(key: 'wallet_transactions', tableName: 'wallet_transactions', label: 'Wallet Txns'),

  // Staff & operations
  BackupCategoryDef(key: 'staff_profiles', tableName: 'staff_profiles', label: 'Staff'),
  BackupCategoryDef(key: 'activity_logs', tableName: 'activity_logs', label: 'Activity Logs'),
  BackupCategoryDef(key: 'visit_logs', tableName: 'visit_logs', label: 'Visit Logs'),
  BackupCategoryDef(key: 'staff_streaks', tableName: 'staff_streaks', label: 'Streaks'),
  BackupCategoryDef(key: 'achievements', tableName: 'achievements', label: 'Achievements'),
  BackupCategoryDef(key: 'offline_queue', tableName: 'offline_sync_queue', label: 'Offline Queue'),
];

// ---------------------------------------------------------------------------
// SERVICE
// ---------------------------------------------------------------------------

class BackupExportService {
  final SupabaseClient _client;

  BackupExportService(this._client);

  // ── CATEGORY COUNTS ───────────────────────────────────────────────────

  Future<Map<String, int>> getCategoryCounts(String orgId) async {
    final results = await Future.wait(
      kBackupCategories.map((cat) async {
        try {
          final count = await _client
              .from(cat.tableName)
              .select('id')
              .eq('org_id', orgId)
              .count();
          return MapEntry(cat.key, count.count);
        } catch (_) {
          return MapEntry(cat.key, 0);
        }
      }),
    );
    return Map.fromEntries(results);
  }

  // ── TABLE DATA FETCH ─────────────────────────────────────────────────
  //
  // NOTE on data quality: several tables (`loans`, `members`, `savings`,
  // `activity_logs`, `staff_streaks`, `achievements`) have a NULLABLE
  // `org_id`. This query filters with `.eq('org_id', orgId)`, so rows with
  // a null `org_id` are silently excluded. The backup faithfully captures
  // what the org-scoped query returns; fixing the underlying null org_id
  // rows is a separate data-quality migration, not something this service
  // should paper over.

  Future<List<Map<String, dynamic>>> fetchTableData(
    String orgId,
    String tableName, {
    DateTime? start,
    DateTime? end,
    int limit = 10000,
  }) async {
    try {
      var query = _client.from(tableName).select().eq('org_id', orgId);
      if (start != null) query = query.gte('created_at', start.toIso8601String());
      if (end != null) query = query.lte('created_at', end.toIso8601String());
      final result = await query.limit(limit);
      return List<Map<String, dynamic>>.from(result as List? ?? const []);
    } catch (e) {
      debugPrint('fetchTableData($tableName) error: $e');
      return const [];
    }
  }

  // ── FULL BACKUP → JSON PAYLOAD ───────────────────────────────────────
  //
  // Returns a JSON-serializable Map (NOT a file path). The Drive service
  // is responsible for serializing + uploading. The notifier orchestrates
  // fetching; this helper just builds the envelope given pre-fetched data.

  Map<String, dynamic> buildJsonBackup({
    required String orgId,
    required String orgName,
    required Map<String, List<Map<String, dynamic>>> categoryData,
  }) {
    final totalRecords = categoryData.values.fold<int>(0, (a, b) => a + b.length);
    final rowCounts = <String, int>{};
    for (final entry in categoryData.entries) {
      rowCounts[entry.key] = entry.value.length;
    }

    return {
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
  }

  // ── EXPORT HISTORY ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExportHistory(String orgId) async {
    try {
      final result = await _client
          .from('data_exports')
          .select()
          .eq('org_id', orgId)
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(result as List? ?? const []);
    } catch (e) {
      debugPrint('getExportHistory error: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> createExportRecord({
    required String orgId,
    required String type,
    required String format,
    Map<String, dynamic>? filters,
    String? createdBy,
  }) async {
    try {
      final response = await _client
          .from('data_exports')
          .insert({
            'org_id': orgId,
            'type': type,
            'format': format,
            'filters': filters ?? {},
            if (createdBy != null) 'created_by': createdBy,
            'status': 'completed',
          })
          .select()
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('createExportRecord error: $e');
      return null;
    }
  }

  // ── SCHEDULE SETTINGS ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getScheduleSettings(String orgId) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final settings = result?['settings'] as Map<String, dynamic>? ?? {};
      return (settings['backup_schedule'] as Map<String, dynamic>?) ??
          _defaultSchedule();
    } catch (e) {
      debugPrint('getScheduleSettings error: $e');
      return _defaultSchedule();
    }
  }

  Map<String, dynamic> _defaultSchedule() => {
        'enabled': false,
        'frequency': 'weekly',
        'day_of_week': 1,
        'time_hour': 2,
        'time_minute': 0,
        'categories': kBackupCategories.map((c) => c.key).toList(),
        'notify_on_complete': true,
      };

  Future<bool> updateScheduleSettings(
      String orgId, Map<String, dynamic> schedule) async {
    try {
      final result = await _client
          .from('organizations')
          .select('settings')
          .eq('id', orgId)
          .maybeSingle();

      final currentSettings = Map<String, dynamic>.from(
        (result?['settings'] as Map<String, dynamic>?) ?? {},
      );
      currentSettings['backup_schedule'] = schedule;

      await _client
          .from('organizations')
          .update({
            'settings': currentSettings,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orgId);

      return true;
    } catch (e) {
      debugPrint('updateScheduleSettings error: $e');
      return false;
    }
  }

  // ── ESTIMATED SIZE ───────────────────────────────────────────────────

  /// Rough estimate of backup size based on record counts.
  /// JSON averages ~250 bytes/row.
  String estimateFileSize(Map<String, int> counts, Set<String> selected, String format) {
    var totalRows = 0;
    for (final key in selected) {
      totalRows += counts[key] ?? 0;
    }

    const bytesPerRow = 250; // JSON
    final estimatedBytes = totalRows * bytesPerRow + 5000; // 5KB overhead
    if (estimatedBytes < 1024) return '~${estimatedBytes}B';
    if (estimatedBytes < 1024 * 1024) return '~${(estimatedBytes / 1024).toStringAsFixed(0)}KB';
    return '~${(estimatedBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
