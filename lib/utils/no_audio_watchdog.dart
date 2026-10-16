/// The Dashboard's two microphone capture paths. Each runs on its own
/// Android AudioRecord, so either can die while the other keeps going.
enum AudioFeed {
  /// noise_meter (audio_streamer, 44.1 kHz): the dB gauge and the saved
  /// levels. Only a finite reading counts as audio: a dead AudioRecord keeps
  /// delivering zero-filled buffers, which read as -Infinity dB.
  meter,

  /// flutter_sound (16 kHz PCM): the YAMNet classifier buffer. Any chunk of
  /// samples counts.
  classifier,
}

/// What the Dashboard should do about its microphone capture.
enum AudioWatchdogVerdict {
  /// Every feed has delivered audio within [NoAudioWatchdog.timeout], or the
  /// watchdog is not armed.
  healthy,

  /// A feed has been silent for [NoAudioWatchdog.timeout]. Tear capture down
  /// fully (stop, close and re-open the recorder), start it again, then call
  /// [NoAudioWatchdog.restarted]. Returned at most
  /// [NoAudioWatchdog.maxRestarts] times per recording.
  restart,

  /// A feed is still silent after the restart. Stop the recording and tell
  /// the user. Sticky until the next [NoAudioWatchdog.start].
  fail,
}

/// Detects a dead microphone recorder during a recording.
///
/// Device QA 2026-10-16 (Galaxy S9+, once in about 45 recordings): at
/// recording start the meter's AudioRecord failed with status -38 ("dead
/// IAudioRecord"), yet every start call reported success. The meter then
/// delivered only -Infinity dB, the classifier received 0 samples ("Waiting
/// for audio buffer... (0/15600)" every 5 s), and the user saw no error. This
/// watchdog turns "no audio for [timeout]" into one restart, then a visible
/// failure.
///
/// Pure state machine: every call takes the current time, so tests drive it
/// with a fake clock.
///
/// Policy:
/// * Armed by [start] when a recording's capture is running. Each feed's
///   no-audio window starts then, and restarts on every [audioReceived].
/// * A feed silent for [timeout] gives [AudioWatchdogVerdict.restart], at
///   most [maxRestarts] times per recording. The watchdog then pauses
///   (ignores audio, reports healthy) until [restarted].
/// * Silent again for [timeout] after the restart, or after the budget is
///   spent: [AudioWatchdogVerdict.fail].
class NoAudioWatchdog {
  NoAudioWatchdog({this.timeout = defaultTimeout, this.maxRestarts = 1})
      : assert(timeout > Duration.zero),
        assert(maxRestarts >= 0);

  /// How long a feed may deliver nothing before its recorder counts as dead.
  ///
  /// 7 s, measured against the Dashboard's 5 s classify tick:
  /// * A healthy feed is never silent for more than about half a second.
  ///   flutter_sound delivers a 4096-sample chunk every 256 ms at 16 kHz and
  ///   the meter delivers dozens of readings per second. The worst
  ///   main-thread stall seen in the QA logs was about 0.7 s (42 skipped
  ///   frames).
  /// * Longer than one classify period (5 s) plus 2 s of slack for
  ///   AudioRecord start-up and jank, so the watchdog never fires before the
  ///   classifier has had its first full window.
  /// * Shorter than two periods (10 s), so a dead recorder is caught after
  ///   one empty classify tick and restarted before the second.
  static const Duration defaultTimeout = Duration(seconds: 7);

  /// How often the Dashboard calls [check]. A dead feed is detected 7–8 s
  /// after its last audio.
  static const Duration checkInterval = Duration(seconds: 1);

  final Duration timeout;

  /// Restarts allowed per recording before [check] reports a failure.
  final int maxRestarts;

  final Map<AudioFeed, DateTime> _lastAudioAt = {};
  bool _armed = false;
  bool _failed = false;
  int _restartsUsed = 0;

  /// Restarts used by the current recording.
  int get restartsUsed => _restartsUsed;

  /// Whether audio is being watched (false before [start], while a restart
  /// runs, and after [stop] or a failure).
  bool get isArmed => _armed;

  /// A recording's capture started at [now]: arm, with the full restart
  /// budget.
  void start(DateTime now) {
    _restartsUsed = 0;
    _failed = false;
    _arm(now);
  }

  /// Capture was restarted at [now] after a [AudioWatchdogVerdict.restart]:
  /// arm again. The restart budget is not refilled.
  void restarted(DateTime now) {
    if (_failed) return;
    _arm(now);
  }

  /// The recording stopped: disarm.
  void stop() => _armed = false;

  /// [feed] delivered audio at [now]. Ignored while not armed, so stray
  /// audio from a recorder being torn down cannot count for its successor.
  void audioReceived(AudioFeed feed, DateTime now) {
    if (_armed) _lastAudioAt[feed] = now;
  }

  /// The feeds that have been silent for at least [timeout] at [now]
  /// (empty while not armed). For logging; call it before [check].
  Set<AudioFeed> silentFeeds(DateTime now) => {
        if (_armed)
          for (final feed in AudioFeed.values)
            if (now.difference(_lastAudioAt[feed]!) >= timeout) feed,
      };

  /// The verdict at [now].
  AudioWatchdogVerdict check(DateTime now) {
    if (_failed) return AudioWatchdogVerdict.fail;
    if (silentFeeds(now).isEmpty) return AudioWatchdogVerdict.healthy;

    _armed = false;
    if (_restartsUsed < maxRestarts) {
      _restartsUsed++;
      return AudioWatchdogVerdict.restart;
    }
    _failed = true;
    return AudioWatchdogVerdict.fail;
  }

  void _arm(DateTime now) {
    _armed = true;
    for (final feed in AudioFeed.values) {
      _lastAudioAt[feed] = now;
    }
  }
}
