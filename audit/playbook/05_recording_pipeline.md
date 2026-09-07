# Implementation Spec — Defect Cluster 05: Recording Pipeline & Dashboard

Target app: `noise_pollution_mapper/` (Flutter + Firebase + TFLite YAMNet).
Execute steps strictly in order. Each step is exactly one commit. `flutter analyze` must be clean after every commit.

All file paths below are relative to the project root `noise_pollution_mapper/`.

**Firestore index note (project convention 1):** NONE of the changes in this spec touch any Firestore query. Only the WRITE path (`FirebaseService.saveNoiseReading`) call-site arguments change (gating + a `null` locationName). The only composite index remains `noise_readings (userId ASC, timestamp DESC)`. Do NOT add any index. Do NOT touch the `_buildCommunityFeedCard` StreamBuilder query in `dashboard_screen.dart` — it is out of scope for this cluster.

**Package API verification (pubspec.yaml, all verified against installed versions and current code):**
- `noise_meter: ^5.0.2` — `NoiseMeter().noise` is a `Stream<NoiseReading>`; `NoiseReading.meanDecibel` is `double` (already used at lines 380-394).
- `flutter_sound: ^9.16.3` — `FlutterSoundRecorder.isRecording` (bool getter), `startRecorder(toStream:, codec:, sampleRate:, numChannels:)`, `stopRecorder()` returning `Future<String?>` (all already used).
- `shared_preferences: ^2.3.3` — `SharedPreferences.getInstance()`, `getBool(String)`, `getDouble(String)` (already used in `settings_screen_enhanced.dart:44-58`).
- Flutter SDK (Dart `^3.10.3`) — `ValueNotifier<T>`, `ValueListenableBuilder<T>`, `Semantics` widget with `button`/`label`/`liveRegion`, `WidgetsBindingObserver`, `AppLifecycleState.paused` and `AppLifecycleState.hidden` (hidden exists since Flutter 3.13; this SDK is far newer).
- `dart:math` — `pow`, `log`, `ln10` (SDK).

No new packages. No `pubspec.yaml` changes.

**Whitespace warning for Edit operations:** `lib/screens/dashboard_screen.dart` contains trailing whitespace on several otherwise-blank lines (e.g., the blank line after `if (!_isRecording || !mounted) return;` at line 384 and after the guard in the save timer at line 490). If an exact-match edit fails, re-read the surrounding lines and include the trailing spaces exactly as the file has them. Do not run a formatter over unrelated regions.

---

## Scope

| Finding IDs | Status | One-line summary |
|---|---|---|
| dash-1 | CONFIRMED (High) | AVG stat uses arithmetic mean of dB values; must be energy-based Leq = 10·log10(mean(10^(dB/10))) (`lib/screens/dashboard_screen.dart:424`) |
| dash-2 | CONFIRMED (High) | Double-start race: `_isRecording` set only after awaits; second tap leaks a noise subscription and a duplicate save timer (`:364`) |
| dash-4 / flow2-4 | CONFIRMED (High) | Location failure still saves readings with hardcoded Colombo 6.9271/79.8612 coords and UI status strings as `locationName` (`:61-63`, `:487-502`) |
| dash-6 | CONFIRMED (High) | Recording continues invisibly on tab switch (IndexedStack keeps screen mounted) and on app background; frozen `_currentDb` re-saved every 5 s as fresh data (`:102`) |
| flow6-04 / settings-4 | CONFIRMED (High) | Alert threshold hardcoded at 70 dB; `high_noise_alerts` toggle and `db_threshold` slider prefs are never read (`:428`) |
| perf-2 | CONFIRMED (High) | `setState` per `NoiseReading` rebuilds the entire dashboard several times per second (`:385`) |
| a11y-2 | CONFIRMED (High) | Record/stop control is a bare unlabeled `GestureDetector`; recording state never announced (`:836-869`) |

Full descriptions and adversarial-verifier evidence: grep `audit/00_MASTER_AUDIT_REPORT.md`, `audit/01_BUGS_AND_CORRECTNESS.md`, `audit/03_E2E_FLOW_AUDIT.md`, `audit/04_PERFORMANCE_AUDIT.md`, `audit/07_ACCESSIBILITY_AUDIT.md` for each ID.

---

## Pre-reading

Open these files completely before touching anything:

1. `lib/screens/dashboard_screen.dart` (1174 lines — every step edits this file; internalize `_startRecording` (:361), `_stopRecording` (:544), the noise listener (:381-449), the save timer (:487-503), `_getCurrentLocation` (:161-308), `didChangeAppLifecycleState` (:101-114), `initState` (:90-99), `dispose` (:659-667), and `build` (:669-897))
2. `lib/widgets/main_app_shell.dart` (59 lines — IndexedStack tabs: Map=0, Analytics=1, Dashboard=2, History=3, Settings=4; tab taps only change `_currentIndex`)
3. `lib/utils/shared_app_state.dart` (10 lines — static cross-screen state; gains a `ValueNotifier` in Step 3)
4. `lib/screens/settings_screen_enhanced.dart` lines 40-190 (pref keys: `high_noise_alerts` bool written at :186, `db_threshold` double written at :161, defaults `true` / `70.0` at :49/:57)
5. `lib/services/firebase_service.dart` lines 16-60 (`saveNoiseReading` signature — `locationName` is `String?`; do not change this file)
6. `lib/services/notification_service.dart` lines 35-41 (`showHighNoiseAlert(double)` — static, already gates on `notifications_enabled`; do not change this file)
7. `lib/widgets/decibel_meter_gauge.dart` lines 1-30 (`DecibelMeterGauge(currentDb:, maxDb:)` — stateless; unchanged, only its call site is wrapped in Step 6)
8. `lib/widgets/noise_history_chart.dart` lines 1-50 (`NoiseHistoryChart(dbHistory:)` — stateless; unchanged, only its call site is wrapped in Step 6)

Key facts your edits rely on:

