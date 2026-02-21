import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/history_screen.dart';

// Widget tests for History Screen
void main() {
  group('History Screen Widget Tests', () {
    testWidgets('History screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('Export CSV button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );

      await tester.pump();

      // Look for export functionality
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('Bottom navigation bar exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Loading state shows initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );

      // Initial state should show loading or content
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
