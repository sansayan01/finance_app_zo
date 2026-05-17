import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sync Status Model
class SyncStatus {
  final int pending;
  final int success;
  final int failed;
  final DateTime? lastSync;
  final bool isOnline;
  final bool isSyncing;

  const SyncStatus({
    this.pending = 0,
    this.success = 0,
    this.failed = 0,
    this.lastSync,
    this.isOnline = true,
    this.isSyncing = false,
  });

  SyncStatus copyWith({
    int? pending,
    int? success,
    int? failed,
    DateTime? lastSync,
    bool? isOnline,
    bool? isSyncing,
  }) {
    return SyncStatus(
      pending: pending ?? this.pending,
      success: success ?? this.success,
      failed: failed ?? this.failed,
      lastSync: lastSync ?? this.lastSync,
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  int get total => pending + success + failed;
  double get successRate => total > 0 ? success / total : 0;
}

/// Sync Status Provider
///
/// This is a simplified provider for the router.
/// The full implementation is in sync_providers.dart
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  return SyncStatusNotifier();
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  SyncStatusNotifier() : super(const SyncStatus());

  void updatePending(int count) {
    state = state.copyWith(pending: count);
  }

  void updateOnline(bool isOnline) {
    state = state.copyWith(isOnline: isOnline);
  }

  void updateSyncing(bool isSyncing) {
    state = state.copyWith(isSyncing: isSyncing);
  }

  void recordSuccess() {
    state = state.copyWith(
      pending: state.pending > 0 ? state.pending - 1 : 0,
      success: state.success + 1,
      lastSync: DateTime.now(),
    );
  }

  void recordFailure() {
    state = state.copyWith(
      pending: state.pending > 0 ? state.pending - 1 : 0,
      failed: state.failed + 1,
    );
  }

  void addPending(int count) {
    state = state.copyWith(pending: state.pending + count);
  }

  void reset() {
    state = const SyncStatus();
  }
}
