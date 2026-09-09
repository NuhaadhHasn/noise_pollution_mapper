@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/edit_profile_screen.dart';

// Widget tests for Edit Profile Screen
void main() {
  group('Edit Profile Screen Widget Tests', () {
    testWidgets('Edit profile screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('Name and email fields exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(),
        ),
      );

      await tester.pump();

      // Verify text fields exist (name and email)
      expect(find.byType(TextFormField), findsAtLeast(2));
    });

    testWidgets('Save button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(),
        ),
      );

      await tester.pump();

      // Look for save button
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Save button is tappable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditProfileScreen(),
        ),
      );

      await tester.pump();

      final saveButton = find.text('Save Changes');
      if (saveButton.evaluate().isNotEmpty) {
        await tester.tap(saveButton);
        await tester.pump();
      }
    });
  });
}
