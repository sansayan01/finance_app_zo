import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../settings/data/models/activity_log_model.dart';
import '../../../settings/data/repositories/activity_log_repository.dart';

/// Repository responsible for persisting an append-only audit row whenever a
/// collection is recorded with a backdated `collection_date` / `collection_time`.
///
/// The audit row is written to `public.collection_backdate_audit` (schema is
/// defined in `supabase/migrations/20260613000001_collection_backdate_audit.sql`).
/// In parallel, a human-readable entry is also written to `public.activity_logs`
/// via `ActivityLogRepository` so the action shows up in the existing audit feed.
///
/// Failures are intentionally non-fatal: a broken audit/replica write MUST NOT
/// block the actual collection recording on the device. We surface failures to
/// `debugPrint` only.
class CollectionBackdateAuditRepository {
  final SupabaseClient _client;
  final String _orgId;
  final ActivityLogRepository _activityLogRepository;

  CollectionBackdateAuditRepository({
    required SupabaseClient client,
    required String orgId,
    ActivityLogRepository? activityLogRepository,
  })  : _client = client,
        _orgId = orgId,
        _activityLogRepository =
            activityLogRepository ?? ActivityLogRepository(client, orgId);

  /// Format [d] as an ISO-8601 calendar date (`YYYY-MM-DD`).
  static String _formatDate(DateTime d) =>
      d.toIso8601String().split('T').first;

  /// Format [d] as an `HH:mm:ss` time string.
  static String _formatTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  /// Persist a backdate audit row for [collectionId].
  ///
  /// `oldDate` / `oldTime` are NULL for the very first insert of a backdated
  /// collection row (the SQL migration makes these columns nullable on
  /// purpose). They are required when editing an existing collection to shift
  /// its date earlier.
  Future<void> logBackdate({
    required String collectionId,
    required DateTime? oldDate,
    required DateTime? oldTime,
    required DateTime newDate,
    required DateTime newTime,
    required String performedBy,
    required String performedByRole,
    required String reason,
  }) async {
    // Compute how many calendar days the new date is behind today. We do this
    // once, on the client, so the value stored in the audit row matches the
    // value surfaced in `activity_logs.details`.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newDateOnly =
        DateTime(newDate.year, newDate.month, newDate.day);
    final daysBack = today.difference(newDateOnly).inDays;

    // Edge case per spec: don't bail when daysBack <= 0. The migration
    // enforces `CHECK (days_back >= 0)` so 0/negative values are valid Postgres
    // inputs (in_days of a same-day or slightly-future timestamp is just
    // clamped naturally — in practice callers should still only invoke this
    // for actual backdates, but we stay defensive).
    final safeDaysBack = daysBack < 0 ? 0 : daysBack;

    // ---------------- Audit table insert ----------------
    try {
      final auditPayload = <String, dynamic>{
        'org_id': _orgId,
        'collection_id': collectionId,
        // Always now() in practice (this is the moment the audit row was
        // written); kept for full audit fidelity.
        'original_created_at': DateTime.now().toIso8601String(),
        // Prior values: nullable when this is the first insert.
        'entry_collection_date':
            oldDate == null ? null : _formatDate(oldDate),
        'entry_collection_time':
            oldTime == null ? null : _formatTime(oldTime),
        // New (backdated) values being recorded.
        'new_collection_date': _formatDate(newDate),
        'new_collection_time': _formatTime(newTime),
        'days_back': safeDaysBack,
        // Who / why.
        'performed_by': performedBy,
        'performed_by_role': performedByRole,
        'reason': reason,
        // ip_address / user_agent intentionally omitted — caller can pass
        // them via the Dart-side defaults; a backend-side proxy could
        // populate these if we ever route through an edge function.
      };

      await _client.from('collection_backdate_audit').insert(auditPayload);
    } catch (e, st) {
      debugPrint(
        'CollectionBackdateAuditRepository: audit insert failed '
        '(non-fatal): $e\n$st',
      );
    }

    // ---------------- Parallel activity_logs entry ----------------
    // Run the activity-log write in parallel with the audit-table write so
    // the replica feed remains consistent if either path is briefly slow.
    // The repository already swallows its own errors, but we wrap defensively
    // here too in case the constructor was overridden or the call throws
    // synchronously.
    try {
      final details = jsonEncode({
        'reason': reason,
        'days_back': safeDaysBack,
        'original_date':
            oldDate == null ? null : _formatDate(oldDate),
        'original_time':
            oldTime == null ? null : _formatTime(oldTime),
        'new_date': _formatDate(newDate),
        'new_time': _formatTime(newTime),
        'collection_id': collectionId,
      });

      await _activityLogRepository.log(
        action: 'collection_backdated',
        details: details,
        type: ActivityType.userAction,
        userId: performedBy,
        userName: null, // let ActivityLogRepository resolve from auth profile
      );
    } catch (e, st) {
      debugPrint(
        'CollectionBackdateAuditRepository: activity_logs write failed '
        '(non-fatal): $e\n$st',
      );
    }
  }
}
