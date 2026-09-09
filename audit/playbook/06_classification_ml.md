# Playbook 06 — YAMNet Classification Correctness

Implementation spec for the defect cluster "YAMNet Classification Correctness".
Written for execution with **zero additional analysis**: every BEFORE block below is
copied verbatim from the current code; apply edits with exact string matching.
All findings below were adversarially verified (see `audit/00_MASTER_AUDIT_REPORT.md`,
`audit/01_BUGS_AND_CORRECTNESS.md`, `audit/03_E2E_FLOW_AUDIT.md`,
`audit/06_ARCHITECTURE_AND_CODE_QUALITY.md` — grep each finding ID).

> Line numbers cited below refer to the file state **before this playbook starts**.
> Apply steps in order; within a step, apply edits top-to-bottom. Anchors are chosen
> to remain unique and valid after earlier steps.
>
> Anchor re-verification 2026-07-18: every BEFORE block below was re-checked
> verbatim against the current working tree (sound_classification_service.dart,
> yamnet_class_mapping.dart, dashboard_screen.dart, analytics_screen.dart,
> category_guide_data.dart, sound_classification_test.dart, firebase_service.dart,
> sync_service.dart, report_noise_screen.dart, main.dart, pubspec.yaml) — all match.

## Scope

| ID | Status | One-liner |
|---|---|---|
| ml-1 | CONFIRMED | Hand-written `indexToClassName` does not match the official YAMNet 521-class map (only 0–8 correct; duplicate names in-file prove it is not the real bijective map); wrong labels persisted to Firestore. |
| ml-2 | CONFIRMED | Range fallbacks are dead code: service emits `Unknown_Class_N` but mapping parses only the `YAMNet_Class_` prefix. |
| ml-3 / ml-4 / flow2-6 / arch-3 | CONFIRMED | Threshold is 0.15 (spec: 0.30) AND gates nothing — below-threshold results are returned identically and persisted as fact. |
| donate-5 | CONFIRMED | Classification guide contradicts the actual mapping for Market, Alarm, Body Sounds, Nature, Other, Transport. |
| flow3-8 / analytics-4 | CONFIRMED | Analytics category filter substring-matches: `Speech-Pollution` files under Ambient, `Other` vanishes entirely. |

## Pre-reading

Open these files first (all paths repo-relative to `noise_pollution_mapper/`):

1. `lib/services/yamnet_class_mapping.dart` — whole file (1536 lines).
2. `lib/services/sound_classification_service.dart` — whole file (320 lines).
3. `lib/screens/dashboard_screen.dart` — lines 480–520 (save timer) and 630–650 (classification result handling).
4. `lib/screens/analytics_screen.dart` — lines 1–50 (imports/state) and 711–760 (`_buildSoundCategoryBreakdown`).
5. `lib/models/category_guide_data.dart` — whole file (295 lines).
6. `lib/screens/report_noise_screen.dart` — lines 35–55 (manual `Speech-Pollution` / `Speech-Ambient` values).
7. `test/unit/sound_classification_test.dart` — whole file.
8. `pubspec.yaml` — lines 126–138 (assets section; note `- assets/models/` is already declared, so the new CSV needs **no pubspec change**).
9. `lib/services/firebase_service.dart` — lines 110–135 (`soundClass`/`soundType` written only when non-null — this is what makes the Step 4 gating safe).

Project conventions this spec adheres to (verify you preserve them):
- No Firestore query changes anywhere in this playbook → the single composite index `noise_readings (userId ASC, timestamp DESC)` is untouched; **no new index needed**.
- No UI color changes; nothing here touches theming (ThemeHelper / `withValues(alpha:)` conventions unaffected).
- Write shape unchanged: `saveNoiseReading` still dual-writes `timestamp` (server) + `createdAt` (client); this spec only makes three already-nullable fields (`soundClass`, `soundType`, `confidence`) legitimately null more often — `firebase_service.dart:129-130` already writes them conditionally, and readers already handle absence (`map_view_screen.dart:182-184`, `analytics_screen.dart:135-140`).
- Classification confidence target is **0.30** (project constraint).
- All logging via `AppLogger`, never `print`.
- `flutter analyze` must be clean after **every** commit.

Known pre-existing condition (arch-2, NOT in scope): the full `flutter test` suite has 53 unrelated failures (Firebase-dependent tests). Therefore every Verify section below runs **targeted test files only**, all of which must pass 100%.

---

## Steps

### Step 1 — Bundle the official `yamnet_class_map.csv` and load it at init; delete the hand-written table (ml-1)

**Goal:** Replace the fabricated 402-entry `indexToClassName` literal with the official 521-class map, bundled as an asset and parsed once at service initialization.

**Files:**
- `assets/models/yamnet_class_map.csv` (NEW — downloaded, not authored)
- `lib/services/yamnet_class_mapping.dart`
- `lib/services/sound_classification_service.dart`
- `test/unit/yamnet_class_map_test.dart` (NEW)

**Exact changes:**

**1a. Download the official CSV** into `assets/models/` (PowerShell, run from the repo root `noise_pollution_mapper/`):

```powershell
curl.exe -sL -o assets/models/yamnet_class_map.csv https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv
Get-FileHash assets/models/yamnet_class_map.csv -Algorithm SHA256
```

The file MUST verify as (checked 2026-07-18 against tensorflow/models master):
- SHA256: `cdf24d193e196d9e95912a2667051ae203e92a2ba09449218ccb40ef787c6df2`
- Size: 14,096 bytes; 522 lines (1 header `index,mid,display_name` + 521 data rows)
- Spot rows: `0,/m/09x0r,Speech` · `132,/m/04rlf,Music` · `294,/m/07yv9,Vehicle` · `390,/m/03kmc9,Siren` · `494,/m/028v0c,Silence` · `520,/m/07hvw1,Field recording`

If the hash differs, STOP and inspect the file manually against the spot rows above before proceeding (upstream reformat is possible but the class order is frozen by the model, so the 521 index→name pairs must match the spot rows).

`pubspec.yaml` already declares `- assets/models/` (line 137), so the CSV is picked up with **no pubspec edit**.

**1b. `lib/services/yamnet_class_mapping.dart` — add imports.** The file currently starts its code (after the doc comment, lines 1–22) with:

BEFORE (lines 23–25):
```dart
library;

class YAMNetClassMapping {
```

AFTER:
```dart
library;

import 'package:flutter/services.dart' show rootBundle;

import '../utils/app_logger.dart';

class YAMNetClassMapping {
```

**1c. `lib/services/yamnet_class_mapping.dart` — delete the entire hand-written table and replace with the loader.** Delete everything from the map's doc comment through its closing brace. The block to delete starts at (lines 49–52):

```dart
  /// YAMNet AudioSet class index to name mapping
  /// Maps class indices (0-520) to AudioSet class names
  /// Source: YAMNet AudioSet ontology
  static final Map<int, String> indexToClassName = {
```

and ends at (lines 483–484):

```dart
    520: 'Talk show',
  };
```

(That is the whole 435-line `indexToClassName` literal, including its internal comments such as `// CRITICAL MISSING CLASSES (420-430)`. Nothing between line 49 and line 484 survives.)

REPLACE that entire block with:

