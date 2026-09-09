@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/firebase_service.dart';

// Unit tests for Firebase Service
void main() {
  group('FirebaseService Unit Tests', () {
    late FirebaseService firebaseService;

    setUp(() {
      firebaseService = FirebaseService();
    });

    test('FirebaseService instance can be created', () {
      expect(firebaseService, isA<FirebaseService>());
    });

    test('FirebaseService is not null', () {
      expect(firebaseService, isNotNull);
    });

    test('getUserReadings stream should not be null', () {
      const testUserId = 'test_user_123';
      final stream = firebaseService.getUserReadings(testUserId);
      expect(stream, isNotNull);
      expect(stream, isA<Stream>());
    });

    test('getNoiseReadings stream should not be null', () {
      final stream = firebaseService.getNoiseReadings();
      expect(stream, isNotNull);
      expect(stream, isA<Stream>());
    });

    test('FirebaseService has required methods', () {
      expect(firebaseService.saveNoiseReading, isA<Function>());
      expect(firebaseService.getUserReadings, isA<Function>());
      expect(firebaseService.getNoiseReadings, isA<Function>());
      expect(firebaseService.calculateStats, isA<Function>());
      expect(firebaseService.getReadingsByLocation, isA<Function>());
    });
  });
}
