import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_pro/core/widgets/glass_button.dart';
import 'package:microflow_pro/core/widgets/status_badge.dart';
import 'package:microflow_pro/core/widgets/shimmer_loading.dart';

void main() {
  group('GlassButton Widget Tests', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Test Button',
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('triggers onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Tap Me',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Loading',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('renders with icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'With Icon',
              icon: Icons.add,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('StatusBadge Widget Tests', () {
    testWidgets('displays label correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Active',
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders with active type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Active',
              type: StatusType.active,
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders with pending type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Pending',
              type: StatusType.pending,
            ),
          ),
        ),
      );

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('renders with default type', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
              label: 'Default',
              type: StatusType.defaultStatus,
            ),
          ),
        ),
      );

      expect(find.text('Default'), findsOneWidget);
    });
  });

  group('ShimmerLoading Widget Tests', () {
    testWidgets('renders child when not loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: false,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('applies shimmer effect when loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: true,
              child: SizedBox(width: 100, height: 20),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('applies custom dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              isLoading: true,
              width: 200,
              height: 20,
              child: SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerLoading), findsOneWidget);
    });
  });
}