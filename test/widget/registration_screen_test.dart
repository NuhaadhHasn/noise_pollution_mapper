import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/registration_screen.dart';

// Widget tests for Registration Screen
void main() {
  group('Registration Screen Widget Tests', () {
    testWidgets('Registration screen displays all required fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Verify we have 4 text fields (name, email, password, confirm password)
      expect(find.byType(TextFormField), findsNWidgets(4));

      // 'Create Account' is BOTH the screen heading (registration_screen.dart
      // :177) and the submit button label (:421), so two widgets is correct
      // here — asserting one was the test's bug, not the screen's.
      expect(find.text('Create Account'), findsNWidgets(2));
    });

    testWidgets('Name field accepts input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, 'Test User');
      await tester.pump();

      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('Email field accepts input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      final emailField = find.byType(TextFormField).at(1);
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Create Account button is tappable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // Two matches (heading, then button); the button is last in tree order.
      final createLabels = find.text('Create Account');
      expect(createLabels, findsNWidgets(2));

      await tester.tap(createLabels.last);
      await tester.pump();
    });

    testWidgets('Back to Login link exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegistrationScreen(),
        ),
      );

      // The link reads 'Log In' (registration_screen.dart:445).
      expect(find.textContaining('Log In'), findsWidgets);
    });
  });
}
