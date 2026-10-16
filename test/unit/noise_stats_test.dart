import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/noise_stats.dart';

void main() {
  group('NoiseStats.energyMeanDb (Leq)', () {
    test('empty list returns 0.0', () {
      expect(NoiseStats.energyMeanDb([]), 0.0);
    });

    test('single value returns itself', () {
      expect(NoiseStats.energyMeanDb([63.0]), closeTo(63.0, 1e-9));
    });

    test('identical values return that value', () {
      expect(
        NoiseStats.energyMeanDb([70.0, 70.0, 70.0]),
        closeTo(70.0, 1e-9),
      );
    });

    test('Leq of 50 and 60 dB is ~57.40 dB, above the arithmetic mean 55', () {
      // 10 * log10((10^5 + 10^6) / 2) = 10 * log10(550000) = 57.40362...
      final leq = NoiseStats.energyMeanDb([50.0, 60.0]);
      expect(leq, closeTo(57.4036, 0.001));
      expect(leq, greaterThan(55.0));
    });

    test('loud events dominate the average', () {
      // 10 * log10((3*10^4 + 10^9) / 4) = 83.98...
      final leq = NoiseStats.energyMeanDb([40.0, 40.0, 40.0, 90.0]);
      final arithmetic = (40.0 * 3 + 90.0) / 4; // 52.5
      expect(leq, greaterThan(80.0));
      expect(leq, greaterThan(arithmetic));
    });

    test('result always lies between min and max input', () {
      final leq = NoiseStats.energyMeanDb([30.0, 55.0, 80.0]);
      expect(leq, greaterThanOrEqualTo(30.0));
      expect(leq, lessThanOrEqualTo(80.0));
    });
  });

  // a1-4 (device QA 2026-10-16): the dashboard MIN card showed "Infinity"
  // before the first reading, because MIN starts at double.infinity.
  group('NoiseStats.formatStatDb', () {
    test('MIN before any reading is the placeholder, not "Infinity"', () {
      expect(
        NoiseStats.formatStatDb(double.infinity, hasData: false),
        NoiseStats.noDataPlaceholder,
      );
      expect(
        NoiseStats.formatStatDb(double.infinity, hasData: false),
        isNot(contains('Infinity')),
      );
    });

    test('AVG and MAX before any reading match MIN, not a fake "0"', () {
      expect(NoiseStats.formatStatDb(0.0, hasData: false),
          NoiseStats.noDataPlaceholder);
    });

    test('a non-finite value never prints, even with data', () {
      expect(NoiseStats.formatStatDb(double.infinity, hasData: true),
          NoiseStats.noDataPlaceholder);
      expect(NoiseStats.formatStatDb(double.negativeInfinity, hasData: true),
          NoiseStats.noDataPlaceholder);
      expect(NoiseStats.formatStatDb(double.nan, hasData: true),
          NoiseStats.noDataPlaceholder);
    });

    test('a real reading prints as whole decibels', () {
      expect(NoiseStats.formatStatDb(63.4, hasData: true), '63');
      expect(NoiseStats.formatStatDb(63.5, hasData: true), '64');
      expect(NoiseStats.formatStatDb(0.0, hasData: true), '0');
    });
  });
}
