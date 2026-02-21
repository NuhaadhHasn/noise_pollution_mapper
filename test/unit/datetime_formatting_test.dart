import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Unit tests for Date/Time formatting
void main() {
  group('Date/Time Formatting Tests', () {
    test('Format timestamp to readable date', () {
      final dateTime = DateTime(2026, 1, 26, 14, 30);
      final formatted = DateFormat('MMM dd, yyyy').format(dateTime);
      expect(formatted, equals('Jan 26, 2026'));
    });

    test('Format timestamp with time', () {
      final dateTime = DateTime(2026, 1, 26, 14, 30);
      final formatted = DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
      expect(formatted, equals('Jan 26, 2026 • 02:30 PM'));
    });

    test('Format time only', () {
      final dateTime = DateTime(2026, 1, 26, 14, 30);
      final formatted = DateFormat('hh:mm a').format(dateTime);
      expect(formatted, equals('02:30 PM'));
    });

    test('Relative time: today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = now.difference(today);
      expect(diff.inDays, equals(0));
    });

    test('Relative time: yesterday', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final diff = now.difference(yesterday);
      expect(diff.inDays, greaterThanOrEqualTo(1));
    });

    test('ISO 8601 format compatibility', () {
      final dateTime = DateTime(2026, 1, 26, 14, 30);
      final iso = dateTime.toIso8601String();
      expect(iso, contains('2026-01-26'));
    });
  });

  group('Duration Formatting Tests', () {
    test('Format seconds to human readable', () {
      const seconds = 125;
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      expect(minutes, equals(2));
      expect(remainingSeconds, equals(5));
    });

    test('Recording duration calculation', () {
      final start = DateTime(2026, 1, 26, 14, 00);
      final end = DateTime(2026, 1, 26, 14, 02);
      final duration = end.difference(start);
      expect(duration.inMinutes, equals(2));
    });
  });
}
