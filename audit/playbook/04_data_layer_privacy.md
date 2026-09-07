# Playbook 04 — Data Layer, Privacy & Security Rules

Implementation spec for the defect cluster covering silent save failures, PII leakage in shared documents, the global CSV export, the non-conforming dashboard community query, and the missing Firestore/Storage security rules.

**Execute steps in order. Each step is exactly one commit. Run `flutter analyze` after every step — it must stay clean (project convention 7).**

All BEFORE blocks below were copied verbatim from the working tree on 2026-07-18. If a BEFORE block does not match, STOP and re-read the file — do not guess.

Environment facts (verified):
- `cloud_firestore: ^5.5.0`, `firebase_auth: ^5.3.3`, `shared_preferences: ^2.3.3`, `connectivity_plus: ^6.1.0`, `intl: ^0.20.1` in `pubspec.yaml`. `count()` aggregate and `startAfterDocument` exist in cloud_firestore 5.x. `compute()` comes from `package:flutter/foundation.dart`.
- Dart SDK `^3.10.3` → Dart 3 switch statements (no `break` needed) are available.
- The ONLY Firestore composite index is `noise_readings (userId ASC, timestamp DESC)`. No step below requires a new index: every per-user query uses `userId isEqualTo` + `timestamp isGreaterThan` + `orderBy timestamp desc`; the dashboard query is a single-field range + orderBy on `timestamp` only (auto single-field index).
- The existing test suite has ~53 pre-existing failures (audit arch-2). Run ONLY the test files named in each step's Verify section, never bare `flutter test`.

---

## Scope

| ID | Status | One-liner |
|---|---|---|
| fb-1 | CONFIRMED | `saveNoiseReading` swallows ALL errors (`Future<void>`, catch-and-log only, firebase_service.dart:16-92); both callers show false success. |
| fb-4 / uiux-3 / perf-5 | CONFIRMED | CSV export (history_screen.dart:219-329) downloads the ENTIRE global `noise_readings` collection (no userId filter, no limit), includes every user's email, and builds the CSV synchronously on the UI thread. |
| sec-2 / flow6-03 | CONFIRMED | `_saveToFirebase` writes full `userEmail` + precise lat/lng to the shared collection (firebase_service.dart:119-122); the `anonymize_location` pref is written by Settings but never read by any upload path (online or offline). |
| sec-1 | PARTIAL (Critical) | No `firestore.rules` / `storage.rules` anywhere in the repo; `firebase.json` contains only the flutterfire config block. Rules must be authored and wired. |
| dash-5 | CONFIRMED (variant 1) | Dashboard community-count query uses `isGreaterThanOrEqualTo` with no `orderBy` (dashboard_screen.dart:909-913), violating the project index convention, and renders `0` on error with no logging. |
| fb-5 | CONFIRMED (variant 1) | `_buildCommunityFeedCard()` constructs a brand-new `.snapshots()` stream inline on every dashboard rebuild (dashboard_screen.dart:906-914); the screen calls `setState` many times per second while recording. |

Full finding text + verifier evidence: grep the IDs in `audit/00_MASTER_AUDIT_REPORT.md`, `audit/01_BUGS_AND_CORRECTNESS.md`, `audit/02_UI_UX_AUDIT.md`, `audit/03_E2E_FLOW_AUDIT.md`, `audit/04_PERFORMANCE_AUDIT.md`, `audit/05_SECURITY_AUDIT.md`.

---

## Pre-reading

Open these files before touching anything:

1. `lib/services/firebase_service.dart` — whole file (344 lines).
2. `lib/screens/report_noise_screen.dart` — `_submitReport()` (lines 207-261).
3. `lib/screens/dashboard_screen.dart` — state fields (lines 35-99), `_startRecording` save timer (lines 482-514), `_buildCommunityFeedCard` (lines 899-1020).
4. `lib/screens/history_screen.dart` — whole file, especially `_exportDataToCSV` (lines 218-329) and the export IconButton (lines 374-381).
5. `lib/services/sync_service.dart` — `_saveToFirebase` (lines 209-234). NOTE: this path does NOT write `userEmail` and uploads coords already stored in the Hive queue — it needs NO change once Step 2 rounds coords before queueing.
6. `lib/models/offline_recording.dart` — model carried through the offline queue.
7. `lib/screens/community_feed_screen.dart` — lines 165-218 (reads `userEmail`, masks client-side; masking is idempotent for already-masked values and passes non-email display names through).
8. `lib/screens/settings_screen_enhanced.dart` — lines 203-213 (`anonymize_location` pref key), lines 893-901 (delete-account batch rewrites `userId` — constrains the rules in Step 5).
9. `firebase.json` (single line, flutter block only) and `pubspec.yaml`.

---

## Steps

### Step 1 — fb-1: `saveNoiseReading` returns a `SaveOutcome`; both callers surface failure

**Goal:** Stop swallowing save errors: the service reports online-saved / queued-offline / failed, and both call sites show accurate feedback instead of unconditional success.

**Files:**
- `lib/services/firebase_service.dart`
- `lib/screens/report_noise_screen.dart`
- `lib/screens/dashboard_screen.dart`

**Exact changes**

