import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/action_snack_bar.dart';

/// Regression tests for a1-3 (device QA 2026-10-16): "Recording deleted /
/// Undo" SnackBars piled up, and Undo restored an EARLIER deletion than the
/// one the user had just made.
void main() {
  late BuildContext hostContext;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  SnackBarAction undo(List<String> log, String id) =>
      SnackBarAction(label: 'Undo', onPressed: () => log.add(id));

  testWidgets(
      'root cause: plain action SnackBars never time out and queue up, '
      'so Undo belongs to the earlier one', (tester) async {
    await pumpHost(tester);
    final undone = <String>[];
    final messenger = ScaffoldMessenger.of(hostContext);
    for (final id in ['A', 'B']) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted $id'),
          duration: const Duration(seconds: 4),
          action: undo(undone, id),
        ),
      );
    }
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.text('Deleted A'), findsOneWidget);
    expect(find.text('Deleted B'), findsNothing);
    await tester.tap(find.text('Undo'));
    expect(undone, ['A']);
  });

  testWidgets('replaces the earlier SnackBar; Undo restores the newest one',
      (tester) async {
    await pumpHost(tester);
    final undone = <String>[];

    showActionSnackBar(
      hostContext,
      content: const Text('Deleted A'),
      action: undo(undone, 'A'),
    );
    await tester.pumpAndSettle();
    showActionSnackBar(
      hostContext,
      content: const Text('Deleted B'),
      action: undo(undone, 'B'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deleted A'), findsNothing);
    expect(find.text('Deleted B'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, ['B']);
    // The earlier one was cleared, not queued: nothing comes back.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('times out after its duration when no assistive tech is on',
      (tester) async {
    await pumpHost(tester);
    showActionSnackBar(
      hostContext,
      content: const Text('Deleted A'),
      duration: const Duration(seconds: 4),
      action: undo(<String>[], 'A'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deleted A'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Deleted A'), findsNothing);
  });

  testWidgets('stays up while a screen reader is navigating', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpHost(tester);
    showActionSnackBar(
      hostContext,
      content: const Text('Deleted A'),
      duration: const Duration(seconds: 4),
      action: undo(<String>[], 'A'),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Deleted A'), findsOneWidget);
  });

  testWidgets('a SnackBar without an action times out even for a screen reader',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpHost(tester);
    showActionSnackBar(
      hostContext,
      content: const Text('Location permission denied.'),
      duration: const Duration(seconds: 4),
      action: null,
    );
    await tester.pumpAndSettle();
    expect(find.text('Location permission denied.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Location permission denied.'), findsNothing);
  });
}
