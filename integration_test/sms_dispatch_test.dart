import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:microflow_pro/app.dart';
import 'package:microflow_pro/core/providers/storage_providers.dart';
import 'package:microflow_pro/core/services/sms_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Send test SMS returns a result code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MicroFlowApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // NOTE: This test requires a real device with a SIM. On emulator it
    // will return "Send failed". The CI environment should skip it via:
    //   flutter test integration_test/sms_dispatch_test.dart --platform=android
    // which will not actually run on a device; run with:
    //   flutter drive --driver=test_driver/integration_test.dart \
    //                  --target=integration_test/sms_dispatch_test.dart \
    //                  --device-id=<real-device-id>
    final svc = SmsService();
    final result = await svc.sendTestSms(
      phone: '+910000000000',
      message: 'integration test',
    );
    expect(result, isNotEmpty);
  });
}