1a. `lib/services/firebase_service.dart` — add an enum immediately above `class FirebaseService {` (line 8):

BEFORE (lines 7-8):
```dart

class FirebaseService {
```

AFTER:
```dart

/// Outcome of a noise-reading save attempt (fb-1).
/// - [savedOnline]: written to Firestore.
/// - [queuedOffline]: stored in the local Hive queue for later sync.
/// - [failed]: nothing was persisted — callers MUST surface this to the user.
enum SaveOutcome { savedOnline, queuedOffline, failed }

class FirebaseService {
```

1b. Replace the whole `saveNoiseReading` method.

BEFORE (lines 14-92, verbatim):
```dart
  // Save noise reading to Firestore (with optional sound classification data)
  // Automatically handles offline mode by queuing for later sync
  Future<void> saveNoiseReading({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.warning('[FirebaseService] No user logged in, cannot save');
        return;
      }

      // Check connectivity with error handling
      bool isOnline = false;
      try {
        final connectivityResult = await _connectivity.checkConnectivity();
        isOnline = _isConnectedToInternet(connectivityResult);
      } catch (e) {
        // If connectivity check fails, assume offline
        AppLogger.warning('[FirebaseService] Connectivity check failed, assuming offline: $e');
        isOnline = false;
      }

      if (isOnline) {
        // ONLINE: Save directly to Firebase
        await _saveToFirebase(
          decibelLevel: decibelLevel,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.info('[FirebaseService] Saved reading to Firebase: $decibelLevel dB');
      } else {
        // OFFLINE: Save to Hive queue for later sync
        await _saveOffline(
          decibelLevel: decibelLevel,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.warning('[FirebaseService] Offline! Queued reading for later sync: $decibelLevel dB');
      }
    } catch (e) {
      AppLogger.error('[FirebaseService] Error saving reading', e);
      // Fallback: Save offline even if online save failed
      try {
        final user = _auth.currentUser;
        if (user != null) {
          await _saveOffline(
            decibelLevel: decibelLevel,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            soundClass: soundClass,
            soundType: soundType,
            confidence: confidence,
            userId: user.uid,
          );
          AppLogger.info('[FirebaseService] Saved to offline queue (fallback): $decibelLevel dB');
        }
      } catch (fallbackError) {
        AppLogger.error('[FirebaseService] Fallback offline save also failed', fallbackError);
      }
    }
  }
```

AFTER:
```dart
  // Save noise reading to Firestore (with optional sound classification data).
  // Automatically handles offline mode by queuing for later sync.
  // Never throws — returns a SaveOutcome the caller must check (fb-1).
  Future<SaveOutcome> saveNoiseReading({
    required double decibelLevel,
    required double latitude,
    required double longitude,
    String? locationName,
    String? soundClass,
    String? soundType,
    double? confidence,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[FirebaseService] No user logged in, cannot save');
      return SaveOutcome.failed;
    }

    // Check connectivity with error handling
    bool isOnline = false;
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      isOnline = _isConnectedToInternet(connectivityResult);
    } catch (e) {
      // If connectivity check fails, assume offline
      AppLogger.warning(
          '[FirebaseService] Connectivity check failed, assuming offline: $e');
      isOnline = false;
    }

    if (isOnline) {
      try {
        // ONLINE: Save directly to Firebase
        await _saveToFirebase(
          decibelLevel: decibelLevel,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          soundClass: soundClass,
          soundType: soundType,
          confidence: confidence,
          userId: user.uid,
        );
        AppLogger.info(
            '[FirebaseService] Saved reading to Firebase: $decibelLevel dB');
        return SaveOutcome.savedOnline;
      } catch (e) {
        AppLogger.error(
            '[FirebaseService] Online save failed, falling back to offline queue',
            e);
        // Fall through to the offline queue below.
      }
    }

    // OFFLINE (or online save failed): queue in Hive for later sync
    try {
      await _saveOffline(
        decibelLevel: decibelLevel,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        soundClass: soundClass,
        soundType: soundType,
        confidence: confidence,
        userId: user.uid,
      );
      AppLogger.warning(
          '[FirebaseService] Queued reading for later sync: $decibelLevel dB');
      return SaveOutcome.queuedOffline;
    } catch (e) {
      AppLogger.error('[FirebaseService] Offline save also failed', e);
      return SaveOutcome.failed;
    }
  }
```

1c. `lib/screens/report_noise_screen.dart` — surface the outcome in `_submitReport`. `SaveOutcome` is exported by the already-imported `../services/firebase_service.dart`; no new import.

BEFORE (lines 223-244, verbatim):
```dart
      // Save to Firebase with sound classification
      await _firebaseService.saveNoiseReading(
        decibelLevel: _manualDb,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        soundClass: _selectedSoundClass,
        soundType: soundType,
        confidence: _selectedSoundClass != null ? 1.0 : null, // Manual entry = 100% confidence
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Noise report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to Dashboard
        Navigator.pop(context);
      }
```

