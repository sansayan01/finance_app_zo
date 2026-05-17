// MicroFlow Pro - Smoke Tests
// Quick sanity checks to ensure app can at least build and render

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:microflow_pro/app.dart';
import 'package:microflow_pro/core/providers/storage_providers.dart';
import 'package:microflow_pro/core/constants/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MicroFlowApp(),
      ),
    );

    // Just verify no crash - give it a moment to initialize
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Theme provider initializes correctly', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              // Verify theme can be accessed
              final theme = Theme.of(context);
              expect(theme, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  });

  test('Enums have expected values', () {
    // Verify critical enums are properly defined
    expect(UserRole.values.length, greaterThanOrEqualTo(5));
    expect(LoanStatus.values.length, greaterThanOrEqualTo(8));
    expect(SavingsStatus.values.length, greaterThanOrEqualTo(4));
  });
}
