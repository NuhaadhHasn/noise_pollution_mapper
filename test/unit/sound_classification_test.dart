import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/sound_classification_service.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';

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
      // Field test §2.2: Vehicle (Traffic) narrowly beating Motorcycle,
      // which maps to Tuk-tuk, not Traffic.
      expect(
        SoundClassificationService.resolveCategory(
          bestClass: 'Vehicle',
          bestScore: 0.58,
          secondClass: 'Motorcycle',
          secondScore: 0.55,
        ),
        equals(YAMNetClassMapping.categoryUncertain),
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
}
