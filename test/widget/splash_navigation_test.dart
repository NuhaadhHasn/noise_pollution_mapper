import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noise_pollution_mapper/screens/login_screen.dart';
import 'package:noise_pollution_mapper/screens/onboarding_screen.dart';
import 'package:noise_pollution_mapper/screens/splash_screen.dart';

// flow1-2: splash routes to Onboarding on first launch only, Login afterwards.
void main() {
  testWidgets('first launch: splash navigates to onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await tester.pump(const Duration(seconds: 3)); // fire the splash timer
    await tester.pump(); // start the pushReplacement transition
    await tester.pump(const Duration(seconds: 1)); // finish the route transition

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('returning launch: splash skips onboarding and shows login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
