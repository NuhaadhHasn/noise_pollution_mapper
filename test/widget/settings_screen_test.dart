import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noise_pollution_mapper/screens/settings_screen_enhanced.dart';

// Widget tests for Settings Screen (defect cluster 09: dead controls removed,
// live controls present, legacy prefs keys cleaned up).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall surface so the lazily-built ListView mounts every row.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreenEnhanced()),
    );
    // Let _loadSettings (async prefs read + setState) complete.
    await tester.pumpAndSettle();
  }

  group('Settings Screen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders without crashing', (tester) async {
      await pumpSettings(tester);
      expect(find.byType(SettingsScreenEnhanced), findsOneWidget);
    });

    testWidgets('removed dead controls are gone', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Decibel Scale'), findsNothing);
      expect(find.text('Response Time'), findsNothing);
      expect(find.text('Share Data with Researchers'), findsNothing);
    });

    testWidgets('live controls are present', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Recording Duration'), findsOneWidget);
      expect(find.text('Save Frequency'), findsOneWidget);
      expect(find.text('Alert Threshold'), findsOneWidget);
      expect(find.text('Daily Reminders'), findsOneWidget);
      expect(find.text('Anonymize Location'), findsOneWidget);
    });

    testWidgets('legacy prefs keys are removed on load', (tester) async {
      SharedPreferences.setMockInitialValues({
        'use_dba': false,
        'use_fast_response': false,
        'share_data_with_researchers': true,
      });
      await pumpSettings(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_dba'), isNull);
      expect(prefs.getBool('use_fast_response'), isNull);
      expect(prefs.getBool('share_data_with_researchers'), isNull);
    });
  });
}
