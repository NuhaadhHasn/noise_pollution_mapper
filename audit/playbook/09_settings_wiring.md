# Implementation Spec — Defect Cluster 09: Settings — Wire or Remove Dead Controls

Target app: `noise_pollution_mapper/` (Flutter + Firebase + TFLite YAMNet).
Execute steps strictly in order. **Each step is exactly one commit.** `flutter analyze` must be clean after every commit (project convention 7). Use `AppLogger` for all logging, never `print` (convention 6). All UI colors via `ThemeHelper.getX(context)` and `withValues(alpha:)`, never `withOpacity` (convention 2).

All BEFORE blocks were copied verbatim from the working tree on 2026-07-18. If a BEFORE block does not match, STOP, re-read the file, and apply the per-step **"If playbook 05 already applied"** adaptation notes — do not guess and do not revert other clusters' changes.

**Firestore note (convention 1):** NOTHING in this spec touches any Firestore query or index. Only SharedPreferences, local timers, local notifications, and UI are changed. The only composite index remains `noise_readings (userId ASC, timestamp DESC)`. No `firestore.indexes.json` change is needed.

**Package API verification (against `pubspec.yaml` as of 2026-07-18):**
- `shared_preferences: ^2.3.3` — `getInstance()`, `getBool`, `getInt`, `setBool`, `setInt`, `remove(String)` all exist (already used in `settings_screen_enhanced.dart:42-68`).
- `flutter_local_notifications: ^18.0.1` — `zonedSchedule(int id, String? title, String? body, tz.TZDateTime scheduledDate, NotificationDetails details, {required AndroidScheduleMode androidScheduleMode, String? payload, DateTimeComponents? matchDateTimeComponents})` and `cancel(int id)` exist in v18. v18 REMOVED the old `uiLocalNotificationDateInterpretation` parameter — do not pass it. If the analyzer complains it is *required*, `flutter pub deps | grep flutter_local_notifications` resolved a 17.x version; run `flutter pub upgrade flutter_local_notifications` to get 18.x. `AndroidScheduleMode.inexactAllowWhileIdle` exists in v18.
- NEW packages added in Step 5: `timezone: ^0.10.0` (exact major that flutter_local_notifications 18.x itself depends on — no conflict) and `flutter_timezone: ^3.0.1` whose API is `Future<String> FlutterTimezone.getLocalTimezone()`. Do NOT use flutter_timezone 4.x (breaking change: returns `TimezoneInfo`, not `String`).
- `noise_meter: ^5.0.2` — exposes ONLY `NoiseReading.meanDecibel` / `maxDecibel`. There is no API for A/C frequency weighting or fast/slow time constants. This is the hardware-honesty basis for Step 1.
- Android: `android/app/build.gradle.kts` already has `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.0.4` — no Gradle change needed for scheduled notifications.
- Dart SDK `^3.10.3` — note `int.clamp(int, int)` statically returns `num`; every clamp below is followed by `.toInt()` intentionally. Do not drop it.

**Test suite warning:** the repo has ~53 pre-existing test failures (audit arch-2). Run ONLY the test files named in each step's Verify section, never bare `flutter test`.

---

## Scope

| ID | Status | One-liner |
|---|---|---|
| settings-6 / uiux-1 (part) | CONFIRMED | dBA/dBC ('use_dba') and Response Time ('use_fast_response') toggles are hardware-impossible no-ops → **REMOVE** (Step 1) |
| arch-1 (part) | PARTIAL | 'share_data_with_researchers' pref has zero backend consumers → **REMOVE** (Step 2) |
| settings-6 / uiux-1 (part) | CONFIRMED | 'save_frequency' pref never read; dashboard save timer hardcodes 5 s (`dashboard_screen.dart:487`) → **WIRE** into the save timer (Step 3) |
| settings-6 / uiux-1 (part) | CONFIRMED | 'recording_duration' pref never read; recording runs until manually stopped → **WIRE** as minutes-based auto-stop (Step 4) |
| settings-5 | CONFIRMED | 'daily_reminders' pref never read; `showDailyReminder()` has zero call sites and uses immediate `show()` → **IMPLEMENT** real daily `zonedSchedule` (Step 5) |

Full finding text + adversarial verifier evidence: grep these IDs in `audit/00_MASTER_AUDIT_REPORT.md`, `audit/01_BUGS_AND_CORRECTNESS.md`, `audit/02_UI_UX_AUDIT.md`, `audit/06_ARCHITECTURE_AND_CODE_QUALITY.md`.

**Explicitly handled by other clusters — do NOT touch here:**
- `db_threshold` + `high_noise_alerts` (settings-4 / flow6-04): wired into the dashboard alert path by **playbook 05, Step 5** (`audit/playbook/05_recording_pipeline.md`). These two prefs keys and their Settings controls stay exactly as they are.
- `anonymize_location` (settings-3 / sec-2 / flow6-03): wired into the upload path by **playbook 04, Step 2** (`audit/playbook/04_data_layer_privacy.md`). The toggle stays exactly as it is.
- `dark_mode`, `notifications_enabled`, `theme_color`: already live; unchanged (except `notifications_enabled` gains daily-reminder teardown in Step 5, which strengthens it, not changes its meaning).

