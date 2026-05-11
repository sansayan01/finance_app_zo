import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/supabase_provider.dart';
import '../services/offline_sync_engine.dart';

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

// Sync engine provider
final syncEngineProvider = Provider<OfflineSyncEngine>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return OfflineSyncEngine(client, prefs);
});

// Pending operations count
final pendingOperationsCountProvider = FutureProvider<int>((ref) async {
  final engine = ref.watch(syncEngineProvider);
  return engine.getPendingCount();
});

// Last sync time
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.getLastSyncTime();
});

// Sync status
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return SyncStatusNotifier(engine);
});

class SyncState {
  final bool isSyncing;
  final int pending;
  final int success;
  final int failed;
  final String? error;
  final DateTime? lastSync;

  SyncState({
    this.isSyncing = false,
    this.pending = 0,
    this.success = 0,
    this.failed = 0,
    this.error,
    this.lastSync,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pending,
    int? success,
    int? failed,
    String? error,
    DateTime? lastSync,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pending: pending ?? this.pending,
      success: success ?? this.success,
      failed: failed ?? this.failed,
      error: error,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class SyncStatusNotifier extends StateNotifier<SyncState> {
  final OfflineSyncEngine _engine;

  SyncStatusNotifier(this._engine) : super(SyncState()) {
    _init();
  }

  Future<void> _init() async {
    final pending = await _engine.getPendingCount();
    final lastSync = _engine.getLastSyncTime();
    state = state.copyWith(pending: pending, lastSync: lastSync);
  }

  Future<void> sync() async {
    state = state.copyWith(isSyncing: true, error: null);

    try {
      final isOnline = await _engine.isOnline();
      if (!isOnline) {
        state = state.copyWith(
          isSyncing: false,
          error: 'No internet connection',
        );
        return;
      }

      final result = await _engine.syncAll();

      state = state.copyWith(
        isSyncing: false,
        pending: result.pending,
        success: result.success,
        failed: result.failed,
        lastSync: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    final pending = await _engine.getPendingCount();
    state = state.copyWith(pending: pending);
  }

  Future<void> queueOperation({
    required String operation,
    required String table,
    required Map<String, dynamic> data,
    String? id,
  }) async {
    await _engine.queueOperation(
      operation: operation,
      table: table,
      data: data,
      id: id,
    );
    await refresh();
  }
}

// Network status provider
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  
  // Check immediately
  yield await engine.isOnline();
  
  // Then check every 5 seconds
  await Future.delayed(const Duration(seconds: 5));
  yield await engine.isOnline();
});
