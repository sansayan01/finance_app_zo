// test/core/services/sms_outbox_service_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:microflow_pro/core/services/sms_outbox_service.dart';

void main() {
  late Directory tempDir;
  late SmsOutboxService outbox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_outbox_test_');
    Hive.init(tempDir.path);
    outbox = await SmsOutboxService.open();
  });

  tearDown(() async {
    await outbox.close();
    await tempDir.delete(recursive: true);
  });

  test('enqueue creates a pending row with attempts=0', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: 'm1',
      recipientName: 'Alice',
      collectorName: 'Bob',
      sentBy: 's1',
    );
    final row = outbox.get(id);
    expect(row, isNotNull);
    expect(row!.status, OutboxStatus.pending);
    expect(row.attempts, 0);
    expect(row.phone, '+919999999999');
  });

  test('markSent transitions to sent', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: null,
      recipientName: null,
      collectorName: null,
      sentBy: 's1',
    );
    await outbox.markSent(id);
    expect(outbox.get(id)!.status, OutboxStatus.sent);
  });

  test('markFailed with attempts<3 reschedules pending with backoff', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: null,
      recipientName: null,
      collectorName: null,
      sentBy: 's1',
    );
    await outbox.markFailed(id, 'SEND_FAILED');
    final row = outbox.get(id)!;
    expect(row.status, OutboxStatus.pending);
    expect(row.attempts, 1);
    expect(row.scheduledFor.isAfter(DateTime.now()), isTrue);
  });

  test('markFailed with attempts==3 dead-letters', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: null,
      recipientName: null,
      collectorName: null,
      sentBy: 's1',
    );
    await outbox.markFailed(id, 'SEND_FAILED');
    await outbox.markFailed(id, 'SEND_FAILED');
    await outbox.markFailed(id, 'SEND_FAILED');
    expect(outbox.get(id)!.status, OutboxStatus.dead);
  });

  test('pendingDue returns rows whose scheduledFor is in the past', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: null,
      recipientName: null,
      collectorName: null,
      sentBy: 's1',
    );
    // Force into the past by direct mutation
    final row = outbox.get(id)!;
    await outbox.replace(row.copyWith(scheduledFor: DateTime.now().subtract(const Duration(minutes: 1))));
    final due = outbox.pendingDue();
    expect(due.any((r) => r.id == id), isTrue);
  });

  test('on open, sending rows are reset to pending (orphaned by process death)', () async {
    final id = await outbox.enqueue(
      phone: '+919999999999',
      message: 'test',
      memberId: null,
      recipientName: null,
      collectorName: null,
      sentBy: 's1',
    );
    final row = outbox.get(id)!;
    await outbox.replace(row.copyWith(status: OutboxStatus.sending));
    await outbox.close();
    final reopened = await SmsOutboxService.open();
    expect(reopened.get(id)!.status, OutboxStatus.pending);
    await reopened.close();
  });
}
