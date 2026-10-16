import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/history_screen.dart';

/// Regression test for device QA 2026-10-16: the "Recording deleted / Undo"
/// SnackBar covered the "Add Manual" button on the History tab.
///
/// The structure mirrors the app: MainAppShell's Scaffold (root, owns the
/// bottom navigation bar and therefore displays the SnackBar) wraps
/// HistoryScreen's own Scaffold, which owns the FAB.
void main() {
  late BuildContext hostContext;
  var addManualTaps = 0;

  Widget fab() => FloatingActionButton.extended(
        onPressed: () => addManualTaps++,
        icon: const Icon(Icons.add),
        label: const Text('Add Manual'),
      );

  Future<void> pumpShell(WidgetTester tester) async {
    addManualTaps = 0;
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Scaffold(
            body: Builder(builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            }),
            floatingActionButton: fab(),
          ),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pumpStandalone(WidgetTester tester) async {
    addManualTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            hostContext = context;
            return const SizedBox.expand();
          }),
          floatingActionButton: fab(),
        ),
      ),
    );
  }

  Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f);

  // The SnackBar widget's own rect includes its outer margin; the visible
  // card is the Material inside it.
  Rect snackCardRect(WidgetTester tester) => tester.getRect(find
      .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
      .first);

  // Lets Flutter's timer and the showActionSnackBar fallback timer finish.
  Future<void> drainSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  testWidgets('root cause: a default SnackBar covers the nested FAB',
      (tester) async {
    await pumpShell(tester);
    final fabBefore = rectOf(tester, find.byType(FloatingActionButton));

    ScaffoldMessenger.of(hostContext).showSnackBar(
      const SnackBar(content: Text('Recording deleted')),
    );
    await tester.pumpAndSettle();

    final fabRect = rectOf(tester, find.byType(FloatingActionButton));
    final snackRect = snackCardRect(tester);
    expect(fabRect, fabBefore, reason: 'nested Scaffold cannot lift the FAB');
    expect(fabRect.overlaps(snackRect), isTrue);
    await drainSnackBar(tester);
  });

  testWidgets('in the shell, the Undo SnackBar sits above Add Manual',
      (tester) async {
    await pumpShell(tester);

    showRecordingDeletedSnackBar(hostContext,
        inAppShell: true, onUndo: () {});
    await tester.pumpAndSettle();

    expect(find.text('Recording deleted'), findsOneWidget);
    final fabRect = rectOf(tester, find.byType(FloatingActionButton));
    final snackRect = snackCardRect(tester);
    expect(fabRect.overlaps(snackRect), isFalse,
        reason: 'fab=$fabRect snack=$snackRect');
    expect(snackRect.bottom, lessThanOrEqualTo(fabRect.top));

    // The button is still hit-testable and tappable.
    await tester.tap(find.text('Add Manual'));
    expect(addManualTaps, 1);
    await drainSnackBar(tester);
  });

  testWidgets('standalone, Scaffold lifts the FAB above the SnackBar',
      (tester) async {
    await pumpStandalone(tester);

    showRecordingDeletedSnackBar(hostContext,
        inAppShell: false, onUndo: () {});
    await tester.pumpAndSettle();

    final fabRect = rectOf(tester, find.byType(FloatingActionButton));
    final snackRect = snackCardRect(tester);
    expect(fabRect.overlaps(snackRect), isFalse,
        reason: 'fab=$fabRect snack=$snackRect');
    await tester.tap(find.text('Add Manual'));
    expect(addManualTaps, 1);
    await drainSnackBar(tester);
  });
}
