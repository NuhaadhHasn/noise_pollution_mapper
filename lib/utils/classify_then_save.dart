import 'dart:async';

import '../services/sound_classification_service.dart'
    show ClassificationResult;
import 'app_logger.dart';

/// The classification a saved reading may carry.
///
/// ml-4/flow2-6: only a result that clears the confidence threshold and is
/// not a near-tie is persisted. Anything else is shown live but saved
/// without a class.
ClassificationResult? persistableClassification(ClassificationResult? result) =>
    (result?.meetsThreshold ?? false) ? result : null;

/// One save-timer tick's persistence step: classify the audio window that
/// ends at this tick, THEN save the reading with that window's result.
///
/// Device QA 2026-10-16 (a1-2): the save timer used to read whatever the
/// separate classification timer had last produced. The save tick fires
/// just before the classification tick for the same window, so every saved
/// reading carried the PREVIOUS cycle's class, or none. Sequencing the two
/// here makes the pairing explicit and testable.
///
/// The save always happens, so the dB reading is never lost (Duration is
/// derived from the saved-reading count): if classification returns null,
/// throws, or takes longer than [classifyTimeout], the reading is saved
/// without a class.
Future<T> classifyThenSave<T>({
  required Future<ClassificationResult?> Function() classifyCurrentWindow,
  required Future<T> Function(ClassificationResult? classification) save,
  Duration classifyTimeout = const Duration(seconds: 3),
}) async {
  ClassificationResult? result;
  try {
    result = await classifyCurrentWindow().timeout(classifyTimeout);
  } on TimeoutException {
    AppLogger.warning(
      'Classification for this save timed out; saving the reading without a class',
    );
  } catch (e) {
    AppLogger.error(
      'Classification for this save failed; saving the reading without a class',
      e,
    );
  }
  return save(persistableClassification(result));
}
