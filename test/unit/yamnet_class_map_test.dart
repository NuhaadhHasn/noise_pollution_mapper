import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';

// Verifies the bundled official YAMNet class map (finding ml-1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Official YAMNet class map', () {
    setUpAll(() async {
      final loaded = await YAMNetClassMapping.loadOfficialClassMap();
      expect(loaded, isTrue, reason: 'yamnet_class_map.csv must parse');
    });

    test('loads all 521 classes', () {
      expect(YAMNetClassMapping.indexToClassName.length, equals(521));
      expect(YAMNetClassMapping.isClassMapLoaded, isTrue);
    });

    test('official map is bijective (521 unique names)', () {
      expect(
        YAMNetClassMapping.indexToClassName.values.toSet().length,
        equals(521),
      );
    });

    test('spot-check official names against tensorflow/models', () {
      final map = YAMNetClassMapping.indexToClassName;
      expect(map[0], equals('Speech'));
      // Quoted-name parsing (display name contains a comma):
      expect(map[1], equals('Child speech, kid speaking'));
      expect(map[132], equals('Music'));
      expect(map[294], equals('Vehicle'));
      expect(map[388], equals('Busy signal'));
      expect(map[390], equals('Siren'));
      expect(map[414], equals('Jackhammer'));
      expect(map[494], equals('Silence'));
      expect(map[520], equals('Field recording'));
    });

    test('fabricated names from the old hand map are gone', () {
      final names = YAMNetClassMapping.indexToClassName.values.toSet();
      // These names never existed in the AudioSet ontology (finding ml-1):
      expect(names.contains('Talk show'), isFalse);
      expect(names.contains('Room tone'), isFalse);
      expect(names.contains('Water polo'), isFalse);
      expect(names.contains('Cubicle'), isFalse);
      expect(names.contains('Forest ambience'), isFalse);
    });
  });
}