- The dashboard lives in `MainAppShell`'s `IndexedStack` at index 2, so switching tabs never disposes it and `dispose()` is not a hook for "screen hidden" (verified in dash-6 evidence). The shell's `onTap` (main_app_shell.dart:50-54) is the single place tab changes happen.
- `_stopRecording()` (`void ... async`) resets `_isRecording = false` inside a `setState`. It must NOT be called from inside `_startRecording` after the flag is set (Step 1 replaces that call with a direct recorder stop).
- The noise listener callback and both `Timer.periodic` callbacks all guard on `_isRecording`, so setting the flag synchronously-first is safe: the subscriptions/timers created afterwards see `true`.
- `_latitude`/`_longitude` are only ever overwritten on GPS success (dashboard_screen.dart:239-244); every failure path leaves the Colombo defaults from :62-63 and writes a status string into `_locationName` (:185, :201, :217, :299) — that is the entire dash-4/flow2-4 defect.
- `SoundClassificationService` confidence threshold is 0.30 (project convention 5) — nothing in this spec touches classification logic; do not drift it.
- Existing tests: `test/unit/` and `test/widget/dashboard_screen_test.dart` exist. Step 4 adds `test/unit/noise_stats_test.dart`. After every step run the full `flutter test test/unit/` to confirm no unit regressions; the widget tests require a Firebase test harness and are not part of this spec's verify gates (run them only if they already pass on your base commit).

---

## Steps

### Step 1 — dash-2: set `_isRecording` synchronously to kill the double-start race

**Goal:** A second tap on the record button during async startup must hit the re-entry guard, and any resources leaked by a previous session must be cancelled before creating new ones.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Commit title:** `fix(dashboard): set recording flag synchronously to prevent double-start leaks`

**Exact changes:**

1a. Replace the head of `_startRecording` (lines 360-377).

BEFORE:
```dart
  // Start noise measurement
  void _startRecording() async {
    try {
      // CRITICAL: Check if already recording - prevent duplicate starts
      if (_isRecording) {
        AppLogger.warning('Already recording, ignoring start request');
        return;
      }

      // CRITICAL: Check if audio recorder is already running
      if (_audioRecorder != null && _audioRecorder!.isRecording) {
        AppLogger.warning('Audio recorder already running, stopping first...');
        _stopRecording(); // Don't await - it's void
        // Small delay to ensure clean state
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Location already fetched on screen start, no need to request again
```

AFTER:
```dart
  // Start noise measurement
  void _startRecording() async {
    // CRITICAL (dash-2): check-and-set the guard SYNCHRONOUSLY, before any
    // await. A second tap during async setup now returns here instead of
    // starting a duplicate noise subscription + save timer.
    if (_isRecording) {
      AppLogger.warning('Already recording, ignoring start request');
      return;
    }
    setState(() {
      _isRecording = true;
    });

    try {
      // Defensively cancel anything a previous session may have leaked
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      _classificationTimer?.cancel();
      _classificationTimer = null;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // CRITICAL: if the audio recorder is somehow still running, stop it
      // directly. Do NOT call _stopRecording() here - it would reset the
      // _isRecording flag we just set.
      if (_audioRecorder != null && _audioRecorder!.isRecording) {
        AppLogger.warning('Audio recorder already running, stopping first...');
        try {
          await _audioRecorder!.stopRecorder().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              AppLogger.warning('stopRecorder() timed out during restart');
              return; // Explicit return to satisfy nullable return type
            },
          );
        } catch (e) {
          AppLogger.error('Failed to stop stale audio recorder', e);
        }
      }

      // Location already fetched on screen start, no need to request again
```

1b. Delete the now-redundant flag set after recorder startup (lines 482-485 of the original file — directly above the `_saveTimer` creation).

BEFORE:
```dart
      setState(() {
        _isRecording = true;
      });

      // Start periodic Firebase saves (every 5 seconds)
```

AFTER:
```dart
      // Start periodic Firebase saves (every 5 seconds)
```

1c. Make the catch block roll everything back (lines 515-517 of the original file).

BEFORE:
```dart
    } catch (e) {
      AppLogger.error('Error starting recording', e);
    }
  }
```

AFTER:
```dart
    } catch (e) {
      AppLogger.error('Error starting recording', e);
      // Roll back: tear down anything partially started and clear the flag
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      _classificationTimer?.cancel();
      _classificationTimer = null;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      if (mounted && !_isDisposed) {
        setState(() {
          _isRecording = false;
        });
      } else {
        _isRecording = false;
      }
    }
  }
```

**Edge cases to preserve:**
- The noise listener (`if (!_isRecording || !mounted) return;`) and both timer guards must keep working — they do, because the flag is already `true` when the subscription/timers are created.
- `_stopRecording()` remains the ONLY place that flips the flag back to `false` on the happy path; the button now turns red immediately on tap (acceptable UX side effect).
- The `onTimeout: () { return; }` bare-return pattern is intentional — it mirrors the identical pattern already in `_stopRecording` (line 553-559) and satisfies `Future<String?>`.

**Acceptance criteria:**
- Rapidly double-tapping the mic button starts exactly one recording session: one "Started real audio capture" log line, one reading save every 5 s (not two).
- If `startRecorder` throws (e.g., mic revoked mid-start), the button returns to the idle "Tap to measure" state and no timers keep firing.

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: run on a device, spam-tap the record button 5× quickly, confirm the log shows `Already recording, ignoring start request` for taps 2-5 and Firestore receives one reading per 5 s.

---

### Step 2 — dash-4 / flow2-4: gate saves on a real GPS fix; never persist Colombo defaults or status strings

**Goal:** A reading is persisted only after a real GPS fix has been obtained, and a UI status string is never stored as `locationName`.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Commit title:** `fix(dashboard): gate reading saves on a real GPS fix, never save Colombo defaults`

**Exact changes:**

2a. Add the tracking field (lines 60-64).

BEFORE:
```dart
  // Location tracking
  String _locationName = 'Fetching location...';
  double _latitude = 6.9271; // Colombo default
  double _longitude = 79.8612;
  bool _isLocationLoading = true;
```

AFTER:
```dart
  // Location tracking
  String _locationName = 'Fetching location...';
  double _latitude = 6.9271; // Colombo default
  double _longitude = 79.8612;
  bool _isLocationLoading = true;
  // dash-4/flow2-4: true only after a real GPS fix. Reading saves are gated
  // on this flag so the hardcoded Colombo default above is never persisted.
  bool _hasRealLocation = false;
```