**Design decisions (justifications):**
1. **dBA/dBC + Response Time → REMOVE.** `noise_meter` 5.0.2 provides only `meanDecibel` from the platform mic pipeline; there is no API for A-vs-C weighting or fast/slow (125 ms/1000 ms) integration, and phone microphones cannot deliver IEC 61672 weighting anyway. Keeping the toggles means the app claims to show dBC when it never does. Removal + one honest caption is the only truthful option.
2. **Save Frequency → WIRE.** Trivial, genuinely useful (fewer Firestore writes on data plans), and the slider (5–30 s) maps 1:1 onto the existing `Timer.periodic` interval.
3. **Recording Duration → WIRE as auto-stop, re-unit to MINUTES.** A 1–60 *second* auto-stop (the current slider unit) would cripple the core monitoring UX, so the slider becomes 1–60 **minutes** (default 10) under a NEW key `recording_duration_minutes`; the old seconds-based `recording_duration` key is deleted so a stored "10" is never silently reinterpreted. Auto-stop is a real feature: it caps open-ended microphone capture (battery + privacy), complementing playbook 05's stop-on-background fix (dash-6).
4. **Daily Reminders → IMPLEMENT (not remove).** This is a community-data app: daily contributions are the product. The notification channel, copy, and permission request already exist; the only missing piece is scheduling. Chosen: `zonedSchedule` at 19:00 local with `matchDateTimeComponents: DateTimeComponents.time` (fires at a consistent local time; `periodicallyShow` would drift to "24 h after whenever the user toggled"). `AndroidScheduleMode.inexactAllowWhileIdle` avoids the Android 12+ `SCHEDULE_EXACT_ALARM` special permission — minute-level precision is irrelevant for a reminder.
5. **Share Data with Researchers → REMOVE.** No researcher-export pipeline, no backend consumer, and every reading already lands in the shared community `noise_readings` collection regardless of the toggle — so the toggle is a false promise in *both* positions. The real privacy control is `anonymize_location` (playbook 04). Storing the flag on the users doc would just create a second dead flag with Firestore-write cost and no reader.

---

## Pre-reading (open these first, in full)

1. `lib/screens/settings_screen_enhanced.dart` — the whole file (1107 lines); Steps 1, 2, 4, 5 edit it.
2. `lib/screens/dashboard_screen.dart` lines 1–110 (fields/imports), 360–518 (`_startRecording`), 543–585 (`_stopRecording`), 658–667 (`dispose`).
3. `lib/services/notification_service.dart` — whole file (111 lines).
4. `lib/main.dart` lines 1–72 (`main()`; NotificationService init at 46–48; `prefs` variable already exists at line 55 — Step 5 must not shadow it).
5. `pubspec.yaml` lines 30–50 (dependencies; Notifications block at ~46–47).
6. `android/app/src/main/AndroidManifest.xml` — whole file (53 lines).
7. `test/widget/settings_screen_test.dart` — whole file (rewritten in Step 2).
8. `audit/playbook/05_recording_pipeline.md` Steps 2 and 5 — they edit the same `_startRecording` region as Steps 3–4 below; read them so the adaptation notes make sense.
9. `lib/utils/app_logger.dart` — `AppLogger.debug/info/warning/error` static methods.

---

## Step 1 — Remove hardware-impossible dBA/dBC and Response Time controls (settings-6, uiux-1 part)

**Goal:** The Decibel Scale and Response Time toggles disappear from Settings, their prefs keys are deleted from storage, and an honest caption explains the hardware limitation.

**Files:** `lib/screens/settings_screen_enhanced.dart`

**Exact changes:**

1a. Delete the two dead state fields (top of `_SettingsScreenEnhancedState`).

BEFORE (lines 23–27):
```dart
  // Settings values
  bool _useDbA = true;
  bool _useFastResponse = true;
  bool _notificationsEnabled = true;
  bool _darkMode = true;
```
AFTER:
```dart
  // Settings values
  bool _notificationsEnabled = true;
  bool _darkMode = true;
```

1b. Delete the dead pref loads and add key cleanup in `_loadSettings`.

BEFORE (lines 42–48):
```dart
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _useDbA = prefs.getBool('use_dba') ?? true;
        _useFastResponse = prefs.getBool('use_fast_response') ?? true;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
```
AFTER:
```dart
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Cleanup of legacy keys whose controls were removed (settings-6):
    // phone hardware (noise_meter) exposes no A/C weighting or fast/slow
    // response time, so these settings could never do anything.
    await prefs.remove('use_dba');
    await prefs.remove('use_fast_response');
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
```

1c. Remove the two toggle rows from the Appearance card.

