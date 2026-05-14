# Testing Pipeline - MicroFlow Pro

This document describes the testing infrastructure for MicroFlow Pro Flutter application.

## Overview

The testing pipeline consists of:
- **Unit Tests** - Test business logic, models, utilities
- **Widget Tests** - Test individual UI components
- **Integration Tests** - Test full app flows
- **Static Analysis** - Flutter analyze for code quality

## Project Structure

```
test/
├── unit/
│   ├── models/
│   │   ├── user_model_test.dart
│   │   ├── loan_model_test.dart
│   │   └── savings_model_test.dart
│   └── utils/
│       └── formatters_test.dart
├── widget/
│   └── smoke_test.dart
└── widget_test.dart          # Smoke tests

integration_test/
└── app_test.dart             # Integration tests

scripts/
├── run_tests.bat             # Windows test runner
└── run_unit_tests.sh         # Linux/Mac test runner
```

## Running Tests

### Windows
```batch
.\scripts\run_tests.bat
```

### Linux/Mac
```bash
chmod +x scripts/run_unit_tests.sh
./scripts/run_unit_tests.sh all
```

### Specific Test Types
```bash
# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# Integration tests
flutter test integration_test/

# Static analysis
flutter analyze
```

## CI/CD

GitHub Actions workflow: [.github/workflows/flutter-tests.yml](.github/workflows/flutter-tests.yml)

### Triggered on:
- Push to `main` or `develop`
- Pull requests to `main` or `develop`

### Pipeline steps:
1. Static Analysis (`flutter analyze`)
2. Unit Tests
3. Widget Tests
4. Integration Tests
5. APK Build

## Test Coverage Areas

### Models
- UserModel - Auth user parsing and serialization
- ProfileModel - User profile handling
- LoanModel - Loan data with joins
- SavingsModel - Savings account data

### Utilities
- AppFormatters - Currency, date, phone formatting
- Calculations - EMI calculations

### Widgets
- GlassButton - Premium button component
- StatusBadge - Status indicator
- ShimmerLoading - Loading placeholder

### Integration
- App launch flow
- Theme initialization
- Navigation structure

## Adding Tests

### Unit Test
```dart
// test/unit/models/your_model_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YourModel', () {
    test('fromJson parses correctly', () {
      final json = {...};
      final model = YourModel.fromJson(json);
      expect(model.property, 'expected');
    });
  });
}
```

### Widget Test
```dart
// test/widget/your_widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/core/widgets/your_widget.dart';

void main() {
  testWidgets('renders correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: YourWidget(param: value),
      ),
    );
    expect(find.text('Expected'), findsOneWidget);
  });
}
```

## Writing Tests

### Best Practices
1. **Arrange-Act-Assert** pattern
2. **Group related tests** using `group()`
3. **Use descriptive names**: `test('parses valid email correctly')`
4. **Test edge cases**: empty, null, boundary values
5. **Mock external dependencies**

### Common Patterns
```dart
// Test async operations
test('fetches user correctly', () async {
  final repository = MockUserRepository();
  when(() => repository.getUser('123'))
      .thenAnswer((_) async => User(id: '123'));

  final user = await repository.getUser('123');
  expect(user.id, '123');
});

// Test widget interactions
test('button triggers callback', () async {
  bool pressed = false;
  await tester.pumpWidget(
    MyButton(onPressed: () => pressed = true),
  );
  await tester.tap(find.byType(MyButton));
  expect(pressed, true);
});
```

## Test Configuration

- **pubspec.yaml** includes: `flutter_test`, `mocktail`, `integration_test`
- **analysis_options.yaml** - Linting rules
- **GitHub Actions** - Automated CI/CD

## Troubleshooting

### Tests fail after adding new code
1. Run `flutter pub get` to update dependencies
2. Check for import errors in new files
3. Verify new code follows existing patterns

### Integration tests timeout
- Increase timeout: `await tester.pumpAndSettle(Duration(seconds: 10))`
- Check for async operations not completing

### Code coverage too low
- Add more unit tests for business logic
- Test edge cases in models
- Add tests for utility functions

## Next Steps

1. Add repository tests with mocked Supabase
2. Add provider tests for Riverpod state
3. Add more widget interaction tests
4. Set up code coverage reporting
5. Add performance benchmarks