2b. Set the flag on GPS success in `_getCurrentLocation` (lines 239-244) and also store the coordinates even if the widget is briefly unmounted (coords are plain state, not UI).

BEFORE:
```dart
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
```

AFTER:
```dart
      _hasRealLocation = true;
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      } else {
        _latitude = position.latitude;
        _longitude = position.longitude;
      }
```

2c. Add a status-string detector directly above `_startRecording` (i.e., insert between the closing `}` of `_showNativeLocationDialog` at line 358 and the `// Start noise measurement` comment at line 360).

BEFORE:
```dart
  // Start noise measurement
  void _startRecording() async {
```

AFTER:
```dart
  // dash-4/flow2-4: _locationName holds UI status strings on failure paths
  // (set at _getCurrentLocation). These must never be persisted as a
  // reading's locationName.
  bool get _locationNameIsStatus =>
      _locationName == 'Fetching location...' ||
      _locationName == 'Location permission denied' ||
      _locationName == 'Location services disabled';

  // Start noise measurement
  void _startRecording() async {
```

2d. Gate the save timer (the `_saveTimer = Timer.periodic(...)` block; original lines 487-503; note the blank line after the guard carries trailing spaces).

BEFORE:
```dart
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;
        
        if (_currentDb > 0 && _currentDb.isFinite) {
          _firebaseService.saveNoiseReading(
            decibelLevel: _currentDb,
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationName,
            // Include classification data if available
            soundClass: _currentClassification?.category,
            soundType: _currentClassification?.soundType,
            confidence: _currentClassification?.confidence,
          );
        }
      });
```

AFTER:
```dart
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;

        // dash-4/flow2-4: never persist the hardcoded Colombo default -
        // only save once a real GPS fix has been obtained this app session.
        if (!_hasRealLocation) {
          AppLogger.warning(
            'Skipping reading save: no real GPS fix yet (refusing to save default coordinates)',
          );
          return;
        }

        if (_currentDb > 0 && _currentDb.isFinite) {
          _firebaseService.saveNoiseReading(
            decibelLevel: _currentDb,
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationNameIsStatus ? null : _locationName,
            // Include classification data if available
            soundClass: _currentClassification?.category,
            soundType: _currentClassification?.soundType,
            confidence: _currentClassification?.confidence,
          );
        }
      });
```

**Edge cases to preserve:**
- Once a real fix exists, a LATER location failure keeps `_hasRealLocation == true` deliberately: `_latitude`/`_longitude` still hold the last real fix (truthful, if stale). Only `_locationName` may then be a status string — the `_locationNameIsStatus ? null : _locationName` sanitizer covers that (FirebaseService already maps null → 'Unknown Location' downstream).
- The `'GPS: 6.9271, 79.8612'`-style names produced when geocoding fails are real fixes and must still be saved as-is.
- Recording/metering itself stays fully functional without a fix — only persistence is skipped. Do not block `_startRecording`.
- `saveNoiseReading` already writes both `timestamp` (server) and `createdAt` (client) — convention 3; do not touch `firebase_service.dart`.

**Acceptance criteria:**
- With location services OFF from a cold start: record for 30 s → zero documents appear in `noise_readings`; log shows the skip warning every 5 s.
- With location ON: readings save exactly as before, with a real place name or `GPS: lat, lng` string, never `Fetching location...` / `Location permission denied` / `Location services disabled`.

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: (1) airplane-mode + location-off cold start, record 30 s, confirm no new Firestore docs and skip warnings in log; (2) location on, record 15 s, inspect the new docs' `latitude`/`longitude`/`locationName` fields.

---

### Step 3 — dash-6: stop recording when hidden (tab switch / background) and stop saving when the meter stalls

**Goal:** Recording never continues invisibly (stop on tab switch away from Dashboard and on app pause/hide), and a stalled meter stream stops producing "fresh" saves of a frozen `_currentDb`.

**Files:**
- `lib/utils/shared_app_state.dart`
- `lib/widgets/main_app_shell.dart`
- `lib/screens/dashboard_screen.dart`

**Commit title:** `fix(dashboard): stop recording when hidden and skip saves when meter stalls`

**Exact changes:**

3a. `lib/utils/shared_app_state.dart` — full new contents (file is 10 lines today):

```dart
import 'package:flutter/foundation.dart';

/// Shared app state to prevent duplicate operations across screens
class SharedAppState {
  // Track if location dialog already shown APP-WIDE (prevent duplicate dialogs)
  static bool locationDialogShown = false;

  /// Currently visible tab in MainAppShell's IndexedStack
  /// (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).
  /// Screens hosted in the IndexedStack stay mounted when hidden, so they
  /// listen to this to react to being shown/hidden (dash-6).
  static final ValueNotifier<int> currentTabIndex = ValueNotifier<int>(2);

  // Reset flag (call when app restarts)
  static void reset() {
    locationDialogShown = false;
  }
}
```

3b. `lib/widgets/main_app_shell.dart` — publish tab changes.

BEFORE (lines 1-8):
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen_enhanced.dart';
import 'shared_bottom_navbar.dart';
```

AFTER:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen_enhanced.dart';
import '../utils/shared_app_state.dart';
import 'shared_bottom_navbar.dart';
```

BEFORE (lines 22-26):
```dart
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }
```

AFTER:
```dart
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SharedAppState.currentTabIndex.value = widget.initialIndex;
  }
```

BEFORE (lines 48-55):
```dart
        bottomNavigationBar: SharedBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
```

AFTER:
```dart
        bottomNavigationBar: SharedBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            SharedAppState.currentTabIndex.value = index;
            setState(() {
              _currentIndex = index;
            });
          },
        ),
```

3c. `lib/screens/dashboard_screen.dart` — add fields (immediately after the `_hasRealLocation` field added in Step 2).

BEFORE:
```dart
  // dash-4/flow2-4: true only after a real GPS fix. Reading saves are gated
  // on this flag so the hardcoded Colombo default above is never persisted.
  bool _hasRealLocation = false;
```

