import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles TTL cleanup of old location records.
/// Runs batch deletes to prevent the staff_locations table from growing unbounded.
class LocationCleanupService {
  final SupabaseClient _client;
  LocationCleanupService(this._client);

  static const int _retentionDays = 30;
  static const int _batchSize = 500;

  /// Delete location records older than [_retentionDays] days.
  /// Processes in batches to avoid timeouts on large datasets.
  /// Should be called once on app lifecycle events (e.g., tracking start).
  Future<void> cleanupOldLocations() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays));
      final cutoffStr = cutoff.toIso8601String();
      int totalDeleted = 0;

      debugPrint('[LocationCleanup] Cleaning up records older than $cutoffStr');

      while (true) {
        // Fetch IDs of old records in batches
        final batch = await _client
            .from('staff_locations')
            .select('id')
            .lt('recorded_at', cutoffStr)
            .limit(_batchSize);

        if (batch.isEmpty) break;

        final ids = batch.map((r) => r['id'] as String).toList();

        // Delete the batch
        await _client
            .from('staff_locations')
            .delete()
            .inFilter('id', ids);

        totalDeleted += ids.length;
        debugPrint('[LocationCleanup] Deleted batch of ${ids.length} records');

        // If we got fewer than batch size, we're done
        if (ids.length < _batchSize) break;
      }

      debugPrint('[LocationCleanup] Cleanup complete. Total deleted: $totalDeleted');
    } catch (e) {
      debugPrint('[LocationCleanup] Error during cleanup: $e');
      // Non-fatal — don't crash the app
    }
  }
}
