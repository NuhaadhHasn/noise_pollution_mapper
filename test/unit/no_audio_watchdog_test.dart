import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/no_audio_watchdog.dart';

/// Regression tests for the dead-recorder incident (device QA 2026-10-16,
/// Galaxy S9+, drill run): AudioRecord start failed with status -38, every
/// start call still reported success, the meter delivered only -Infinity dB
/// and the classifier 0 samples, and the user saw no error. The Dashboard
/// now feeds [NoAudioWatchdog] and acts on its verdict; the DashboardScreen
/// widget test is quarantined (arch-2), so these tests pin the policy with a
/// fake clock.
void main() {
  // Fake clock: seconds since the recording started.
  final t0 = DateTime(2026, 10, 16, 23, 25, 17);
  DateTime at(num seconds) =>
      t0.add(Duration(microseconds: (seconds * 1e6).round()));

  /// Both feeds deliver every [period] seconds over [from, to).
  void feedBoth(NoAudioWatchdog w, num from, num to, {num period = 0.25}) {
    for (var s = from; s < to; s += period) {
      w.audioReceived(AudioFeed.meter, at(s));
      w.audioReceived(AudioFeed.classifier, at(s));
    }
  }

  group('thresholds', () {
    test('7 s: longer than one 5 s classify tick, shorter than two', () {
      const classifyTick = Duration(seconds: 5);
      expect(NoAudioWatchdog.defaultTimeout, const Duration(seconds: 7));
      expect(NoAudioWatchdog.defaultTimeout, greaterThan(classifyTick));
      expect(NoAudioWatchdog.defaultTimeout, lessThan(classifyTick * 2));
    });

    test('checked every second, one restart per recording by default', () {
      expect(NoAudioWatchdog.checkInterval, const Duration(seconds: 1));
      final w = NoAudioWatchdog();
      expect(w.timeout, NoAudioWatchdog.defaultTimeout);
      expect(w.maxRestarts, 1);
    });
  });

  group('healthy recording', () {
    test('never trips while both feeds deliver, for a 10 min recording', () {
      final w = NoAudioWatchdog()..start(at(0));
      for (var s = 1; s <= 600; s++) {
        feedBoth(w, s - 1, s);
        expect(w.check(at(s)), AudioWatchdogVerdict.healthy, reason: 't=$s');
      }
      expect(w.restartsUsed, 0);
    });

    test('gaps just under the timeout never trip', () {
      final w = NoAudioWatchdog()..start(at(0));
      for (var s = 6.9; s < 60; s += 6.9) {
        expect(w.check(at(s)), AudioWatchdogVerdict.healthy, reason: 't=$s');
        w.audioReceived(AudioFeed.meter, at(s));
        w.audioReceived(AudioFeed.classifier, at(s));
      }
    });

    test('not armed before start or after stop', () {
      final w = NoAudioWatchdog();
      expect(w.isArmed, isFalse);
      expect(w.check(at(60)), AudioWatchdogVerdict.healthy);

      w
        ..start(at(0))
        ..stop();
      expect(w.isArmed, isFalse);
      expect(w.silentFeeds(at(60)), isEmpty);
      expect(w.check(at(60)), AudioWatchdogVerdict.healthy);
    });
  });

  group('dead recorder', () {
    test('a classifier that gets 0 samples (the incident) restarts at 7 s',
        () {
      final w = NoAudioWatchdog()..start(at(0));
      // The meter keeps delivering; the classifier never gets a sample.
      for (var s = 0.0; s < 7; s += 0.05) {
        w.audioReceived(AudioFeed.meter, at(s));
      }
      // The 5 s classify tick logs "Waiting for audio buffer (0/15600)"...
      expect(w.check(at(5)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(6.999)), AudioWatchdogVerdict.healthy);
      // ...and the recorder counts as dead before the 10 s tick.
      expect(w.silentFeeds(at(7)), {AudioFeed.classifier});
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      expect(w.restartsUsed, 1);
    });

    test('a meter that delivers no finite reading also restarts', () {
      final w = NoAudioWatchdog()..start(at(0));
      for (var s = 0.0; s < 7; s += 0.256) {
        w.audioReceived(AudioFeed.classifier, at(s));
      }
      expect(w.silentFeeds(at(7)), {AudioFeed.meter});
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
    });

    test('a feed that dies mid-recording restarts 7 s after its last audio',
        () {
      final w = NoAudioWatchdog()..start(at(0));
      feedBoth(w, 0, 120);
      final last = 120 - 0.25;
      expect(w.check(at(last + 6.9)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(last + 7)), AudioWatchdogVerdict.restart);
    });

    test('pauses while the restart runs: one verdict, stray audio ignored',
        () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      expect(w.isArmed, isFalse);
      // The teardown takes a while (a stuck stop alone waits 3 s); no
      // second restart and no failure meanwhile.
      for (final s in [8, 10, 15, 30]) {
        expect(w.check(at(s)), AudioWatchdogVerdict.healthy, reason: 't=$s');
      }
      // Audio from the recorder being torn down does not count.
      w.audioReceived(AudioFeed.classifier, at(9));
      w.restarted(at(30));
      expect(w.check(at(36.9)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(37)), AudioWatchdogVerdict.fail);
    });

    test('audio after the restart: healthy for the rest of the recording',
        () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      w.restarted(at(10));
      for (var s = 11; s <= 600; s++) {
        feedBoth(w, s - 1, s);
        expect(w.check(at(s)), AudioWatchdogVerdict.healthy, reason: 't=$s');
      }
    });

    test('still no audio after the restart: fail, 7 s after the restart', () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      w.restarted(at(10.5));
      expect(w.check(at(17.4)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(17.5)), AudioWatchdogVerdict.fail);
    });

    test('fail is sticky until the next recording starts', () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      w.restarted(at(8));
      expect(w.check(at(15)), AudioWatchdogVerdict.fail);
      // Late audio or a late restarted() call cannot revive it.
      w
        ..audioReceived(AudioFeed.meter, at(16))
        ..audioReceived(AudioFeed.classifier, at(16))
        ..restarted(at(16));
      expect(w.check(at(17)), AudioWatchdogVerdict.fail);
      expect(w.isArmed, isFalse);
    });

    test('one restart per recording: a second stall fails', () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      w.restarted(at(8));
      feedBoth(w, 8, 300);
      expect(w.check(at(300)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(300 - 0.25 + 7)), AudioWatchdogVerdict.fail);
    });

    test('the next recording gets the restart budget back', () {
      final w = NoAudioWatchdog()..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.restart);
      w.restarted(at(8));
      expect(w.check(at(15)), AudioWatchdogVerdict.fail);
      w.stop();

      w.start(at(100));
      expect(w.restartsUsed, 0);
      expect(w.check(at(106)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(107)), AudioWatchdogVerdict.restart);
    });

    test('with no restart budget the first stall fails', () {
      final w = NoAudioWatchdog(maxRestarts: 0)..start(at(0));
      expect(w.check(at(7)), AudioWatchdogVerdict.fail);
    });

    test('a custom timeout is honoured', () {
      final w = NoAudioWatchdog(timeout: const Duration(seconds: 3))
        ..start(at(0));
      expect(w.check(at(2.9)), AudioWatchdogVerdict.healthy);
      expect(w.check(at(3)), AudioWatchdogVerdict.restart);
    });
  });
}
