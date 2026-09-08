import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noise_pollution_mapper/utils/marker_key.dart';

void main() {
  group('markerNoiseKey (regression for audit map-1/uiux-4)', () {
    test('writer and reader produce the identical key for the same point', () {
      const lat = 6.9271;
      const lng = 79.8612;
      // Writer side: keyed by raw doubles from Firestore.
      final noiseLevels = <String, double>{markerNoiseKey(lat, lng): 85.0};
      // Reader side: keyed from a flutter_map marker's LatLng.
      final point = LatLng(lat, lng);
      final db = noiseLevels[markerNoiseKey(point.latitude, point.longitude)];
      expect(db, 85.0);
    });

    test('key is lat_lng with no LatLng.toString() artifacts', () {
      final point = LatLng(1.5, 2.5);
      final key = markerNoiseKey(point.latitude, point.longitude);
      expect(key, '1.5_2.5');
      expect(key.contains('LatLng'), isFalse,
          reason: 'Unbraced \$point interpolation regression');
    });

    test('distinct coordinates produce distinct keys', () {
      expect(markerNoiseKey(1.0, 2.0), isNot(markerNoiseKey(2.0, 1.0)));
    });
  });
}
