import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/models/heatmap_point.dart';

void main() {
  Map<String, dynamic> baseDoc() => {
        'decibelLevel': 82.0,
        'latitude': 6.9271,
        'longitude': 79.8612,
        'timestamp': Timestamp.fromDate(DateTime(2026, 7, 1)),
      };

  group('HeatmapPoint.fromFirestore (regression for audit flow3-1)', () {
    test('reads classification from soundClass (the writer field)', () {
      final point =
          HeatmapPoint.fromFirestore({...baseDoc(), 'soundClass': 'Traffic'});
      expect(point.soundCategory, 'Traffic');
    });

    test('falls back to legacy soundCategory field', () {
      final point = HeatmapPoint.fromFirestore(
          {...baseDoc(), 'soundCategory': 'Nature'});
      expect(point.soundCategory, 'Nature');
    });

    test('soundClass wins when both fields are present', () {
      final point = HeatmapPoint.fromFirestore({
        ...baseDoc(),
        'soundClass': 'Traffic',
        'soundCategory': 'Nature',
      });
      expect(point.soundCategory, 'Traffic');
    });

    test('null when neither classification field is present', () {
      final point = HeatmapPoint.fromFirestore(baseDoc());
      expect(point.soundCategory, isNull);
    });

    test('falls back to createdAt when timestamp is missing/pending', () {
      final created = DateTime(2026, 6, 15);
      final doc = baseDoc()
        ..remove('timestamp')
        ..['createdAt'] = Timestamp.fromDate(created);
      final point = HeatmapPoint.fromFirestore(doc);
      expect(point.timestamp, created);
    });

    test('intensity is normalized dB / 120', () {
      final point = HeatmapPoint.fromFirestore(baseDoc());
      expect(point.intensity, closeTo(82.0 / 120.0, 1e-9));
    });
  });
}