```dart
  /// YAMNet class index -> official AudioSet display name.
  ///
  /// Populated from assets/models/yamnet_class_map.csv (the official class
  /// map shipped with the yamnet.tflite model) by [loadOfficialClassMap].
  /// Empty until the load completes. Never hand-edit class names here —
  /// the CSV is the single source of truth (finding ml-1).
  static final Map<int, String> indexToClassName = {};

  /// Number of classes the bundled YAMNet model outputs.
  static const int officialClassCount = 521;

  /// Whether the official class map has been loaded successfully.
  static bool get isClassMapLoaded =>
      indexToClassName.length == officialClassCount;

  /// Loads and parses the official YAMNet class map asset.
  ///
  /// CSV format: `index,mid,display_name` where display_name may be quoted
  /// and contain commas (e.g. `1,/m/0ytgt,"Child speech, kid speaking"`).
  /// Returns true only when all 521 rows parsed. Safe to call repeatedly.
  static Future<bool> loadOfficialClassMap() async {
    if (isClassMapLoaded) return true;

    try {
      final csv =
          await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      final parsed = <int, String>{};
      final lines = csv.split('\n');

      // Skip the header row (i = 1).
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final firstComma = line.indexOf(',');
        final secondComma = line.indexOf(',', firstComma + 1);
        if (firstComma < 0 || secondComma < 0) continue;

        final index = int.tryParse(line.substring(0, firstComma));
        if (index == null) continue;

        var name = line.substring(secondComma + 1);
        if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
          name = name.substring(1, name.length - 1).replaceAll('""', '"');
        }
        parsed[index] = name;
      }

      if (parsed.length != officialClassCount) {
        AppLogger.warning(
            'yamnet_class_map.csv parsed ${parsed.length} classes '
            '(expected $officialClassCount)');
        return false;
      }

      indexToClassName
        ..clear()
        ..addAll(parsed);
      AppLogger.info('Official YAMNet class map loaded (521 classes)');
      return true;
    } catch (e) {
      AppLogger.error('Failed to load yamnet_class_map.csv', e);
      return false;
    }
  }
```

**1d. `lib/services/sound_classification_service.dart` — load the map during `initialize()` and abort init if it fails** (a classifier that cannot name its own outputs must not run — this is exactly the ml-1 failure mode):

BEFORE (lines 53–58):
```dart
    try {
      AppLogger.debug('Initializing Sound Classification Service...');

      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      AppLogger.debug('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      AppLogger.debug('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
```

AFTER:
```dart
    try {
      AppLogger.debug('Initializing Sound Classification Service...');

      // Load the official index->name class map first (finding ml-1).
      // Without it every label would be wrong, so failure aborts init;
      // the app then runs with dB measurement but no classification.
      final classMapLoaded = await YAMNetClassMapping.loadOfficialClassMap();
      if (!classMapLoaded) {
        AppLogger.error('Official YAMNet class map failed to load - '
            'sound classification disabled');
        _isInitialized = false;
        return false;
      }

      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      AppLogger.debug('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      AppLogger.debug('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
```

**1e. NEW file `test/unit/yamnet_class_map_test.dart`** (full contents — `flutter_test` wires `rootBundle` to real project assets once the binding is initialized):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';

// Verifies the bundled official YAMNet class map (finding ml-1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Official YAMNet class map', () {
    setUpAll(() async {
      final loaded = await YAMNetClassMapping.loadOfficialClassMap();
      expect(loaded, isTrue, reason: 'yamnet_class_map.csv must parse');
    });

    test('loads all 521 classes', () {
      expect(YAMNetClassMapping.indexToClassName.length, equals(521));
      expect(YAMNetClassMapping.isClassMapLoaded, isTrue);
    });

    test('official map is bijective (521 unique names)', () {
      expect(
        YAMNetClassMapping.indexToClassName.values.toSet().length,
        equals(521),
      );
    });

    test('spot-check official names against tensorflow/models', () {
      final map = YAMNetClassMapping.indexToClassName;
      expect(map[0], equals('Speech'));
      // Quoted-name parsing (display name contains a comma):
      expect(map[1], equals('Child speech, kid speaking'));
      expect(map[132], equals('Music'));
      expect(map[294], equals('Vehicle'));
      expect(map[388], equals('Busy signal'));
      expect(map[390], equals('Siren'));
      expect(map[414], equals('Jackhammer'));
      expect(map[494], equals('Silence'));
      expect(map[520], equals('Field recording'));
    });

    test('fabricated names from the old hand map are gone', () {
      final names = YAMNetClassMapping.indexToClassName.values.toSet();
      // These names never existed in the AudioSet ontology (finding ml-1):
      expect(names.contains('Talk show'), isFalse);
      expect(names.contains('Room tone'), isFalse);
      expect(names.contains('Water polo'), isFalse);
      expect(names.contains('Cubicle'), isFalse);
      expect(names.contains('Forest ambience'), isFalse);
    });
  });
}
```

**Edge cases to preserve:**
- `indexToClassName` keeps its name and `Map<int, String>` type, so the two existing consumers (`sound_classification_service.dart:116` and `yamnet_class_mapping.dart:1015-1017`) compile unchanged.
- `loadOfficialClassMap()` is idempotent (guard at top) — `initialize()` is called from both `main.dart:_initializeSoundClassification` and any later `reset()`.
- CRLF safety: the parser `trim()`s each line, so a Windows-checkout CSV with `\r\n` still parses.
- Existing tests in `test/unit/sound_classification_test.dart` touch only `classMapping` (untouched in this step) — they must still pass except the pre-existing 0.6-threshold failure (fixed in Step 4).

**Acceptance criteria:**
- App startup log shows `Official YAMNet class map loaded (521 classes)` and classification labels are official AudioSet names (e.g. a silent room now logs `Silence`, not `Ice skating`; music logs `Music` at index 132, not `Unknown_Class_132`).
- If the CSV asset is missing/corrupt, `initialize()` returns false and the app degrades to dB-only measurement (dashboard already handles `classifySound` returning null when uninitialized).

**Verify:**
```powershell
flutter analyze
flutter test test/unit/yamnet_class_map_test.dart
```
Both must be clean/green. Manual: run the app on a device/emulator, start recording near music, and confirm the log line `YAMNet Top 3: #...` shows a real AudioSet name.

Commit: `fix(ml): replace fabricated YAMNet class table with official yamnet_class_map.csv asset (ml-1)`

---

### Step 2 — Re-audit `classMapping` keys against the real 521 names (ml-1, part 2)

**Goal:** Remove the fabricated class-name blocks that can never match real model output, and add exact-match entries for high-impact official names that previously fell through to keyword guessing.

Ground truth for this step (computed by diffing `classMapping` keys against the official CSV): 444 current entries, of which **113 keys are not official class names**. The fabricated Sports block (35 keys), fabricated Office block (25 keys), fabricated ambience blocks (18 keys), and 2 fabricated whistle keys are deleted below. 33 generic dead keys (e.g. `'Machine'`, `'Revving'`, `'Scooter'`) are **intentionally kept** because the partial-match loop in `getCategoryFromClassName` (lines 1034–1039) uses them as substring helpers for real names (e.g. official `'Sewing machine'` → contains `'machine'`); they are annotated and pinned by a test.

**Files:**
- `lib/services/yamnet_class_mapping.dart`
- `test/unit/yamnet_class_map_test.dart`

**Exact changes (top-to-bottom in the file):**

**2a. Remove the two fabricated whistle keys.**

BEFORE (lines 760–763):
```dart
    'Steam whistle': categoryTransport,
    'Whistle (referee)': categorySports,
    'Mouth whistle': categoryBodySounds,
    'Whistle': categoryOther,
```

AFTER:
```dart
    'Steam whistle': categoryTransport,
    'Whistle': categoryOther,
```

**2b. Replace the fabricated environmental block.** Note: current line 798 (the blank line before `// Nature/Weather ambient`) contains trailing spaces — this edit deliberately stops before it.

BEFORE (lines 786–797):
```dart
    // Environmental/Background sounds (NEW - from logs)
    'Environmental noise': categoryOther,
    'Room tone': categoryOther,
    'Ambient noise': categoryOther,
    'Noise floor': categoryOther,
    'Reverberation': categoryOther,
    'Echo': categoryOther,
    'Acoustic environment': categoryOther,
    'Soundscapes': categoryNature,
    'Atmospheric sounds': categoryWeather,
    'Environmental ambient': categoryNature,
    'Background ambient': categoryOther,
```

AFTER (keeps only the three names that exist in the official map — indices 508, 505, 506):
```dart
    // Environmental/room-tone sounds (official AudioSet names)
    'Environmental noise': categoryOther,
    'Reverberation': categoryOther,
    'Echo': categoryOther,
```

**2c. Replace the fabricated nature-ambience block.**

