import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database.dart';
import 'offline_sync_engine.dart';
import '../../../../core/providers/storage_providers.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

/// Background sync service that handles automatic synchronization
/// between local database and Supabase
class BackgroundSyncService {
  final SupabaseClient _client;
  final LocalDatabase _localDb;
  final OfflineSyncEngine _syncEngine;

  Timer? _syncTimer;
  bool _isSyncing = false;
  final Duration _syncInterval = const Duration(minutes: 5);

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  BackgroundSyncService(
    this._client,
    this._localDb,
    this._syncEngine,
  );

  /// Start automatic background sync
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      syncIfOnline();
    });
  }

  /// Stop automatic background sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform sync if device is online
  Future<SyncResult> syncIfOnline() async {
    if (_isSyncing) {
      return SyncResult(success: 0, failed: 0, pending: 0);
    }

    final isOnline = await _syncEngine.isOnline();
    if (!isOnline) {
      _syncStatusController.add(SyncStatus.offline);
      return SyncResult(success: 0, failed: 0, pending: 0);
    }

    return await performFullSync();
  }

  /// Perform a full sync operation
  Future<SyncResult> performFullSync() async {
    if (_isSyncing) {
      return SyncResult(success: 0, failed: 0, pending: 0);
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    int success = 0;
    int failed = 0;

    try {
      // 1. Sync pending operations to server
      final pendingResult = await _syncEngine.syncAll();
      success += pendingResult.success;
      failed += pendingResult.failed;

      // 2. Pull latest data from server
      await _pullServerData();

      // 3. Update last sync time
      await _localDb.setLastSyncTime(DateTime.now());

      _syncStatusController.add(SyncStatus.synced);

      return SyncResult(
        success: success,
        failed: failed,
        pending: pendingResult.pending,
      );
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      return SyncResult(success: success, failed: failed, pending: 0);
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull latest data from server
  Future<void> _pullServerData() async {
    final staffId = _localDb.getCurrentStaffId();
    if (staffId == null) return;

    // Pull customers
    final customers = await _client.from('members').select('''
          *,
          loans(
            id,
            loan_number,
            principal,
            interest_rate,
            status,
            outstanding_balance,
            emi_schedule(
              id,
              installment_number AS period,
              due_date,
              emi_amount AS emi,
              is_paid,
              is_overdue
            )
          ),
          savings(
            id,
            account_number,
            balance
          )
        ''').limit(500);

    await _localDb.syncCustomers(List<Map<String, dynamic>>.from(customers));

    // Pull recent collections
    final collections = await _client
        .from('collections')
        .select()
        .eq('staff_id', staffId)
        .order('collection_time', ascending: false)
        .limit(100);

    for (final collection in collections) {
      await _localDb.putCollection(
        collection['id'] as String,
        Map<String, dynamic>.from(collection),
      );
    }
  }

  /// Force sync now
  Future<SyncResult> forceSync() async {
    return await performFullSync();
  }

  /// Get current sync state
  BackgroundSyncState getCurrentState() {
    return BackgroundSyncState(
      isSyncing: _isSyncing,
      lastSyncTime: _localDb.getLastSyncTime(),
      pendingOperations: _localDb.getPendingOperations().length,
    );
  }

  void dispose() {
    stopAutoSync();
    _syncStatusController.close();
  }
}

enum SyncStatus {
  syncing,
  synced,
  offline,
  error,
}

class SyncResult {
  final int success;
  final int failed;
  final int pending;

  SyncResult({
    required this.success,
    required this.failed,
    required this.pending,
  });

  bool get hasErrors => failed > 0;
  bool get isComplete => pending == 0;
}

class BackgroundSyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final int pendingOperations;

  BackgroundSyncState({
    required this.isSyncing,
    this.lastSyncTime,
    required this.pendingOperations,
  });
}

/// Provider for background sync service
final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final localDb = LocalDatabase();
  final syncEngine =
      OfflineSyncEngine(client, ref.watch(sharedPreferencesProvider));

  return BackgroundSyncService(client, localDb, syncEngine);
});
