import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/analytics_screen.dart';

void main() {
  group('dayBucketFor (weekly, maxDays = 6)', () {
    // Saturday 2026-07-18 14:30 local time.
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading earlier today lands in the last bucket (today)', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 18, 0, 5), 6), 6);
    });

    test('reading late yesterday lands in bucket 5 even though <24h ago', () {
      // 23:50 yesterday is only ~14.7 h before now — the old rolling-window
      // code put this reading in TODAY's bucket (analytics-2).
      expect(dayBucketFor(now, DateTime(2026, 7, 17, 23, 50), 6), 5);
    });

    test('reading 6 calendar days ago lands in bucket 0', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 12, 9, 0), 6), 0);
    });

    test('reading 7 calendar days ago is outside the window', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 11, 23, 59), 6), isNull);
    });

    test('future reading (clock skew) is rejected, not mis-bucketed', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 19, 1, 0), 6), isNull);
    });
  });

  group('dayBucketFor (monthly, maxDays = 29)', () {
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading 29 calendar days ago lands in bucket 0', () {
      expect(dayBucketFor(now, DateTime(2026, 6, 19, 23, 0), 29), 0);
    });

    test('reading 30 calendar days ago is outside the window', () {
      expect(dayBucketFor(now, DateTime(2026, 6, 18, 12, 0), 29), isNull);
    });
  });

  group('dailyBucketFor', () {
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading in the current clock hour lands in bucket 23', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 18, 14, 5)), 23);
    });

    test('reading in the previous clock hour lands in bucket 22', () {
      // 13:55 is only 35 min before now, but belongs to the 13h label bucket.
      expect(dailyBucketFor(now, DateTime(2026, 7, 18, 13, 55)), 22);
    });

    test('reading 23 clock hours ago lands in bucket 0', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 17, 15, 10)), 0);
    });

    test('reading 24+ clock hours ago is outside the window', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 17, 13, 59)), isNull);
    });
  });
}