BEFORE (lines 799–810):
```dart
    // Nature/Weather ambient (NEW - from logs)
    'Natural sounds': categoryNature,
    'Outdoor ambient': categoryNature,
    'Forest ambience': categoryNature,
    'Field recording': categoryNature,
    'Environmental recording': categoryNature,
    'Location sound': categoryNature,
    'Field ambient': categoryNature,
    'Nature ambience': categoryNature,
    'Outdoor soundscape': categoryNature,
    'Environmental sound effects': categoryNature,
    'Nature sounds': categoryNature,
```

AFTER (only `Field recording` is official — index 520):
```dart
    // Field recording (official AudioSet name, index 520)
    'Field recording': categoryNature,
```

**2d. Replace the fabricated Sports block.** Delete the whole block from `    // Sports and recreation (NEW)` (line 893) through `    'Fencing': categorySports,` (line 928) inclusive — none of those 35 names exists in the official map.

AFTER (single replacement for the deleted block):
```dart
    // Sports and recreation — only 'Basketball bounce' (official index 459)
    // maps directly; everything else reaches Sports via keyword fallback
    // in _categorizeByKeywords or via manual reports.
    'Basketball bounce': categorySports,
```

**2e. Replace the fabricated Office block.** Delete from `    // Office and technology (NEW)` (line 930) through `    'Stapler': categoryOffice,` (line 958) inclusive.

AFTER:
```dart
    // Office and technology (official AudioSet names only:
    // indices 408 Cash register, 409 Printer, 410-411 cameras, 519 Radio)
    'Printer': categoryOffice,
    'Radio': categoryOffice,
    'Cash register': categoryOffice,
    'Camera': categoryOffice,
    'Single-lens reflex camera': categoryOffice,
```

**2f. Insert exact-match entries for previously-unmapped official names.** Insert immediately ABOVE the final block, whose first two lines are (lines 960–961):

```dart
    // Other / Ambient
    'Silence': categoryOther,
```

INSERT before those lines:

```dart
    // ── Official AudioSet names previously unmapped (ml-1 re-audit) ──
    // Human voice (crying/laughing family stays with Speech, matching
    // the existing 'Laughter' -> Speech decision)
    'Bellow': categorySpeech,
    'Whoop': categorySpeech,
    'Children shouting': categorySpeech,
    'Baby laughter': categorySpeech,
    'Crying, sobbing': categorySpeech,
    'Baby cry, infant cry': categorySpeech,
    'Whimper': categorySpeech,
    'Wail, moan': categorySpeech,
    'Sigh': categorySpeech,
    'Groan': categorySpeech,
    'Grunt': categorySpeech,
    'Chatter': categorySpeech,
    // Body sounds
    'Whistling': categoryBodySounds,
    'Wheeze': categoryBodySounds,
    'Snoring': categoryBodySounds,
    'Pant': categoryBodySounds,
    'Snort': categoryBodySounds,
    'Heart murmur': categoryBodySounds,
    // Animals / nature
    'Wild animals': categoryNature,
    'Roaring cats (lions, tigers)': categoryNature,
    'Roar': categoryNature,
    'Canidae, dogs, wolves': categoryNature,
    'Rodents, rats, mice': categoryNature,
    'Mouse': categoryNature,
    'Patter': categoryNature,
    'Bird flight, flapping wings': categoryNature,
    'Caterwaul': categoryNature,
    'Whimper (dog)': categoryNature,
    'Steam': categoryNature,
    'Outside, rural or natural': categoryNature,
    // Water vehicles / rail
    'Boat, Water vehicle': categoryTransport,
    'Sailboat, sailing ship': categoryTransport,
    'Rowboat, canoe, kayak': categoryTransport,
    'Motorboat, speedboat': categoryTransport,
    'Ship': categoryTransport,
    'Rail transport': categoryTransport,
    // Road vehicles
    'Air brake': categoryTraffic,
    'Ice cream truck, ice cream van': categoryTraffic,
    'Toot': categoryTraffic,
    'Heavy engine (low frequency)': categoryTraffic,
    'Engine knocking': categoryTraffic,
    // Impulsive/percussive noise — Construction, consistent with the
    // existing 'Boom'/'Bang' mapping and the explosion/firework keyword rule
    "Dental drill, dentist's drill": categoryConstruction,
    'Tools': categoryConstruction,
    'Explosion': categoryConstruction,
    'Gunshot, gunfire': categoryConstruction,
    'Machine gun': categoryConstruction,
    'Fusillade': categoryConstruction,
    'Artillery fire': categoryConstruction,
    'Cap gun': categoryConstruction,
    'Fireworks': categoryConstruction,
    'Firecracker': categoryConstruction,
    'Burst, pop': categoryConstruction,
    'Eruption': categoryConstruction,
    // Mechanisms
    'Mechanisms': categoryIndustrial,
    'Ratchet, pawl': categoryIndustrial,
    'Gears': categoryIndustrial,
    'Pulleys': categoryIndustrial,
    'Mains hum': categoryIndustrial,
    'Sewing machine': categoryDomestic,
    'Television': categoryDomestic,
    // Alarms — without an exact entry, official 'Alarm' (index 382) would
    // partial-match 'Car alarm' and be misfiled under Traffic
    'Alarm': categoryAlarm,
    'Beep, bleep': categoryAlarm,
    // Room/environment tones (very common argmaxes in real recordings)
    'Inside, small room': categoryOther,
    'Inside, large room or hall': categoryOther,
    'Inside, public space': categoryOther,
    'Outside, urban or manmade': categoryOther,
    'Noise': categoryOther,
    'Cacophony': categoryOther,
    'Distortion': categoryOther,
    'Sidetone': categoryOther,
    'Throbbing': categoryOther,
    'Vibration': categoryOther,
    'Sine wave': categoryOther,
    'Harmonic': categoryOther,
    'Chirp tone': categoryOther,
    'Sound effect': categoryOther,
    'Pulse': categoryOther,

```

**2g. Append the audit-pinning tests** to `test/unit/yamnet_class_map_test.dart`. Insert a new group before the final closing `});`+`}` of the file (i.e. after the closing of the `'Official YAMNet class map'` group):

```dart
  group('classMapping audit against official names (ml-1)', () {
    setUpAll(() async {
      await YAMNetClassMapping.loadOfficialClassMap();
    });

    // Generic non-official keys intentionally kept because the
    // partial-match fallback in getCategoryFromClassName uses them as
    // substring helpers for real names. Do not grow this list.
    const allowedHelperKeys = {
      'Revving', 'Accelerating', 'Brake', 'Scooter', 'Small engine',
      'Hammering', 'Machine', 'Machinery', 'Industrial noise', 'Motor',
      'Male speech, man speaking', 'Female speech, woman speaking',
      'Battle cry', 'String instrument', 'Tuba', 'Cowbell (instrument)',
      'Music genre', 'Country music', 'Prayer',
      'Domestic sounds, home sounds', 'Mechanical pencil', 'Clock alarm',
      'Auto rickshaw', 'Go-kart', 'Hiss (cat)', 'Lightning', 'Breeze',
      'Gust', 'Roaring', 'Environmental sounds', 'Bay', 'Pop', 'Thump',
    };

    test('no fabricated class names remain in classMapping', () {
      final official = YAMNetClassMapping.indexToClassName.values.toSet();
      final nonOfficial = YAMNetClassMapping.classMapping.keys
          .where((k) => !official.contains(k))
          .toSet();
      expect(
        nonOfficial.difference(allowedHelperKeys),
        isEmpty,
        reason: 'classMapping contains non-official class names',
      );
    });

    test('high-impact official names resolve to the right category', () {
      expect(YAMNetClassMapping.getCategoryFromClassName('Siren'),
          equals('Traffic'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Alarm'),
          equals('Alarm'));
      expect(
          YAMNetClassMapping.getCategoryFromClassName('Boat, Water vehicle'),
          equals('Transport'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Rain'),
          equals('Weather'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Explosion'),
          equals('Construction'));
      expect(
          YAMNetClassMapping.getCategoryFromClassName('Inside, small room'),
          equals('Other'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Silence'),
          equals('Other'));
      expect(YAMNetClassMapping.getCategoryFromClassName('Basketball bounce'),
          equals('Sports'));
    });
  });
```

