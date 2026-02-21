import 'package:flutter_test/flutter_test.dart';

// Unit tests for Data Validation Logic
void main() {
  group('Data Validation Tests', () {
    group('Email Validation', () {
      test('Valid email addresses pass validation', () {
        final validEmails = [
          'test@example.com',
          'user.name@example.co.uk',
          'test+tag@gmail.com',
          'user123@domain.org',
        ];

        for (var email in validEmails) {
          expect(_isValidEmail(email), isTrue, reason: 'Email $email should be valid');
        }
      });

      test('Invalid email addresses fail validation', () {
        final invalidEmails = [
          'notanemail',
          '@example.com',
          'user@',
          'user @example.com',
          '',
        ];

        for (var email in invalidEmails) {
          expect(_isValidEmail(email), isFalse, reason: 'Email $email should be invalid');
        }
      });
    });

    group('Password Validation', () {
      test('Valid passwords pass validation', () {
        expect(_isValidPassword('test123'), isTrue);
        expect(_isValidPassword('password'), isTrue);
        expect(_isValidPassword('MyP@ssw0rd!'), isTrue);
      });

      test('Invalid passwords fail validation', () {
        expect(_isValidPassword(''), isFalse, reason: 'Empty password should fail');
        expect(_isValidPassword('abc'), isFalse, reason: 'Too short password should fail');
        expect(_isValidPassword('12345'), isFalse, reason: '5 chars should fail');
      });
    });

    group('Decibel Level Validation', () {
      test('Valid decibel levels', () {
        expect(_isValidDecibelLevel(30), isTrue);
        expect(_isValidDecibelLevel(50), isTrue);
        expect(_isValidDecibelLevel(70), isTrue);
        expect(_isValidDecibelLevel(100), isTrue);
      });

      test('Invalid decibel levels', () {
        expect(_isValidDecibelLevel(-10), isFalse);
        expect(_isValidDecibelLevel(0), isFalse);
        expect(_isValidDecibelLevel(150), isFalse);
      });
    });

    group('Confidence Score Validation', () {
      test('Valid confidence scores', () {
        expect(_isValidConfidence(0.0), isTrue);
        expect(_isValidConfidence(0.5), isTrue);
        expect(_isValidConfidence(0.89), isTrue);
        expect(_isValidConfidence(1.0), isTrue);
      });

      test('Invalid confidence scores', () {
        expect(_isValidConfidence(-0.1), isFalse);
        expect(_isValidConfidence(1.1), isFalse);
        expect(_isValidConfidence(2.0), isFalse);
      });
    });

    group('Location Validation', () {
      test('Valid coordinates', () {
        expect(_isValidLatitude(6.9271), isTrue);   // Colombo
        expect(_isValidLatitude(-90), isTrue);
        expect(_isValidLatitude(90), isTrue);
        expect(_isValidLongitude(79.8612), isTrue);  // Colombo
        expect(_isValidLongitude(-180), isTrue);
        expect(_isValidLongitude(180), isTrue);
      });

      test('Invalid coordinates', () {
        expect(_isValidLatitude(-91), isFalse);
        expect(_isValidLatitude(91), isFalse);
        expect(_isValidLongitude(-181), isFalse);
        expect(_isValidLongitude(181), isFalse);
      });
    });
  });
}

// Helper validation functions
bool _isValidEmail(String email) {
  if (email.isEmpty) return false;
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

bool _isValidPassword(String password) {
  return password.length >= 6;
}

bool _isValidDecibelLevel(double db) {
  return db > 0 && db <= 120;
}

bool _isValidConfidence(double confidence) {
  return confidence >= 0.0 && confidence <= 1.0;
}

bool _isValidLatitude(double lat) {
  return lat >= -90 && lat <= 90;
}

bool _isValidLongitude(double lng) {
  return lng >= -180 && lng <= 180;
}
