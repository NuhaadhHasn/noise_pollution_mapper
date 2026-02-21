import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/analytics_screen.dart';

// Widget tests for Analytics Screen
void main() {
  group('Analytics Screen Widget Tests', () {
    testWidgets('Analytics screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('Analytics'), findsOneWidget);
    });

    testWidgets('Filter chips are present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Look for filter options
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pollution'), findsOneWidget);
      expect(find.text('Ambient'), findsOneWidget);
    });

    testWidgets('Filter chips are tappable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Find and tap Pollution filter
      final pollutionFilter = find.text('Pollution');
      if (pollutionFilter.evaluate().isNotEmpty) {
        await tester.tap(pollutionFilter);
        await tester.pump();
      }

      // Find and tap Ambient filter
      final ambientFilter = find.text('Ambient');
      if (ambientFilter.evaluate().isNotEmpty) {
        await tester.tap(ambientFilter);
        await tester.pump();
      }
    });

    testWidgets('Bottom navigation bar exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AnalyticsScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });
}
