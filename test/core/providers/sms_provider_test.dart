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
import 'package:microflow_pro/core/services/sms_service.dart';
import 'package:microflow_pro/providers/supabase_provider.dart';

class _FakeSupabaseClient extends Mock implements SupabaseClient {}

class _FakeSmsService extends Mock implements SmsService {}

/// Minimal stand-in for the PostgrestQueryBuilder chain. We only need
/// `.insert(...)` to not throw — the rest of the call is logged-and-swallowed
/// by the production code's try/catch.
class _FakeQueryBuilder extends Mock
    implements SupabaseQueryBuilder {}

class _FakeFilterBuilder extends Mock
    implements PostgrestFilterBuilder {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Register a fallback for any() on the dynamic insert map argument.
    registerFallbackValue(<String, dynamic>{});
  });

  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_provider_test_');
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeClient = _FakeSupabaseClient();
    final fakeQuery = _FakeQueryBuilder();
    final fakeFilter = _FakeFilterBuilder();
    final fakeSmsService = _FakeSmsService();

    when(() => fakeClient.from(any())).thenAnswer((_) => fakeQuery);
    when(() => fakeQuery.insert(any())).thenAnswer((_) => fakeFilter);

    when(() => fakeSmsService.buildCollectionSms(
          amount: any(named: 'amount'),
          memberName: any(named: 'memberName'),
          collectorName: any(named: 'collectorName'),
          orgName: any(named: 'orgName'),
          loanNumber: any(named: 'loanNumber'),
          outstandingBalance: any(named: 'outstandingBalance'),
          date: any(named: 'date'),
        )).thenReturn('Mock collection message');

    when(() => fakeSmsService.sendSms(
          phoneNumber: any(named: 'phoneNumber'),
          message: any(named: 'message'),
          requestId: any(named: 'requestId'),
        )).thenAnswer((_) async => false);

    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseClientProvider.overrideWith((ref) => fakeClient),
      currentOrgIdProvider.overrideWith((ref) => 'test-org'),
      smsServiceProvider.overrideWithValue(fakeSmsService),
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
    // forceDispatch bypasses the Android/iOS platform guard so the outbox
    // row is actually persisted on this Windows test host.
    await notifier.enqueueCollection(
      phone: '+919999999999',
      memberId: 'm1',
      memberName: 'Alice',
      loanNumber: 'L-1',
      amount: 500,
      outstandingBalance: 4500,
      collectorName: 'Ravi',
      sentBy: 's1',
      forceDispatch: true,
    );
    // Give the unawaited asynchronous dispatchOutboxRow execution a moment to complete
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Read pendingAll() (not pendingDue) so the test is robust to the
    // unawaited dispatchOutboxRow running first and rescheduling via
    // markFailed. Either way, the row exists and is in a pending state.
    final outbox = await container.read(smsOutboxProvider.future);
    final rows = outbox.pendingAll();
    expect(rows.length, 1);
    expect(rows.first.phone, '+919999999999');
    expect(rows.first.status, OutboxStatus.pending);
  });
}
