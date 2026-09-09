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