**Edge cases to preserve:**
- Dart map literals reject duplicate keys at compile time — if any insertion collides with an existing key, `flutter analyze` fails; fix by removing the older duplicate, never the new official entry.
- `"Dental drill, dentist's drill"` uses double quotes (embedded apostrophe).
- Keep insertion order: the partial-match loop returns the FIRST matching entry, so the new exact entries must not reorder existing blocks.
- Existing test `'Class mapping contains common sound classes'` expects keys `Car`, `Music`, `Rain`, `Speech`, `Jackhammer` — all still present.

**Acceptance criteria:**
- A siren classifies as Traffic; official `Alarm` (382) as Alarm (not Traffic via `Car alarm` substring); `Inside, small room` (500) as Other instead of keyword-guessing; boats/ships as Transport.
- `classMapping` contains no fabricated names outside the pinned helper list.

**Verify:**
```powershell
flutter analyze
flutter test test/unit/yamnet_class_map_test.dart test/unit/sound_classification_test.dart
```
`sound_classification_test.dart` will still have exactly ONE failure: `Confidence threshold is reasonable` (expects 0.6 — pre-existing arch-2 staleness, fixed in Step 4). Everything else green.

Commit: `fix(ml): re-audit classMapping against official AudioSet class names (ml-1)`

---

### Step 3 — Align the fallback prefix and correct the range buckets (ml-2)

**Goal:** Make the index-range fallback reachable (`YAMNet_Class_` prefix everywhere) and correct its buckets to the official CSV ordering; it now only matters as a degraded mode if the CSV asset ever fails, but it must not silently mislabel.

**Files:**
- `lib/services/sound_classification_service.dart`
- `lib/services/yamnet_class_mapping.dart`
- `test/unit/yamnet_range_fallback_test.dart` (NEW)

**Exact changes:**

**3a. `sound_classification_service.dart` — emit the prefix the mapping understands.**

BEFORE (lines 115–116):
```dart
      // Get actual YAMNet class name from mapping (CRITICAL FIX)
      final yamnetClassName = YAMNetClassMapping.indexToClassName[maxIndex] ?? 'Unknown_Class_$maxIndex';
```

AFTER:
```dart
      // Get the official YAMNet class name; the placeholder prefix must be
      // 'YAMNet_Class_' so getCategoryFromClassName can parse the index (ml-2)
      final yamnetClassName = YAMNetClassMapping.indexToClassName[maxIndex] ?? 'YAMNet_Class_$maxIndex';
```

**3b. `yamnet_class_mapping.dart` — hoist `classIndex` so it also reaches the keyword fallback for named-but-unmapped classes.**

BEFORE (lines 1007–1024):
```dart
  static String getCategoryFromClassName(String className) {
    String? actualClassName;

    // Check if className is in format "YAMNet_Class_123"
    if (className.startsWith('YAMNet_Class_')) {
      final indexStr = className.replaceFirst('YAMNet_Class_', '');
      final classIndex = int.tryParse(indexStr);

      if (classIndex != null && indexToClassName.containsKey(classIndex)) {
        // Convert index to AudioSet class name
        actualClassName = indexToClassName[classIndex]!;
      } else {
        // Unknown class index - try intelligent categorization by keywords
        return _categorizeByKeywords(className, classIndex);
      }
    } else {
      actualClassName = className;
    }
```

AFTER:
```dart
  static String getCategoryFromClassName(String className) {
    String? actualClassName;
    int? classIndex;

    // Check if className is in format "YAMNet_Class_123"
    if (className.startsWith('YAMNet_Class_')) {
      final indexStr = className.replaceFirst('YAMNet_Class_', '');
      classIndex = int.tryParse(indexStr);

      if (classIndex != null && indexToClassName.containsKey(classIndex)) {
        // Convert index to AudioSet class name
        actualClassName = indexToClassName[classIndex]!;
      } else {
        // Unknown class index - try intelligent categorization by keywords
        return _categorizeByKeywords(className, classIndex);
      }
    } else {
      actualClassName = className;
    }
```

BEFORE (lines 1041–1042):
```dart
    // Try intelligent categorization by keywords
    return _categorizeByKeywords(actualClassName, null);
```

AFTER:
```dart
    // Try intelligent categorization by keywords
    return _categorizeByKeywords(actualClassName, classIndex);
```

**3c. `yamnet_class_mapping.dart` — replace the range table with buckets matching the OFFICIAL class ordering.** (The old ranges were written for the fabricated table: e.g. it claims 137–228 = Music while official Music is 132–276.)

BEFORE (lines 1049–1063):
```dart
    // Range-based fallback for gap indices where the class name is still
    // "YAMNet_Class_N" (no indexToClassName entry). Uses AudioSet ontology
    // structure to assign a reasonable category without guessing exact names.
    if (classIndex != null && className.startsWith('YAMNet_Class_')) {
      if (classIndex >= 137 && classIndex <= 228) return categoryMusic;
      if (classIndex >= 0 && classIndex <= 15) return categorySpeech;
      if (classIndex >= 16 && classIndex <= 35) return categoryBodySounds;
      if (classIndex >= 36 && classIndex <= 136) return categoryNature;   // 36-108 animals, 109-136 more animals
      if (classIndex >= 229 && classIndex <= 309) return categoryDomestic;
      if (classIndex >= 310 && classIndex <= 373) return categoryTraffic;  // 323-347 have named entries; raw gaps default to Traffic
      if (classIndex >= 374 && classIndex <= 387) return categorySports;
      if (classIndex >= 388 && classIndex <= 393) return categoryConstruction;
      if (classIndex >= 394 && classIndex <= 399) return categoryIndustrial;
      // Indices 137-228 (Music), 400-520: fall through to keyword checks below
    }
```

AFTER:
```dart
    // Range-based fallback for "YAMNet_Class_N" placeholders (only produced
    // when the official class map failed to load). Coarse buckets follow the
    // OFFICIAL yamnet_class_map.csv ordering, verified against the CSV:
    // 0 Speech..35 Whistling, 36 Breathing..60 Heart murmur,
    // 61 Cheering..66 Children playing, 67 Animal..131 Whale vocalization,
    // 132 Music..276 Scary music, 277 Wind..281 Thunder, 282 Water..293
    // Crackle, 294 Vehicle..321 Traffic noise, 322 Rail transport..336
    // Skateboard, 337 Engine..347 Accelerating, 348 Door..388 Busy signal,
    // 389 Alarm clock..395 Foghorn, 406 Fan/407 A/C, 408 Cash register..412
    // Tools, 413 Hammer..430 Boom. Everything else: Other.
    if (classIndex != null && className.startsWith('YAMNet_Class_')) {
      if (classIndex >= 0 && classIndex <= 34) return categorySpeech;
      if (classIndex >= 35 && classIndex <= 60) return categoryBodySounds;
      if (classIndex >= 61 && classIndex <= 66) return categorySpeech;
      if (classIndex >= 67 && classIndex <= 131) return categoryNature;
      if (classIndex >= 132 && classIndex <= 276) return categoryMusic;
      if (classIndex >= 277 && classIndex <= 281) return categoryWeather;
      if (classIndex >= 282 && classIndex <= 293) return categoryNature;
      if (classIndex >= 294 && classIndex <= 321) return categoryTraffic;
      if (classIndex >= 322 && classIndex <= 336) return categoryTransport;
      if (classIndex >= 337 && classIndex <= 347) return categoryTraffic;
      if (classIndex >= 348 && classIndex <= 388) return categoryDomestic;
      if (classIndex >= 389 && classIndex <= 395) return categoryAlarm;
      if (classIndex >= 406 && classIndex <= 407) return categoryIndustrial;
      if (classIndex >= 408 && classIndex <= 412) return categoryOffice;
      if (classIndex >= 413 && classIndex <= 430) return categoryConstruction;
      return categoryOther;
    }
```

