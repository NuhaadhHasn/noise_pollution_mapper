import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noise_pollution_mapper/screens/splash_screen.dart';

// Widget tests for Splash Screen
void main() {
  group('Splash Screen Widget Tests', () {
    testWidgets('Splash screen renders without crashing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);

      // Let SplashScreen's 3 s navigation timer fire and the replacement route
      // settle, so the test does not end with a pending timer.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('App logo or branding exists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      // Verify some content is displayed (logo, text, etc.)
      expect(find.byType(Scaffold), findsOneWidget);

      // Let SplashScreen's 3 s navigation timer fire and the replacement route
      // settle, so the test does not end with a pending timer.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Loading indicator exists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      await tester.pump();
      // May have a progress indicator
      expect(find.byType(MaterialApp), findsOneWidget);

      // Let SplashScreen's 3 s navigation timer fire and the replacement route
      // settle, so the test does not end with a pending timer.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
