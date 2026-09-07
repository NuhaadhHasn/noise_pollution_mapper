import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/models/offline_recording.dart';

void main() {
  group('OfflineRecording.fromMap', () {
    Map<dynamic, dynamic> hiveStyleMap() {
      // Deliberately Map<dynamic, dynamic>: this is what a Hive dynamic box
      // returns for entries loaded from disk after an app restart.
      return <dynamic, dynamic>{
        'id': '1700000000000_userA',
        'decibelLevel': 72.5,
        'latitude': 6.9271,
        'longitude': 79.8612,
        'locationName': 'Colombo',
        'timestamp': DateTime(2026, 7, 1, 8, 30),
        'soundClass': 'Traffic',
        'soundType': 'Pollution',
        'confidence': 0.42,
        'syncAttempts': 1,
        'syncError': null,
        'isSynced': false,
      };
    }

    test('parses an untyped Map<dynamic, dynamic> as returned by Hive '
        'after restart (offline-1/flow2-1)', () {
      final rec = OfflineRecording.fromMap(hiveStyleMap());

      expect(rec.id, '1700000000000_userA');
      expect(rec.decibelLevel, 72.5);
      expect(rec.latitude, 6.9271);
      expect(rec.longitude, 79.8612);
      expect(rec.locationName, 'Colombo');
      expect(rec.timestamp, DateTime(2026, 7, 1, 8, 30));
      expect(rec.soundClass, 'Traffic');
      expect(rec.confidence, 0.42);
      expect(rec.syncAttempts, 1);
      expect(rec.isSynced, false);
    });

    test('round-trips through toMap/fromMap', () {
      final original = OfflineRecording(
        id: '1700000000001_userB',
        decibelLevel: 55.0,
        latitude: 1.0,
        longitude: 2.0,
        timestamp: DateTime(2026, 7, 2, 9, 15),
      );

      final restored = OfflineRecording.fromMap(
        // Simulate Hive's type erasure on the round trip.
        Map<dynamic, dynamic>.from(original.toMap()),
      );

      expect(restored.id, original.id);
      expect(restored.decibelLevel, original.decibelLevel);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isSynced, false);
      expect(restored.syncAttempts, 0);
    });

    test('parses ISO-8601 string timestamps defensively', () {
      final map = hiveStyleMap();
      map['timestamp'] = '2026-07-01T08:30:00.000';

      final rec = OfflineRecording.fromMap(map);
      expect(rec.timestamp, DateTime(2026, 7, 1, 8, 30));
    });
  });
}