**3d. NEW file `test/unit/yamnet_range_fallback_test.dart`** (full contents). This file must NOT call `loadOfficialClassMap()` — each test file runs in its own isolate, so `indexToClassName` stays empty here, which is exactly the degraded mode the fallback serves:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/yamnet_class_mapping.dart';

// Verifies the 'YAMNet_Class_N' range fallback is reachable and uses the
// official class ordering (finding ml-2). Deliberately does NOT load the
// official class map: the fallback only runs when the map is absent.
void main() {
  group('YAMNet_Class_ range fallback (class map NOT loaded)', () {
    test('precondition: class map is not loaded in this isolate', () {
      expect(YAMNetClassMapping.isClassMapLoaded, isFalse);
    });

    test('range buckets follow the official ontology', () {
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_5'),
          equals('Speech')); // 0-34 human voice
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_40'),
          equals('Body Sounds')); // 35-60 body sounds
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_100'),
          equals('Nature')); // 67-131 animals
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_200'),
          equals('Music')); // 132-276 music
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_280'),
          equals('Weather')); // 277-281 wind/thunder
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_300'),
          equals('Traffic')); // 294-321 vehicles
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_330'),
          equals('Transport')); // 322-336 rail/air/water
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_360'),
          equals('Domestic')); // 348-388 household
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_392'),
          equals('Alarm')); // 389-395 alarms
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_415'),
          equals('Construction')); // 413-430 tools/impulse
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_510'),
          equals('Other')); // remainder
    });

    test('out-of-range and unparseable placeholders degrade to Other', () {
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_999'),
          equals('Other'));
      expect(YAMNetClassMapping.getCategoryFromClassName('YAMNet_Class_abc'),
          equals('Other'));
    });
  });
}
```

**Edge cases to preserve:**
- `'YAMNet_Class_abc'`: `int.tryParse` yields null → falls to keyword matching on the raw string → `Other`. The hoisted `classIndex` stays null there; no behavior change.
- The keyword fallback below the range block is unchanged — real (named) classes that miss both exact and partial matches still get keyword treatment.
- Do NOT change `numClasses` or tensor shapes in the service.

**Acceptance criteria:**
- Grep proof: `Unknown_Class_` no longer appears anywhere under `lib/`.
- With the class map loaded (normal operation), behavior is identical to Step 2 — the fallback is exercised only when the CSV fails.

**Verify:**
```powershell
flutter analyze
flutter test test/unit/yamnet_range_fallback_test.dart test/unit/yamnet_class_map_test.dart
```
Plus: `Select-String -Path lib -Pattern 'Unknown_Class_' -Recurse` (or `rg Unknown_Class_ lib/`) returns nothing.

Commit: `fix(ml): align YAMNet_Class_ fallback prefix and correct range buckets to official ontology (ml-2)`

---

### Step 4 — Enforce the 0.30 threshold; below-threshold results become `Uncertain` and are never persisted (ml-3, ml-4, flow2-6, arch-3)

**Goal:** Set the confidence threshold to the project-spec 0.30 and give it real behavior: below-threshold classifications are returned as a live-only `Uncertain` pseudo-category and are excluded from Firestore writes.

**Chosen behavior and justification** (the task offered "return Uncertain, not persisted" vs "persist with lowConfidence:true"): **return `Uncertain` + do not persist.** Rationale: (a) the dashboard keeps live feedback (users see "Uncertain" instead of a frozen stale label); (b) Firestore stays free of guesses — no downstream reader (map, analytics, history, community feed) needs a new `lowConfidence` field or a data migration, and the write path already treats `soundClass`/`soundType`/`confidence` as optional (`firebase_service.dart:129-130` writes them only when non-null; `map_view_screen.dart:182-184` and `analytics_screen.dart:135-140` already handle absence); (c) it needs no Firestore index or schema change, honoring the index constraint. The alternative (`lowConfidence:true`) would require touching every reader to filter, which is exactly the kind of scattered taxonomy logic this cluster is eliminating.

**Files:**
- `lib/services/yamnet_class_mapping.dart`
- `lib/services/sound_classification_service.dart`
- `lib/screens/dashboard_screen.dart`
- `test/unit/sound_classification_test.dart`

**Exact changes:**

**4a. `yamnet_class_mapping.dart` — add the `Uncertain` pseudo-category constant.**

BEFORE (lines 43–45):
```dart
  static const String categoryOffice = "Office";

  /// Pollution type classification
```

AFTER:
```dart
  static const String categoryOffice = "Office";

  /// Live-display-only pseudo-category for below-threshold classifications.
  /// NEVER persisted to Firestore (see the dashboard save-timer gating).
  static const String categoryUncertain = "Uncertain";

  /// Pollution type classification
```

**4b. `yamnet_class_mapping.dart` — explicit `getSoundType` case.**

BEFORE:
```dart
      case categorySports:
      case categoryWeather:
      case categoryOffice:
        return typeAmbient;
```

AFTER:
```dart
      case categorySports:
      case categoryWeather:
      case categoryOffice:
      case categoryUncertain:
        return typeAmbient;
```

**4c. `yamnet_class_mapping.dart` — icon case.**

BEFORE:
```dart
      case categoryOffice:
        return '💼';
      case categoryOther:
      default:
        return '🔊';
```

AFTER:
```dart
      case categoryOffice:
        return '💼';
      case categoryUncertain:
        return '❓';
      case categoryOther:
      default:
        return '🔊';
```

**4d. `yamnet_class_mapping.dart` — color case.**

BEFORE:
```dart
      case categoryOffice:
        return 0xFF5E35B1; // Deep Purple (office)
      case categoryOther:
      default:
        return 0xFF9E9E9E; // Grey
```

AFTER:
```dart
      case categoryOffice:
        return 0xFF5E35B1; // Deep Purple (office)
      case categoryUncertain:
        return 0xFF757575; // Dark Grey (uncertain)
      case categoryOther:
      default:
        return 0xFF9E9E9E; // Grey
```

**4e. `sound_classification_service.dart` — the threshold constant and its stale justification comment.**

BEFORE (lines 28–34):
```dart
  /// Confidence threshold for classification
  /// Lowered to 15% for real-world environmental sound detection
  /// Environmental sounds often have 10-25% confidence due to:
  /// - Overlapping sounds (traffic + wind + birds)
  /// - Phone microphone quality limitations
  /// - Non-stationary nature of environmental sounds
  static const double confidenceThreshold = 0.15;
```

AFTER:
```dart
  /// Confidence threshold for classification (project spec: 0.30).
  /// Results below this are returned with category 'Uncertain' for live
  /// display only and must NEVER be persisted to Firestore as fact
  /// (see the save-timer gating in dashboard_screen.dart).
  static const double confidenceThreshold = 0.30;
```

**4f. `sound_classification_service.dart` — below-threshold branch returns `Uncertain`.**

BEFORE (lines 125–138):
```dart
      // Step 6: Check confidence threshold
      if (confidence < confidenceThreshold) {
        AppLogger.debug('Low confidence: ${(confidence * 100).toStringAsFixed(1)}% for $yamnetClassName (threshold: ${(confidenceThreshold * 100).toStringAsFixed(0)}%)');
        // Map to category even for low confidence
        final lowConfCategory = YAMNetClassMapping.getCategoryFromClassName(yamnetClassName);
        final lowConfSoundType = YAMNetClassMapping.getSoundType(lowConfCategory);
        return ClassificationResult(
          category: lowConfCategory,
          soundType: lowConfSoundType,
          confidence: confidence,
          yamnetClass: yamnetClassName,
          yamnetClassIndex: maxIndex,
        );
      }
