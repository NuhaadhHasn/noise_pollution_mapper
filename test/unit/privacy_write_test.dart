import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/firebase_service.dart';

void main() {
  group('FirebaseService.roundCoordinate', () {
    test('rounds to exactly 3 decimal places', () {
      expect(FirebaseService.roundCoordinate(6.927079), closeTo(6.927, 1e-9));
      expect(FirebaseService.roundCoordinate(79.861243), closeTo(79.861, 1e-9));
      expect(FirebaseService.roundCoordinate(-6.927579), closeTo(-6.928, 1e-9));
      expect(FirebaseService.roundCoordinate(0.0), closeTo(0.0, 1e-9));
    });
  });

  group('FirebaseService.authorLabel', () {
    test('prefers non-empty displayName', () {
      expect(
        FirebaseService.authorLabel(
            displayName: 'Nuha', email: 'nuhaadhh@codegen.net'),
        'Nuha',
      );
    });

    test('masks email when displayName missing or blank', () {
      expect(
        FirebaseService.authorLabel(
            displayName: null, email: 'nuhaadhh@codegen.net'),
        'nuh***@codegen.net',
      );
      expect(
        FirebaseService.authorLabel(
            displayName: '   ', email: 'ab@codegen.net'),
        'ab***@codegen.net',
      );
    });

    test('never returns the raw email', () {
      final label = FirebaseService.authorLabel(
          displayName: null, email: 'someone@example.com');
      expect(label, isNot('someone@example.com'));
      expect(label, contains('***'));
    });

    test('falls back to Anonymous', () {
      expect(FirebaseService.authorLabel(displayName: null, email: null),
          'Anonymous');
      expect(
          FirebaseService.authorLabel(displayName: '', email: 'not-an-email'),
          'Anonymous');
    });
  });
}
