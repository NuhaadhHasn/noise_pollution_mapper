import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/notification_service.dart';

// Unit tests for Notification Service
void main() {
  group('Notification Service Tests', () {
    test('NotificationService class exists', () {
      expect(NotificationService, isNotNull);
    });

    test('NotificationService has initialize static method', () {
      expect(NotificationService.initialize, isA<Function>());
    });

    test('NotificationService has requestPermission static method', () {
      expect(NotificationService.requestPermission, isA<Function>());
    });

    test('NotificationService has showHighNoiseAlert static method', () {
      expect(NotificationService.showHighNoiseAlert, isA<Function>());
    });

    test('All notification methods are static (not instance)', () {
      // Verify that NotificationService uses static methods
      // This is tested by confirming the class itself has the methods
      expect(NotificationService, isNotNull);
      expect(NotificationService.initialize, isNotNull);
      expect(NotificationService.requestPermission, isNotNull);
      expect(NotificationService.showHighNoiseAlert, isNotNull);
    });
  });
}
