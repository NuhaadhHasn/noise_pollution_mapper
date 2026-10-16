import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/sound_classification_service.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';
import 'package:noise_pollution_mapper/utils/classify_then_save.dart';

// Unit tests for Sound Classification Service
void main() {
  group('Sound Classification Service Tests', () {
    late SoundClassificationService classificationService;

    setUp(() {
      classificationService = SoundClassificationService();
    });

    test('SoundClassificationService can be instantiated', () {
      expect(classificationService, isA<SoundClassificationService>());
    });

    test('Class mapping contains expected categories', () {
      expect(YAMNetClassMapping.classMapping, isNotEmpty);

      // Check for expected categories
      final categories = YAMNetClassMapping.classMapping.values.toSet();
      expect(categories.contains('Traffic'), isTrue);
      expect(categories.contains('Construction'), isTrue);
      expect(categories.contains('Music'), isTrue);
      expect(categories.contains('Nature'), isTrue);
    });

    test('Sound type mapping works for pollution sounds', () {
      // Traffic should be pollution
      expect(YAMNetClassMapping.getSoundType('Traffic'), equals('Pollution'));
      expect(YAMNetClassMapping.getSoundType('Construction'), equals('Pollution'));
      expect(YAMNetClassMapping.getSoundType('Industrial'), equals('Pollution'));
      expect(YAMNetClassMapping.getSoundType('Tuk-tuk'), equals('Pollution'));
    });

    test('Sound type mapping works for ambient sounds', () {
      // Music should be ambient
      expect(YAMNetClassMapping.getSoundType('Music'), equals('Ambient'));
      expect(YAMNetClassMapping.getSoundType('Nature'), equals('Ambient'));
      expect(YAMNetClassMapping.getSoundType('Religious'), equals('Ambient'));
      expect(YAMNetClassMapping.getSoundType('Market'), equals('Ambient'));
      expect(YAMNetClassMapping.getSoundType('Speech'), equals('Ambient'));
    });

    test('Category constants are defined', () {
      expect(YAMNetClassMapping.categoryTraffic, equals('Traffic'));
      expect(YAMNetClassMapping.categoryConstruction, equals('Construction'));
      expect(YAMNetClassMapping.categoryMusic, equals('Music'));
      expect(YAMNetClassMapping.categoryNature, equals('Nature'));
      expect(YAMNetClassMapping.categoryOther, isNotNull);
    });

    test('Type constants are defined', () {
      expect(YAMNetClassMapping.typeAmbient, equals('Ambient'));
      expect(YAMNetClassMapping.typePollution, equals('Pollution'));
    });

    test('soundTypeForStoredClass buckets stored soundClass values exactly', () {
      // Manual-report pseudo-categories (report_noise_screen.dart)
      expect(YAMNetClassMapping.soundTypeForStoredClass('Speech-Pollution'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Speech-Ambient'),
          equals('Ambient'));
      // Regression flow3-8: 'Other' must appear under the Ambient filter
      expect(YAMNetClassMapping.soundTypeForStoredClass('Other'),
          equals('Ambient'));
      // Ordinary categories defer to getSoundType
      expect(YAMNetClassMapping.soundTypeForStoredClass('Traffic'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Transport'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Alarm'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Uncertain'),
          equals('Ambient'));
      // Unknown legacy values degrade to Ambient (getSoundType default)
      expect(YAMNetClassMapping.soundTypeForStoredClass('SomeLegacyValue'),
          equals('Ambient'));
    });

    test('Classification constants have correct types', () {
      expect(YAMNetClassMapping.categoryOther, isA<String>());
      expect(YAMNetClassMapping.typeAmbient, isA<String>());
      expect(YAMNetClassMapping.typePollution, isA<String>());
      expect(SoundClassificationService.classificationIntervalSeconds, isA<int>());
      expect(SoundClassificationService.confidenceThreshold, isA<double>());
    });

    test('Confidence threshold matches project spec (0.30)', () {
      expect(SoundClassificationService.confidenceThreshold, greaterThanOrEqualTo(0.0));
      expect(SoundClassificationService.confidenceThreshold, lessThanOrEqualTo(1.0));
      // Project constraint: classification confidence target is 0.30
      expect(SoundClassificationService.confidenceThreshold, equals(0.30));
    });

    test('Uncertain pseudo-category is Ambient for display purposes', () {
      expect(YAMNetClassMapping.categoryUncertain, equals('Uncertain'));
      expect(YAMNetClassMapping.getSoundType('Uncertain'), equals('Ambient'));
      expect(YAMNetClassMapping.getCategoryIcon('Uncertain'), equals('❓'));
    });

    test('Classification interval is positive', () {
      expect(SoundClassificationService.classificationIntervalSeconds, greaterThan(0));
      expect(SoundClassificationService.classificationIntervalSeconds, lessThanOrEqualTo(10));
      // Should be 5 seconds
      expect(SoundClassificationService.classificationIntervalSeconds, equals(5));
    });

    test('YAMNet model specifications are correct', () {
      expect(SoundClassificationService.sampleRate, equals(16000));
      expect(SoundClassificationService.inputLength, equals(15600));
      expect(SoundClassificationService.numClasses, equals(521));
    });

    test('Get category from class name works', () {
      // Test exact match
      expect(YAMNetClassMapping.getCategoryFromClassName('Car'), equals('Traffic'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Music'), equals('Music'));

      // Test default for unknown
      expect(YAMNetClassMapping.getCategoryFromClassName('UnknownSound'), equals('Other'));
    });

    test('Get category icon returns emoji', () {
      final trafficIcon = YAMNetClassMapping.getCategoryIcon('Traffic');
      expect(trafficIcon, isNotEmpty);
      expect(trafficIcon, equals('🚗'));

      final musicIcon = YAMNetClassMapping.getCategoryIcon('Music');
      expect(musicIcon, equals('🎵'));
    });

    test('Get category color returns valid color code', () {
      final trafficColor = YAMNetClassMapping.getCategoryColor('Traffic');
      expect(trafficColor, isA<int>());
      expect(trafficColor, equals(0xFFF44336)); // Red

      final natureColor = YAMNetClassMapping.getCategoryColor('Nature');
      expect(natureColor, equals(0xFF4CAF50)); // Green
    });

    // --- Quiet category -------------------------------------------------

    test("'Silence' is the only class that maps to Quiet", () {
      expect(YAMNetClassMapping.categoryQuiet, equals('Quiet'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Silence'),
          equals(YAMNetClassMapping.categoryQuiet));
      // Exactly one classMapping entry moved out of Other.
      final quietClasses = YAMNetClassMapping.classMapping.entries
          .where((e) => e.value == YAMNetClassMapping.categoryQuiet)
          .map((e) => e.key)
          .toList();
      expect(quietClasses, equals(['Silence']));
    });

    test('Quiet is an Ambient category, not Pollution', () {
      expect(YAMNetClassMapping.getSoundType(YAMNetClassMapping.categoryQuiet),
          equals(YAMNetClassMapping.typeAmbient));
      // Analytics filters by the STORED soundClass value (flow3-8), so the
      // stored-value path has to resolve too or 'Quiet' readings would
      // vanish from the Ambient filter.
      expect(YAMNetClassMapping.soundTypeForStoredClass('Quiet'),
          equals('Ambient'));
    });

    test('Room tone stays in Other - an enclosed space is not a quiet one',
        () {
      // Deliberate: these classes mean "indoors", not "silent". A 55 dB
      // room-tone reading labelled Quiet would be worse than Other.
      expect(YAMNetClassMapping.getCategoryFromClassName('Inside, small room'),
          equals(YAMNetClassMapping.categoryOther));
      expect(
          YAMNetClassMapping.getCategoryFromClassName(
              'Inside, large room or hall'),
          equals(YAMNetClassMapping.categoryOther));
      expect(
          YAMNetClassMapping.getCategoryFromClassName('Inside, public space'),
          equals(YAMNetClassMapping.categoryOther));
      // Noise floors are not silence either.
      expect(YAMNetClassMapping.getCategoryFromClassName('White noise'),
          equals(YAMNetClassMapping.categoryOther));
      expect(YAMNetClassMapping.getCategoryFromClassName('Static'),
          equals(YAMNetClassMapping.categoryOther));
      expect(YAMNetClassMapping.getCategoryFromClassName('Environmental noise'),
          equals(YAMNetClassMapping.categoryOther));
    });

    test('Quiet has its own icon and colour, and is never Uncertain', () {
      expect(YAMNetClassMapping.getCategoryIcon('Quiet'), equals('🔇'));
      expect(YAMNetClassMapping.getCategoryColor('Quiet'), equals(0xFF00897B));
      // Fallback rendering would reuse the Other icon/colour.
      expect(YAMNetClassMapping.getCategoryIcon('Quiet'),
          isNot(equals(YAMNetClassMapping.getCategoryIcon('Other'))));
      expect(YAMNetClassMapping.getCategoryColor('Quiet'),
          isNot(equals(YAMNetClassMapping.getCategoryColor('Other'))));
      // ml-3/ml-4: the mapping never produces the live-only pseudo-category.
      expect(
        YAMNetClassMapping.classMapping.values
            .contains(YAMNetClassMapping.categoryUncertain),
        isFalse,
      );
      expect(YAMNetClassMapping.getCategoryFromClassName('Silence'),
          isNot(equals(YAMNetClassMapping.categoryUncertain)));
    });

    // --- Top-1/top-2 ambiguity margin gate (field test 12 §4.1) ---------
    //
    // resolveCategory is the pure core of the gate: no TFLite interpreter is
    // involved, and it takes class NAMES rather than indices so these tests
    // never have to populate YAMNetClassMapping.indexToClassName (another
    // test asserts that map is empty when unloaded).

    test('Ambiguity margin constant is a sane fraction of the threshold', () {
      expect(SoundClassificationService.ambiguityMargin, equals(0.10));
      expect(SoundClassificationService.ambiguityMargin, greaterThan(0.0));
      // Must be small enough that it can never swallow a confident winner.
      expect(
        SoundClassificationService.ambiguityMargin,
        lessThan(SoundClassificationService.confidenceThreshold),
      );
    });

    test('Clear winner across different categories keeps the winner', () {
      // Car -> Traffic beats Bird -> Nature by 65pp: not ambiguous.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.85,
          secondClass: 'Bird',
          secondScore: 0.20,
        ),
        equals(YAMNetClassMapping.categoryTraffic),
      );
      // A comfortably clear winner (20pp) is never gated. The behaviour
      // at the 10pp boundary itself is pinned by the next test, where it
      // turns out to be less exact than `< 0.10` suggests.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.50,
          secondClass: 'Bird',
          secondScore: 0.30,
        ),
        equals(YAMNetClassMapping.categoryTraffic),
      );
    });

    test('Margin boundary follows double arithmetic, not the literal 0.10',
        () {
      // A gap of "exactly 0.10" is not representable as a double, and
      // which side of `< ambiguityMargin` it falls on depends on the two
      // operands. Verified in Dart 3.10:
      //   0.45 - 0.35 == 0.10000000000000003  -> NOT gated
      //   0.50 - 0.40 == 0.09999999999999998  -> gated
      // Both pairs are "10 percentage points apart" to a human, so the
      // boundary is a heuristic and not a contract. Both representative
      // pairs are asserted here so that asymmetry stays visible instead
      // of one lucky pair implying the boundary is exact.
      expect(0.45 - 0.35,
          greaterThan(SoundClassificationService.ambiguityMargin));
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.45,
          secondClass: 'Bird',
          secondScore: 0.35,
        ),
        equals(YAMNetClassMapping.categoryTraffic),
      );

      expect(0.50 - 0.40,
          lessThan(SoundClassificationService.ambiguityMargin));
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.50,
          secondClass: 'Bird',
          secondScore: 0.40,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
      );
    });

    test('Near-tie across DIFFERENT categories becomes Uncertain', () {
      // The observed failure: ambient street noise wins by a hair over the
      // sound actually being measured, and the label flaps between windows.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.42,
          secondClass: 'Bird',
          secondScore: 0.38,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // Field test 2026-10-16, printer: two SPECIFIC classes in different
      // categories, 8.6pp apart. Still a near-tie.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Printer',
          bestScore: 0.50,
          secondClass: 'Mechanisms',
          secondScore: 0.414,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // Vehicle narrowly beating Motorcycle used to land here (Uncertain).
      // Since the specific-over-broad rule (field test 12 §7), the
      // specific class wins. That case is pinned in the group below.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Vehicle',
          bestScore: 0.58,
          secondClass: 'Motorcycle',
          secondScore: 0.55,
        ),
        equals(YAMNetClassMapping.categoryTuktuk),
      );
    });

    test('Near-tie within the SAME category keeps that category', () {
      // YAMNet is multi-label and its taxonomy is hierarchical, so sibling
      // and parent/child classes score close together constantly. The gate
      // must not fire on those - the outcome is not in doubt.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.42,
          secondClass: 'Truck',
          secondScore: 0.38,
        ),
        equals(YAMNetClassMapping.categoryTraffic),
      );
      // Identical scores, same category: still not ambiguous.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Music',
          bestScore: 0.97,
          secondClass: 'Piano',
          secondScore: 0.97,
        ),
        equals(YAMNetClassMapping.categoryMusic),
      );
    });

    test('Below-threshold winner is still Uncertain (ml-3/ml-4 unchanged)', () {
      // Sub-0.30 stays Uncertain regardless of how large the gap is.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.22,
          secondClass: 'Bird',
          secondScore: 0.02,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // ...and regardless of whether the runner-up shares its category.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Car',
          bestScore: 0.29,
          secondClass: 'Truck',
          secondScore: 0.28,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
      );
    });

    test('Ambiguous results are never persisted (meetsThreshold false)', () {
      // The near-tie result carries a real, above-threshold confidence, so
      // isAmbiguous - not the confidence - is what keeps it out of Firestore.
      final ambiguous = ClassificationResult(
        category: YAMNetClassMapping.categoryUncertain,
        soundType: YAMNetClassMapping.typeAmbient,
        confidence: 0.42,
        yamnetClass: 'Car',
        yamnetClassIndex: 1,
        isAmbiguous: true,
      );
      expect(ambiguous.confidence,
          greaterThan(SoundClassificationService.confidenceThreshold));
      expect(ambiguous.meetsThreshold, isFalse);

      // A confident, unambiguous result is still persistable.
      final confident = ClassificationResult(
        category: YAMNetClassMapping.categoryTraffic,
        soundType: YAMNetClassMapping.typePollution,
        confidence: 0.85,
        yamnetClass: 'Car',
        yamnetClassIndex: 1,
      );
      expect(confident.isAmbiguous, isFalse);
      expect(confident.meetsThreshold, isTrue);

      // Below threshold remains non-persistable (existing behaviour).
      final lowConfidence = ClassificationResult(
        category: YAMNetClassMapping.categoryUncertain,
        soundType: YAMNetClassMapping.typeAmbient,
        confidence: 0.12,
        yamnetClass: 'Car',
        yamnetClassIndex: 1,
      );
      expect(lowConfidence.meetsThreshold, isFalse);
    });

    test('Class mapping contains common sound classes', () {
      final mapping = YAMNetClassMapping.classMapping;

      // Check for key sound classes
      expect(mapping.containsKey('Car'), isTrue);
      expect(mapping.containsKey('Music'), isTrue);
      expect(mapping.containsKey('Rain'), isTrue);
      expect(mapping.containsKey('Speech'), isTrue);
      expect(mapping.containsKey('Jackhammer'), isTrue);
    });
  });

  // --- Specific over broad (field test 12 §7) ----------------------------
  //
  // Every score vector below is a real YAMNet Top-3 from the on-device
  // run of 2026-10-16 (Galaxy S9+). The scratchpad file names are given;
  // the logs print scores to 0.1%. Synthetic vectors are labelled as such.
  group('Specific over broad (field test 2026-10-16)', () {
    ClassificationCandidate c(int index, String name, double score) =>
        ClassificationCandidate(
            classIndex: index, className: name, score: score);

    CategoryDecision decide(List<ClassificationCandidate> ranked) =>
        SoundClassificationService.decideCategory(ranked);

    String categoryOf(List<ClassificationCandidate> ranked) =>
        decide(ranked).category;

    test('the broad set is small and explicit, the margin absolute', () {
      expect(SoundClassificationService.broadCatchAllClasses,
          equals({'Vehicle', 'Water'}));
      // Considered and rejected - see the doc comment on the set.
      expect(SoundClassificationService.isBroadCatchAll('Motor vehicle (road)'),
          isFalse);
      expect(SoundClassificationService.isBroadCatchAll('Engine'), isFalse);
      expect(SoundClassificationService.isBroadCatchAll('Silence'), isFalse);

      expect(SoundClassificationService.specificOverBroadMargin, equals(0.15));
      expect(SoundClassificationService.specificOverBroadMargin,
          greaterThan(SoundClassificationService.ambiguityMargin));
      expect(SoundClassificationService.specificOverBroadMargin,
          lessThan(SoundClassificationService.confidenceThreshold));
      // Unchanged invariants.
      expect(SoundClassificationService.confidenceThreshold, equals(0.30));
      expect(SoundClassificationService.ambiguityMargin, equals(0.10));
    });

    test('train -> Transport (log_train.txt, every train window)', () {
      // All ten train windows (these nine plus railOnTop below) read
      // Uncertain before this rule.
      const windows = [
        [0.891, 0.801, 0.738],
        [0.941, 0.941, 0.891],
        [0.996, 0.984, 0.980],
        [0.992, 0.984, 0.969],
        [0.941, 0.918, 0.891],
        [0.984, 0.969, 0.957],
        [0.980, 0.980, 0.957],
        [0.969, 0.957, 0.941],
        [0.984, 0.969, 0.957],
      ];
      for (final w in windows) {
        final d = decide([
          c(294, 'Vehicle', w[0]),
          c(322, 'Rail transport', w[1]),
          c(323, 'Train', w[2]),
        ]);
        expect(d.category, equals(YAMNetClassMapping.categoryTransport),
            reason: 'Vehicle ${w[0]} / Rail transport ${w[1]}');
        expect(d.chosen.className, equals('Rail transport'));
        expect(d.overruledBroad?.className, equals('Vehicle'));
        expect(d.isAmbiguous, isFalse);
      }

      // The one window where Rail transport out-scored Vehicle. A broad
      // runner-up must not gate a specific winner, or the same train
      // would read Uncertain here and Transport everywhere else.
      final railOnTop = decide([
        c(322, 'Rail transport', 0.957),
        c(294, 'Vehicle', 0.941),
        c(323, 'Train', 0.918),
      ]);
      expect(railOnTop.category, equals(YAMNetClassMapping.categoryTransport));
      expect(railOnTop.overruledBroad, isNull);
      expect(railOnTop.runnerUp?.className, equals('Train'));
    });

    test('Jawa motorbike -> Tuk-tuk (log_motorcycle_jawa350.txt)', () {
      final first = decide([
        c(294, 'Vehicle', 0.738),
        c(320, 'Motorcycle', 0.668),
        c(300, 'Motor vehicle (road)', 0.332),
      ]);
      expect(first.category, equals(YAMNetClassMapping.categoryTuktuk));
      expect(first.chosen.className, equals('Motorcycle'));
      expect(first.chosen.score, equals(0.668));

      // Motorcycle on top, Vehicle 8.2pp behind: used to be Uncertain.
      expect(
        categoryOf([
          c(320, 'Motorcycle', 0.414),
          c(294, 'Vehicle', 0.332),
          c(0, 'Speech', 0.109),
        ]),
        equals(YAMNetClassMapping.categoryTuktuk),
      );

      // Vehicle 17.2pp clear of Motorcycle is outside the 0.15 margin,
      // so it stays Traffic. Logged as-is, not hidden.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.586),
          c(320, 'Motorcycle', 0.414),
          c(300, 'Motor vehicle (road)', 0.199),
        ]),
        equals(YAMNetClassMapping.categoryTraffic),
      );
    });

    test('helicopter -> Transport (log_helicopter.txt)', () {
      final d = decide([
        c(294, 'Vehicle', 0.50),
        c(333, 'Helicopter', 0.414),
        c(329, 'Aircraft', 0.332),
      ]);
      expect(d.category, equals(YAMNetClassMapping.categoryTransport));
      expect(d.chosen.className, equals('Helicopter'));
      expect(d.overruledBroad?.className, equals('Vehicle'));

      // Another window of the same run: Motorcycle 16.8pp under Vehicle
      // is outside the margin, so it stays Traffic.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.50),
          c(320, 'Motorcycle', 0.332),
          c(300, 'Motor vehicle (road)', 0.148),
        ]),
        equals(YAMNetClassMapping.categoryTraffic),
      );
    });

    test('room baseline with nothing playing stays Traffic '
        '(log_control_noplay.txt)', () {
      // Vehicle 0.738 with Rail transport 0.332: a 0.41 gap.
      final d = decide([
        c(294, 'Vehicle', 0.738),
        c(322, 'Rail transport', 0.332),
        c(323, 'Train', 0.332),
      ]);
      expect(d.category, equals(YAMNetClassMapping.categoryTraffic));
      expect(d.chosen.className, equals('Vehicle'));
      expect(d.overruledBroad, isNull);

      expect(
        categoryOf([
          c(294, 'Vehicle', 0.801),
          c(300, 'Motor vehicle (road)', 0.148),
          c(310, 'Truck', 0.109),
        ]),
        equals(YAMNetClassMapping.categoryTraffic),
      );
    });

    test('real road traffic stays Traffic (train, silence, taskB logs)', () {
      // Vehicle with Car / Bus / Truck / Emergency vehicle: one category,
      // so the rule has nothing to change.
      const traffic = [
        [['Vehicle', 0.801], ['Motor vehicle (road)', 0.668], ['Car', 0.668]],
        [['Bus', 0.414], ['Vehicle', 0.332], ['Motor vehicle (road)', 0.148]],
        [['Vehicle', 0.414], ['Car', 0.414], ['Motor vehicle (road)', 0.332]],
        [['Vehicle', 0.50], ['Motor vehicle (road)', 0.199], ['Truck', 0.199]],
        [
          ['Fire engine, fire truck (siren)', 0.586],
          ['Vehicle', 0.414],
          ['Emergency vehicle', 0.332],
        ],
        [
          ['Vehicle', 0.668],
          ['Traffic noise, roadway noise', 0.414],
          ['Motor vehicle (road)', 0.199],
        ],
      ];
      for (final w in traffic) {
        final d = decide([
          for (final e in w) c(-1, e[0] as String, e[1] as double),
        ]);
        expect(d.category, equals(YAMNetClassMapping.categoryTraffic),
            reason: w.toString());
        expect(d.overruledBroad, isNull);
      }
    });

    test('chainsaw stays Industrial, drill stays Construction', () {
      // log_chainsaw.txt - no broad class involved.
      for (final w in const [
        [['Light engine (high frequency)', 0.891], ['Chainsaw', 0.891],
          ['Engine', 0.801]],
        [['Chainsaw', 0.957], ['Light engine (high frequency)', 0.941],
          ['Engine', 0.891]],
        [['Light engine (high frequency)', 0.801], ['Chainsaw', 0.801],
          ['Engine', 0.738]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryIndustrial),
          reason: w.toString(),
        );
      }
      // log_hammerdrill.txt
      for (final w in const [
        [['Tools', 0.414], ['Power tool', 0.414], ['Drill', 0.262]],
        [['Jackhammer', 0.586], ['Tools', 0.50], ['Engine', 0.332]],
        [['Jackhammer', 0.668], ['Tools', 0.50], ['Power tool', 0.414]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryConstruction),
          reason: w.toString(),
        );
      }
    });

    test('below threshold stays Uncertain', () {
      // log_control_noplay.txt
      final d = decide([
        c(294, 'Vehicle', 0.199),
        c(300, 'Motor vehicle (road)', 0.082),
        c(301, 'Car', 0.082),
      ]);
      expect(d.category, equals(YAMNetClassMapping.categoryUncertain));
      expect(d.belowThreshold, isTrue);
      // log_thunder.txt
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.262),
          c(283, 'Rain', 0.199),
          c(282, 'Water', 0.148),
        ]),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // Synthetic: the specific class must clear 0.30 itself. A weak
      // Helicopter 7pp under Vehicle is not promoted, and the plain
      // near-tie gate still fires.
      final weak = decide([
        c(294, 'Vehicle', 0.35),
        c(333, 'Helicopter', 0.28),
        c(329, 'Aircraft', 0.20),
      ]);
      expect(weak.overruledBroad, isNull);
      expect(weak.category, equals(YAMNetClassMapping.categoryUncertain));
      expect(weak.isAmbiguous, isTrue);
    });

    test('Water steps aside for a storm, whichever tied class sorts first '
        '(log_thunder.txt)', () {
      // Three-way tie at 0.414. The sort order of equal scores is not
      // something to rely on, so both orders must give the same answer.
      expect(
        categoryOf([
          c(280, 'Thunderstorm', 0.414),
          c(282, 'Water', 0.414),
          c(283, 'Rain', 0.414),
        ]),
        equals(YAMNetClassMapping.categoryWeather),
      );
      expect(
        categoryOf([
          c(282, 'Water', 0.414),
          c(280, 'Thunderstorm', 0.414),
          c(283, 'Rain', 0.414),
        ]),
        equals(YAMNetClassMapping.categoryWeather),
      );
      // log_rainthunder.txt: Rain 40.6pp under Water stays Nature.
      expect(
        categoryOf([
          c(282, 'Water', 0.738),
          c(287, 'Waterfall', 0.50),
          c(283, 'Rain', 0.332),
        ]),
        equals(YAMNetClassMapping.categoryNature),
      );
    });

    test('Speech tied with Vehicle reads Speech (log_silence2.txt)', () {
      // Used to be Uncertain. Speech is specific and Vehicle is the room's
      // broad drone.
      expect(
        categoryOf([
          c(0, 'Speech', 0.332),
          c(294, 'Vehicle', 0.332),
          c(300, 'Motor vehicle (road)', 0.199),
        ]),
        equals(YAMNetClassMapping.categorySpeech),
      );
    });

    test('non-broad near-ties keep the 0.10 gate', () {
      // log_hammerdrill.txt: Engine is NOT broad, so this stays Uncertain.
      expect(
        categoryOf([
          c(337, 'Engine', 0.414),
          c(414, 'Jackhammer', 0.414),
          c(412, 'Tools', 0.332),
        ]),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // log_blender.txt
      expect(
        categoryOf([
          c(371, 'Vacuum cleaner', 0.50),
          c(412, 'Tools', 0.414),
          c(418, 'Power tool', 0.262),
        ]),
        equals(YAMNetClassMapping.categoryUncertain),
      );
      // Synthetic: a promoted specific class is still gated by a
      // competing specific class from another category.
      final contested = decide([
        c(294, 'Vehicle', 0.50),
        c(333, 'Helicopter', 0.414),
        c(320, 'Motorcycle', 0.40),
      ]);
      expect(contested.overruledBroad?.className, equals('Vehicle'));
      expect(contested.isAmbiguous, isTrue);
      expect(contested.runnerUp?.className, equals('Motorcycle'));
      expect(contested.category, equals(YAMNetClassMapping.categoryUncertain));
      // Synthetic: when the strongest specific class shares the broad
      // class's category, that category stands. A weaker different-category
      // class does not get promoted past it.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.60),
          c(301, 'Car', 0.59),
          c(333, 'Helicopter', 0.46),
        ]),
        equals(YAMNetClassMapping.categoryTraffic),
      );
    });

    test('result carries the specific class and its own score, and is saved',
        () {
      final train = SoundClassificationService.resultFromRanked([
        c(294, 'Vehicle', 0.996),
        c(322, 'Rail transport', 0.984),
        c(323, 'Train', 0.980),
      ]);
      expect(train.category, equals(YAMNetClassMapping.categoryTransport));
      expect(train.soundType, equals(YAMNetClassMapping.typePollution));
      expect(train.confidence, equals(0.984));
      expect(train.yamnetClass, equals('Rail transport'));
      expect(train.yamnetClassIndex, equals(322));
      expect(train.isAmbiguous, isFalse);
      expect(train.meetsThreshold, isTrue);
      expect(train.topPredictions?.first.className, equals('Vehicle'));
      // classify-then-save persists it, with the specific class.
      final saved = persistableClassification(train);
      expect(saved, same(train));
      expect(saved!.toMap()['soundClass'], equals('Transport'));
      expect(saved.toMap()['yamnetClass'], equals('Rail transport'));
      expect(saved.toMap()['confidence'], equals(0.984));

      // The room baseline is still saved as Traffic from Vehicle.
      final baseline = SoundClassificationService.resultFromRanked([
        c(294, 'Vehicle', 0.738),
        c(322, 'Rail transport', 0.332),
        c(323, 'Train', 0.332),
      ]);
      expect(baseline.category, equals(YAMNetClassMapping.categoryTraffic));
      expect(baseline.yamnetClass, equals('Vehicle'));
      expect(persistableClassification(baseline), same(baseline));

      // Below threshold and near-tie results are still saved without a
      // class.
      final low = SoundClassificationService.resultFromRanked([
        c(294, 'Vehicle', 0.199),
        c(300, 'Motor vehicle (road)', 0.082),
        c(301, 'Car', 0.082),
      ]);
      expect(low.category, equals(YAMNetClassMapping.categoryUncertain));
      expect(persistableClassification(low), isNull);

      final tie = SoundClassificationService.resultFromRanked([
        c(337, 'Engine', 0.414),
        c(414, 'Jackhammer', 0.414),
        c(412, 'Tools', 0.332),
      ]);
      expect(tie.isAmbiguous, isTrue);
      expect(tie.nearTieWith?.className, equals('Jackhammer'));
      expect(persistableClassification(tie), isNull);
    });
  });
}
