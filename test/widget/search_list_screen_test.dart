import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/search_list_screen.dart';

// Widget tests for Search List Screen
void main() {
  group('Search List Screen Widget Tests', () {
    testWidgets('Search screen renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchListScreen(),
        ),
      );

      await tester.pump();
      expect(find.text('Search Cities'), findsOneWidget);
    });

    testWidgets('Search field exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchListScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Sort menu button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchListScreen(),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('Search field accepts input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SearchListScreen(),
        ),
      );

      await tester.pump();

      final searchField = find.byType(TextField);
      if (searchField.evaluate().isNotEmpty) {
        await tester.enterText(searchField, 'Colombo');
        await tester.pump();
        expect(find.text('Colombo'), findsOneWidget);
      }
    });
  });
}
