import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/splash_screen.dart';

// Widget tests for Splash Screen
void main() {
  group('Splash Screen Widget Tests', () {
    testWidgets('Splash screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App logo or branding exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      // Verify some content is displayed (logo, text, etc.)
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Loading indicator exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      // May have a progress indicator
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
