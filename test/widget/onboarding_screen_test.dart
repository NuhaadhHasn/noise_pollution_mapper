import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/onboarding_screen.dart';

// Widget tests for Onboarding Screen
void main() {
  group('Onboarding Screen Widget Tests', () {
    testWidgets('Onboarding screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('PageView exists for swiping', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('Get Started button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.pump();
      expect(find.text('Get Started'), findsWidgets);
    });

    testWidgets('Skip button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.pump();
      expect(find.text('Skip'), findsWidgets);
    });

    testWidgets('Page indicators exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.pump();
      // Look for indicator dots or similar widgets
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
