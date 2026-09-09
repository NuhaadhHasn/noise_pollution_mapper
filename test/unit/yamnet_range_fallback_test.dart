import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';

// Verifies the 'YAMNet_Class_N' range fallback is reachable and uses the
// official class ordering (finding ml-2). Deliberately does NOT load the
// official class map: the fallback only runs when the map is absent.
void main() {
  group('YAMNet_Class_ range fallback (class map NOT loaded)', () {
    test('precondition: class map is not loaded in this isolate', () {
      expect(YAMNetClassMapping.isClassMapLoaded, isFalse);
    });

    test('range buckets follow the official ontology', () {
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_5'),
          equals('Speech')); // 0-34 human voice
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_40'),
          equals('Body Sounds')); // 35-60 body sounds
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_100'),
          equals('Nature')); // 67-131 animals
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_200'),
          equals('Music')); // 132-276 music
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_280'),
          equals('Weather')); // 277-281 wind/thunder
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_300'),
          equals('Traffic')); // 294-321 vehicles
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_330'),
          equals('Transport')); // 322-336 rail/air/water
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_360'),
          equals('Domestic')); // 348-388 household
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_392'),
          equals('Alarm')); // 389-395 alarms
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_415'),
          equals('Construction')); // 413-430 tools/impulse
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_510'),
          equals('Other')); // remainder
    });

    test('out-of-range and unparseable placeholders degrade to Other', () {
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_999'),
          equals('Other'));
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_abc'),
          equals('Other'));
    });
  });
}
