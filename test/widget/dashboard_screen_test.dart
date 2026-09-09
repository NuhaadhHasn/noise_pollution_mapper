@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/dashboard_screen.dart';

// Widget tests for Dashboard Screen
void main() {
  group('Dashboard Screen Widget Tests', () {
    testWidgets('Dashboard displays key UI elements', (tester) async {
      // Build the Dashboard widget
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Verify app bar title exists
      expect(find.text('Dashboard'), findsOneWidget);

      // Verify bottom navigation bar exists (5 items)
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Verify record button exists (with microphone icon)
      expect(find.byIcon(Icons.mic), findsWidgets);
    });

    testWidgets('Dashboard has stat cards for MIN, AVG, MAX', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      await tester.pump();

      // Look for stat labels
      expect(find.text('MIN'), findsOneWidget);
      expect(find.text('AVG'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
    });

    testWidgets('Dashboard displays user greeting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      await tester.pump();

      // Look for greeting text (starts with "Hello")
      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('Bottom navigation has 5 items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(),
        ),
      );

      await tester.pump();

      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);

      // Get the BottomNavigationBar widget
      final navBar = tester.widget<BottomNavigationBar>(bottomNav);

      // Verify 5 items (Map, Analytics, Home, History, Settings)
      expect(navBar.items.length, equals(5));
    });
  });
}
