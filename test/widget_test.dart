// MicroFlow Pro - Smoke Tests

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
    await tester.runAsync(() async {
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

      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });
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
    expect(UserRole.values.length, greaterThanOrEqualTo(5));
    expect(LoanStatus.values.length, greaterThanOrEqualTo(8));
    expect(SavingsStatus.values.length, greaterThanOrEqualTo(4));
  });
}
