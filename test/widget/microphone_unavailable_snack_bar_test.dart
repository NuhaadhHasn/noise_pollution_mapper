import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/theme/app_theme.dart';
import 'package:noise_pollution_mapper/utils/microphone_unavailable_snack_bar.dart';

/// The error the Dashboard shows when the microphone delivers no audio even
/// after a capture restart (device QA 2026-10-16: a dead recorder used to
/// give the user no sign at all).
void main() {
  Future<void> showIt(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMicrophoneUnavailableSnackBar(context),
              child: const Text('fail'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('fail'));
    await tester.pump(); // start the SnackBar entrance animation
    await tester.pump(const Duration(milliseconds: 750));
  }

  test('message wording', () {
    expect(microphoneUnavailableMessage,
        'Microphone unavailable — please try again');
  });

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('uses the theme error colour ($name theme)', (tester) async {
      await showIt(tester, theme);

      expect(find.text(microphoneUnavailableMessage), findsOneWidget);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, theme.colorScheme.error);
      expect(snackBar.action, isNull);
      final text = tester.widget<Text>(find.text(microphoneUnavailableMessage));
      expect(text.style?.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('times out on its own', (tester) async {
    await showIt(tester, AppTheme.lightTheme);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('replaces a SnackBar that is already showing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('older'),
                      duration: Duration(minutes: 1),
                    ),
                  ),
                  child: const Text('older'),
                ),
                TextButton(
                  onPressed: () => showMicrophoneUnavailableSnackBar(context),
                  child: const Text('fail'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, 'older'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fail'));
    await tester.pumpAndSettle();

    expect(find.text(microphoneUnavailableMessage), findsOneWidget);
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('older')),
        findsNothing);
  });
}