BEFORE (lines 89–104):
```dart
          _buildSettingCard([
            _buildToggleSetting('Decibel Scale', 'dBA', 'dBC', _useDbA, (val) {
              setState(() => _useDbA = val);
              _saveSetting('use_dba', val);
            }),
            _buildToggleSetting(
              'Response Time',
              'Fast',
              'Slow',
              _useFastResponse,
              (val) {
                setState(() => _useFastResponse = val);
                _saveSetting('use_fast_response', val);
              },
            ),
            _buildSwitchSetting('Dark Mode', Icons.dark_mode, _darkMode, (val) {
```
AFTER:
```dart
          _buildSettingCard([
            _buildSwitchSetting('Dark Mode', Icons.dark_mode, _darkMode, (val) {
```

1d. Add the honest caption at the top of the Measurement section.

BEFORE (lines 128–133):
```dart
          // MEASUREMENT SECTION
          _buildSectionHeader('Measurement', Icons.mic),
          _buildSettingCard([
            _buildSliderSetting(
              'Recording Duration',
              _recordingDuration.toDouble(),
```
AFTER:
```dart
          // MEASUREMENT SECTION
          _buildSectionHeader('Measurement', Icons.mic),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Readings use your phone microphone\'s built-in response. '
              'Professional A/C frequency weighting and fast/slow response '
              'modes are not supported by phone hardware.',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(
                  context,
                ).withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          _buildSettingCard([
            _buildSliderSetting(
              'Recording Duration',
              _recordingDuration.toDouble(),
```

1e. Delete the now-unreferenced helper widgets `_buildToggleSetting` and `_buildToggleButton` (they only called each other; leaving them trips `unused_element` in `flutter analyze`).

BEFORE (lines 370–435, the entire block between the `_buildSettingCard` helper and the `// Switch setting` comment):
```dart
  // Toggle setting (dBA/dBC style)
  Widget _buildToggleSetting(
    String title,
    String left,
    String right,
    bool isLeft,
    Function(bool) onChanged,
  ) {
    final isDark = ThemeHelper.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: ThemeHelper.getTextColor(context)),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkPurple
                  : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildToggleButton(left, isLeft, () => onChanged(true)),
                _buildToggleButton(right, !isLeft, () => onChanged(false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    final isDark = ThemeHelper.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeHelper.getPrimaryColor(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : isDark
                ? AppTheme.textGray
                : ThemeHelper.getTextColor(context).withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Switch setting
```
AFTER:
```dart
  // Switch setting
```

Do NOT remove the `import '../theme/app_theme.dart';` line — `AppTheme` is still used by `_buildSliderSetting` (`AppTheme.darkPurple`) and the dialogs (`AppTheme.cardBackground`, `AppTheme.textWhite`, etc.).

