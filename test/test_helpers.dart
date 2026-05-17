import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// =====================================================
// TEST HELPERS - Shared Utilities
// =====================================================

/// Wraps a widget with necessary providers for testing
Widget createTestableWidget({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

/// Mock classes should be defined specifically for each type in tests
// class MockClass<T> extends Mock implements T {}

/// Callback for testing async operations
typedef AsyncCallback = Future<void> Function();

/// Setup register fallback values for Mocktail
void registerFallbackValues() {
  registerFallbackValue(FakeUserModel());
  registerFallbackValue(FakeLoanModel());
  registerFallbackValue(FakeSavingsModel());
}

// Fake Classes for fallback values
class FakeUserModel extends Fake {}

class FakeLoanModel extends Fake {}

class FakeSavingsModel extends Fake {}

/// Extension for easier widget testing
extension WidgetTesterExtension on WidgetTester {
  /// Pump and settle with timeout
  Future<void> pumpWithTimeout({
    Duration timeout = const Duration(seconds: 5),
    int pumpCount = 10,
  }) async {
    for (var i = 0; i < pumpCount; i++) {
      await pump(const Duration(milliseconds: 200));
      if (binding.hasScheduledFrame) {
        await pump();
      }
    }
  }

  /// Enter text and pump
  Future<void> enterTextAndPump(Finder finder, String text) async {
    await enterText(finder, text);
    await pump();
  }

  /// Tap and wait
  Future<void> tapAndPump(Finder finder, {int milliseconds = 300}) async {
    await tap(finder);
    await pump(Duration(milliseconds: milliseconds));
  }
}
