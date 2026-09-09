import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/analytics_screen.dart';

/// Regression tests for the Analytics "Duration" stat (fb-6 / flow3-7).
///
/// The stat counts persisted readings and multiplies by the dashboard save
/// interval. That interval is the `save_frequency` setting (5-30 s, playbook
/// cluster 09) — NOT a hardcoded 5 s. Hardcoding 5 made Duration under-report
/// by up to 6x for anyone who changed the setting, which is exactly the defect
/// fb-6/flow3-7 describe. These tests exist so a revert to a literal 5 fails
/// loudly: the widget test for this screen is quarantined (arch-2), so nothing
/// else would catch it.
void main() {
  group('totalHoursFor', () {
    test('no readings is zero hours regardless of interval', () {
      expect(totalHoursFor(0, 5), 0);
      expect(totalHoursFor(0, 30), 0);
    });

    test('720 readings at the 5s default is exactly 1 hour', () {
      // 3600 / 5 = 720 ticks per hour.
      expect(totalHoursFor(720, 5), closeTo(1.0, 1e-9));
    });

    test('scales with the interval — the whole point of the fix', () {
      // Same reading count, 6x the interval, 6x the monitoring time.
      expect(totalHoursFor(720, 30), closeTo(6.0, 1e-9));
      expect(totalHoursFor(720, 10), closeTo(2.0, 1e-9));
    });

    test('does NOT return the hardcoded-5s answer when the interval differs',
        () {
      // Guards the specific regression: if someone restores
      // `count * 5 / 3600`, this fails.
      final atThirty = totalHoursFor(360, 30);
      final atFive = totalHoursFor(360, 5);
      expect(atThirty, isNot(closeTo(atFive, 1e-9)));
      expect(atThirty, closeTo(atFive * 6, 1e-9));
    });

    test('honors both ends of the settings range', () {
      // save_frequency is clamped to 5..30 in dashboard_screen.dart and
      // analytics_screen.dart alike.
      expect(totalHoursFor(1, 5), closeTo(5 / 3600, 1e-12));
      expect(totalHoursFor(1, 30), closeTo(30 / 3600, 1e-12));
    });
  });
}