AFTER:
```dart
  // dash-4/flow2-4: true only after a real GPS fix. Reading saves are gated
  // on this flag so the hardcoded Colombo default above is never persisted.
  bool _hasRealLocation = false;

  // dash-6: timestamp of the last NoiseReading delivered by the meter stream.
  // The save timer refuses to persist _currentDb if the stream has stalled.
  DateTime? _lastNoiseReadingAt;

  // dash-6: Dashboard's index in MainAppShell's IndexedStack
  // (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).
  static const int _dashboardTabIndex = 2;
```

3d. Subscribe/unsubscribe to tab changes and stop on hide. Replace `initState` (lines 90-99) and add the handler right after it.

BEFORE:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudioRecorder();
    _requestPermissions();
    // Call location immediately (no delay - delay causes race condition)
    _getCurrentLocation();
    AppLogger.debug('User ID: ${FirebaseAuth.instance.currentUser?.uid}');
  }
```

AFTER:
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // dash-6: the IndexedStack keeps this screen mounted when the user
    // switches tabs, so dispose() never fires - listen for tab changes.
    SharedAppState.currentTabIndex.addListener(_onShellTabChanged);
    _initializeAudioRecorder();
    _requestPermissions();
    // Call location immediately (no delay - delay causes race condition)
    _getCurrentLocation();
    AppLogger.debug('User ID: ${FirebaseAuth.instance.currentUser?.uid}');
  }

  // dash-6: invoked whenever MainAppShell switches tabs
  void _onShellTabChanged() {
    if (widget.isInAppShell &&
        SharedAppState.currentTabIndex.value != _dashboardTabIndex &&
        _isRecording) {
      AppLogger.info('Dashboard hidden by tab switch, stopping recording');
      _stopRecording();
    }
  }
```

3e. Stop on app background. Replace the head of `didChangeAppLifecycleState` (lines 101-105).

