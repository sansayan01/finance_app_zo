// lib/core/services/sms_outbox_service.dart
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum OutboxStatus { pending, sending, sent, failed, dead }

class OutboxRow {
  final String id;
  final String phone;
  final String message;
  final String? memberId;
  final String? recipientName;
  final String? collectorName;
  final String sentBy;
  final OutboxStatus status;
  final int attempts;
  final String? lastError;
  final DateTime scheduledFor;
  final DateTime createdAt;

  OutboxRow({
    required this.id,
    required this.phone,
    required this.message,
    required this.memberId,
    required this.recipientName,
    required this.collectorName,
    required this.sentBy,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.scheduledFor,
    required this.createdAt,
  });

  OutboxRow copyWith({
    OutboxStatus? status,
    int? attempts,
    String? lastError,
    DateTime? scheduledFor,
  }) {
    return OutboxRow(
      id: id,
      phone: phone,
      message: message,
      memberId: memberId,
      recipientName: recipientName,
      collectorName: collectorName,
      sentBy: sentBy,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt,
    );
  }
}

/// Durable queue for outbound SMS. Survives process death.
/// Retry policy: 30s → 5m → 30m → dead-letter (after 3 failed attempts).
///
/// **Concurrency contract:** `markFailed`/`markSent`/`markSending` perform a
/// read-modify-write against the Hive box. The intended call pattern is a
/// single dispatcher coroutine processing one row at a time; concurrent
/// mutations of the same id are not safe and may lose the second update.
class SmsOutboxService {
  static const _boxName = 'sms_outbox_v1';
  static const _uuid = Uuid();

  final Box<OutboxRow> _box;

  SmsOutboxService._(this._box);

  static Future<SmsOutboxService> open() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(OutboxRowAdapter());
    }
    final box = await Hive.openBox<OutboxRow>(_boxName);
    // On open, orphaned `sending` rows are reset to pending.
    final toReset = <dynamic>[];
    for (final key in box.keys) {
      final row = box.get(key);
      if (row != null && row.status == OutboxStatus.sending) {
        toReset.add(key);
      }
    }
    for (final key in toReset) {
      final r = box.get(key)!;
      await box.put(key, r.copyWith(status: OutboxStatus.pending));
    }
    return SmsOutboxService._(box);
  }

  Future<void> close() => _box.close();

  Future<String> enqueue({
    required String phone,
    required String message,
    String? memberId,
    String? recipientName,
    String? collectorName,
    required String sentBy,
  }) async {
    final id = _uuid.v4();
    final row = OutboxRow(
      id: id,
      phone: phone,
      message: message,
      memberId: memberId,
      recipientName: recipientName,
      collectorName: collectorName,
      sentBy: sentBy,
      status: OutboxStatus.pending,
      attempts: 0,
      lastError: null,
      scheduledFor: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _box.put(id, row);
    return id;
  }

  OutboxRow? get(String id) => _box.get(id);

  Future<void> replace(OutboxRow row) async {
    await _box.put(row.id, row);
  }

  Future<void> markSending(String id) async {
    final r = _box.get(id);
    if (r == null) return;
    await _box.put(id, r.copyWith(status: OutboxStatus.sending));
  }

  Future<void> markSent(String id) async {
    final r = _box.get(id);
    if (r == null) return;
    await _box.put(id, r.copyWith(status: OutboxStatus.sent));
  }

  Future<void> markFailed(String id, String errorCode) async {
    final r = _box.get(id);
    if (r == null) return;
    final newAttempts = r.attempts + 1;
    if (newAttempts >= 3) {
      await _box.put(id, r.copyWith(
        status: OutboxStatus.dead,
        attempts: newAttempts,
        lastError: errorCode,
      ));
    } else {
      await _box.put(id, r.copyWith(
        status: OutboxStatus.pending,
        attempts: newAttempts,
        lastError: errorCode,
        scheduledFor: DateTime.now().add(_backoff(newAttempts)),
      ));
    }
  }

  List<OutboxRow> pendingDue() {
    final now = DateTime.now();
    return _box.values
        .where((r) =>
            r.status == OutboxStatus.pending &&
            r.scheduledFor.isBefore(now))
        .toList();
  }

  /// All rows in `pending` state, regardless of `scheduledFor`. Includes
  /// rows currently in the backoff window after a failed send. Use this for
  /// user-facing "messages waiting" counts; use [pendingDue] for dispatcher
  /// "ready to send now" counts.
  List<OutboxRow> pendingAll() {
    return _box.values
        .where((r) => r.status == OutboxStatus.pending)
        .toList();
  }

  Duration _backoff(int attempt) {
    switch (attempt) {
      case 1: return const Duration(seconds: 30);
      case 2: return const Duration(minutes: 5);
      default: return const Duration(minutes: 30);
    }
  }
}

class OutboxRowAdapter extends TypeAdapter<OutboxRow> {
  @override
  final int typeId = 0;

  @override
  OutboxRow read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return OutboxRow(
      id: fields[0] as String,
      phone: fields[1] as String,
      message: fields[2] as String,
      memberId: fields[3] as String?,
      recipientName: fields[4] as String?,
      collectorName: fields[5] as String?,
      sentBy: fields[6] as String,
      status: OutboxStatus.values[fields[7] as int],
      attempts: fields[8] as int,
      lastError: fields[9] as String?,
      scheduledFor: fields[10] as DateTime,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OutboxRow obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.phone)
      ..writeByte(2)..write(obj.message)
      ..writeByte(3)..write(obj.memberId)
      ..writeByte(4)..write(obj.recipientName)
      ..writeByte(5)..write(obj.collectorName)
      ..writeByte(6)..write(obj.sentBy)
      ..writeByte(7)..write(obj.status.index)
      ..writeByte(8)..write(obj.attempts)
      ..writeByte(9)..write(obj.lastError)
      ..writeByte(10)..write(obj.scheduledFor)
      ..writeByte(11)..write(obj.createdAt);
  }
}

/// One-shot migrator: read the legacy SharedPreferences queue (key
/// `pending_sms_queue`) and enqueue each entry into the new outbox.
/// Idempotent: deletes the key after a successful pass.
Future<int> migrateLegacyQueue(SharedPreferences prefs, SmsOutboxService outbox) async {
  final raw = prefs.getString('pending_sms_queue');
  if (raw == null) return 0;
  int migrated = 0;
  try {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    for (final entry in list) {
      final phone = entry['phone'] as String?;
      final message = entry['message'] as String?;
      if (phone == null || message == null) continue;
      await outbox.enqueue(
        phone: phone,
        message: message,
        memberId: entry['member_id'] as String?,
        recipientName: entry['recipient_name'] as String?,
        collectorName: entry['collector_name'] as String?,
        sentBy: entry['sent_by'] as String? ?? 'migrated',
      );
      migrated++;
    }
    await prefs.remove('pending_sms_queue');
  } catch (_) {
    // Corrupt legacy payload — wipe so we don't keep retrying.
    await prefs.remove('pending_sms_queue');
  }
  return migrated;
}
