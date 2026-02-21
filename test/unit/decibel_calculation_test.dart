import 'package:flutter_test/flutter_test.dart';

// Unit tests for Decibel level calculations and categorization
void main() {
  group('Decibel Level Categorization Tests', () {
    test('Low noise level (< 50 dB)', () {
      final category = _categorizeNoiseLevel(30);
      expect(category, equals('Low'));
    });

    test('Moderate noise level (50-70 dB)', () {
      final category = _categorizeNoiseLevel(60);
      expect(category, equals('Moderate'));
    });

    test('High noise level (> 70 dB)', () {
      final category = _categorizeNoiseLevel(85);
      expect(category, equals('High'));
    });

    test('Boundary case: exactly 50 dB', () {
      final category = _categorizeNoiseLevel(50);
      expect(category, isIn(['Low', 'Moderate']));
    });

    test('Boundary case: exactly 70 dB', () {
      final category = _categorizeNoiseLevel(70);
      expect(category, isIn(['Moderate', 'High']));
    });

    test('Extreme low: 0 dB', () {
      final category = _categorizeNoiseLevel(0);
      expect(category, equals('Low'));
    });

    test('Extreme high: 120 dB', () {
      final category = _categorizeNoiseLevel(120);
      expect(category, equals('High'));
    });

    test('Typical conversation: ~60 dB', () {
      final category = _categorizeNoiseLevel(60);
      expect(category, equals('Moderate'));
    });

    test('Traffic noise: ~80 dB', () {
      final category = _categorizeNoiseLevel(80);
      expect(category, equals('High'));
    });

    test('Library quiet: ~40 dB', () {
      final category = _categorizeNoiseLevel(40);
      expect(category, equals('Low'));
    });
  });

  group('Decibel Statistical Calculations', () {
    test('Calculate average from list of readings', () {
      final readings = [30.0, 40.0, 50.0, 60.0, 70.0];
      final avg = _calculateAverage(readings);
      expect(avg, equals(50.0));
    });

    test('Find minimum value', () {
      final readings = [30.0, 40.0, 50.0, 60.0, 70.0];
      final min = _findMinimum(readings);
      expect(min, equals(30.0));
    });

    test('Find maximum value', () {
      final readings = [30.0, 40.0, 50.0, 60.0, 70.0];
      final max = _findMaximum(readings);
      expect(max, equals(70.0));
    });

    test('Empty list returns 0 for average', () {
      final avg = _calculateAverage([]);
      expect(avg, equals(0.0));
    });

    test('Single value list', () {
      final avg = _calculateAverage([42.5]);
      expect(avg, equals(42.5));
    });
  });
}

// Helper functions for testing
String _categorizeNoiseLevel(double db) {
  if (db < 50) return 'Low';
  if (db < 70) return 'Moderate';
  return 'High';
}

double _calculateAverage(List<double> values) {
  if (values.isEmpty) return 0.0;
  return values.reduce((a, b) => a + b) / values.length;
}

double _findMinimum(List<double> values) {
  return values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
}

double _findMaximum(List<double> values) {
  return values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
}
