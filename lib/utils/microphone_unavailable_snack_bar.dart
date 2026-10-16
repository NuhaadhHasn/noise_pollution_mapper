import 'package:flutter/material.dart';

import 'theme_helper.dart';

/// Shown when the Dashboard stops a recording because the microphone
/// delivered no audio, even after one restart, or could not be started.
const String microphoneUnavailableMessage =
    'Microphone unavailable — please try again';

/// Replaces any visible SnackBar with the "microphone unavailable" error.
///
/// Device QA 2026-10-16: a dead recorder gave the user no sign at all. The
/// colours come from [ThemeHelper], so the message follows the app's light
/// and dark themes. It has no action, so it always times out.
void showMicrophoneUnavailableSnackBar(BuildContext context) {
  final foreground = ThemeHelper.getButtonTextColor(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: ThemeHelper.getErrorColor(context),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(Icons.mic_off, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                microphoneUnavailableMessage,
                style: TextStyle(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
}