**Edge cases to preserve:**
- `_loadSettings` still guards `if (mounted)` before `setState`; the two `prefs.remove` awaits run before the guard, which is safe (they don't touch state).
- Users who previously stored `use_dba=false` lose nothing — the value never did anything.
- The Appearance card still contains Dark Mode + Theme Colors; Dark Mode's snackbar and `themeNotifier` behavior unchanged.

**Acceptance criteria:**
- Settings screen shows NO "Decibel Scale" and NO "Response Time" row.
- The Measurement section shows the hardware-honesty caption above the sliders.
- After opening Settings once, `use_dba` and `use_fast_response` keys no longer exist in SharedPreferences.

**Verify:**
```
flutter analyze
```
(must be clean — in particular no `unused_element`, no `unused_field`). Manual: launch app → Settings tab (MainAppShell tab index 4) → confirm both toggles gone and caption visible in both light and dark mode.

**Commit title:** `fix(settings): remove hardware-unsupported dBA/dBC and Response Time controls (settings-6, uiux-1)`

---

## Step 2 — Remove the no-op "Share Data with Researchers" toggle + rewrite settings widget test (arch-1 part)

**Goal:** The researcher-sharing toggle disappears from UI and prefs, and the settings widget test is rewritten to lock in the removals from Steps 1–2.

**Files:** `lib/screens/settings_screen_enhanced.dart`, `test/widget/settings_screen_test.dart`

**Exact changes:**

2a. Delete the state field.

BEFORE (lines around 30–32, post-Step-1):
```dart
  bool _dailyReminders = false;
  bool _shareDataWithResearchers = true;
  int _recordingDuration = 10; // seconds
```
AFTER:
```dart
  bool _dailyReminders = false;
  int _recordingDuration = 10; // seconds
```

2b. Delete the pref load.

BEFORE:
```dart
        _dailyReminders = prefs.getBool('daily_reminders') ?? false;
        _shareDataWithResearchers =
            prefs.getBool('share_data_with_researchers') ?? true;
        _darkMode = prefs.getBool('dark_mode') ?? true;
```
AFTER:
```dart
        _dailyReminders = prefs.getBool('daily_reminders') ?? false;
        _darkMode = prefs.getBool('dark_mode') ?? true;
```

2c. Add the key to the legacy cleanup block created in Step 1b.

BEFORE:
```dart
    await prefs.remove('use_dba');
    await prefs.remove('use_fast_response');
```
AFTER:
```dart
    await prefs.remove('use_dba');
    await prefs.remove('use_fast_response');
    // arch-1: 'share_data_with_researchers' had zero backend consumers;
    // all readings already flow to the shared community collection, and the
    // real privacy control is 'anonymize_location' (playbook 04).
    await prefs.remove('share_data_with_researchers');
```

2d. Remove the switch from the Privacy card.

BEFORE (lines 214–223 of the original file):
```dart
            _buildSwitchSetting(
              'Share Data with Researchers',
              Icons.science,
              _shareDataWithResearchers,
              (val) {
                setState(() => _shareDataWithResearchers = val);
                _saveSetting('share_data_with_researchers', val);
              },
            ),
            _buildNavigationItem('Privacy Policy', Icons.policy, () {}),
```
AFTER:
```dart
            _buildNavigationItem('Privacy Policy', Icons.policy, () {}),
```

2e. Replace `test/widget/settings_screen_test.dart` with the following FULL contents (the old file pumped the screen without a SharedPreferences mock and asserted nothing meaningful):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noise_pollution_mapper/screens/settings_screen_enhanced.dart';

// Widget tests for Settings Screen (defect cluster 09: dead controls removed,
// live controls present, legacy prefs keys cleaned up).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall surface so the lazily-built ListView mounts every row.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreenEnhanced()),
    );
    // Let _loadSettings (async prefs read + setState) complete.
    await tester.pumpAndSettle();
  }

  group('Settings Screen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders without crashing', (tester) async {
      await pumpSettings(tester);
      expect(find.byType(SettingsScreenEnhanced), findsOneWidget);
    });

    testWidgets('removed dead controls are gone', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Decibel Scale'), findsNothing);
      expect(find.text('Response Time'), findsNothing);
      expect(find.text('Share Data with Researchers'), findsNothing);
    });

    testWidgets('live controls are present', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Recording Duration'), findsOneWidget);
      expect(find.text('Save Frequency'), findsOneWidget);
      expect(find.text('Alert Threshold'), findsOneWidget);
      expect(find.text('Daily Reminders'), findsOneWidget);
      expect(find.text('Anonymize Location'), findsOneWidget);
    });

    testWidgets('legacy prefs keys are removed on load', (tester) async {
      SharedPreferences.setMockInitialValues({
        'use_dba': false,
        'use_fast_response': false,
        'share_data_with_researchers': true,
      });
      await pumpSettings(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_dba'), isNull);
      expect(prefs.getBool('use_fast_response'), isNull);
      expect(prefs.getBool('share_data_with_researchers'), isNull);
    });
  });
}
```

**Edge cases to preserve:**
- The Privacy card MUST keep 'Anonymize Location' (wired by playbook 04) and 'Privacy Policy'.
- Do not touch `firebase_service.dart` or any upload path — nothing ever read this flag, so removal is UI+prefs only.

**Acceptance criteria:**
- No "Share Data with Researchers" row anywhere; Privacy section = Anonymize Location + Privacy Policy.
- Key `share_data_with_researchers` is deleted from SharedPreferences after opening Settings.
- New widget test passes.

**Verify:**
```
flutter analyze
flutter test test/widget/settings_screen_test.dart
```
Manual: Settings → Privacy & Security card shows exactly two rows.

**Commit title:** `fix(settings): remove no-op Share Data with Researchers toggle (arch-1)`

---

## Step 3 — Wire `save_frequency` into the dashboard save timer (settings-6, uiux-1)

**Goal:** The periodic Firestore save interval during recording equals the user's Save Frequency setting (5–30 s, default 5) instead of a hardcoded 5 s.

**Files:** `lib/screens/dashboard_screen.dart`

**Exact changes:**

3a. Add the SharedPreferences import.

BEFORE (lines 23–24):
```dart
import 'community_feed_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
```
AFTER:
```dart
import 'community_feed_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

3b. Read the pref inside `_startRecording` (which is already `async`) and use it for the timer interval.

BEFORE (lines 486–487):
```dart
      // Start periodic Firebase saves (every 5 seconds)
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
```
AFTER:
```dart
      // Start periodic Firebase saves at the user's chosen interval
      // ('save_frequency' pref, 5-30 s, default 5 — settings-6).
      final prefs = await SharedPreferences.getInstance();
      final saveFrequencySeconds =
          (prefs.getInt('save_frequency') ?? 5).clamp(5, 30).toInt();
      AppLogger.debug('Save frequency: ${saveFrequencySeconds}s');
      _saveTimer = Timer.periodic(Duration(seconds: saveFrequencySeconds), (
        timer,
      ) {
```
(The body of the timer callback and its closing `});` are untouched. Keep the `.toInt()` — `int.clamp` statically returns `num` and `Duration(seconds:)` requires `int`.)

