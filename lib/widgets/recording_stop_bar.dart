import 'package:flutter/material.dart';
import '../utils/theme_helper.dart';

/// Compact Stop control pinned to the bottom of the Dashboard while it is
/// recording.
///
/// Device QA 2026-10-16 (a1-5): the round record button sits in the
/// scrolling content, below the gauge, the location chip and, while
/// recording, the classification card (plus the optional Top-3 panel). Those
/// grow and push the button below the fold, so the user had to scroll to
/// find Stop and could miss that recording was on. This bar does not scroll,
/// so Stop stays reachable and the recording state stays visible.
///
/// Its Stop button carries the same accessible label as the round button in
/// its recording state ("Stop noise measurement").
class RecordingStopBar extends StatelessWidget {
  final VoidCallback onStop;

  const RecordingStopBar({super.key, required this.onStop});

  /// Accessible label of the Stop button. Matches the round record button's
  /// Semantics label while recording.
  static const String stopSemanticsLabel = 'Stop noise measurement';

  @override
  Widget build(BuildContext context) {
    final recordingColor = ThemeHelper.getErrorColor(context);

    return Material(
      color: ThemeHelper.getCardColor(context),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                color: recordingColor,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recording',
                  style: TextStyle(
                    color: ThemeHelper.getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: onStop,
                style: FilledButton.styleFrom(
                  backgroundColor: recordingColor,
                  foregroundColor: ThemeHelper.getButtonTextColor(context),
                ),
                icon: const Icon(Icons.stop),
                label: const Text(
                  'Stop',
                  semanticsLabel: stopSemanticsLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
