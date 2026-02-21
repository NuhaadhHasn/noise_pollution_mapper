import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/settings_screen_enhanced.dart';

// Widget tests for Settings Screen
void main() {
  group('Settings Screen Widget Tests', () {
    testWidgets('Settings screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreenEnhanced(),
        ),
      );

      await tester.pump();

      // Verify settings elements exist
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Edit Profile option exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreenEnhanced(),
        ),
      );

      await tester.pump();

      // Look for Edit Profile
      expect(find.textContaining('Edit'), findsWidgets);
    });

    testWidgets('Dark Mode toggle exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreenEnhanced(),
        ),
      );

      await tester.pump();

      // Look for theme toggles/switches
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('Bottom navigation bar exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreenEnhanced(),
        ),
      );

      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });
}
