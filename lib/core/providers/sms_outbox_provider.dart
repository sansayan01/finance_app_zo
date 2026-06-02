// lib/core/providers/sms_outbox_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sms_outbox_service.dart';

/// Async-initialized outbox. UI code uses `ref.watch(smsOutboxProvider).when(...)`.
final smsOutboxProvider =
    FutureProvider<SmsOutboxService>((ref) async {
  final outbox = await SmsOutboxService.open();
  ref.onDispose(outbox.close);
  return outbox;
});
