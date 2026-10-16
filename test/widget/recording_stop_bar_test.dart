import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/theme/app_theme.dart';
import 'package:noise_pollution_mapper/widgets/recording_stop_bar.dart';

/// Regression tests for a1-5 (device QA 2026-10-16): while recording, the
/// classification card pushed the Dashboard's Stop button below the fold.
/// The Dashboard now pins [RecordingStopBar] in its bottomNavigationBar
/// slot while recording. The DashboardScreen widget test is quarantined
/// (arch-2), so this pins the bar on a host shaped like the Dashboard: a
/// Scaffold whose scrolling body is much taller than the screen.
void main() {
  Future<void> pumpDashboardLike(
    WidgetTester tester, {
    required VoidCallback onStop,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Gauge, location chip, classification card, Top-3 panel...
                const SizedBox(height: 1500),
                Semantics(
                  button: true,
                  label: 'Stop noise measurement',
                  child: const SizedBox(width: 70, height: 70),
                ),
              ],
            ),
          ),
          bottomNavigationBar: RecordingStopBar(onStop: onStop),
        ),
      ),
    );
  }

  testWidgets('Stop is on screen without scrolling, however tall the content',
      (tester) async {
    await pumpDashboardLike(tester, onStop: () {});

    final screen = Offset.zero &
        (tester.view.physicalSize / tester.view.devicePixelRatio);
    final stopRect = tester.getRect(find.text('Stop'));
    expect(screen.contains(stopRect.topLeft), isTrue);
    expect(screen.contains(stopRect.bottomRight - const Offset(1, 1)), isTrue);
    expect(find.text('Recording'), findsOneWidget);
  });

  testWidgets('tapping Stop calls onStop once', (tester) async {
    var stops = 0;
    await pumpDashboardLike(tester, onStop: () => stops++);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(stops, 1);
  });

  testWidgets('Stop carries the record button\'s accessible label',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpDashboardLike(tester, onStop: () {});

    expect(
      find.descendant(
        of: find.byType(RecordingStopBar),
        matching: find.bySemanticsLabel(RecordingStopBar.stopSemanticsLabel),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('renders in the app\'s light and dark themes', (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await pumpDashboardLike(tester, onStop: () {}, theme: theme);
      expect(tester.takeException(), isNull);
      expect(find.text('Stop'), findsOneWidget);
    }
  });
}
