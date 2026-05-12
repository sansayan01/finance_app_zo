import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Sync status for offline records
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

/// Offline Sync Engine for field operations
/// Handles queuing, syncing, and conflict resolution
class OfflineSyncEngine {
  static const String _queueKey = 'offline_queue';
  static const String _lastSyncKey = 'last_sync_time';

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  OfflineSyncEngine(this._client, this._prefs);

  /// Queue an operation for offline sync
  Future<void> queueOperation({
    required String operation,
    required String table,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    final queue = await _getQueue();

    final item = {
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'operation': operation, // 'insert', 'update', 'delete'
      'table': table,
      'data': data,
      'queued_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'status': 'pending',
    };

    queue.add(item);
    await _saveQueue(queue);
  }

  /// Get pending operations count
  Future<int> getPendingCount() async {
    final queue = await _getQueue();
    return queue.where((item) => item['status'] == 'pending').length;
  }

  /// Get all pending operations
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final queue = await _getQueue();
    return queue.where((item) => item['status'] == 'pending').toList().cast<Map<String, dynamic>>();
  }

  /// Sync all pending operations
  Future<SyncResult> syncAll() async {
    final queue = await _getQueue();
    final pending = queue.where((item) => item['status'] == 'pending').toList();

    if (pending.isEmpty) {
      return SyncResult(success: 0, failed: 0, pending: 0);
    }

    int success = 0;
    int failed = 0;

    for (var item in pending) {
      try {
        item['status'] = 'syncing';
        item['attempts'] = (item['attempts'] as int? ?? 0) + 1;
        await _saveQueue(queue);

        await _syncSingle(item);
        item['status'] = 'synced';
        item['synced_at'] = DateTime.now().toIso8601String();
        success++;
      } catch (e) {
        item['status'] = 'failed';
        item['last_error'] = e.toString();
        failed++;

        // Remove if max attempts reached
        if ((item['attempts'] as int) >= 5) {
          queue.remove(item);
          continue;
        }
      }

      await _saveQueue(queue);
    }

    // Update last sync time
    await _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    // Clean up synced items older than 24 hours
    await _cleanupSyncedItems();

    return SyncResult(
      success: success,
      failed: failed,
      pending: queue.where((item) => item['status'] == 'pending').length,
    );
  }

  /// Sync a single operation
  Future<void> _syncSingle(Map<String, dynamic> item) async {
    final operation = item['operation'] as String;
    final table = item['table'] as String;
    final data = Map<String, dynamic>.from(item['data'] as Map);

    switch (operation) {
      case 'insert':
        await _client.from(table).insert(data);
        break;
      case 'update':
        final id = data['id'];
        await _client.from(table).update(data).eq('id', id);
        break;
      case 'delete':
        final id = data['id'];
        await _client.from(table).delete().eq('id', id);
        break;
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  /// Get offline queue
  Future<List<Map<String, dynamic>>> _getQueue() async {
    final queueStr = _prefs.getString(_queueKey);
    if (queueStr == null) return [];

    final List<dynamic> decoded = jsonDecode(queueStr);
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Save offline queue
  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Clean up synced items older than 24 hours
  Future<void> _cleanupSyncedItems() async {
    final queue = await _getQueue();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    queue.removeWhere((item) {
      if (item['status'] != 'synced') return false;
      final syncedAt = DateTime.tryParse(item['synced_at'] ?? '');
      return syncedAt != null && syncedAt.isBefore(cutoff);
    });

    await _saveQueue(queue);
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final syncTime = _prefs.getString(_lastSyncKey);
    return syncTime != null ? DateTime.tryParse(syncTime) : null;
  }

  /// Clear entire queue (use with caution)
  Future<void> clearQueue() async {
    await _prefs.remove(_queueKey);
  }

  /// Check if device is online
   Future<bool> isOnline() async {
     return await InternetConnectionChecker().hasConnection;
   }
}

/// Result of a sync operation
class SyncResult {
  final int success;
  final int failed;
  final int pending;

  SyncResult({
    required this.success,
    required this.failed,
    required this.pending,
  });

  int get total => success + failed + pending;
  double get successRate => total > 0 ? success / total : 0;
}