**If playbook 05 already applied:** its Step 1 sets `_isRecording = true` synchronously at the top of `_startRecording` and its Step 2d rewrites the `_saveTimer` block's *body* (gating). In that case the BEFORE above won't match verbatim. Apply the same semantic change: insert the three `prefs`/`saveFrequencySeconds`/`AppLogger` lines immediately above whatever the current `_saveTimer = Timer.periodic(const Duration(seconds: 5), ...)` creation is, and replace only `const Duration(seconds: 5)` with `Duration(seconds: saveFrequencySeconds)`. Do not modify the timer body. If playbook 05's Step 5 already created a prefs read in `_startRecording` (it loads `high_noise_alerts`/`db_threshold`), reuse that existing `prefs` instance instead of calling `getInstance()` twice. The extra `await` before timer creation is safe: all timer callbacks and the noise listener guard on `_isRecording`/`mounted`.

**Edge cases to preserve:**
- Interval is read once per recording session; changing the slider mid-recording applies on the next Start. (Intentional — matches how the classification timer works.)
- Clamp protects against a corrupted/out-of-range stored value.
- Timer-leak guard `if (!_isRecording || !mounted) return;` inside the callback stays exactly as is (note: the blank line after it carries trailing spaces — do not "clean" it).

**Acceptance criteria:**
- With Save Frequency = 30 s, a 65+ second recording produces readings ~30 s apart in History (MainAppShell tab 3) / Firestore, instead of ~5 s apart.
- Log line `Save frequency: 30s` appears on Start.
- Default behavior (slider untouched) is byte-identical to before: 5 s interval.

**Verify:**
```
flutter analyze
```
Manual: Settings → Save Frequency → 30 s. Dashboard (tab 2) → Start → record ≥ 65 s → Stop → History tab: consecutive new readings are ~30 s apart. Repeat with 5 s to confirm default.

**Commit title:** `feat(dashboard): honor save_frequency setting for periodic Firestore saves (settings-6)`

---

## Step 4 — Recording Duration becomes a minutes-based auto-stop (settings-6, uiux-1)

**Goal:** Recording automatically stops after the user's Recording Duration (1–60 minutes, default 10, new key `recording_duration_minutes`), with a snackbar telling the user why; the old seconds-based key is deleted.

**Files:** `lib/screens/settings_screen_enhanced.dart`, `lib/screens/dashboard_screen.dart`

**Exact changes — settings screen:**

4a. Re-unit the state field.

BEFORE (post-Step-2):
```dart
  int _recordingDuration = 10; // seconds
  int _saveFrequency = 5; // seconds
```
AFTER:
```dart
  int _recordingDurationMinutes = 10; // minutes (auto-stop)
  int _saveFrequency = 5; // seconds
```

4b. Load the new key; delete the old one in the legacy-cleanup block.

BEFORE:
```dart
        _recordingDuration = prefs.getInt('recording_duration') ?? 10;
```
AFTER:
```dart
        _recordingDurationMinutes =
            prefs.getInt('recording_duration_minutes') ?? 10;
```

BEFORE (cleanup block, post-Step-2c):
```dart
    await prefs.remove('share_data_with_researchers');
```
AFTER:
```dart
    await prefs.remove('share_data_with_researchers');
    // settings-6: old key stored SECONDS and was never consumed; replaced by
    // 'recording_duration_minutes' (auto-stop). Removed so a stored value is
    // never reinterpreted under the new unit.
    await prefs.remove('recording_duration');
```

4c. Re-unit the slider.

BEFORE (lines 131–141 of the original file):
```dart
            _buildSliderSetting(
              'Recording Duration',
              _recordingDuration.toDouble(),
              1,
              60,
              'seconds',
              (val) {
                setState(() => _recordingDuration = val.toInt());
                _saveSetting('recording_duration', val.toInt());
              },
            ),
```
AFTER:
```dart
            _buildSliderSetting(
              'Recording Duration',
              _recordingDurationMinutes.toDouble(),
              1,
              60,
              'min (auto-stop)',
              (val) {
                setState(() => _recordingDurationMinutes = val.toInt());
                _saveSetting('recording_duration_minutes', val.toInt());
              },
            ),
```

**Exact changes — dashboard:**

4d. Add the timer field.

BEFORE (lines 69–73):
```dart
  // Timer for periodic sound classification (every 5 seconds)
  Timer? _classificationTimer;

  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;
```
AFTER:
```dart
  // Timer for periodic sound classification (every 5 seconds)
  Timer? _classificationTimer;

  // One-shot auto-stop timer ('recording_duration_minutes' pref — settings-6)
  Timer? _autoStopTimer;

  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;
```

4e. Create the auto-stop timer at the end of `_startRecording`, after the classification timer. `prefs` is in scope from Step 3.

