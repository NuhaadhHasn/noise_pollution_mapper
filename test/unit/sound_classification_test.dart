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
  // runs of 2026-10-16 (Galaxy S9+). Session 1 is the pre-rule build
  // (log_<name>.txt), session 2 the rule build (log_v3_<name>.txt). The
  // logs print scores to 0.1%. Synthetic vectors are labelled as such.
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
          equals({'Vehicle', 'Water', 'Engine'}));
      expect(SoundClassificationService.isBroadCatchAll('Engine'), isTrue);
      // Considered and rejected - see the doc comment on the set.
      expect(SoundClassificationService.isBroadCatchAll('Motor vehicle (road)'),
          isFalse);
      // Engine's children stay specific.
      expect(
          SoundClassificationService.isBroadCatchAll(
              'Light engine (high frequency)'),
          isFalse);
      expect(SoundClassificationService.isBroadCatchAll('Idling'), isFalse);
      expect(SoundClassificationService.isBroadCatchAll('Silence'), isFalse);

      expect(SoundClassificationService.specificOverBroadMargin, equals(0.18));
      expect(SoundClassificationService.specificOverBroadMargin,
          greaterThan(SoundClassificationService.ambiguityMargin));
      expect(SoundClassificationService.specificOverBroadMargin,
          lessThan(SoundClassificationService.confidenceThreshold));
      // Unchanged invariants.
      expect(SoundClassificationService.confidenceThreshold, equals(0.30));
      expect(SoundClassificationService.ambiguityMargin, equals(0.10));
    });

    test('the margin admits two quantisation levels, not three '
        '(field test 12 §7.4)', () {
      // Synthetic pairs built from score levels the uint8 model actually
      // emitted that day. Indices: 0.262, 0.332, 0.414, 0.50, 0.586,
      // 0.668, 0.738, 0.801, 0.852.
      const ladder = [0.262, 0.332, 0.414, 0.50, 0.586, 0.668, 0.738, 0.801,
        0.852];
      String pair(double vehicle, double motorcycle) => categoryOf([
            c(294, 'Vehicle', vehicle),
            c(320, 'Motorcycle', motorcycle),
            c(300, 'Motor vehicle (road)', 0.109),
          ]);
      // Broad class at 0.50-0.738: two levels below is promoted, three
      // levels below is not.
      for (var i = 3; i <= 6; i++) {
        expect(pair(ladder[i], ladder[i - 2]),
            equals(YAMNetClassMapping.categoryTuktuk),
            reason: 'two levels: ${ladder[i]} vs ${ladder[i - 2]}');
        expect(pair(ladder[i], ladder[i - 3]),
            equals(YAMNetClassMapping.categoryTraffic),
            reason: 'three levels: ${ladder[i]} vs ${ladder[i - 3]}');
      }
      // Three levels below 0.852 is 0.184 behind: still out.
      expect(pair(0.852, 0.668), equals(YAMNetClassMapping.categoryTraffic));
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

    test('train stays Transport (log_v3_train.txt, log_v3_train_r2.txt)', () {
      for (final w in const [
        [['Vehicle', 0.941], ['Rail transport', 0.918], ['Train', 0.891]],
        [['Vehicle', 0.988], ['Rail transport', 0.969], ['Train', 0.941]],
        [['Rail transport', 0.957], ['Train', 0.941], ['Vehicle', 0.918]],
        [
          ['Vehicle', 0.668],
          ['Subway, metro, underground', 0.586],
          ['Rail transport', 0.50],
        ],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryTransport),
          reason: w.toString(),
        );
      }
      // The approach: Rail transport three levels (0.254) under Vehicle
      // stays Traffic, as the room's own Rail transport reading must.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.668),
          c(322, 'Rail transport', 0.414),
          c(323, 'Train', 0.414),
        ]),
        equals(YAMNetClassMapping.categoryTraffic),
      );
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

      // Motorcycle two levels (17.2pp) under Vehicle. It read Traffic
      // under the old 0.15 margin; 0.18 admits it.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.586),
          c(320, 'Motorcycle', 0.414),
          c(300, 'Motor vehicle (road)', 0.199),
        ]),
        equals(YAMNetClassMapping.categoryTuktuk),
      );
    });

    test('Jawa motorbike, rule build: two levels down -> Tuk-tuk '
        '(log_v3_jawa350.txt, log_v3_jawa350_r2.txt)', () {
      // Every one of these read Traffic on the device with 0.15.
      for (final w in const [
        [0.586, 0.414, 0.199], // gap 0.172
        [0.50, 0.332, 0.109], // gap 0.168, logged in both runs
        [0.738, 0.586, 0.332], // gap 0.152, the window as playback stopped
      ]) {
        final d = decide([
          c(294, 'Vehicle', w[0]),
          c(320, 'Motorcycle', w[1]),
          c(300, 'Motor vehicle (road)', w[2]),
        ]);
        expect(d.category, equals(YAMNetClassMapping.categoryTuktuk),
            reason: 'Vehicle ${w[0]} / Motorcycle ${w[1]}');
        expect(d.chosen.className, equals('Motorcycle'));
        expect(d.overruledBroad?.className, equals('Vehicle'));
      }

      // Three or more levels down, or under 0.30, it stays Traffic.
      for (final w in const [
        [['Vehicle', 0.586], ['Motorcycle', 0.332], ['Helicopter', 0.199]],
        [['Vehicle', 0.738], ['Motorcycle', 0.414],
          ['Motor vehicle (road)', 0.199]],
        [['Vehicle', 0.586], ['Motorcycle', 0.262], ['Engine', 0.148]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryTraffic),
          reason: w.toString(),
        );
      }
      // A Motorcycle under 0.30 is never promoted, so the near-tie gate
      // still fires.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.332),
          c(320, 'Motorcycle', 0.262),
          c(300, 'Motor vehicle (road)', 0.082),
        ]),
        equals(YAMNetClassMapping.categoryUncertain),
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

      // log_v3_helicopter.txt: Helicopter on top of Vehicle (mirror case).
      expect(
        categoryOf([
          c(333, 'Helicopter', 0.738),
          c(294, 'Vehicle', 0.668),
          c(329, 'Aircraft', 0.586),
        ]),
        equals(YAMNetClassMapping.categoryTransport),
      );
    });

    test('known cost: two-level promotions the scores cannot tell apart '
        '(field test 12 §7.4)', () {
      // log_helicopter.txt: the same Vehicle 0.50 / Motorcycle 0.332 as
      // two Jawa windows, so the helicopter's rotor now reads Tuk-tuk.
      // It read Traffic before, which was also wrong.
      final heli = decide([
        c(294, 'Vehicle', 0.50),
        c(320, 'Motorcycle', 0.332),
        c(300, 'Motor vehicle (road)', 0.148),
      ]);
      expect(heli.category, equals(YAMNetClassMapping.categoryTuktuk));
      expect(heli.overruledBroad?.className, equals('Vehicle'));

      // log_crowd.txt: a crowd's first window, Subway 0.168 under
      // Vehicle (the Jawa's gap), now reads Transport, not Traffic.
      expect(
        categoryOf([
          c(294, 'Vehicle', 0.668),
          c(328, 'Subway, metro, underground', 0.50),
          c(322, 'Rail transport', 0.50),
        ]),
        equals(YAMNetClassMapping.categoryTransport),
      );
    });

    test('room baseline with nothing playing stays Traffic '
        '(log_control_noplay.txt, log_v3_control_r2.txt, log_taskB.txt)',
        () {
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

      // log_v3_control_r2.txt: the room's closest call. Aircraft and
      // Helicopter sit three levels (0.254) under Vehicle; 0.18 admits
      // two, so this is one level from flipping.
      final closest = decide([
        c(294, 'Vehicle', 0.586),
        c(329, 'Aircraft', 0.332),
        c(333, 'Helicopter', 0.332),
      ]);
      expect(closest.category, equals(YAMNetClassMapping.categoryTraffic));
      expect(closest.overruledBroad, isNull);

      for (final w in const [
        // log_v3_control_r2.txt: Engine is broad now, and its Traffic
        // child is under 0.30.
        [['Vehicle', 0.586], ['Engine', 0.148],
          ['Heavy engine (low frequency)', 0.148]],
        [['Vehicle', 0.586], ['Motorboat, speedboat', 0.148],
          ['Boat, Water vehicle', 0.109]],
        // log_taskB.txt (4.5 min, nothing playing)
        [['Vehicle', 0.801], ['Railroad car, train wagon', 0.414],
          ['Rail transport', 0.414]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryTraffic),
          reason: w.toString(),
        );
      }
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
        // log_v3_passby.txt
        [
          ['Vehicle', 0.801],
          ['Accelerating, revving, vroom', 0.332],
          ['Motor vehicle (road)', 0.262],
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
      // log_chainsaw.txt and log_v3_chainsaw.txt. Engine (broad) is
      // always third, under two Industrial classes.
      for (final w in const [
        [['Light engine (high frequency)', 0.891], ['Chainsaw', 0.891],
          ['Engine', 0.801]],
        [['Chainsaw', 0.957], ['Light engine (high frequency)', 0.941],
          ['Engine', 0.891]],
        [['Light engine (high frequency)', 0.801], ['Chainsaw', 0.801],
          ['Engine', 0.738]],
        [['Chainsaw', 0.918], ['Light engine (high frequency)', 0.891],
          ['Engine', 0.801]],
        [['Light engine (high frequency)', 0.941], ['Chainsaw', 0.941],
          ['Engine', 0.852]],
        [['Chainsaw', 0.941], ['Light engine (high frequency)', 0.918],
          ['Engine', 0.852]],
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
        // log_v3_hammerdrill.txt
        [['Jackhammer', 0.414], ['Tools', 0.332], ['Power tool', 0.332]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryConstruction),
          reason: w.toString(),
        );
      }
    });

    test('hammer drill: Engine steps aside for the tool '
        '(log_hammerdrill.txt, log_v3_hammerdrill*.txt)', () {
      // Each of these read Traffic or Uncertain on the device.
      for (final w in const [
        // Engine on top, the tool within the margin.
        [['Engine', 0.414], ['Jackhammer', 0.414], ['Tools', 0.332]],
        [['Engine', 0.50], ['Power tool', 0.414], ['Jackhammer', 0.414]],
        // Two levels (0.168) down: needs both Engine and the 0.18 margin.
        [['Engine', 0.50], ['Jackhammer', 0.332], ['Tools', 0.262]],
      ]) {
        final d = decide(
            [for (final e in w) c(-1, e[0] as String, e[1] as double)]);
        expect(d.category, equals(YAMNetClassMapping.categoryConstruction),
            reason: w.toString());
        expect(d.overruledBroad?.className, equals('Engine'));
        expect(d.chosen.className, equals(w[1][0]));
      }

      // Mirror case: Engine as runner-up no longer gates the tool.
      final mirror = decide([
        c(412, 'Tools', 0.414),
        c(337, 'Engine', 0.332),
        c(418, 'Power tool', 0.332),
      ]);
      expect(mirror.category, equals(YAMNetClassMapping.categoryConstruction));
      expect(mirror.overruledBroad, isNull);
      expect(mirror.runnerUp?.className, equals('Power tool'));

      // Still open: with nothing specific above 0.30, Engine's own
      // category stands.
      for (final w in const [
        [['Engine', 0.414], ['Idling', 0.109], ['Vibration', 0.109]],
        [['Engine', 0.414], ['Lawn mower', 0.148], ['Idling', 0.109]],
      ]) {
        expect(
          categoryOf([for (final e in w) c(-1, e[0] as String, e[1] as double)]),
          equals(YAMNetClassMapping.categoryTraffic),
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
      // log_printer.txt
      expect(
        categoryOf([
          c(409, 'Printer', 0.50),
          c(398, 'Mechanisms', 0.414),
          c(408, 'Cash register', 0.199),
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
        c(371, 'Vacuum cleaner', 0.50),
        c(412, 'Tools', 0.414),
        c(418, 'Power tool', 0.262),
      ]);
      expect(tie.isAmbiguous, isTrue);
      expect(tie.nearTieWith?.className, equals('Tools'));
      expect(persistableClassification(tie), isNull);

      // A drill window that Engine used to hide is saved as the tool.
      final drill = SoundClassificationService.resultFromRanked([
        c(337, 'Engine', 0.50),
        c(418, 'Power tool', 0.414),
        c(414, 'Jackhammer', 0.414),
      ]);
      expect(drill.category, equals(YAMNetClassMapping.categoryConstruction));
      expect(drill.yamnetClass, equals('Power tool'));
      expect(drill.confidence, equals(0.414));
      expect(persistableClassification(drill), same(drill));
    });
  });
}
