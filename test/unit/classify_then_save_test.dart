import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/sound_classification_service.dart';
import 'package:noise_pollution_mapper/utils/classify_then_save.dart';

/// Regression tests for a1-2 (device QA 2026-10-16): each saved reading
/// carried the PREVIOUS cycle's classification, or none, because the save
/// timer read whatever the separate classification timer had last produced.
/// The dashboard now runs each save tick through [classifyThenSave]; the
/// DashboardScreen widget test is quarantined (arch-2), so these tests pin
/// the sequencing directly.
ClassificationResult _result({
  required String category,
  required double confidence,
  bool isAmbiguous = false,
}) =>
    ClassificationResult(
      category: category,
      soundType: 'Pollution',
      confidence: confidence,
      yamnetClass: category,
      yamnetClassIndex: 0,
      isAmbiguous: isAmbiguous,
    );

void main() {
  group('persistableClassification', () {
    test('keeps a confident result', () {
      final r = _result(category: 'Traffic', confidence: 0.801);
      expect(persistableClassification(r), same(r));
    });

    test('drops a below-threshold result (ml-4/flow2-6)', () {
      expect(
        persistableClassification(_result(category: 'Traffic', confidence: 0.2)),
        isNull,
      );
    });

    test('drops a near-tie even when its score is high', () {
      expect(
        persistableClassification(
          _result(category: 'Uncertain', confidence: 0.6, isAmbiguous: true),
        ),
        isNull,
      );
    });

    test('null stays null', () {
      expect(persistableClassification(null), isNull);
    });
  });

  group('classifyThenSave', () {
    test('saves only after this tick\'s classification completes, with it',
        () async {
      final classification = Completer<ClassificationResult?>();
      final saved = <ClassificationResult?>[];
      var saveCalls = 0;

      final done = classifyThenSave<String>(
        classifyCurrentWindow: () => classification.future,
        save: (c) async {
          saveCalls++;
          saved.add(c);
          return 'saved';
        },
      );

      // The window is still being classified: nothing may be saved yet,
      // otherwise the save would carry the previous cycle's class.
      await Future<void>.delayed(Duration.zero);
      expect(saveCalls, 0);

      final traffic = _result(category: 'Traffic', confidence: 0.801);
      classification.complete(traffic);

      expect(await done, 'saved');
      expect(saveCalls, 1);
      expect(saved.single, same(traffic));
    });

    test('saves without a class when the window is below threshold', () async {
      ClassificationResult? saved =
          _result(category: 'sentinel', confidence: 1);
      await classifyThenSave<void>(
        classifyCurrentWindow: () async =>
            _result(category: 'Traffic', confidence: 0.1),
        save: (c) async => saved = c,
      );
      expect(saved, isNull);
    });

    test('still saves the reading when classification returns null', () async {
      var saveCalls = 0;
      ClassificationResult? saved =
          _result(category: 'sentinel', confidence: 1);
      await classifyThenSave<void>(
        classifyCurrentWindow: () async => null,
        save: (c) async {
          saveCalls++;
          saved = c;
        },
      );
      expect(saveCalls, 1);
      expect(saved, isNull);
    });

    test('still saves the reading when classification throws', () async {
      var saveCalls = 0;
      ClassificationResult? saved =
          _result(category: 'sentinel', confidence: 1);
      await classifyThenSave<void>(
        classifyCurrentWindow: () => throw StateError('interpreter closed'),
        save: (c) async {
          saveCalls++;
          saved = c;
        },
      );
      expect(saveCalls, 1);
      expect(saved, isNull);
    });

    test('a hung classification cannot block the save past the timeout',
        () async {
      var saveCalls = 0;
      ClassificationResult? saved =
          _result(category: 'sentinel', confidence: 1);
      final done = classifyThenSave<void>(
        // Never completes.
        classifyCurrentWindow: () => Completer<ClassificationResult?>().future,
        save: (c) async {
          saveCalls++;
          saved = c;
        },
        classifyTimeout: const Duration(milliseconds: 50),
      );

      expect(saveCalls, 0);
      await done.timeout(const Duration(seconds: 5));
      expect(saveCalls, 1);
      expect(saved, isNull);
    });
  });
}
