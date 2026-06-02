import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import 'package:microflow_pro/core/providers/org_provider.dart';
import 'package:microflow_pro/core/providers/sms_outbox_provider.dart';
import 'package:microflow_pro/core/providers/sms_provider.dart';
import 'package:microflow_pro/core/providers/storage_providers.dart';
import 'package:microflow_pro/core/services/sms_outbox_service.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class _FakeSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_provider_test_');
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWith((ref) => _FakeSupabaseClient()),
      currentOrgIdProvider.overrideWith((ref) => 'test-org'),
    ]);
    await container.read(smsOutboxProvider.future); // force init
  });

  tearDown(() async {
    container.dispose();
    // Give the async onDispose box.close() a chance to run.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      await Hive.close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows can hold a handle briefly; ignore.
    }
  });

  test('enqueueCollection persists a pending outbox row', () async {
    final notifier = container.read(collectionSmsSenderProvider.notifier);
    await notifier.enqueueCollection(
      phone: '+919999999999',
      memberId: 'm1',
      memberName: 'Alice',
      loanNumber: 'L-1',
      amount: 500,
      outstandingBalance: 4500,
      collectorName: 'Ravi',
      sentBy: 's1',
    );
    final outbox = await container.read(smsOutboxProvider.future);
    final rows = outbox.pendingDue().toList();
    expect(rows.length, 1);
    expect(rows.first.phone, '+919999999999');
    expect(rows.first.status, OutboxStatus.pending);
  });
}