```

AFTER:
```dart
      // Step 6: Check confidence threshold (0.30, project spec).
      // Below-threshold predictions come back as 'Uncertain' so the UI can
      // show live feedback, but meetsThreshold is false and the dashboard
      // save timer excludes them from Firestore (ml-4/flow2-6).
      if (confidence < confidenceThreshold) {
        AppLogger.debug('Low confidence: ${(confidence * 100).toStringAsFixed(1)}% for $yamnetClassName (threshold: ${(confidenceThreshold * 100).toStringAsFixed(0)}%) -> Uncertain');
        return ClassificationResult(
          category: YAMNetClassMapping.categoryUncertain,
          soundType: YAMNetClassMapping.typeAmbient,
          confidence: confidence,
          yamnetClass: yamnetClassName,
          yamnetClassIndex: maxIndex,
        );
      }
```

**4g. `dashboard_screen.dart` — gate the periodic Firestore save on `meetsThreshold`.** (No new import needed: `meetsThreshold` lives on `ClassificationResult`, already imported. An `Uncertain` result always has `confidence < 0.30`, so `meetsThreshold` alone is a complete gate.)

BEFORE (lines 491–502):
```dart
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
```

AFTER:
```dart
        if (_currentDb > 0 && _currentDb.isFinite) {
          // ml-4/flow2-6: only persist classification data that meets the
          // 0.30 confidence threshold. Below-threshold ('Uncertain') results
          // are shown live but never written to Firestore as fact.
          final classification =
              (_currentClassification?.meetsThreshold ?? false)
                  ? _currentClassification
                  : null;
          _firebaseService.saveNoiseReading(
            decibelLevel: _currentDb,
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationName,
            // Include classification data only when confident
            soundClass: classification?.category,
            soundType: classification?.soundType,
            confidence: classification?.confidence,
          );
        }
```

**4h. `test/unit/sound_classification_test.dart` — fix the stale threshold assertion (also clears one of the arch-2 red tests).**

BEFORE (lines 67–72):
```dart
    test('Confidence threshold is reasonable', () {
      expect(SoundClassificationService.confidenceThreshold, greaterThanOrEqualTo(0.0));
      expect(SoundClassificationService.confidenceThreshold, lessThanOrEqualTo(1.0));
      // Should be 60% for testing
      expect(SoundClassificationService.confidenceThreshold, equals(0.6));
    });
```

AFTER:
```dart
    test('Confidence threshold matches project spec (0.30)', () {
      expect(SoundClassificationService.confidenceThreshold, greaterThanOrEqualTo(0.0));
      expect(SoundClassificationService.confidenceThreshold, lessThanOrEqualTo(1.0));
      // Project constraint: classification confidence target is 0.30
      expect(SoundClassificationService.confidenceThreshold, equals(0.30));
    });

    test('Uncertain pseudo-category is Ambient for display purposes', () {
      expect(YAMNetClassMapping.categoryUncertain, equals('Uncertain'));
      expect(YAMNetClassMapping.getSoundType('Uncertain'), equals('Ambient'));
      expect(YAMNetClassMapping.getCategoryIcon('Uncertain'), equals('❓'));
    });
```

**Edge cases to preserve:**
- `main.dart:119` prints the threshold from the constant — it now correctly logs `30%` with no edit.
- Dashboard display: `result.soundType == 'Pollution'` color checks (dashboard_screen.dart:1126,1134) render `Uncertain` with the Ambient color — intended.
- The dB reading itself is still saved every 5 s even when classification is uncertain — only the three classification fields are omitted (readings without classification are already a supported document shape).
- The offline path (`firebase_service._saveOffline` → `sync_service`) receives the same nulls; `sync_service.dart:223-227` already writes `soundClass`/`soundType` only when non-null.
- `meetsThreshold` (service line 300) is now load-bearing — do not remove it.

**Acceptance criteria:**
- Startup log shows `Confidence threshold: 30%`.
- In a quiet room (model confidence typically < 0.30) the dashboard shows category `Uncertain` with ❓, and new `noise_readings` documents contain `decibelLevel`/location/timestamps but NO `soundClass`, `soundType`, or `confidence` fields.
- A clearly identifiable loud sound (e.g. music at volume, confidence ≥ 0.30) persists the real category exactly as before.

**Verify:**
```powershell
flutter analyze
flutter test test/unit/sound_classification_test.dart test/unit/yamnet_class_map_test.dart test/unit/yamnet_range_fallback_test.dart
```
Manual: record in a quiet room ≥ 10 s, then inspect the newest `noise_readings` doc in the Firebase console — it must have no `soundClass` field. Record near loud music — the doc must have `soundClass` with `confidence >= 0.3`.

Commit: `fix(ml): enforce 0.30 confidence threshold; below-threshold results are Uncertain and never persisted (ml-3, ml-4, flow2-6, arch-3)`

---

### Step 5 — Regenerate the classification guide from the fixed mapping (donate-5)

**Goal:** Make every guide entry state what the mapping actually does (post Steps 1–4), fixing the six verified contradictions (Market, Alarm, Body Sounds, Nature, Other, Transport) and the inflated `yamnetInfo` counts.

Counts below are the exact number of direct (exact-match) `classMapping` entries per category after Step 2, computed against the official CSV: Traffic 28, Tuk-tuk 1, Construction 23, Industrial 14, Speech 32, Music 88, Religious 8, Market 0, Nature 78, Domestic 42, Alarm 7, Body Sounds 26, Transport 23, Sports 1, Weather 7, Office 5, Other 28.

**Files:**
- `lib/models/category_guide_data.dart`

**Exact changes:** Replace the entire body of the returned list in `getAllCategories()`. The block to replace starts at (line 27):

```dart
    return [
```

and ends at (lines 282–283):

```dart
    ];
  }