BEFORE (lines 505–518 of the original file, as amended by Step 3):
```dart
        _performSoundClassification();
      });
    } catch (e) {
      AppLogger.error('Error starting recording', e);
    }
  }
```
AFTER:
```dart
        _performSoundClassification();
      });

      // Auto-stop after the user's chosen duration
      // ('recording_duration_minutes' pref, 1-60 min, default 10 — settings-6).
      final autoStopMinutes =
          (prefs.getInt('recording_duration_minutes') ?? 10).clamp(1, 60).toInt();
      _autoStopTimer = Timer(Duration(minutes: autoStopMinutes), () {
        if (!_isRecording || !mounted) return;
        AppLogger.info(
          'Auto-stopping recording after $autoStopMinutes minute(s)',
        );
        _stopRecording();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording stopped automatically after $autoStopMinutes min '
              '(change in Settings > Recording Duration)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      AppLogger.error('Error starting recording', e);
    }
  }
```

4f. Cancel it in `_stopRecording`.

BEFORE (lines 544–548):
```dart
  void _stopRecording() async {
    _noiseSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _saveTimer?.cancel();
    _classificationTimer?.cancel();
```
AFTER:
```dart
  void _stopRecording() async {
    _noiseSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _saveTimer?.cancel();
    _classificationTimer?.cancel();
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
```
(`dispose()` already calls `_stopRecording()`, so no separate dispose edit is needed.)

**If playbook 05 already applied:** the tail of `_startRecording` and the head of `_stopRecording` may differ (05 adds early-return double-stop guards and moves flag assignments). Apply semantically: (1) auto-stop block goes after the LAST timer creation inside the `try`, before `} catch`; (2) `_autoStopTimer?.cancel(); _autoStopTimer = null;` goes next to the other timer cancels in `_stopRecording` (after any early-return guard 05 added, alongside `_saveTimer?.cancel()`); (3) if 05 renamed/duplicated the prefs variable, use whichever `SharedPreferences` instance is in scope. The manual-stop → auto-stop interaction is safe in both worlds because the callback re-checks `_isRecording`.

**Edge cases to preserve:**
- Manual Stop before the deadline: timer is cancelled in `_stopRecording`, callback never fires, no snackbar.
- Callback fires while user is on another IndexedStack tab: DashboardScreen stays mounted inside MainAppShell (tabs Map=0 Analytics=1 Dashboard=2 History=3 Settings=4), so `mounted` is true and `_stopRecording` runs correctly; the snackbar surfaces on the shell's Scaffold messenger. This is desired — recording must not run forever just because the user switched tabs.
- Screen actually disposed (e.g. standalone route pop): `dispose()` → `_stopRecording()` cancels the timer; the `!mounted` guard covers any race.
- The `use_build_context_synchronously` lint does not fire here (no `await` precedes the `context` use inside the closure, and the `mounted` guard is present) — confirm via `flutter analyze`.

**Acceptance criteria:**
- With Recording Duration = 1 min: Start → after ~60 s recording stops by itself, mic button returns to Start state, snackbar explains the auto-stop.
- Manual Stop at 30 s: nothing fires at the 60 s mark.
- Slider shows "10 min (auto-stop)" by default; a legacy stored `recording_duration` (seconds) value is ignored and deleted.

**Verify:**
```
flutter analyze
flutter test test/widget/settings_screen_test.dart
```
Manual: set Recording Duration = 1 min, start recording, wait 60–65 s → auto-stop + snackbar. Start again, stop manually at ~15 s, keep the app open 60 s → no snackbar, no state change.

**Commit title:** `feat(recording): auto-stop recording via recording_duration_minutes setting (settings-6)`

---

## Step 5 — Real daily reminder: `zonedSchedule` at 19:00 local (settings-5)

**Goal:** Toggling Daily Reminders ON schedules a genuine repeating OS notification at 19:00 local time (persisting across app restarts and device reboots); toggling OFF — or disabling notifications entirely — cancels it.

**Files:** `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `lib/services/notification_service.dart`, `lib/screens/settings_screen_enhanced.dart`, `lib/main.dart`

**Exact changes:**

5a. `pubspec.yaml` — add the timezone packages.

BEFORE (lines 46–47):
```yaml
  # Notifications
  flutter_local_notifications: ^18.0.1
```
AFTER:
```yaml
  # Notifications
  flutter_local_notifications: ^18.0.1
  timezone: ^0.10.0
  flutter_timezone: ^3.0.1
```
Then run `flutter pub get`. It must resolve without conflicts (flutter_local_notifications 18.x itself depends on `timezone ^0.10.0`). Do NOT bump flutter_timezone to 4.x.

5b. `android/app/src/main/AndroidManifest.xml` — permissions + receivers required for scheduled notifications (and the POST_NOTIFICATIONS permission that Android 13+ requires for the already-present `requestNotificationsPermission()` call to actually show a dialog).

BEFORE:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```
AFTER:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

BEFORE:
```xml
        <meta-data
                android:name="flutterEmbedding"
                android:value="2"/>
    </application>
```
AFTER:
```xml
        <meta-data
                android:name="flutterEmbedding"
                android:value="2"/>
        <receiver
                android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
                android:exported="false"/>
        <receiver
                android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
                android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>
```