AFTER (snackbar colors follow this file's existing literal-color snackbar pattern — Colors.green/red are already used here for snackbars; do not introduce new ThemeHelper getters):
```dart
      // Save to Firebase with sound classification
      final outcome = await _firebaseService.saveNoiseReading(
        decibelLevel: _manualDb,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        soundClass: _selectedSoundClass,
        soundType: soundType,
        confidence: _selectedSoundClass != null ? 1.0 : null, // Manual entry = 100% confidence
      );

      if (mounted) {
        switch (outcome) {
          case SaveOutcome.savedOnline:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Noise report submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Go back to Dashboard
            Navigator.pop(context);
          case SaveOutcome.queuedOffline:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No connection — report saved locally and will sync automatically.'),
                backgroundColor: Colors.orange,
              ),
            );
            // Go back to Dashboard
            Navigator.pop(context);
          case SaveOutcome.failed:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not save the report. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          // Stay on the screen so the user can retry.
        }
      }
```

1d. `lib/screens/dashboard_screen.dart` — surface periodic-save failure once per recording session.

Add a state field. BEFORE (lines 72-73, verbatim):
```dart
  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;
```

AFTER:
```dart
  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;

  // Track if we've already surfaced a save failure for the current
  // recording session (avoid a snackbar every 5 s) — fb-1
  bool _hasShownSaveErrorSnackbar = false;
```

Reset the flag when recording starts. BEFORE (lines 482-484, inside `_startRecording`, immediately after the audio-capture `AppLogger.debug('Started real audio capture...` block — this exact `setState` also appears in `_stopRecording` with `= false`; edit the one at line 482):
```dart
      setState(() {
        _isRecording = true;
      });
```

AFTER:
```dart
      setState(() {
        _isRecording = true;
        _hasShownSaveErrorSnackbar = false;
      });
```

Check the outcome in the save timer. BEFORE (lines 486-503, verbatim):
```dart
      // Start periodic Firebase saves (every 5 seconds)
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
      // Start periodic Firebase saves (every 5 seconds)
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;

        if (_currentDb > 0 && _currentDb.isFinite) {
          _firebaseService
              .saveNoiseReading(
                decibelLevel: _currentDb,
                latitude: _latitude,
                longitude: _longitude,
                locationName: _locationName,
                // Include classification data if available
                soundClass: _currentClassification?.category,
                soundType: _currentClassification?.soundType,
                confidence: _currentClassification?.confidence,
              )
              .then((outcome) {
            if (outcome == SaveOutcome.failed &&
                mounted &&
                !_hasShownSaveErrorSnackbar) {
              _hasShownSaveErrorSnackbar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Could not save readings — recording data is NOT being stored.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      });
```

**Edge cases to preserve**
- The offline-queue fallback after a failed online write must remain (readings survive flaky networks) — it now reports `queuedOffline`, not silent "success".
- `saveNoiseReading` must never throw: the dashboard timer call is intentionally un-awaited and an unhandled async error would surface as a zone error.
- No-user → `failed` (previously a silent `return`).
- The timer's `!_isRecording || !mounted` guard stays first.

**Acceptance criteria**
- Manual report with Firestore unreachable but device "online" (e.g. airplane-mode raced, or rules deny): red failure snackbar, screen does NOT pop.
- Manual report with connectivity off: orange "saved locally" snackbar, screen pops, reading appears in the Hive queue (sync indicator).
- Manual report online: unchanged green snackbar + pop.
- During dashboard recording with saves failing: exactly one red snackbar per recording session; `AppLogger` errors every attempt.

**Verify**
```
flutter analyze
```
Must report no new issues. Manual: run the app (`flutter run`), submit a manual report in each of the three states above.

**Commit title:** `fix(data): saveNoiseReading returns SaveOutcome; callers surface save failures (fb-1)`

---

### Step 2 — sec-2 / flow6-03: mask author identity and honor anonymize_location at write time

**Goal:** New shared docs never contain a raw email (displayName or masked email instead), and when the `anonymize_location` pref is on, coordinates are rounded to 3 decimals (~110 m) before they reach the online write OR the offline queue.

**Files:**
- `lib/services/firebase_service.dart`
- `test/unit/privacy_write_test.dart` (new)

**Exact changes**

2a. Add the import. BEFORE (lines 1-6, verbatim):
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/app_logger.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';
```

AFTER:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';
```

2b. Add two public static helpers inside `FirebaseService`, immediately after the `_offlineStorage` field declaration (`final OfflineStorageService _offlineStorage = OfflineStorageService();`):

```dart
  /// Round a coordinate to 3 decimal places (~110 m grid).
  /// Applied when the 'anonymize_location' preference is enabled (flow6-03).
  static double roundCoordinate(double value) =>
      (value * 1000).roundToDouble() / 1000;

  /// Privacy-safe author label written to shared noise_readings docs (sec-2).
  /// Prefers the Auth displayName; falls back to a masked email
  /// (abc***@domain.com). Never returns a full raw email address.
  static String authorLabel({String? displayName, String? email}) {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final local = parts[0];
    final prefix = local.length > 3 ? local.substring(0, 3) : local;
    return '$prefix***@${parts.sublist(1).join('@')}';
  }
```

2c. Apply coordinate anonymization ONCE at the top of `saveNoiseReading` so the online write, the offline queue, and the fallback path all get the same (possibly rounded) values.

BEFORE (the Step-1 AFTER state — top of `saveNoiseReading` through the connectivity check):
```dart
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[FirebaseService] No user logged in, cannot save');
      return SaveOutcome.failed;
    }

    // Check connectivity with error handling
```

AFTER:
```dart
    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.warning('[FirebaseService] No user logged in, cannot save');
      return SaveOutcome.failed;
    }

    // Honor the 'Anonymize Location' privacy setting at WRITE time (flow6-03).
    // Rounding happens here — before BOTH the online write and the offline
    // queue entry — so raw coordinates never leave the device when enabled.
    double lat = latitude;
    double lng = longitude;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('anonymize_location') ?? false) {
        lat = roundCoordinate(latitude);
        lng = roundCoordinate(longitude);
      }
    } catch (e) {
      AppLogger.warning(
          '[FirebaseService] Could not read privacy prefs, using raw coordinates: $e');
    }

    // Check connectivity with error handling
```

Then, in the SAME method, replace the argument lines in BOTH inner calls (the `_saveToFirebase(...)` call and the `_saveOffline(...)` call):
```dart
          latitude: latitude,
          longitude: longitude,
```
becomes (in `_saveToFirebase(...)`):
```dart
          latitude: lat,
          longitude: lng,
```
and in `_saveOffline(...)`:
```dart
        latitude: lat,
        longitude: lng,
```
(There are exactly two call sites inside `saveNoiseReading` after Step 1; change both. Do NOT touch the private method signatures.)

2d. Stop writing the raw email. BEFORE (lines 117-127 of the current file, inside `_saveToFirebase`, verbatim):
```dart
    final data = {
      'userId': userId,
      'userEmail': _auth.currentUser?.email,
      'decibelLevel': decibelLevel,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName ?? 'Unknown Location',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now(),
      'deviceInfo': 'Mobile Device',
    };
```

AFTER (keep the `userEmail` FIELD NAME — community_feed_screen.dart:171-218 reads it; its client-side masking is idempotent for already-masked values and passes plain display names through unchanged; keep the dual `timestamp` + `createdAt` write — convention 3):
```dart
    final data = {
      'userId': userId,
      // Privacy (sec-2): never store the raw email in the shared collection.
      // Field name kept as 'userEmail' for reader compatibility
      // (community_feed_screen.dart displays and re-masks it harmlessly).
      'userEmail': authorLabel(
        displayName: _auth.currentUser?.displayName,
        email: _auth.currentUser?.email,
      ),
      'decibelLevel': decibelLevel,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName ?? 'Unknown Location',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': DateTime.now(),
      'deviceInfo': 'Mobile Device',
    };
```

2e. New file `test/unit/privacy_write_test.dart` — full contents:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/firebase_service.dart';

void main() {
  group('FirebaseService.roundCoordinate', () {
    test('rounds to exactly 3 decimal places', () {
      expect(FirebaseService.roundCoordinate(6.927079), closeTo(6.927, 1e-9));
      expect(FirebaseService.roundCoordinate(79.861243), closeTo(79.861, 1e-9));
      expect(FirebaseService.roundCoordinate(-6.927579), closeTo(-6.928, 1e-9));
      expect(FirebaseService.roundCoordinate(0.0), closeTo(0.0, 1e-9));
    });
  });

  group('FirebaseService.authorLabel', () {
    test('prefers non-empty displayName', () {
      expect(
        FirebaseService.authorLabel(
            displayName: 'Nuha', email: 'nuhaadhh@codegen.net'),
        'Nuha',
      );
    });

    test('masks email when displayName missing or blank', () {
      expect(
        FirebaseService.authorLabel(
            displayName: null, email: 'nuhaadhh@codegen.net'),
        'nuh***@codegen.net',
      );
      expect(
        FirebaseService.authorLabel(
            displayName: '   ', email: 'ab@codegen.net'),
        'ab***@codegen.net',
      );
    });

    test('never returns the raw email', () {
      final label = FirebaseService.authorLabel(
          displayName: null, email: 'someone@example.com');
      expect(label, isNot('someone@example.com'));
      expect(label, contains('***'));
    });

    test('falls back to Anonymous', () {
      expect(FirebaseService.authorLabel(displayName: null, email: null),
          'Anonymous');
      expect(
          FirebaseService.authorLabel(displayName: '', email: 'not-an-email'),
          'Anonymous');
    });
  });
}
```
(The test only calls static members — `FirebaseService` is never instantiated, so no Firebase initialization is needed.)

**Edge cases to preserve**
- `sync_service.dart` `_saveToFirebase` (lines 210-233) needs NO change: it never wrote `userEmail`, and it uploads coordinates from the Hive queue, which this step rounds at enqueue time.
- Prefs read failure must not block saving (falls back to raw coords with a warning) — a save must never be lost to a privacy check.
- Registration sets `displayName` (registration_screen.dart:52), so most users get their name, not a masked email.
- Existing docs with raw emails are untouched here (see Out of scope).

**Acceptance criteria**
- With 'Anonymize Location' ON (Settings tab, index 4): a new reading's `latitude`/`longitude` in Firestore have at most 3 decimals; toggle OFF → full precision again.
- New docs' `userEmail` field contains a display name or `abc***@domain` — never a raw email (check Firestore console).
- Offline: enable anonymize, record offline, reconnect, let SyncService flush — synced docs also carry rounded coords.

**Verify**
```
flutter analyze
flutter test test/unit/privacy_write_test.dart
```
Manual: the three acceptance checks above against the Firestore console.

**Commit title:** `fix(privacy): mask author identity and honor anonymize_location at write time (sec-2, flow6-03)`

---

### Step 3 — fb-4 / uiux-3 / perf-5: CSV export scoped to current user, paginated, built off the UI thread

**Goal:** The History export downloads only the signed-in user's readings (paged through the composite index), drops the email column entirely, and assembles the CSV via `compute()` instead of on the UI thread.

**Files:**
- `lib/utils/csv_builder.dart` (new)
- `lib/screens/history_screen.dart`
- `test/unit/csv_builder_test.dart` (new)

**Exact changes**

3a. New file `lib/utils/csv_builder.dart` — full contents:
```dart
/// Builds the CSV document for the History export.
///
/// Top-level function so it can run on a background isolate via `compute()`
/// (perf-5) and be unit tested in isolation. [rows] must contain only
/// isolate-sendable primitives (String / num / null) — no Firestore types.
///
/// Privacy (fb-4 / uiux-3): there is deliberately NO email column.
String buildNoiseCsv(List<Map<String, Object?>> rows) {
  final csvData = StringBuffer();

  // CSV Header (includes sound classification fields; no user email)
  csvData.writeln(
      'Timestamp,Location,Latitude,Longitude,Decibel Level (dB),Sound Classification,Sound Type,Confidence (%),Device');

  for (final row in rows) {
    final location = _escape(row['location'] as String? ?? 'Unknown');
    final soundClass = _escape(row['soundClass'] as String? ?? 'N/A');
    final soundType = _escape(row['soundType'] as String? ?? 'N/A');
    csvData.writeln(
        '${row['timestamp']},"$location",${row['latitude']},${row['longitude']},${row['decibelLevel']},"$soundClass","$soundType",${row['confidence']},${row['device']}');
  }

  return csvData.toString();
}

/// Escape embedded double quotes for quoted CSV fields.
String _escape(String value) => value.replaceAll('"', '""');
```

3b. `lib/screens/history_screen.dart` — add two imports. BEFORE (lines 1-12, verbatim):
```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/theme_helper.dart';
import '../services/firebase_service.dart';
import 'report_noise_screen.dart';
```

AFTER:
```dart
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/csv_builder.dart';
import '../utils/theme_helper.dart';
import '../services/firebase_service.dart';
import 'report_noise_screen.dart';
```

3c. Replace `_exportDataToCSV` entirely. BEFORE: the full method at lines 218-329 (verbatim — starts with `  // Export data to CSV` / `  Future<void> _exportDataToCSV(BuildContext context) async {`, contains the unscoped `FirebaseFirestore.instance.collection('noise_readings').orderBy('timestamp', descending: true).get()` at lines 230-233, the `StringBuffer` CSV loop with the `User Email` column at lines 244-274, the file write at 276-281, the success dialog at 283-318, and the catch block ending at line 329 with `  }`).

AFTER:
```dart
  // Export data to CSV — current user's readings only (fb-4/uiux-3), fetched
  // page-by-page through the composite index (userId ASC, timestamp DESC),
  // CSV assembled on a background isolate (perf-5).
  Future<void> _exportDataToCSV(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to export your data')),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing export...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Fetch ONLY this user's readings, page by page.
      // userId isEqualTo + orderBy timestamp desc == the one composite index.
      const int exportPageSize = 500;
      final rows = <Map<String, Object?>>[];
      DocumentSnapshot? cursor;
      while (true) {
        final snapshot = await _firebaseService.getUserReadingsPaginated(
          userId: userId,
          limit: exportPageSize,
          startAfter: cursor,
        );

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Readers handle both server timestamp and client createdAt.
          final createdAtRaw = data['createdAt'];
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ??
              (createdAtRaw is Timestamp ? createdAtRaw.toDate() : null);

          final confidence = data['confidence'];
          rows.add({
            'timestamp': timestamp != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)
                : 'N/A',
            'location': data['locationName'] as String? ?? 'Unknown',
            'latitude': data['latitude'] ?? 0.0,
            'longitude': data['longitude'] ?? 0.0,
            'decibelLevel': data['decibelLevel'] ?? 0.0,
            'soundClass': data['soundClass'] as String? ?? 'N/A',
            'soundType': data['soundType'] as String? ?? 'N/A',
            'confidence': confidence is num
                ? (confidence * 100).toStringAsFixed(1)
                : 'N/A',
            'device': data['deviceInfo'] as String? ?? 'N/A',
          });
        }

        if (snapshot.docs.length < exportPageSize) break;
        cursor = snapshot.docs.last;
      }

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      // Build the CSV off the UI thread (perf-5)
      final csv = await compute(buildNoiseCsv, rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'noise_pollution_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csv);

      // Success message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ThemeHelper.getCardColor(context),
            title: Text('Export Successful!', style: TextStyle(color: ThemeHelper.getTextColor(context))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exported ${rows.length} recordings',
                  style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                ),
                const SizedBox(height: 12),
                Text(
                  'File saved to:',
                  style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  file.path,
                  style: TextStyle(color: ThemeHelper.getPrimaryColor(context), fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: ThemeHelper.getPrimaryColor(context))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
```

3d. New file `test/unit/csv_builder_test.dart` — full contents:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/csv_builder.dart';

void main() {
  test('header has no User Email column', () {
    final csv = buildNoiseCsv([]);
    expect(
      csv.trim(),
      'Timestamp,Location,Latitude,Longitude,Decibel Level (dB),Sound Classification,Sound Type,Confidence (%),Device',
    );
    expect(csv, isNot(contains('User Email')));
  });

  test('writes one row per reading and escapes embedded quotes', () {
    final csv = buildNoiseCsv([
      {
        'timestamp': '2026-07-18 10:00:00',
        'location': 'Main "North" Gate',
        'latitude': 6.927,
        'longitude': 79.861,
        'decibelLevel': 72.4,
        'soundClass': 'Traffic',
        'soundType': 'Pollution',
        'confidence': '85.0',
        'device': 'Mobile Device',
      },
      {
        'timestamp': 'N/A',
        'location': null, // missing locationName
        'latitude': 0.0,
        'longitude': 0.0,
        'decibelLevel': 0.0,
        'soundClass': null,
        'soundType': null,
        'confidence': 'N/A',
        'device': 'Mobile Device',
      },
    ]);

    final lines = csv.trim().split('\n');
    expect(lines.length, 3); // header + 2 rows
    expect(lines[1], contains('"Main ""North"" Gate"'));
    expect(lines[1], contains('72.4'));
    expect(lines[2], contains('"Unknown"'));
    expect(lines[2], contains('"N/A"'));
  });
}
```

**Edge cases to preserve**
- Empty result → "No data to export" snackbar (unchanged).
- Docs missing `timestamp` fall back to `createdAt` (convention 3); missing both → `'N/A'`.
- Older docs without classification fields → `'N/A'` columns (unchanged behavior).
- `getUserReadingsPaginated` already exists in `firebase_service.dart:214-230` — do NOT add a new query method or a new index.
- The `rows` maps must stay primitive-only (String/num/null): `compute` sends them to another isolate.

**Acceptance criteria**
- Export from the History tab (tab index 3) with two different accounts having data: each CSV contains only that account's rows.
- No `User Email` column anywhere in the file.
- With 1000+ readings, the UI does not freeze during export (scroll the list while it runs).
- Row count in the success dialog equals the user's own reading count ("Showing X of Y" header total).

**Verify**
```
flutter analyze
flutter test test/unit/csv_builder_test.dart
```
Manual: run the app, History tab → download icon → open the CSV from the dialog path and inspect the header + rows.

**Commit title:** `fix(export): scope CSV export to current user, paginate, build off UI thread (fb-4, uiux-3, perf-5)`

---

### Step 4 — fb-5 / dash-5: cache the community-feed stream; conform the query; surface errors

**Goal:** The dashboard community card subscribes to ONE cached Firestore stream (recreated only when the calendar day changes), the query follows the project convention (`isGreaterThan` + `orderBy timestamp desc`), and query errors are logged instead of silently rendering 0.

**Files:**
- `lib/screens/dashboard_screen.dart`

**Exact changes**

4a. Add cached-stream state + helper, and rewrite the head of `_buildCommunityFeedCard`.

BEFORE (lines 899-918, verbatim):
```dart
  // Build Community Feed Card with today's report count
  Widget _buildCommunityFeedCard() {
    // Get today's start and end timestamps
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('noise_readings')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
          .snapshots(),
      builder: (context, snapshot) {
        // Count today's reports
        final reportCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
```

AFTER:
```dart
  // Community-feed stream is cached so frequent rebuilds while recording do
  // not open a brand-new Firestore listener each time (fb-5). Recreated only
  // when the calendar day changes.
  Stream<QuerySnapshot>? _communityFeedStream;
  DateTime? _communityFeedDay;

  Stream<QuerySnapshot> _getCommunityFeedStream() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (_communityFeedStream == null || _communityFeedDay != todayStart) {
      final todayEnd = todayStart.add(const Duration(days: 1));
      _communityFeedDay = todayStart;
      // Project index rule (dash-5): range filter + orderBy on the SAME
      // field (timestamp) — isGreaterThan + orderBy descending. Single-field
      // query: served by the automatic index, no composite index required.
      _communityFeedStream = FirebaseFirestore.instance
          .collection('noise_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return _communityFeedStream!;
  }

  // Build Community Feed Card with today's report count
  Widget _buildCommunityFeedCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCommunityFeedStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // dash-5: do not silently render 0 — log the real failure.
          AppLogger.error(
              '[Dashboard] Community feed count query failed', snapshot.error);
        }
        // Count today's reports
        final reportCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
```

Everything from `final reportCount = ...` to the end of the method (through line 1020 `  }`) stays byte-identical.

Placement note: put the two fields + `_getCommunityFeedStream()` directly above the existing `// Build Community Feed Card with today's report count` comment (i.e., between the `build` method's closing lines at 897 and line 899). `AppLogger` is already imported (line 12).

**Edge cases to preserve**
- Assigning `_communityFeedStream` inside `_getCommunityFeedStream()` during `build` is safe — no `setState` is called; it is plain field mutation.
- Day rollover: a rebuild after midnight creates a fresh stream for the new day (previous behavior recomputed the window every rebuild; this preserves correctness without churning listeners).
- Boundary semantics change: a reading whose server timestamp is EXACTLY 00:00:00.000 is no longer counted (`isGreaterThan` vs `isGreaterThanOrEqualTo`). This is the project-wide convention used by every other period query (see `getUserReadingsByPeriod`, firebase_service.dart:259-266) and is accepted.
- The badge stays live (snapshots). Do NOT swap to a one-shot `count()` aggregate here — cloud_firestore 5.5.0 has no streaming aggregate, so that would silently freeze the badge; see Out of scope.

**Acceptance criteria**
- Start a recording on the Dashboard tab (index 2): while `_dbHistory` updates several times per second, Firestore opens no new `Listen` channels (verify via `AppLogger` debug / Firestore network inspector — listener count stays constant).
- Community count still updates live when another account adds a reading.
- Force a query failure (e.g. temporarily deny reads in rules on a dev project): the card renders 0 AND `AppLogger` shows `[Dashboard] Community feed count query failed ...` instead of silence.

**Verify**
```
flutter analyze
```
Manual: the three acceptance checks above.

**Commit title:** `fix(dashboard): cache community-feed stream and conform count query to index rule (fb-5, dash-5)`

---

### Step 5 — sec-1: author Firestore + Storage security rules and wire them into firebase.json

**Goal:** The repo contains deployable security rules: authenticated-only access, `noise_readings` create stamped with the caller's uid and update/delete restricted to the owner, `users/{uid}` owner-only, Storage locked; `firebase.json` references them and the one composite index is codified.

**Files (all at the project root `noise_pollution_mapper/`):**
- `firestore.rules` (new)
- `storage.rules` (new)
- `firestore.indexes.json` (new)
- `.firebaserc` (new)
- `firebase.json` (modified)

**Exact changes**

5a. New file `firestore.rules` — full contents:
```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    // Community noise readings: readable by any signed-in user (community
    // map / feed / heatmap / dashboard count are cross-user by design),
    // writable only for your own documents.
    match /noise_readings/{readingId} {
      allow read: if isSignedIn();

      // Create: the document must be stamped with the caller's uid.
      allow create: if isSignedIn()
        && request.resource.data.userId is string
        && request.resource.data.userId == request.auth.uid;

      // Update/delete: only the current owner. NOTE: ownership is checked
      // against the EXISTING doc (resource.data), which deliberately permits
      // the delete-account anonymization flow
      // (settings_screen_enhanced.dart:893-901) that rewrites userId to
      // 'deleted_user_<prefix>' — after which no one can modify the doc.
      allow update, delete: if isSignedIn()
        && resource.data.userId == request.auth.uid;
    }

    // User profiles: owner-only (created at registration,
    // registration_screen.dart:57-74; edited in edit_profile_screen.dart).
    match /users/{uid} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;
    }

    // Everything else is locked.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

5b. New file `storage.rules` — full contents:
```
rules_version = '2';

// No Storage paths are used by the app today: firebase_storage is declared in
// pubspec.yaml but has zero call sites in lib/ (verified by grep). Lock the
// bucket down entirely; open a scoped path (e.g. /profile_photos/{uid}) when
// a feature actually needs it.
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

5c. New file `firestore.indexes.json` — full contents (codifies the ONE existing composite index; nothing else may appear here):
```json
{
  "indexes": [
    {
      "collectionGroup": "noise_readings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

5d. New file `.firebaserc` — full contents:
```json
{
  "projects": {
    "default": "noise-pollution-mapper-9ad3d"
  }
}
```

5e. `firebase.json` — replace the whole file. BEFORE (single line, verbatim):
```json
{"flutter":{"platforms":{"android":{"default":{"projectId":"noise-pollution-mapper-9ad3d","appId":"1:185708456928:android:84881c81b95eafd4191985","fileOutput":"android/app/google-services.json"}},"dart":{"lib/firebase_options.dart":{"projectId":"noise-pollution-mapper-9ad3d","configurations":{"android":"1:185708456928:android:84881c81b95eafd4191985","ios":"1:185708456928:ios:2cac42f1845a4a6c191985","web":"1:185708456928:web:4ee8514096fc8dcc191985"}}}}}}
```

AFTER (flutterfire block preserved verbatim, rules/indexes wired):
```json
{
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "noise-pollution-mapper-9ad3d",
          "appId": "1:185708456928:android:84881c81b95eafd4191985",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "dart": {
        "lib/firebase_options.dart": {
          "projectId": "noise-pollution-mapper-9ad3d",
          "configurations": {
            "android": "1:185708456928:android:84881c81b95eafd4191985",
            "ios": "1:185708456928:ios:2cac42f1845a4a6c191985",
            "web": "1:185708456928:web:4ee8514096fc8dcc191985"
          }
        }
      }
    }
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  }
}
```

5f. Deploy commands (run by the user/CI — the commit only adds the files; deployment is a manual, deliberate action against the live project):
```
npm install -g firebase-tools        # once
firebase login                       # once, interactive
cd noise_pollution_mapper
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
```
- `firestore:indexes` deploy compares the manifest against live indexes and PROMPTS before deleting any index not listed. The manifest matches the single known index, so accept only if the listed deletion set is empty or contains genuinely unwanted indexes.
- `--only storage` fails if the default bucket was never provisioned; in that case skip it until Storage is enabled in the console.

**Edge cases to preserve (rules were checked against every Firestore call site in lib/):**
- Cross-user reads that MUST keep working (all post-login): community feed, map/heatmap (`getNoiseReadings*`), dashboard community count → covered by `allow read: if isSignedIn()`.
- `getUserReadingsCount` uses a `count()` aggregate → permitted by the same read rule.
- Edit-profile batch update of `userEmail` on own readings (edit_profile_screen.dart:133-139) → owner update, allowed.
- Delete-account batch rewriting `userId` to `deleted_user_*` (settings_screen_enhanced.dart:893-901) → allowed because ownership checks `resource.data`, not the incoming value.
- Registration writes `users/{uid}` immediately after `createUserWithEmailAndPassword` → request is authenticated, owner-only rule passes.
- No unauthenticated Firestore access exists in the app (login/splash query nothing before auth), so deploying these rules must not break any screen.

**Acceptance criteria**
- `firebase deploy --only firestore:rules` succeeds (rules compile server-side).
- Signed-in user: dashboard records, history paginates, community feed lists, CSV export works, profile edits save.
- Signed-out REST probe is denied, e.g.:
  `curl "https://firestore.googleapis.com/v1/projects/noise-pollution-mapper-9ad3d/databases/(default)/documents/noise_readings"` → `403 PERMISSION_DENIED`.
- Rules simulator (Firebase console → Firestore → Rules → Playground): create on `noise_readings` with `userId` != auth uid → denied; update of a doc whose `userId` != auth uid → denied.

**Verify**
```
flutter analyze                      # unchanged app code — must still be clean
firebase deploy --only firestore:rules
```
Then run the manual acceptance checks above (full logged-in smoke pass: Map=0, Analytics=1, Dashboard=2 record 30 s, History=3 + export, Settings=4).

**Commit title:** `feat(security): add Firestore/Storage rules, index manifest, and firebase.json wiring (sec-1)`

---

## Risks & rollback

- **Rules lockdown (Step 5) is the highest-risk change.** If any overlooked call path is unauthenticated or touches another user's doc for writes, it will start failing with `permission-denied` only at runtime. Mitigation: the smoke pass in Step 5 Verify covers every collection call site enumerated above. Rollback: redeploy permissive rules from the console's rules history (Firebase keeps prior versions) — no app release needed.
- **`firestore:indexes` deploy can delete live indexes** not present in the manifest. The prompt lists deletions — abort if anything unexpected appears. Rollback: recreate the index from the console (userId ASC, timestamp DESC) or from the error-message link of any failing query.
- **Step 1 changes save semantics visible to users** (offline now shows orange, failures show red). No data-path change; rollback is `git revert` of the commit.
- **Step 2 changes the content of new `noise_readings` docs** (`userEmail` now a display name/masked email; coords possibly rounded). Old docs are unmodified, and all readers (`community_feed_screen`, history list) tolerate both formats. Analytics/heatmaps see ≤110 m coordinate error only for users who opted in — that is the feature. Rollback: `git revert`; already-written masked docs stay masked (acceptable — strictly less PII).
- **Step 3** removes other users' data from the export — this is intentional (it was a data leak, not a feature). If a legitimate admin-export need exists, it belongs server-side, not in the client.
- **Step 4** freezes the "today" window per calendar day instead of per rebuild; midnight rollover is handled by the day check. Exact-midnight readings are excluded from the count (convention-consistent).
- **Test suite**: `flutter test` at repo level fails for pre-existing reasons (audit arch-2, 53 failures). Only the per-file test commands in each step gate these commits.

## Out of scope

- **Backfilling existing docs** that already contain raw `userEmail` values (and the edit-profile flow writing the raw new email into old readings, settings-9/account lifecycle) — covered by `audit/playbook/03_account_lifecycle.md`.
- **Switching the dashboard badge to a `count()` aggregate**: cloud_firestore 5.5.0 offers only one-shot `count().get()`, no aggregate stream; adopting it would drop the live badge. Revisit if community volume makes the snapshots payload expensive (then: cached `FutureBuilder` + refresh on resume).
- **`getReadingsByLocation` full-collection scan** (firebase_service.dart:243-255) — currently uncalled; flagged in the performance audit, not part of this cluster.
- **Delete-account batch >500 ops chunking** (arch-4) and the delete-ordering bug (sec-3/settings-1) — playbook 03.
- **Offline sync retry/UX overhaul** — `audit/playbook/02_offline_sync_overhaul.md` (Step 1 here intentionally only adds outcome reporting around the existing queue).
- **Server-side enforcement of coordinate rounding/masking** (rules cannot verify "anonymized enough"); client-side write-time enforcement plus locked-down rules is the accepted scope.