```

REPLACE with (icons and `color:` lookups unchanged from the current file; only `examples`, `description`, `yamnetInfo` regenerated):

```dart
    return [
      // 1. Traffic - Red
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTraffic,
        icon: Icons.traffic,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTraffic),
        examples: [
          'Cars, buses, and trucks',
          'Vehicle horns and engine noise',
          'Emergency-vehicle sirens (police, ambulance, fire engine)',
          'Car alarms and reversing beeps',
        ],
        description:
            'Road vehicle noise, including emergency-vehicle sirens.',
        yamnetInfo: '28 official vehicle and siren classes mapped directly',
      ),

      // 2. Tuk-tuk - Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTuktuk,
        icon: Icons.two_wheeler,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTuktuk),
        examples: [
          'Three-wheeler engines (Sri Lanka specific)',
          'Motorcycles',
          'Small two-stroke engines (keyword-detected)',
        ],
        description:
            'Three-wheeler and small engine vehicles common in Sri Lanka.',
        yamnetInfo:
            "1 official class ('Motorcycle') plus scooter/moped keyword fallback",
      ),

      // 3. Construction - Deep Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryConstruction,
        icon: Icons.construction,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryConstruction),
        examples: [
          'Drilling, hammering, and jackhammers',
          'Sawing, sanding, and power tools',
          'Explosions, blasting, and fireworks',
        ],
        description:
            'Construction-site tools and impulsive blast-type noise.',
        yamnetInfo: '23 official tool and impulse-noise classes mapped directly',
      ),

      // 4. Industrial - Brown
      CategoryGuideData(
        category: YAMNetClassMapping.categoryIndustrial,
        icon: Icons.factory,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryIndustrial),
        examples: [
          'Factory machinery, gears, and mechanisms',
          'Fans and air conditioning',
          'Chainsaws and lawn mowers',
          'Electrical mains hum',
        ],
        description: 'Industrial and machinery noise.',
        yamnetInfo: '14 official machinery classes mapped directly',
      ),

      // 5. Speech - Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categorySpeech,
        icon: Icons.record_voice_over,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySpeech),
        examples: [
          'Talking and conversation',
          'Shouting, crowds, and chatter',
          'Laughing and crying',
          'Children playing',
        ],
        description:
            'Human voices: conversation, crowds, laughter, and crying.',
        yamnetInfo: '32 official human-voice classes mapped directly',
      ),

      // 6. Music - Purple
      CategoryGuideData(
        category: YAMNetClassMapping.categoryMusic,
        icon: Icons.music_note,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryMusic),
        examples: [
          'Songs (any genre)',
          'Musical instruments (guitar, piano, drums)',
          'Radio/TV music',
          'Humming or singing',
        ],
        description:
            'Musical sounds of any genre, including instruments and vocals.',
        yamnetInfo:
            '88 official music classes mapped directly, plus genre keyword fallback',
      ),

      // 7. Religious - Yellow
      CategoryGuideData(
        category: YAMNetClassMapping.categoryReligious,
        icon: Icons.auto_stories,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryReligious),
        examples: [
          'Church and temple bells',
          'Chants and mantras',
          'Gongs and chimes',
        ],
        description: 'Religious and spiritual sounds.',
        yamnetInfo: '8 official bell and chant classes mapped directly',
      ),

      // 8. Market - Cyan
      CategoryGuideData(
        category: YAMNetClassMapping.categoryMarket,
        icon: Icons.storefront,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryMarket),
        examples: [
          'Street market and bazaar ambience (keyword-detected)',
          'Manually reported market noise',
        ],
        description:
            'Market and commercial-area sounds. No YAMNet class maps directly '
            'to Market; crowd sounds are classified as Speech.',
        yamnetInfo: 'Keyword fallback and manual reports only - no direct classes',
      ),

      // 9. Nature - Green
      CategoryGuideData(
        category: YAMNetClassMapping.categoryNature,
        icon: Icons.park,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryNature),
        examples: [
          'Birds, insects, and animals (pets, farm, wildlife)',
          'Water: streams, waterfalls, ocean waves',
          'Rustling leaves and crackling fire',
        ],
        description:
            'Animal and natural-environment sounds. Rain, wind, and thunder '
            'are classified as Weather.',
        yamnetInfo: '78 official animal and nature classes mapped directly',
      ),

      // 10. Domestic - Amber
      CategoryGuideData(
        category: YAMNetClassMapping.categoryDomestic,
        icon: Icons.home,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryDomestic),
        examples: [
          'Doors, knocks, and doorbells',
          'Kitchen and appliance sounds',
          'Telephones, clocks, and television',
        ],
        description: 'Domestic and household sounds.',
        yamnetInfo: '42 official household classes mapped directly',
      ),

      // 11. Alarm - Deep Red
      CategoryGuideData(
        category: YAMNetClassMapping.categoryAlarm,
        icon: Icons.alarm,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryAlarm),
        examples: [
          'Alarm clocks and buzzers',
          'Smoke detectors and fire alarms',
          'Civil defense sirens',
        ],
        description:
            'Alarm and warning sounds. Emergency-vehicle sirens (police, '
            'ambulance, fire engine) are classified as Traffic.',
        yamnetInfo: '7 official alarm classes mapped directly',
      ),

      // 12. Body Sounds - Lavender
      CategoryGuideData(
        category: YAMNetClassMapping.categoryBodySounds,
        icon: Icons.accessibility_new,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryBodySounds),
        examples: [
          'Cough, sneeze, and sniff',
          'Breathing, snoring, and heartbeat',
          'Clapping, finger snapping, and footsteps',
          'Whistling',
        ],
        description:
            'Sounds produced by the human body. Laughing and crying are '
            'classified as Speech.',
        yamnetInfo: '26 official body-sound classes mapped directly',
      ),

      // 13. Transport - Dark Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTransport,
        icon: Icons.directions_bus,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTransport),
        examples: [
          'Trains, railways, and subways',
          'Aircraft and helicopters',
          'Boats and ships',
          'Bicycles and skateboards',
        ],
        description:
            'Rail, air, and water transport sounds. Buses are classified '
            'as Traffic.',
        yamnetInfo: '23 official transport classes mapped directly',
      ),

      // 14. Sports - Green (Sports)
      CategoryGuideData(
        category: YAMNetClassMapping.categorySports,
        icon: Icons.sports_soccer,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySports),
        examples: [
          'Basketball bounce',
          'Gym, stadium, and sports keywords (keyword-detected)',
        ],
        description:
            'Sports and recreation sounds. Mostly keyword-detected or '
            'manually reported.',
        yamnetInfo:
            "1 official class ('Basketball bounce') plus keyword fallback",
      ),

      // 15. Weather - Light Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryWeather,
        icon: Icons.cloud,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryWeather),
        examples: [
          'Rain and raindrops',
          'Thunder and thunderstorms',
          'Wind',
        ],
        description: 'Weather and atmospheric sounds.',
        yamnetInfo: '7 official weather classes mapped directly',
      ),

      // 16. Office - Deep Purple
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOffice,
        icon: Icons.business,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOffice),
        examples: [
          'Printers and cash registers',
          'Radio',
          'Cameras',
        ],
        description: 'Office and workplace sounds.',
        yamnetInfo: '5 official office and technology classes mapped directly',
      ),

      // 17. Other - Grey
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOther,
        icon: Icons.help_outline,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOther),
        examples: [
          'Silence and background noise',
          'Static, white noise, and pink noise',
          'Room tone (indoor/outdoor ambience)',
          'Unclassified sounds',
        ],
        description:
            'Ambient room tone and sounds that do not fit other categories. '
            'Finger snaps and clapping are classified as Body Sounds.',
        yamnetInfo:
            '28 official ambience/noise classes mapped directly, plus all unmatched sounds',
      ),
    ];
  }
```

**Edge cases to preserve:**
- Keep the class shape (`category`, `icon`, `color`, `examples`, `description`, `yamnetInfo`) and the 17-entry count — `classification_guide_screen.dart` and `getCategoryByName` iterate this list.
- `Uncertain` is deliberately NOT added as an 18th entry: it is a live-only pseudo-category that never reaches persisted data or the guide.
- Icons and colors are unchanged (no ThemeHelper implications; colors still come from `getCategoryColor`).

**Acceptance criteria:**
- Guide no longer claims: sirens under Alarm, laughing/crying under Body Sounds, wind/rain/thunder under Nature, finger snap/clapping under Other, "15+ market classes", boats under a Transport that had none, or "Public transport" (Bus = Traffic).
- Every `yamnetInfo` count equals the actual number of direct entries in `classMapping` for that category.

**Verify:**
```powershell
flutter analyze
flutter test test/unit/sound_classification_test.dart
```
Manual: open the Sound Classification Guide screen (from Settings, tab index 4 of the MainAppShell IndexedStack) and read the Market, Alarm, Body Sounds, Nature, Other, and Transport cards against `classMapping`.

Commit: `fix(guide): regenerate classification guide from the actual YAMNet mapping (donate-5)`

---

### Step 6 — Exact-match analytics category filter via a shared taxonomy (flow3-8, analytics-4)

**Goal:** Delete the hardcoded, substring-matched category lists in the analytics breakdown and classify every stored `soundClass` through one shared function exported by `YAMNetClassMapping`.

**Files:**
- `lib/services/yamnet_class_mapping.dart`
- `lib/screens/analytics_screen.dart`
- `test/unit/sound_classification_test.dart`

**Exact changes:**

**6a. `yamnet_class_mapping.dart` — export the single taxonomy function.** Insert immediately after `getSoundType` and before `getCategoryFromClassName`:

BEFORE:
```dart
      default:
        return typeAmbient;
    }
  }

  /// Get category from YAMNet class name or index
```

AFTER:
```dart
      default:
        return typeAmbient;
    }
  }

  /// Single source of truth for bucketing a `soundClass` value AS STORED in
  /// Firestore into Pollution/Ambient. Handles the two manual-report values
  /// from report_noise_screen.dart ('Speech-Pollution'/'Speech-Ambient')
  /// that are not YAMNet categories, then defers to [getSoundType].
  /// Use this everywhere instead of hand-maintained category lists
  /// (findings flow3-8 / analytics-4).
  static String soundTypeForStoredClass(String storedClass) {
    if (storedClass == 'Speech-Pollution') return typePollution;
    if (storedClass == 'Speech-Ambient') return typeAmbient;
    return getSoundType(storedClass);
  }

  /// Get category from YAMNet class name or index
