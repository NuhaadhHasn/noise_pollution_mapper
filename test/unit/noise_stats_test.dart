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
}