5c. `lib/services/notification_service.dart` — imports, timezone init, replace dead `showDailyReminder` with schedule/cancel.

BEFORE (lines 1–2):
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
```
AFTER:
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../utils/app_logger.dart';
```

BEFORE (lines 10–19):
```dart
  // Initialize notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    _initialized = true;
  }
```
AFTER:
```dart
  // Notification id for the recurring daily reminder (settings-5).
  // Ids 0 (high-noise) and 2 (export) are used elsewhere in this file.
  static const int dailyReminderId = 1;

  // Hour of day (local time) at which the daily reminder fires.
  static const int dailyReminderHour = 19;

  // Initialize notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Timezone database is required for zonedSchedule (settings-5).
    tzdata.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (e) {
      AppLogger.warning('Could not resolve local timezone, using default: $e');
    }

    _initialized = true;
  }
```

BEFORE (lines 62–85, the whole dead method):
```dart
  // Show daily reminder
  static Future<void> showDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily reminders to record noise levels',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,
      '📊 Record Today',
      'Help map noise pollution in your area - Record now!',
      notificationDetails,
    );
  }
```
AFTER:
```dart
  // Schedule the recurring daily reminder at dailyReminderHour local time.
  // Re-scheduling with the same id replaces any existing schedule (settings-5).
  static Future<void> scheduleDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily reminders to record noise levels',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      dailyReminderId,
      '📊 Record Today',
      'Help map noise pollution in your area - Record now!',
      _nextInstanceOfReminderTime(),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    AppLogger.info(
      'Daily reminder scheduled for $dailyReminderHour:00 local time',
    );
  }

  // Cancel the recurring daily reminder.
  static Future<void> cancelDailyReminder() async {
    await _notifications.cancel(dailyReminderId);
    AppLogger.info('Daily reminder cancelled');
  }

  static tz.TZDateTime _nextInstanceOfReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      dailyReminderHour,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
```

5d. `lib/screens/settings_screen_enhanced.dart` — import the service and wire both toggles.

BEFORE (lines 10–11):
```dart
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
```
AFTER:
```dart
import 'donation_screen.dart';
import '../services/notification_service.dart';
import '../utils/theme_helper.dart';
```

Daily Reminders toggle — BEFORE (lines 189–197 of the original file):
```dart
            _buildSwitchSetting(
              'Daily Reminders',
              Icons.alarm,
              _dailyReminders,
              (val) {
                setState(() => _dailyReminders = val);
                _saveSetting('daily_reminders', val);
              },
            ),
```
AFTER:
```dart
            _buildSwitchSetting(
              'Daily Reminders',
              Icons.alarm,
              _dailyReminders,
              (val) async {
                setState(() => _dailyReminders = val);
                // Save first: scheduleDailyReminder re-reads prefs.
                await _saveSetting('daily_reminders', val);
                if (val) {
                  await NotificationService.scheduleDailyReminder();
                } else {
                  await NotificationService.cancelDailyReminder();
                }
              },
            ),
```

Enable Notifications master toggle — BEFORE (lines 171–179 of the original file):
```dart
            _buildSwitchSetting(
              'Enable Notifications',
              Icons.notifications_active,
              _notificationsEnabled,
              (val) {
                setState(() => _notificationsEnabled = val);
                _saveSetting('notifications_enabled', val);
              },
            ),
```
AFTER:
```dart
            _buildSwitchSetting(
              'Enable Notifications',
              Icons.notifications_active,
              _notificationsEnabled,
              (val) async {
                setState(() => _notificationsEnabled = val);
                await _saveSetting('notifications_enabled', val);
                if (!val) {
                  // OS-level schedules must be torn down explicitly; in-app
                  // alerts already check this pref at fire time.
                  await NotificationService.cancelDailyReminder();
                } else if (_dailyReminders) {
                  await NotificationService.scheduleDailyReminder();
                }
              },
            ),
```
(`_buildSwitchSetting` takes `Function(bool)`, so async closures are accepted as-is.)

5e. `lib/main.dart` — re-sync the schedule with saved settings on every launch (covers app updates, cleared OS alarms, and devices whose OEMs drop boot broadcasts). Note: a `prefs` variable already exists later in `main()` at line 55 — the new variable is deliberately named `notifPrefs` to avoid a collision.

BEFORE (lines 46–48):
```dart
  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();
```
AFTER:
```dart
  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  // Re-sync the daily reminder schedule with saved settings (settings-5).
  final notifPrefs = await SharedPreferences.getInstance();
  final dailyRemindersOn =
      (notifPrefs.getBool('notifications_enabled') ?? true) &&
      (notifPrefs.getBool('daily_reminders') ?? false);
  if (dailyRemindersOn) {
    await NotificationService.scheduleDailyReminder();
  } else {
    await NotificationService.cancelDailyReminder();
  }
```

