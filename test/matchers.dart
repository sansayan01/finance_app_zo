import 'package:flutter_test/flutter_test.dart';

// =====================================================
// CUSTOM TEST MATCHERS
// =====================================================

/// Matcher for checking if a string is a valid email
final Matcher isValidEmail = matchesPattern(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Matcher for checking if a number is positive
final Matcher isPositive = predicate<num>((n) => n > 0, 'is positive');

/// Matcher for checking if a number is non-negative
final Matcher isNonNegative = predicate<num>((n) => n >= 0, 'is non-negative');

/// Matcher for checking valid phone number
final Matcher isValidPhone = matchesPattern(r'^\+?[1-9]\d{1,14}$');

/// Matcher for valid currency amount
final Matcher isValidAmount = allOf(
  isNonNegative,
  isA<num>(),
);

/// Matcher for valid UUID
final Matcher isValidUUID = matchesPattern(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Matcher for valid date string (ISO 8601)
final Matcher isIso8601Date = matchesPattern(
  r'^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?)?$',
);