BEFORE:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When user returns from settings (app resumes), check if location is now enabled
    if (state == AppLifecycleState.resumed) {
```

AFTER:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // dash-6: recording must not continue invisibly in the background
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _isRecording) {
      AppLogger.info('App backgrounded while recording, stopping recording');
      _stopRecording();
    }
    // When user returns from settings (app resumes), check if location is now enabled
    if (state == AppLifecycleState.resumed) {
```

3f. Track stream liveness in the noise listener (lines 382-384 as they stand after Step 1; the line after the guard is blank with trailing spaces).

BEFORE:
```dart
        (NoiseReading reading) {
          if (!_isRecording || !mounted) return;
```

AFTER:
```dart
        (NoiseReading reading) {
          if (!_isRecording || !mounted) return;
          // dash-6: record stream liveness for the save timer's stall check
          _lastNoiseReadingAt = DateTime.now();
```

3g. Reset liveness on session start — in the defensive-cancel block Step 1 added at the top of `_startRecording`'s `try`.

BEFORE:
```dart
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // CRITICAL: if the audio recorder is somehow still running, stop it
```

AFTER:
```dart
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      _lastNoiseReadingAt = null;

      // CRITICAL: if the audio recorder is somehow still running, stop it
```

3h. Stall gate in the save timer (block as it stands after Step 2).

BEFORE:
```dart
        // dash-4/flow2-4: never persist the hardcoded Colombo default -
        // only save once a real GPS fix has been obtained this app session.
        if (!_hasRealLocation) {
          AppLogger.warning(
            'Skipping reading save: no real GPS fix yet (refusing to save default coordinates)',
          );
          return;
        }

        if (_currentDb > 0 && _currentDb.isFinite) {
```

AFTER:
```dart
        // dash-4/flow2-4: never persist the hardcoded Colombo default -
        // only save once a real GPS fix has been obtained this app session.
        if (!_hasRealLocation) {
          AppLogger.warning(
            'Skipping reading save: no real GPS fix yet (refusing to save default coordinates)',
          );
          return;
        }

        // dash-6: if the meter stream has stalled, _currentDb is frozen -
        // do not keep re-saving it as fresh data.
        final lastReading = _lastNoiseReadingAt;
        if (lastReading == null ||
            DateTime.now().difference(lastReading) >
                const Duration(seconds: 6)) {
          AppLogger.warning(
            'Skipping reading save: noise stream stalled (no reading in >6s)',
          );
          return;
        }

        if (_currentDb > 0 && _currentDb.isFinite) {
```

3i. Unsubscribe in `dispose` (lines 659-667 of the original file).

BEFORE:
```dart
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopRecording();
```

AFTER:
```dart
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    SharedAppState.currentTabIndex.removeListener(_onShellTabChanged);
    _stopRecording();
```

**Edge cases to preserve:**
- `AppLifecycleState.inactive` must NOT stop recording — it fires on transient events (permission dialogs, notification shade) and would kill legitimate sessions.
- The existing `resumed` branch (location re-check) must remain exactly as-is below the new block.
- `_onShellTabChanged` guards on `widget.isInAppShell` so a standalone-pushed `DashboardScreen` never reacts to shell tab state.
- `_stopRecording()` is `void ... async`; calling it un-awaited from the listener/lifecycle hook matches the existing button call site.
- Stall window is 6 s (> one 5 s save period) so a healthy stream (several readings/second) is never falsely flagged.
- Settings tab (index 4) and the pushed `SettingsScreenEnhanced` route both leave the dashboard hidden → stop is correct in both paths (the pushed route case is covered by the tab remaining 2; recording keeps running there, which matches today's behavior for pushed routes — do not try to "fix" that here).

**Acceptance criteria:**
- Start recording, tap the Map tab: log shows "Dashboard hidden by tab switch, stopping recording"; back on Dashboard the button is idle and no saves occurred while away.
- Start recording, press device Home: recording stops (log line), no 5 s saves accumulate while backgrounded.
- If the mic stream stalls (e.g., another app grabs the mic), saves stop within one timer tick with the stall warning.

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: the three acceptance flows above on a device, watching `adb logcat` (or `flutter run` console) and the Firestore console.

---### Step 4 — dash-1: AVG becomes energy-based Leq

**Goal:** The AVG stat reports the equivalent continuous sound level Leq = 10·log10(mean(10^(dB/10))) instead of an arithmetic mean of decibels.

**Files:**
- `lib/utils/noise_stats.dart` (new)
- `lib/screens/dashboard_screen.dart`
- `test/unit/noise_stats_test.dart` (new)

**Commit title:** `fix(dashboard): compute AVG as energy-based Leq instead of arithmetic dB mean`

**Exact changes:**

4a. New file `lib/utils/noise_stats.dart` — full contents:

```dart
import 'dart:math' as math;

/// Acoustic statistics helpers.
///
/// Decibels are logarithmic, so averaging them arithmetically understates
/// the true equivalent continuous sound level. The correct average (Leq)
/// converts each dB value back to relative energy, averages the energies,
/// and converts back to dB:
///
///   Leq = 10 * log10( mean( 10^(dB/10) ) )
class NoiseStats {
  NoiseStats._();

  /// Energy-based average (Leq) of a list of dB values.
  ///
  /// Returns 0.0 for an empty list.
  static double energyMeanDb(List<double> dbValues) {
    if (dbValues.isEmpty) return 0.0;
    double energySum = 0.0;
    for (final db in dbValues) {
      energySum += math.pow(10, db / 10).toDouble();
    }
    final meanEnergy = energySum / dbValues.length;
    return 10 * (math.log(meanEnergy) / math.ln10);
  }
}
```

4b. `lib/screens/dashboard_screen.dart` — add the import (current line 14 area).

BEFORE:
```dart
import '../utils/theme_helper.dart';
import '../utils/shared_app_state.dart';
```

AFTER:
```dart
import '../utils/theme_helper.dart';
import '../utils/shared_app_state.dart';
import '../utils/noise_stats.dart';
```

4c. Replace the average computation in the noise listener (original lines 422-425).

BEFORE:
```dart
              // Calculate average from history
              if (_dbHistory.isNotEmpty) {
                _avgDb = _dbHistory.reduce((a, b) => a + b) / _dbHistory.length;
              }
```

AFTER:
```dart
              // dash-1: energy-based average (Leq), not arithmetic dB mean
              if (_dbHistory.isNotEmpty) {
                _avgDb = NoiseStats.energyMeanDb(_dbHistory);
              }
```

4d. New file `test/unit/noise_stats_test.dart` — full contents:

```dart
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

    test('Leq of 50 and 60 dB is ~57.54 dB, above the arithmetic mean 55', () {
      // 10 * log10((10^5 + 10^6) / 2) = 57.5395...
      final leq = NoiseStats.energyMeanDb([50.0, 60.0]);
      expect(leq, closeTo(57.5395, 0.001));
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
```

**Edge cases to preserve:**
- `_avgDb` starts at 0.0 and `_dbHistory` is capped at 100 entries — unchanged.
- Do NOT edit `test/unit/decibel_calculation_test.dart` — its `_calculateAverage` is a self-contained test helper, not app code.
- MIN/MAX logic is untouched.

**Acceptance criteria:**
- AVG shown on the dashboard is ≥ the old arithmetic mean whenever readings vary, and equals a constant input exactly.
- New unit test passes.

**Verify:**
```
flutter analyze
flutter test test/unit/noise_stats_test.dart
flutter test test/unit/
```
Manual: record in a quiet room, clap loudly a few times — AVG should jump noticeably toward MAX (energy dominance), unlike the old sluggish arithmetic mean.

---

### Step 5 — flow6-04 / settings-4: honor the `high_noise_alerts` toggle and `db_threshold` slider

**Goal:** The high-noise alert fires only when the user's `high_noise_alerts` pref is on, at the user's `db_threshold` (50-100 dB) instead of a hardcoded 70.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Commit title:** `fix(dashboard): honor high-noise alert toggle and threshold from settings`

**Exact changes:**

5a. Add the import (current line 7 area).

BEFORE:
```dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
```

AFTER:
```dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

5b. Add fields (immediately after the `_hasShownHighNoiseAlert` field, original lines 72-73).

BEFORE:
```dart
  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;
```

AFTER:
```dart
  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;

  // flow6-04/settings-4: alert prefs written by SettingsScreenEnhanced
  // (keys 'high_noise_alerts' and 'db_threshold', defaults true / 70.0 -
  // must match settings_screen_enhanced.dart lines 49 and 57).
  bool _highNoiseAlertsEnabled = true;
  double _alertThresholdDb = 70.0;
```

5c. Add the loader and call it from `initState`. In the Step 3 version of `initState`:

BEFORE:
```dart
    _initializeAudioRecorder();
    _requestPermissions();
```

AFTER:
```dart
    _initializeAudioRecorder();
    _requestPermissions();
    _loadAlertPrefs();
```

Then insert the method directly after `_requestPermissions` (original lines 150-158 end with the closing `}` of `_requestPermissions`):

BEFORE:
```dart
    } else {
      _showPermissionDeniedDialog();
    }
  }

  // Get current GPS location with retry mechanism and debouncing
```

AFTER:
```dart
    } else {
      _showPermissionDeniedDialog();
    }
  }

  // flow6-04/settings-4: load alert prefs written by SettingsScreenEnhanced
  Future<void> _loadAlertPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _highNoiseAlertsEnabled = prefs.getBool('high_noise_alerts') ?? true;
      _alertThresholdDb = prefs.getDouble('db_threshold') ?? 70.0;
      AppLogger.debug(
        'Alert prefs loaded: enabled=$_highNoiseAlertsEnabled, '
        'threshold=${_alertThresholdDb.toStringAsFixed(0)} dB',
      );
    } catch (e) {
      AppLogger.error('Failed to load alert preferences', e);
    }
  }

  // Get current GPS location with retry mechanism and debouncing