**Edge cases to preserve:**
- `daily_reminders` defaults to `false` — no schedule is ever created for users who never opted in (the launch re-sync's `cancel` on a never-scheduled id is a harmless no-op).
- Toggling ON while `notifications_enabled` is false: `scheduleDailyReminder` early-returns; when the user later enables the master toggle, its handler re-schedules because `_dailyReminders` is true. Symmetric teardown when the master toggle goes off.
- Toggle order matters: `_saveSetting` MUST be awaited before `scheduleDailyReminder()`, which re-reads prefs.
- If the timezone lookup fails, `tz.local` falls back to the package default (UTC): the reminder still fires daily, possibly hours off — logged via `AppLogger.warning`, never a crash.
- `showHighNoiseAlert` (id 0) and `showExportComplete` (id 2) are untouched; `dailyReminderId = 1` matches the id the dead method used.
- `test/unit/notification_service_test.dart` contains no reference to `showDailyReminder` (verified by grep), so the rename breaks no test.

**Acceptance criteria:**
- Toggling Daily Reminders ON logs `Daily reminder scheduled for 19:00 local time`; `adb shell dumpsys notification --noredact | grep -A2 reminder_channel` (or fln's `pendingNotificationRequests`) shows one pending request with id 1.
- Toggling OFF (or turning Enable Notifications off) removes the pending request.
- With the device clock set a minute before 19:00 and the app killed, the "📊 Record Today" notification appears at 19:00, and again the next day.
- Fresh install, toggle never touched → zero pending notification requests.

**Verify:**
```
flutter pub get
flutter analyze
flutter test test/unit/notification_service_test.dart
flutter test test/widget/settings_screen_test.dart
```
Manual (device/emulator): toggle ON → check log; `adb shell "cmd alarm dump | grep -i noise_pollution_mapper"` shows an inexact alarm; set device time to 18:59, background the app, wait → notification fires at ~19:00 (inexact mode may add small OS-side delay). Toggle OFF → alarm gone. Reboot device → alarm re-registered (boot receiver) or re-created on next app launch (main.dart re-sync).

**Commit title:** `feat(notifications): schedule real daily reminder via zonedSchedule (settings-5)`

---

## Risks & rollback

- **Merge conflicts with playbook 05 (highest risk).** Steps 3–4 edit `_startRecording`/`_stopRecording`, which playbook 05 Steps 1, 2 and 5 also rewrite. Preferred order: apply playbook 05 first, then this spec using the per-step adaptation notes; if this spec lands first, playbook 05's executor must adapt symmetrically. Never blind-apply a non-matching BEFORE block.
- **flutter_local_notifications version drift.** If `pub get` resolves fln < 18, `zonedSchedule` demands the removed `uiLocalNotificationDateInterpretation` parameter and Step 5 won't compile. Fix by upgrading fln to 18.x, not by adding the parameter.
- **flutter_timezone 4.x API break.** The spec pins `^3.0.1` (`getLocalTimezone()` → `String`). If someone bumps to 4.x later, that call site must change to `.identifier`.
- **Auto-stop is a genuine behavior change.** Long-running monitoring sessions now end after 10 min by default. Mitigations: slider goes to 60 min, snackbar explains the stop and points to Settings, and the pref is read fresh each session. If users complain, raising the default/max is a one-line change in Step 4b/4c and the clamp in 4e.
- **Prefs key deletion is irreversible** for `use_dba`, `use_fast_response`, `share_data_with_researchers`, `recording_duration` — acceptable because none was ever consumed; rollback = `git revert` of the relevant commit (the keys repopulate defaults on next use if the UI returns).
- **OEM boot-broadcast suppression** (some Xiaomi/Huawei builds) can drop the re-registered alarm after reboot until the app next launches; the `main.dart` re-sync bounds the damage to "reminder resumes on first app open".
- **Test suite noise.** 53 pre-existing failures (arch-2); only the test files named in Verify sections gate these commits. Bare `flutter test` being red is NOT caused by this cluster.
- **Rollback strategy.** Each step is one self-contained commit with no cross-step file coupling except: Step 4 needs Step 3's `prefs` variable in `_startRecording`, and Step 2's test asserts Step 1's removals. Reverting therefore must proceed newest-first (5 → 4 → 3 → 2 → 1).

## Out of scope

- `db_threshold` / `high_noise_alerts` wiring — playbook 05 Step 5. `anonymize_location` wiring — playbook 04 Step 2. Do not duplicate.
- The dead navigation stubs in Settings (`Privacy Policy`, `Export All Data`, `Rate Us`, `Contact Support`, `Terms of Service` — empty `() {}` handlers) — separate UX finding, not part of this cluster.
- `NotificationService.cancelAll()` / `showExportComplete()` dead-code cleanup (settings-13 / roadmap item).
- iOS notification support (`DarwinInitializationSettings`) — the app initializes Android-only today; unchanged.
- Any Firestore query, index, write-schema (`timestamp`/`createdAt` dual-write, convention 3), or classification-threshold (0.30, convention 5) change — none needed here.
- Refactoring the 1,100-line settings screen or extracting a SettingsService (arch-12 territory).
