import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

// Unit tests for Location utilities
void main() {
  group('GPS Coordinate Validation Tests', () {
    test('Sri Lankan coordinates (Colombo) are valid', () {
      expect(_isValidLatitude(6.9271), isTrue);
      expect(_isValidLongitude(79.8612), isTrue);
    });

    test('Sri Lankan coordinates (Kandy) are valid', () {
      expect(_isValidLatitude(7.2906), isTrue);
      expect(_isValidLongitude(80.6337), isTrue);
    });

    test('Sri Lankan coordinates (Galle) are valid', () {
      expect(_isValidLatitude(6.0535), isTrue);
      expect(_isValidLongitude(80.2210), isTrue);
    });

    test('Invalid latitude: out of range', () {
      expect(_isValidLatitude(-91), isFalse);
      expect(_isValidLatitude(91), isFalse);
    });

    test('Invalid longitude: out of range', () {
      expect(_isValidLongitude(-181), isFalse);
      expect(_isValidLongitude(181), isFalse);
    });

    test('Boundary values: poles', () {
      expect(_isValidLatitude(-90), isTrue); // South Pole
      expect(_isValidLatitude(90), isTrue);  // North Pole
    });

    test('Boundary values: international date line', () {
      expect(_isValidLongitude(-180), isTrue);
      expect(_isValidLongitude(180), isTrue);
    });

    test('Equator and Prime Meridian', () {
      expect(_isValidLatitude(0), isTrue);
      expect(_isValidLongitude(0), isTrue);
    });
  });

  group('Distance Calculation Tests', () {
    test('Distance between two nearby points', () {
      // Colombo Fort to Mount Lavinia (approximate)
      const lat1 = 6.9271;
      const lon1 = 79.8612;
      const lat2 = 6.8380;
      const lon2 = 79.8636;

      final distance = _calculateDistance(lat1, lon1, lat2, lon2);
      expect(distance, greaterThan(0));
      expect(distance, lessThan(20)); // Should be less than 20 km
    });

    test('Distance between same point is zero', () {
      const lat = 6.9271;
      const lon = 79.8612;

      final distance = _calculateDistance(lat, lon, lat, lon);
      expect(distance, equals(0));
    });

    test('Distance calculation is symmetric', () {
      const lat1 = 6.9271;
      const lon1 = 79.8612;
      const lat2 = 7.2906;
      const lon2 = 80.6337;

      final distance1 = _calculateDistance(lat1, lon1, lat2, lon2);
      final distance2 = _calculateDistance(lat2, lon2, lat1, lon1);

      expect(distance1, equals(distance2));
    });
  });

  group('Location Name Formatting Tests', () {
    test('Format location name from components', () {
      final name = _formatLocationName('Colombo', 'Western Province', 'Sri Lanka');
      expect(name, contains('Colombo'));
    });

    test('Handle null location components', () {
      final name = _formatLocationName(null, 'Western Province', 'Sri Lanka');
      expect(name, isNotEmpty);
    });

    test('Unknown location fallback', () {
      final name = _formatLocationName(null, null, null);
      expect(name, equals('Unknown Location'));
    });
  });
}

// Helper functions
bool _isValidLatitude(double lat) {
  return lat >= -90 && lat <= 90;
}

bool _isValidLongitude(double lng) {
  return lng >= -180 && lng <= 180;
}

double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  if (lat1 == lat2 && lon1 == lon2) return 0;

  const earthRadius = 6371; // km

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadius * c;
}

double _toRadians(double degrees) {
  return degrees * math.pi / 180;
}

String _formatLocationName(String? locality, String? administrativeArea, String? country) {
  if (locality != null && locality.isNotEmpty) {
    return locality;
  } else if (administrativeArea != null && administrativeArea.isNotEmpty) {
    return administrativeArea;
  } else if (country != null && country.isNotEmpty) {
    return country;
  }
  return 'Unknown Location';
}
