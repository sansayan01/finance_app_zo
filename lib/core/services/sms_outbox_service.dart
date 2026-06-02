// lib/core/services/sms_outbox_service.dart
import 'package:hive/hive.dart';
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
