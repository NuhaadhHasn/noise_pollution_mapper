import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/widgets/startup_error_app.dart';

// boot-1 / flow1-1: fatal startup failures show a retryable error screen.
void main() {
  testWidgets('shows the error and a Retry button', (tester) async {
    await tester.pumpWidget(StartupErrorApp(
      error: Exception('firebase down'),
      onRetry: () async {},
    ));

    expect(find.text('Could not start the app'), findsOneWidget);
    expect(find.textContaining('firebase down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry invokes the callback and disables the button',
      (tester) async {
    final completer = Completer<void>();
    var retries = 0;

    await tester.pumpWidget(StartupErrorApp(
      error: Exception('boom'),
      onRetry: () {
        retries++;
        return completer.future;
      },
    ));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
    // While retrying: spinner shown, button disabled.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pump();
  });
}