```

**6b. `analytics_screen.dart` — add the import.**

BEFORE (lines 7–9):
```dart
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

AFTER:
```dart
import '../services/firebase_service.dart';
import '../services/yamnet_class_mapping.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

**6c. `analytics_screen.dart` — replace the substring filter.**

BEFORE (lines 716–754):
```dart
    Map<String, int> filteredCounts = {};

    if (_selectedFilter == 'All') {
      filteredCounts = Map.from(_soundTypeCounts);
    } else {
      final pollutionCategories = [
        'Traffic',
        'Construction',
        'Industrial',
        'Tuk-tuk',
        'Transport',
        'Alarm',
      ];
      final ambientCategories = [
        'Music',
        'Nature',
        'Speech',
        'Religious',
        'Market',
        'Domestic',
        'Body Sounds',
        'Sports',
        'Weather',
        'Office',
      ];

      for (var entry in _soundTypeCounts.entries) {
        final category = entry.key;
        final count = entry.value;

        if (_selectedFilter == 'Pollution' &&
            pollutionCategories.any((c) => category.contains(c))) {
          filteredCounts[category] = count;
        } else if (_selectedFilter == 'Ambient' &&
            ambientCategories.any((c) => category.contains(c))) {
          filteredCounts[category] = count;
        }
      }
    }
```

AFTER:
```dart
    Map<String, int> filteredCounts = {};

    if (_selectedFilter == 'All') {
      filteredCounts = Map.from(_soundTypeCounts);
    } else {
      // flow3-8/analytics-4: exact-match every stored soundClass against the
      // shared taxonomy — no hand-maintained lists, no substring matching.
      // 'Speech-Pollution' now files under Pollution and 'Other' under
      // Ambient, matching the pie chart's soundType buckets.
      for (var entry in _soundTypeCounts.entries) {
        final type = YAMNetClassMapping.soundTypeForStoredClass(entry.key);
        if (type == _selectedFilter) {
          filteredCounts[entry.key] = entry.value;
        }
      }
    }
```

**6d. `test/unit/sound_classification_test.dart` — pin the shared taxonomy.** Insert after the `'Type constants are defined'` test:

BEFORE:
```dart
    test('Type constants are defined', () {
      expect(YAMNetClassMapping.typeAmbient, equals('Ambient'));
      expect(YAMNetClassMapping.typePollution, equals('Pollution'));
    });
```

AFTER:
```dart
    test('Type constants are defined', () {
      expect(YAMNetClassMapping.typeAmbient, equals('Ambient'));
      expect(YAMNetClassMapping.typePollution, equals('Pollution'));
    });

    test('soundTypeForStoredClass buckets stored soundClass values exactly', () {
      // Manual-report pseudo-categories (report_noise_screen.dart)
      expect(YAMNetClassMapping.soundTypeForStoredClass('Speech-Pollution'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Speech-Ambient'),
          equals('Ambient'));
      // Regression flow3-8: 'Other' must appear under the Ambient filter
      expect(YAMNetClassMapping.soundTypeForStoredClass('Other'),
          equals('Ambient'));
      // Ordinary categories defer to getSoundType
      expect(YAMNetClassMapping.soundTypeForStoredClass('Traffic'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Transport'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Alarm'),
          equals('Pollution'));
      expect(YAMNetClassMapping.soundTypeForStoredClass('Uncertain'),
          equals('Ambient'));
      // Unknown legacy values degrade to Ambient (getSoundType default)
      expect(YAMNetClassMapping.soundTypeForStoredClass('SomeLegacyValue'),
          equals('Ambient'));
    });
```

**Edge cases to preserve:**
- `_selectedFilter` chip values are exactly `'All'` / `'Pollution'` / `'Ambient'`, which equal `typePollution`/`typeAmbient` string constants — the `type == _selectedFilter` comparison is safe.
- The pie chart (lines 143–147) still buckets by the document's own `soundType` field; the breakdown now agrees with it for every value the app has ever written (both derive Pollution/Ambient identically for all 17 categories + the two manual values).
- No Firestore query changes: the filter operates on already-loaded `_soundTypeCounts`. Period queries keep `isGreaterThan` + `orderBy timestamp descending` untouched; the composite index is unaffected.
- Legacy docs with categories no longer producible (e.g. old wrong labels) fall into Ambient via `getSoundType`'s default — they no longer vanish from both filters.

**Acceptance criteria:**
- Analytics → Sound Categories: selecting `Pollution` shows `Speech-Pollution` entries; selecting `Ambient` shows `Other` entries and does NOT show `Speech-Pollution`; every category key visible under `All` appears under exactly one of the two filters.
- The pie chart and the breakdown never disagree about a reading's bucket.

**Verify:**
```powershell
flutter analyze
flutter test test/unit/sound_classification_test.dart test/unit/yamnet_class_map_test.dart test/unit/yamnet_range_fallback_test.dart
```
Manual: seed one manual report as `Speech-Pollution` (Report Noise screen) and one recording that classifies as `Other`, open Analytics (MainAppShell tab index 1), and toggle the three filter chips checking the two acceptance bullets above.

Commit: `fix(analytics): exact-match category filter via shared taxonomy in YAMNetClassMapping (flow3-8, analytics-4)`

---

## Risks & rollback

- **Historical Firestore data is NOT migrated.** Every reading written before Step 1 carries labels from the fabricated table (e.g. `Jackhammer` that was really `Busy signal`) and low-confidence guesses. This spec fixes the write path only; old docs keep their wrong `soundClass`/`yamnetClass`. A backfill is impossible anyway (raw audio is not stored). Expect a visible discontinuity in analytics around the deploy date.
- **Classified share of readings will drop.** Raising 0.15→0.30 AND gating persistence means many readings now save without classification fields. This is the intended correction (guesses were being persisted as fact), but dashboards/analytics will show fewer classified readings. If the product owner objects, the rollback is Step 4's commit alone.
- **Partial-match drift (Step 2).** Removing fabricated keys changes which entries the substring loop can hit for the ~190 official names still without exact entries. The curated additions cover the highest-impact ones (verified against the official CSV); remaining names fall through to the keyword categorizer, whose behavior is unchanged. The pinned helper-key test prevents silent re-growth of fabricated names.
- **CSV asset failure aborts classification init** (Step 1 decision). A corrupted asset bundle disables classification entirely instead of mislabeling; the dB pipeline is unaffected. Watch for `Official YAMNet class map failed to load` in crash/log reporting after release.
- **Upstream CSV availability.** If the tensorflow/models raw URL is unreachable at execution time, obtain `yamnet_class_map.csv` from any TFHub YAMNet distribution and validate against the spot rows + 521-row count before committing. The SHA256 above is authoritative for the canonical file.
- **Test isolation assumption (Step 3).** `yamnet_range_fallback_test.dart` relies on per-file isolates so the class map is unloaded; its first test asserts that precondition explicitly and will fail loudly (not silently pass) if the runner ever changes.
- **Rollback:** each step is one self-contained commit; `git revert <sha>` in reverse order. Step 4 (threshold/gating) and Step 6 (analytics) are independently revertible. Steps 2 and 3 depend on Step 1; revert them together with Step 1 if the CSV approach must be abandoned.

## Out of scope

- ml-10 (stale classification re-saved when later classifications fail), ml-11 (Int16 scaling), ml-12 (resampler anti-aliasing), ml-13 (interpreter never disposed) — separate findings, not in this cluster.
- arch-2 (53 pre-existing test failures from missing Firebase mocks) — this playbook fixes only the one stale threshold assertion it collides with; the Firebase-dependent test failures remain.
- Migration/cleanup of historical mislabeled Firestore documents.
- report_noise_screen's manual category list design (`Speech-Pollution`/`Speech-Ambient` remain valid stored values; Step 6 handles them at read time).
- Any Firestore index, security-rule, or query changes (none are needed).
- Adding `Uncertain` to the classification guide or to manual report options.
