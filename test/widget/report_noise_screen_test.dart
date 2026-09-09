@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/report_noise_screen.dart';

// Widget tests for Report Noise Screen (Manual Entry)
void main() {
  group('Report Noise Screen Widget Tests', () {
    testWidgets('Report screen renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportNoiseScreen(),
        ),
      );

      await tester.pump();

      // Verify app bar exists
      expect(find.text('Add Manual'), findsOneWidget);
    });

    testWidgets('Decibel level slider exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportNoiseScreen(),
        ),
      );

      await tester.pump();

      // Look for slider
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Sound classification dropdown exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportNoiseScreen(),
        ),
      );

      await tester.pump();

      // Look for classification dropdown
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('Submit button exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportNoiseScreen(),
        ),
      );

      await tester.pump();

      // Look for submit button
      expect(find.text('Submit Report'), findsOneWidget);
    });
  });
}