```

5d. Re-load at the start of every session so settings changes apply without an app restart. In `_startRecording`'s `try` block (Step 3 version):

BEFORE:
```dart
    try {
      // Defensively cancel anything a previous session may have leaked
      await _noiseSubscription?.cancel();
```

AFTER:
```dart
    try {
      // flow6-04: pick up any threshold/toggle change made in Settings
      await _loadAlertPrefs();

      // Defensively cancel anything a previous session may have leaked
      await _noiseSubscription?.cancel();
```

5e. Use the prefs in the noise listener (original lines 427-437).

BEFORE:
```dart
              // Check for high noise and show notification
              if (_currentDb > 70 && !_hasShownHighNoiseAlert) {
                NotificationService.showHighNoiseAlert(_currentDb);
                _hasShownHighNoiseAlert =
                    true; // Only alert once per recording session
              }

              // Reset alert flag if noise drops below threshold
              if (_currentDb < 65) {
                _hasShownHighNoiseAlert = false;
              }
```

AFTER:
```dart
              // flow6-04/settings-4: threshold + toggle come from user
              // settings, not hardcoded values
              if (_highNoiseAlertsEnabled &&
                  _currentDb > _alertThresholdDb &&
                  !_hasShownHighNoiseAlert) {
                NotificationService.showHighNoiseAlert(_currentDb);
                _hasShownHighNoiseAlert =
                    true; // Only alert once per recording session
              }

              // Reset alert flag once noise drops 5 dB below the threshold
              if (_currentDb < _alertThresholdDb - 5) {
                _hasShownHighNoiseAlert = false;
              }
```

**Edge cases to preserve:**
- Defaults (`true` / `70.0`) exactly mirror the settings screen's read defaults, so behavior is identical for users who never touched Settings.
- The 5 dB hysteresis replaces the old fixed 70/65 pair and scales with the threshold.
- `NotificationService.showHighNoiseAlert` already independently gates on `notifications_enabled` — keep both gates; do not modify `notification_service.dart`.
- Prefs are re-read per recording session (and once at init); a threshold changed MID-session applies from the next session — acceptable, matches settings-4 scope.

**Acceptance criteria:**
- Toggle "High Noise Alerts" OFF in Settings → no alert notification fires even at 90+ dB.
- Set threshold to 90 dB → normal speech (~65-75 dB) never triggers; a shout that crosses 90 does.
- Default install behavior unchanged (alert above 70 dB).

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: the three acceptance flows above (change setting → return to Dashboard → start a NEW recording session each time).

---

### Step 6 — perf-2: per-reading updates via ValueNotifier; only gauge/stats/chart rebuild

**Goal:** Remove the per-`NoiseReading` `setState` so each reading rebuilds only the gauge, the MIN/AVG/MAX row, and the history chart — not the whole dashboard tree.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Commit title:** `perf(dashboard): rebuild only gauge/stats/chart per noise reading`

**Exact changes:**

6a. Add notifier fields (directly after the `_dbHistory` field, original lines 53-58).

BEFORE:
```dart
  // Decibel values
  double _currentDb = 0.0;
  double _maxDb = 0.0;
  double _minDb = double.infinity;
  double _avgDb = 0.0;
  final List<double> _dbHistory = [];
```

AFTER:
```dart
  // Decibel values
  double _currentDb = 0.0;
  double _maxDb = 0.0;
  double _minDb = double.infinity;
  double _avgDb = 0.0;
  final List<double> _dbHistory = [];

  // perf-2: live meter values are published through notifiers instead of
  // setState, so only the gauge / stats row / chart subtrees rebuild on the
  // several-per-second NoiseReading events - not the whole dashboard.
  final ValueNotifier<double> _currentDbNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _historyVersion = ValueNotifier<int>(0);
```

6b. Rewrite the noise listener callback WITHOUT `setState`. After Steps 1-5 the listener (inside `_startRecording`) reads exactly as the BEFORE block below; replace the whole callback body.

BEFORE:
```dart
      _noiseSubscription = _noiseMeter?.noise.listen(
        (NoiseReading reading) {
          if (!_isRecording || !mounted) return;
          // dash-6: record stream liveness for the save timer's stall check
          _lastNoiseReadingAt = DateTime.now();
          
          setState(() {
            // Apply calibration offset for phone microphone
            // Phone mics read 10-20 dB higher than actual SPL
            // This offset adjusts readings to realistic environmental values:
            // - Quiet room: 30-40 dB (was showing 10-20 dB)
            // - Normal conversation: 60-70 dB (was showing 30-50 dB)
            // - Loud speech: 80-90 dB (was showing 50-60 dB)
            // - Traffic: 70-85 dB
            const double calibrationOffset = 10.0;
            final rawDb = reading.meanDecibel - calibrationOffset;
            
            // Validate dB range (filter unrealistic values)
            // Environmental sounds typically range from 20-120 dB
            if (rawDb < 10 || rawDb > 130) {
              AppLogger.debug('Filtered unrealistic dB reading: ${rawDb.toStringAsFixed(1)} dB');
              return; // Don't add invalid readings
            }
            
            _currentDb = rawDb.clamp(0.0, 120.0); // Clamp to valid range

            // Add to history (only valid values)
            if (_currentDb.isFinite && _currentDb > 0) {
              _dbHistory.add(_currentDb);
              if (_dbHistory.length > 100) {
                _dbHistory.removeAt(0); // Keep last 100 readings
              }

              // Update min, max, and average
              if (_currentDb > _maxDb) _maxDb = _currentDb;

              // Set minDb to first reading if still infinity
              if (_minDb == double.infinity) {
                _minDb = _currentDb;
              } else if (_currentDb < _minDb) {
                _minDb = _currentDb;
              }

              // dash-1: energy-based average (Leq), not arithmetic dB mean
              if (_dbHistory.isNotEmpty) {
                _avgDb = NoiseStats.energyMeanDb(_dbHistory);
              }

              // flow6-04/settings-4: threshold + toggle come from user
              // settings, not hardcoded values
              if (_highNoiseAlertsEnabled &&
                  _currentDb > _alertThresholdDb &&
                  !_hasShownHighNoiseAlert) {
                NotificationService.showHighNoiseAlert(_currentDb);
                _hasShownHighNoiseAlert =
                    true; // Only alert once per recording session
              }

              // Reset alert flag once noise drops 5 dB below the threshold
              if (_currentDb < _alertThresholdDb - 5) {
                _hasShownHighNoiseAlert = false;
              }
            }
          });
        },
```

AFTER:
```dart
      _noiseSubscription = _noiseMeter?.noise.listen(
        (NoiseReading reading) {
          if (!_isRecording || !mounted) return;
          // dash-6: record stream liveness for the save timer's stall check
          _lastNoiseReadingAt = DateTime.now();

          // perf-2: no setState here. Values are published through
          // _currentDbNotifier / _historyVersion so only the gauge, stats
          // row, and chart subtrees rebuild per reading.

          // Apply calibration offset for phone microphone
          // Phone mics read 10-20 dB higher than actual SPL
          // This offset adjusts readings to realistic environmental values:
          // - Quiet room: 30-40 dB (was showing 10-20 dB)
          // - Normal conversation: 60-70 dB (was showing 30-50 dB)
          // - Loud speech: 80-90 dB (was showing 50-60 dB)
          // - Traffic: 70-85 dB
          const double calibrationOffset = 10.0;
          final rawDb = reading.meanDecibel - calibrationOffset;

          // Validate dB range (filter unrealistic values)
          // Environmental sounds typically range from 20-120 dB
          if (rawDb < 10 || rawDb > 130) {
            AppLogger.debug('Filtered unrealistic dB reading: ${rawDb.toStringAsFixed(1)} dB');
            return; // Don't add invalid readings
          }

          _currentDb = rawDb.clamp(0.0, 120.0); // Clamp to valid range
          _currentDbNotifier.value = _currentDb;

          // Add to history (only valid values)
          if (_currentDb.isFinite && _currentDb > 0) {
            _dbHistory.add(_currentDb);
            if (_dbHistory.length > 100) {
              _dbHistory.removeAt(0); // Keep last 100 readings
            }

            // Update min, max, and average
            if (_currentDb > _maxDb) _maxDb = _currentDb;

            // Set minDb to first reading if still infinity
            if (_minDb == double.infinity) {
              _minDb = _currentDb;
            } else if (_currentDb < _minDb) {
              _minDb = _currentDb;
            }

            // dash-1: energy-based average (Leq), not arithmetic dB mean
            if (_dbHistory.isNotEmpty) {
              _avgDb = NoiseStats.energyMeanDb(_dbHistory);
            }

            // perf-2: bump version so stats row + history chart rebuild
            _historyVersion.value = _historyVersion.value + 1;

            // flow6-04/settings-4: threshold + toggle come from user
            // settings, not hardcoded values
            if (_highNoiseAlertsEnabled &&
                _currentDb > _alertThresholdDb &&
                !_hasShownHighNoiseAlert) {
              NotificationService.showHighNoiseAlert(_currentDb);
              _hasShownHighNoiseAlert =
                  true; // Only alert once per recording session
            }

            // Reset alert flag once noise drops 5 dB below the threshold
            if (_currentDb < _alertThresholdDb - 5) {
              _hasShownHighNoiseAlert = false;
            }
          }
        },
```

(The `onError:` / `onDone:` / `cancelOnError:` arguments that follow are unchanged.)

6c. Wrap the three consumers in `build`.

Stats row — BEFORE (original lines 734-742):
```dart
              // Min, Avg, Max values row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('MIN', _minDb, Icons.arrow_downward),
                  _buildStatCard('AVG', _avgDb, Icons.show_chart),
                  _buildStatCard('MAX', _maxDb, Icons.arrow_upward),
                ],
              ),
```

AFTER:
```dart
              // Min, Avg, Max values row (perf-2: rebuilds per reading via
              // _historyVersion, not via whole-screen setState)
              ValueListenableBuilder<int>(
                valueListenable: _historyVersion,
                builder: (context, _, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('MIN', _minDb, Icons.arrow_downward),
                    _buildStatCard('AVG', _avgDb, Icons.show_chart),
                    _buildStatCard('MAX', _maxDb, Icons.arrow_upward),
                  ],
                ),
              ),
```

Gauge — BEFORE (original lines 746-747):
```dart
              // Main Decibel Meter (Circular Gauge)
              DecibelMeterGauge(currentDb: _currentDb, maxDb: 100),
```

AFTER:
```dart
              // Main Decibel Meter (Circular Gauge) - perf-2: only this
              // subtree rebuilds on live dB changes
              ValueListenableBuilder<double>(
                valueListenable: _currentDbNotifier,
                builder: (context, db, _) =>
                    DecibelMeterGauge(currentDb: db, maxDb: 100),
              ),
```

Chart — BEFORE (original lines 884-885):
```dart
              // Real-time noise history graph
              NoiseHistoryChart(dbHistory: _dbHistory),
```

AFTER:
```dart
              // Real-time noise history graph (perf-2: rebuilds per reading
              // via _historyVersion)
              ValueListenableBuilder<int>(
                valueListenable: _historyVersion,
                builder: (context, _, __) =>
                    NoiseHistoryChart(dbHistory: _dbHistory),
              ),
```

6d. Dispose the notifiers. In `dispose` (Step 3 version):

BEFORE:
```dart
    _stopRecording();
    _audioRecorder?.closeRecorder();
    // Don't reset locationDialogShown - it's static and shared across app lifetime
    super.dispose();
```

AFTER:
```dart
    _stopRecording();
    _audioRecorder?.closeRecorder();
    _currentDbNotifier.dispose();
    _historyVersion.dispose();
    // Don't reset locationDialogShown - it's static and shared across app lifetime
    super.dispose();
```

**Edge cases to preserve:**
- `_currentDb` (plain field) is still what the save timer and alert logic read — keep field and notifier in sync exactly as shown (field first, then notifier).
- The classification card, "Recording..." status text, and button color depend on `_isRecording` / `_currentClassification`, which are still updated via the remaining `setState` calls in `_startRecording`, `_stopRecording`, and `_performSoundClassification` — those `setState`s stay.
- After stop, the gauge keeps showing the last value (current behavior) — do not reset the notifier in `_stopRecording`.
- `_minDb` starts at `double.infinity` and renders as it does today before the first reading — do not "fix" the display here.
- Builder parameters named `_` / `__` are exempt from `no_leading_underscores_for_local_identifiers`.
- The early `return` for filtered readings now exits the listener callback (previously exited the setState closure) — identical net effect.

**Acceptance criteria:**
- While recording, gauge/stats/chart update live at the same visual rate as before.
- Flutter DevTools "Track widget rebuilds": `DashboardScreen.build` does NOT re-run per reading; only the three `ValueListenableBuilder` subtrees do.
- Start/stop, classification card appearance, and alerts all behave exactly as after Step 5.

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: `flutter run --profile`, open DevTools performance overlay, record for 30 s — jank from whole-tree rebuilds should be gone; confirm via the widget-rebuild tracker that only gauge/stats/chart rebuild per reading.

---

### Step 7 — a11y-2: label the record/stop control and announce recording state

**Goal:** The primary record/stop control exposes a button role with a state-dependent label, and recording state changes are announced to assistive tech via a live region.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Commit title:** `fix(a11y): label record button and announce recording state changes`

**Exact changes:**

7a. Replace the record button + status text block in `build` (original lines 832-880; after Step 6 this block is unchanged, only surrounding regions moved).

BEFORE:
```dart
              // Recording button - round and beautiful
              Column(
                children: [
                  // Round record button
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isRecording
                              ? [Colors.red, Colors.red.shade700]
                              : [ThemeHelper.getPrimaryColor(context), ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isRecording
                                        ? Colors.red
                                        : ThemeHelper.getPrimaryColor(context))
                                    .withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status text below button
                  Text(
                    _isRecording ? 'Recording...' : 'Tap to measure',
                    style: TextStyle(
                      color: _isRecording ? Colors.red : AppTheme.textGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
```

AFTER:
```dart
              // Recording button - round and beautiful
              Column(
                children: [
                  // Round record button (a11y-2: expose button role + label)
                  Semantics(
                    button: true,
                    enabled: true,
                    label: _isRecording
                        ? 'Stop noise measurement'
                        : 'Start noise measurement',
                    child: GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [Colors.red, Colors.red.shade700]
                                : [ThemeHelper.getPrimaryColor(context), ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isRecording
                                          ? Colors.red
                                          : ThemeHelper.getPrimaryColor(context))
                                      .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status text below button (a11y-2: live region announces
                  // recording state changes to assistive tech)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _isRecording ? 'Recording...' : 'Tap to measure',
                      style: TextStyle(
                        color: _isRecording ? Colors.red : AppTheme.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
```

**Edge cases to preserve:**
- Do NOT change any colors in this block — the `Colors.red` / `AppTheme.textGray` usages are finding dash-19 (out of scope for this cluster).
- The `Semantics` widget is exported by `package:flutter/material.dart` — no new import.
- The status `Text` remains visually identical; the live region only affects the semantics tree. State changes flow through the existing `setState`s in start/stop, which rebuild this subtree and re-fire the live region.
- The inner `Icon` has no `semanticLabel`, so it contributes nothing that would double-speak with the outer label.

**Acceptance criteria:**
- TalkBack (Android) focuses the round button and reads "Start noise measurement, button" when idle and "Stop noise measurement, button" while recording.
- On tap, TalkBack announces "Recording..." (and "Tap to measure" after stop) without moving focus.
- Visual appearance is pixel-identical.

**Verify:**
```
flutter analyze
flutter test test/unit/
```
Manual: enable TalkBack, swipe to the record control, confirm role+label, double-tap to start, confirm the live-region announcement; stop and confirm again. Optionally inspect with Flutter DevTools' semantics view.

---

## Risks & rollback

Each step is one self-contained commit; `git revert <sha>` of any single step restores prior behavior without breaking the others (later steps' BEFORE anchors depend on earlier steps' AFTER text, so revert from the tail backwards if reverting multiple).

- **Behavioral change (dash-6):** stopping on tab switch / background is intentional but user-visible; anyone relying on "background recording" loses it. Mitigation: log lines make the stop reason explicit; revert Step 3 alone to restore old behavior.
- **Data volume drop (dash-4):** devices that never get a GPS fix now save nothing. This is the intended fix (those rows were garbage at Colombo city center), but Analytics/Map totals may dip. Revert Step 2 alone if product disagrees.
- **perf-2 refactor is the highest-risk edit** (largest diff, listener rewritten). Failure modes to watch: gauge frozen (notifier not wired), stats not updating (version not bumped), or classification card missing (a `setState` accidentally removed — only the per-reading one must go). All are caught by the manual 30 s recording check. Revert Step 6 alone restores setState-per-reading.
- **Threshold semantics (flow6-04):** hysteresis is now `threshold - 5` instead of fixed 65; users with threshold 50 get re-alerts below 45. Deemed correct; revert Step 5 alone if disputed.
- **AVG values change (dash-1):** historical expectations of the AVG tile shift upward for varying noise. This is a correctness fix; saved Firestore data is unaffected (per-reading `decibelLevel` was never the average).
- No Firestore schema, query, index, or security-rule changes anywhere in this spec — zero server-side rollback surface.

## Out of scope

- dash-10 (stop not immediate through async teardown), dash-11 (in-flight classification resurrection after stop), dash-13 (gauge tops out at 100 vs 120 clamp), dash-14 (chart maxY 100 vs 120 data), dash-16 (dispose races closeRecorder), dash-17 (no save feedback UI), dash-18 (gauge shouldRepaint), dash-19/dash-20 (hardcoded colors in dashboard/gauge — ThemeHelper convention cleanup), dash-22 (curved-line overshoot), a11y-26 (location pill / community card semantics), perf classification-on-UI-thread stutter.
- The `_buildCommunityFeedCard` Firestore query (uses `isGreaterThanOrEqualTo` on `timestamp` only — single-field, not the composite index; any change to it belongs to the dashboard-query cluster, not here).
- `firebase_service.dart`, `notification_service.dart`, `settings_screen_enhanced.dart`, `decibel_meter_gauge.dart`, `noise_history_chart.dart` internals — read-only for this spec.
- Continuing recording in the background as a foreground service (the "correct" long-term answer to dash-6) — product decision, separate cluster.
