import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Recursively normalizes JSON-like data coming from Supabase (especially on
/// the web/JS target, where every nested object arrives as a
/// `LinkedHashMap<dynamic, dynamic>`).
///
/// Dart 3 strong mode rejects `LinkedMap<dynamic, dynamic>` as a subtype of
/// `Map<String, dynamic>`, so a naive `as Map<String, dynamic>` or shallow
/// `Map<String, dynamic>.from(...)` throws at runtime. This walks the whole
/// structure — converting every map to `Map<String, dynamic>` (stringifying
/// keys) and every list element — so the value is safe to use in typed code.
///
/// Pass any value: a top-level `Map`, a `List` of rows, or already-normal
/// flutter entries (those pass through unchanged).
dynamic normalizeJson(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k?.toString() ?? ''] = normalizeJson(v);
    });
    return out;
  }
  if (value is List) {
    return value.map(normalizeJson).toList();
  }
  return value;
}

/// Convenience: normalize a single row/record to a typed `Map<String, dynamic>`.
Map<String, dynamic> normalizeMap(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) {
      out[k?.toString() ?? ''] = normalizeJson(v);
    });
    return out;
  }
  // Already a valid map or null-safe fallback.
  if (value is Map<String, dynamic>) return value;
  return <String, dynamic>{};
}

/// Normalize a list of rows returned by Supabase `.select()` / `.rpc()` into
/// a typed `List<Map<String, dynamic>>`. Each row is normalized recursively.
List<Map<String, dynamic>> normalizeRows(dynamic response) {
  if (response is! List) return const [];
  return response.map((e) => normalizeMap(e)).toList();
}

/// Helper retained for callers that want to safely decode JSON strings that
/// may have been stringified by Postgres (e.g. jsonb columns stored as text).
dynamic decodeJsonField(dynamic value) {
  if (value is String) {
    try {
      return normalizeJson(jsonDecode(value));
    } catch (_) {
      return value;
    }
  }
  return normalizeJson(value);
}

/// Global safety net for Supabase Realtime.
///
/// On the web/JS target, `payload.newRecord` / `payload.oldRecord` arrive as
/// `LinkedMap<dynamic, dynamic>`, which is NOT a subtype of `Map<String,
/// dynamic>` and crashes any `fromJson` that casts. These getters return a
/// recursively-normalized `Map<String, dynamic>` instead, so every realtime
/// callback in the app is protected without touching each one individually.
extension NormalizedPostgresChange on PostgresChangePayload {
  /// `newRecord` as a normalized `Map<String, dynamic>` (empty map if absent).
  Map<String, dynamic> get newRecordNormalized => normalizeMap(newRecord);

  /// `oldRecord` as a normalized `Map<String, dynamic>` (empty map if absent).
  Map<String, dynamic> get oldRecordNormalized => normalizeMap(oldRecord);
}
