import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/login_screen.dart';

// Widget tests for Login Screen
void main() {
  group('Login Screen Widget Tests', () {
    testWidgets('Login screen displays all required elements', (tester) async {
      // Build the LoginScreen widget
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify the screen has email and password fields
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Verify login button exists
      expect(find.text('Login'), findsOneWidget);

      // Verify sign up option exists
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Email field accepts input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find email field (first TextFormField)
      final emailField = find.byType(TextFormField).first;

      // Enter text
      await tester.enterText(emailField, 'test@example.com');
      await tester.pump();

      // Verify text was entered
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Password field exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find password field (second TextFormField)
      final passwordFields = find.byType(TextFormField);

      // Verify we have at least 2 text fields (email + password)
      expect(passwordFields, findsAtLeast(2));
    });

    testWidgets('Login button is tappable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find login button
      final loginButton = find.text('Login');

      // Verify button exists
      expect(loginButton, findsOneWidget);

      // Tap the button
      await tester.tap(loginButton);
      await tester.pump();

      // If we get here without errors, the button is tappable
    });
  });
}
