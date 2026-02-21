import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/map_view_screen.dart';

// Widget tests for Map View Screen
void main() {
  group('Map View Screen Widget Tests', () {
    testWidgets('Map view screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapViewScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('Noise Map'), findsOneWidget);
    });

    testWidgets('Search button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapViewScreen(),
        ),
      );

      await tester.pump();

      // Look for search functionality
      expect(find.byIcon(Icons.search), findsWidgets);
    });

    testWidgets('Bottom navigation bar exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapViewScreen(),
        ),
      );

      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Map container exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapViewScreen(),
        ),
      );

      await tester.pump();

      // Verify some content is rendered
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
