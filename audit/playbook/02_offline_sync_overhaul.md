# Implementation Spec — Defect Cluster 02: Offline Storage & Sync Overhaul

Target app: `noise_pollution_mapper/` (Flutter + Firebase + Hive).
Execute steps strictly in order. Each step is exactly one commit. `flutter analyze` must be clean after every commit.

All file paths below are relative to the project root `noise_pollution_mapper/`.

**Firestore index note (project convention 1):** NONE of the changes in this spec require a new composite index. The only composite index remains `noise_readings (userId ASC, timestamp DESC)`. No query shapes are changed — only write paths (`.doc(id).set()` instead of `.add()`, and a `Timestamp` value instead of `FieldValue.serverTimestamp()` on the offline-sync writer). Do NOT add any index.

**Package API verification (pubspec.yaml):** `cloud_firestore: ^5.5.0` provides `CollectionReference.doc(String).set(Map)`, `Timestamp.fromDate(DateTime)`, `FieldValue.serverTimestamp()`. `firebase_auth: ^5.3.3` provides `FirebaseAuth.authStateChanges()` returning `Stream<User?>`. `hive: ^2.2.3` dynamic boxes return `Map<dynamic, dynamic>` for map values read from disk and store `DateTime` natively. `connectivity_plus: ^6.1.0` `onConnectivityChanged` is `Stream<List<ConnectivityResult>>` (already handled). `unawaited` comes from `dart:async` (SDK ^3.10.3). All verified against the installed versions and current code.

---

## Scope

| Finding IDs | Status | One-line summary |
|---|---|---|
| offline-1 / flow2-1 | CONFIRMED (Critical) | Hive returns `Map<dynamic,dynamic>` after restart; `fromMap` implicit cast throws; queue permanently unsyncable (`lib/services/offline_storage_service.dart:93`) |
| offline-6 / flow2-2 / flow5-2 | CONFIRMED (High) | `OfflineRecording` has no `userId` field; recordings upload under whoever is logged in at sync time — cross-user attribution + privacy leak |
| offline-4 / flow5-3 | CONFIRMED (High) | Non-idempotent uploads: `.add()` auto-ID + mark-after-ack duplicates documents on retry (`lib/services/sync_service.dart:233`) |
| fb-2 / flow2-3 | CONFIRMED (High) | Offline-synced readings get sync time as `timestamp` (true time only in `createdAt`) AND omit `userEmail` that Community Feed / CSV export consume (`lib/services/sync_service.dart:211-220`) |
| offline-2 / flow2-7 | CONFIRMED (High) | After 3 failed attempts recordings are stranded forever — attempts never reset, no recovery surface (`lib/services/sync_service.dart:151`) |
| offline-3 | CONFIRMED (High) | Sync only fires on offline→online transition — never at startup, after login, or after a fallback offline save (`lib/services/sync_service.dart:83`) |

Full descriptions and verifier evidence: grep `audit/01_BUGS_AND_CORRECTNESS.md`, `audit/03_E2E_FLOW_AUDIT.md`, `audit/05_SECURITY_AUDIT.md` for each ID.

---

## Pre-reading

Open these files completely before touching anything:

1. `lib/models/offline_recording.dart` (105 lines — the model, `toMap`/`fromMap`/`copyWith`)
2. `lib/services/offline_storage_service.dart` (397 lines — Hive box access; note `getPendingSyncRecordings` at line 103 already does the `Map<String,dynamic>.from` conversion correctly, the other readers do not)
3. `lib/services/sync_service.dart` (291 lines — connectivity listener, sync loop, `_saveToFirebase`)
4. `lib/services/firebase_service.dart` (lines 1–162 — online save, offline save, fallback save paths; note the online writer at lines 117–133 writes `userEmail` and both `timestamp`/`createdAt`)
5. `lib/widgets/sync_status_indicator.dart` (280 lines — status dialog + Sync Now button)
6. `lib/utils/theme_helper.dart` (56 lines — will gain one getter in Step 6)
7. `lib/main.dart` lines 26–72 (`SyncService().initialize()` is called at line 51, before `runApp`)

Key facts your edits rely on:

- `OfflineRecording.id` is `'${DateTime.now().millisecondsSinceEpoch}_$userId'` (set in `firebase_service.dart:148`) — unique per reading, valid as a Firestore document ID, and carries the owner uid after the first `_` (used for legacy fallback in Step 2).
- Hive dynamic boxes persist `DateTime` values natively, so `map['timestamp']` comes back as `DateTime` after restart; the map itself comes back as `Map<dynamic, dynamic>` (root cause of offline-1).
- `_storage.getPendingCount()` counts ALL unsynced entries regardless of `syncAttempts`, so the "Sync Now" button in the dialog already appears for max-attempts-failed items (relevant to Step 6).
- `SyncService` is a singleton (`factory SyncService() => _instance`), safe to reference from `FirebaseService` (Step 7); `sync_service.dart` does not import `firebase_service.dart`, so no import cycle.

---

## Steps

### Step 1 — Fix Hive `Map<dynamic,dynamic>` deserialization so the queue survives app restart

**Finding IDs:** offline-1, flow2-1
**Goal:** Make `OfflineRecording.fromMap` accept the untyped maps Hive returns after a restart, and remove the two hard `as Map<String, dynamic>` casts in the storage service, so queued recordings load and sync after an app relaunch.

**Files:**
- `lib/models/offline_recording.dart`
- `lib/services/offline_storage_service.dart`
- `test/unit/offline_recording_test.dart` (new)

**Commit title:** `fix(offline): deserialize Hive maps safely so queue survives app restart`

**Exact changes:**

1a. `lib/models/offline_recording.dart` — replace the `fromMap` factory (lines 33–49).

BEFORE:
```dart
  /// Create from a map (for deserialization)
  factory OfflineRecording.fromMap(Map<String, dynamic> map) {
    return OfflineRecording(
      id: map['id'] as String,
      decibelLevel: (map['decibelLevel'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationName: map['locationName'] as String?,
      timestamp: map['timestamp'] as DateTime,
      soundClass: map['soundClass'] as String?,
      soundType: map['soundType'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      syncError: map['syncError'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
```

AFTER:
```dart
  /// Create from a map (for deserialization).
  /// Accepts Map<dynamic, dynamic> because Hive dynamic boxes return
  /// untyped maps for entries loaded from disk after an app restart
  /// (offline-1/flow2-1) — a Map<String, dynamic> parameter would throw
  /// an implicit-cast TypeError before the body even runs.
  factory OfflineRecording.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return OfflineRecording(
      id: map['id'] as String,
      decibelLevel: (map['decibelLevel'] as num).toDouble(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      locationName: map['locationName'] as String?,
      // Hive persists DateTime natively; the String branch is defensive
      // for any entry that was serialized through JSON.
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp'] as DateTime
          : DateTime.parse(map['timestamp'] as String),
      soundClass: map['soundClass'] as String?,
      soundType: map['soundType'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble(),
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      syncError: map['syncError'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
```

1b. `lib/services/offline_storage_service.dart` — `getQueuedRecordings` (lines 86–94): make the map call explicit.

BEFORE:
```dart
    final recordings = _recordingsBox!.values
        .where((v) {
          if (v is Map) {
            return !(v['isSynced'] as bool? ?? false);
          }
          return false;
        })
        .map((v) => OfflineRecording.fromMap(v))
        .toList();
```

AFTER:
```dart
    final recordings = _recordingsBox!.values
        .where((v) {
          if (v is Map) {
            return !(v['isSynced'] as bool? ?? false);
          }
          return false;
        })
        .map((v) => OfflineRecording.fromMap(v as Map))
        .toList();
```

1c. `lib/services/offline_storage_service.dart` — `getAllOfflineRecordings` (lines 213–222): remove the hard cast.

BEFORE:
```dart
  /// Get all offline recordings (including synced)
  List<OfflineRecording> getAllOfflineRecordings() {
    if (!_isInitialized) {
      return [];
    }
    return _recordingsBox!.values
        .whereType<Map>()
        .map((v) => OfflineRecording.fromMap(v as Map<String, dynamic>))
        .toList();
  }
```

AFTER:
```dart
  /// Get all offline recordings (including synced)
  List<OfflineRecording> getAllOfflineRecordings() {
    if (!_isInitialized) {
      return [];
    }
    return _recordingsBox!.values
        .whereType<Map>()
        .map((v) => OfflineRecording.fromMap(v))
        .toList();
  }
```

1d. `lib/services/offline_storage_service.dart` — `getRecording` (lines 224–232): remove the hard cast.

BEFORE:
```dart
  /// Get a specific recording by ID
  OfflineRecording? getRecording(String id) {
    if (!_isInitialized) return null;
    final data = _recordingsBox!.get(id);
    if (data is Map) {
      return OfflineRecording.fromMap(data as Map<String, dynamic>);
    }
    return null;
  }
```

AFTER:
```dart
  /// Get a specific recording by ID
  OfflineRecording? getRecording(String id) {
    if (!_isInitialized) return null;
    final data = _recordingsBox!.get(id);
    if (data is Map) {
      return OfflineRecording.fromMap(data);
    }
    return null;
  }
```

1e. NEW FILE `test/unit/offline_recording_test.dart` — full contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/models/offline_recording.dart';

void main() {
  group('OfflineRecording.fromMap', () {
    Map<dynamic, dynamic> hiveStyleMap() {
      // Deliberately Map<dynamic, dynamic>: this is what a Hive dynamic box
      // returns for entries loaded from disk after an app restart.
      return <dynamic, dynamic>{
        'id': '1700000000000_userA',
        'decibelLevel': 72.5,
        'latitude': 6.9271,
        'longitude': 79.8612,
        'locationName': 'Colombo',
        'timestamp': DateTime(2026, 7, 1, 8, 30),
        'soundClass': 'Traffic',
        'soundType': 'Pollution',
        'confidence': 0.42,
        'syncAttempts': 1,
        'syncError': null,
        'isSynced': false,
      };
    }

    test('parses an untyped Map<dynamic, dynamic> as returned by Hive '
        'after restart (offline-1/flow2-1)', () {
      final rec = OfflineRecording.fromMap(hiveStyleMap());

      expect(rec.id, '1700000000000_userA');
      expect(rec.decibelLevel, 72.5);
      expect(rec.latitude, 6.9271);
      expect(rec.longitude, 79.8612);
      expect(rec.locationName, 'Colombo');
      expect(rec.timestamp, DateTime(2026, 7, 1, 8, 30));
      expect(rec.soundClass, 'Traffic');
      expect(rec.confidence, 0.42);
      expect(rec.syncAttempts, 1);
      expect(rec.isSynced, false);
    });

    test('round-trips through toMap/fromMap', () {
      final original = OfflineRecording(
        id: '1700000000001_userB',
        decibelLevel: 55.0,
        latitude: 1.0,
        longitude: 2.0,
        timestamp: DateTime(2026, 7, 2, 9, 15),
      );

      final restored = OfflineRecording.fromMap(
        // Simulate Hive's type erasure on the round trip.
        Map<dynamic, dynamic>.from(original.toMap()),
      );

      expect(restored.id, original.id);
      expect(restored.decibelLevel, original.decibelLevel);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isSynced, false);
      expect(restored.syncAttempts, 0);
    });

    test('parses ISO-8601 string timestamps defensively', () {
      final map = hiveStyleMap();
      map['timestamp'] = '2026-07-01T08:30:00.000';

      final rec = OfflineRecording.fromMap(map);
      expect(rec.timestamp, DateTime(2026, 7, 1, 8, 30));
    });
  });
}
```

**Edge cases to preserve:**
- `getPendingSyncRecordings` (line 103) already converts with `Map<String, dynamic>.from` — leave it untouched.
- `markRecordingAsSynced`, `incrementSyncAttempts`, `markAsSynced`, `updateSyncStatus` operate on raw maps, not `fromMap` — leave untouched.
- `fromMap` must still work for freshly written entries (typed `Map<String, dynamic>` — a subtype of `Map<dynamic, dynamic>`, so all existing call sites remain valid).

**Acceptance criteria:**
- Recording saved offline, app killed and relaunched, then connectivity restored → `getQueuedRecordings()` returns the entries instead of throwing `_Map<dynamic, dynamic> is not a subtype of Map<String, dynamic>`, and sync uploads them.
- No call site of `OfflineRecording.fromMap` performs an `as Map<String, dynamic>` cast anymore (`grep -n "as Map<String, dynamic>" lib/` returns nothing in the offline path).

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
(Do NOT run the full `flutter test` suite as a gate — audit finding arch-2 documents 53 pre-existing failures unrelated to this cluster.)
Manual: run the app, enable airplane mode, record a reading (Dashboard tab = index 2 in MainAppShell), force-kill the app, relaunch, disable airplane mode → the pending badge clears and the reading appears in Firestore.

---

### Step 2 — Add `userId`/`userEmail` to `OfflineRecording` and populate them at save time

**Finding IDs:** offline-6, flow2-2, flow5-2 (part 1 of 2) — also provides `userEmail` needed by fb-2/flow2-3 in Step 5
**Goal:** Persist the recording owner's uid and email in every queued entry so sync can attribute correctly, with a legacy fallback that parses the uid out of the existing `'${ms}_$uid'` id format.

**Files:**
- `lib/models/offline_recording.dart`
- `lib/services/firebase_service.dart`
- `test/unit/offline_recording_test.dart`

**Commit title:** `feat(offline): store userId/userEmail on OfflineRecording at save time`

**Exact changes:**

2a. `lib/models/offline_recording.dart` — fields + constructor (lines 4–31, as left by Step 1).

BEFORE:
```dart
class OfflineRecording {
  final String id;
  final double decibelLevel;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime timestamp;
  final String? soundClass;
  final String? soundType;
  final double? confidence;
  final int syncAttempts;
  final String? syncError;
  final bool isSynced;

  OfflineRecording({
    required this.id,
    required this.decibelLevel,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.timestamp,
    this.soundClass,
    this.soundType,
    this.confidence,
    this.syncAttempts = 0,
    this.syncError,
    this.isSynced = false,
  });
```

AFTER:
```dart
class OfflineRecording {
  final String id;
  final double decibelLevel;
  final double latitude;
  final double longitude;
  final String? locationName;
  final DateTime timestamp;
  final String? soundClass;
  final String? soundType;
  final double? confidence;
  final int syncAttempts;
  final String? syncError;
  final bool isSynced;

  /// Uid of the user who recorded this reading (offline-6/flow2-2/flow5-2).
  /// Nullable only for legacy queue entries written before this field
  /// existed; fromMap falls back to parsing the id suffix for those.
  final String? userId;

  /// Email of the user who recorded this reading — written to Firestore at
  /// sync time so offline-synced docs match the online writer's shape.
  final String? userEmail;

  OfflineRecording({
    required this.id,
    required this.decibelLevel,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.timestamp,
    this.soundClass,
    this.soundType,
    this.confidence,
    this.syncAttempts = 0,
    this.syncError,
    this.isSynced = false,
    this.userId,
    this.userEmail,
  });
```

2b. Same file — inside the `fromMap` factory body (as rewritten in Step 1), add the two fields to the returned constructor call.

BEFORE (last three lines of the constructor call inside `fromMap`):
```dart
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      syncError: map['syncError'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }
```

AFTER:
```dart
      syncAttempts: map['syncAttempts'] as int? ?? 0,
      syncError: map['syncError'] as String?,
      isSynced: map['isSynced'] as bool? ?? false,
      userId:
          map['userId'] as String? ?? _userIdFromLegacyId(map['id'] as String?),
      userEmail: map['userEmail'] as String?,
    );
  }

  /// Legacy queue entries have no stored userId, but their id was always
  /// built as '${millisecondsSinceEpoch}_$userId' (firebase_service.dart),
  /// so the owner uid can be recovered from everything after the first '_'.
  static String? _userIdFromLegacyId(String? id) {
    if (id == null) return null;
    final sep = id.indexOf('_');
    if (sep <= 0 || sep >= id.length - 1) return null;
    return id.substring(sep + 1);
  }
```

2c. Same file — `toMap` (lines 52–67).

BEFORE:
```dart
      'syncAttempts': syncAttempts,
      'syncError': syncError,
      'isSynced': isSynced,
    };
  }
```

AFTER:
```dart
      'syncAttempts': syncAttempts,
      'syncError': syncError,
      'isSynced': isSynced,
      'userId': userId,
      'userEmail': userEmail,
    };
  }
```

2d. Same file — `copyWith` (lines 69–98).

BEFORE:
```dart
  OfflineRecording copyWith({
    String? id,
    double? decibelLevel,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? timestamp,
    String? soundClass,
    String? soundType,
    double? confidence,
    int? syncAttempts,
    String? syncError,
    bool? isSynced,
  }) {
    return OfflineRecording(
      id: id ?? this.id,
      decibelLevel: decibelLevel ?? this.decibelLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timestamp: timestamp ?? this.timestamp,
      soundClass: soundClass ?? this.soundClass,
      soundType: soundType ?? this.soundType,
      confidence: confidence ?? this.confidence,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      isSynced: isSynced ?? this.isSynced,
    );
  }
```

AFTER:
```dart
  OfflineRecording copyWith({
    String? id,
    double? decibelLevel,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? timestamp,
    String? soundClass,
    String? soundType,
    double? confidence,
    int? syncAttempts,
    String? syncError,
    bool? isSynced,
    String? userId,
    String? userEmail,
  }) {
    return OfflineRecording(
      id: id ?? this.id,
      decibelLevel: decibelLevel ?? this.decibelLevel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      timestamp: timestamp ?? this.timestamp,
      soundClass: soundClass ?? this.soundClass,
      soundType: soundType ?? this.soundType,
      confidence: confidence ?? this.confidence,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      syncError: syncError ?? this.syncError,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
    );
  }
```

2e. `lib/services/firebase_service.dart` — `_saveOffline` (lines 137–162): populate the new fields.

BEFORE:
```dart
    final recording = OfflineRecording(
      id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
      decibelLevel: decibelLevel,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      timestamp: DateTime.now(),
      soundClass: soundClass,
      soundType: soundType,
      confidence: confidence,
      syncAttempts: 0,
      isSynced: false,
    );
```

AFTER:
```dart
    final recording = OfflineRecording(
      id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
      decibelLevel: decibelLevel,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      timestamp: DateTime.now(),
      soundClass: soundClass,
      soundType: soundType,
      confidence: confidence,
      syncAttempts: 0,
      isSynced: false,
      userId: userId,
      userEmail: _auth.currentUser?.email,
    );
```

2f. `test/unit/offline_recording_test.dart` — append this group inside `main()` (after the existing group):

```dart
  group('OfflineRecording userId/userEmail', () {
    test('stored userId and userEmail survive the toMap/fromMap round trip',
        () {
      final original = OfflineRecording(
        id: '1700000000002_userC',
        decibelLevel: 61.0,
        latitude: 3.0,
        longitude: 4.0,
        timestamp: DateTime(2026, 7, 3),
        userId: 'userC',
        userEmail: 'c@example.com',
      );

      final restored = OfflineRecording.fromMap(
        Map<dynamic, dynamic>.from(original.toMap()),
      );
      expect(restored.userId, 'userC');
      expect(restored.userEmail, 'c@example.com');
    });

    test('legacy entry without userId falls back to parsing the id suffix',
        () {
      final legacy = <dynamic, dynamic>{
        'id': '1700000000000_abc123XYZ',
        'decibelLevel': 70.0,
        'latitude': 1.0,
        'longitude': 2.0,
        'locationName': null,
        'timestamp': DateTime(2026, 7, 1),
        'syncAttempts': 0,
        'isSynced': false,
        // no userId / userEmail keys at all
      };

      final rec = OfflineRecording.fromMap(legacy);
      expect(rec.userId, 'abc123XYZ');
      expect(rec.userEmail, isNull);
    });

    test('stored userId wins over the id-suffix fallback', () {
      final map = <dynamic, dynamic>{
        'id': '1700000000000_wrongUser',
        'decibelLevel': 70.0,
        'latitude': 1.0,
        'longitude': 2.0,
        'timestamp': DateTime(2026, 7, 1),
        'userId': 'rightUser',
        'isSynced': false,
      };
      expect(OfflineRecording.fromMap(map).userId, 'rightUser');
    });

    test('malformed legacy id yields null userId (never a wrong owner)', () {
      final map = <dynamic, dynamic>{
        'id': 'no-separator-here',
        'decibelLevel': 70.0,
        'latitude': 1.0,
        'longitude': 2.0,
        'timestamp': DateTime(2026, 7, 1),
        'isSynced': false,
      };
      expect(OfflineRecording.fromMap(map).userId, isNull);
    });
  });
```

**Edge cases to preserve:**
- Legacy queued entries (written before this commit) have no `userId`/`userEmail` keys — `fromMap` must not throw and must recover the uid from the id suffix.
- Firebase uids never contain `_`? Not guaranteed in general — that is why `substring(sep + 1)` takes everything AFTER the FIRST underscore (the millisecond prefix never contains one), which is always the complete uid.
- `userEmail` can legitimately be null (anonymous-style accounts); all consumers already null-coalesce (`?? 'Anonymous'`, `?? 'N/A'`).

**Acceptance criteria:**
- A reading queued offline stores `userId` and `userEmail` in the Hive map (visible via debug log of `toMap()`).
- Old queue entries still deserialize and report the correct owner uid.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: airplane mode → record a reading → breakpoint/log in `saveOfflineRecording` shows `userId` and `userEmail` keys in the persisted map.

---

### Step 3 — Sync uploads under the recording owner; skip foreign queue entries

**Finding IDs:** offline-6, flow2-2, flow5-2 (part 2 of 2)
**Goal:** Upload each recording under its stored owner uid and never upload entries queued by a different (or unresolvable) user, leaving them queued for their owner.

**Files:**
- `lib/services/sync_service.dart`

**Commit title:** `fix(sync): upload recordings under their owner and skip foreign queue entries`

**Exact changes:**

3a. `lib/services/sync_service.dart` — sync loop (lines 149–162).

BEFORE:
```dart
      for (final recording in queuedRecordings) {
        // Check if max attempts exceeded
        if (recording.syncAttempts >= maxSyncAttempts) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: Max sync attempts ($maxSyncAttempts) exceeded',
          );
          continue;
        }

        try {
          AppLogger.debug('[SyncService] Syncing recording: ${recording.id}');

          // Save to Firebase
          await _saveToFirebase(recording, user.uid);
```

AFTER:
```dart
      for (final recording in queuedRecordings) {
        // Check if max attempts exceeded
        if (recording.syncAttempts >= maxSyncAttempts) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: Max sync attempts ($maxSyncAttempts) exceeded',
          );
          continue;
        }

        // Never upload another user's queued recording
        // (offline-6/flow2-2/flow5-2). Foreign entries stay queued until
        // their owner signs in; entries with no resolvable owner are
        // skipped so they are never mis-attributed.
        final ownerId = recording.userId;
        if (ownerId == null || ownerId != user.uid) {
          AppLogger.warning(
            '[SyncService] Skipping ${recording.id}: queued by '
            '${ownerId ?? "unknown user"}, current user is ${user.uid}. '
            'Leaving in queue for its owner.',
          );
          continue;
        }

        try {
          AppLogger.debug('[SyncService] Syncing recording: ${recording.id}');

          // Save to Firebase under the recording owner's uid
          await _saveToFirebase(recording, ownerId);
```

**Edge cases to preserve:**
- Foreign entries must NOT have `syncAttempts` incremented (the guard `continue`s before the try/catch) — they are not failures.
- The pending badge (`getPendingCount`) will keep counting foreign entries while the other user is signed in. That is intentional: data is preserved, not dropped. Do not "fix" this by deleting them.
- `clearSyncedRecordings()` only removes `isSynced == true` entries, so foreign entries survive the post-sync cleanup. Leave that behavior.
- Because the guard guarantees `ownerId == user.uid`, `_saveToFirebase`'s `userId` parameter now always receives the true owner uid — no signature change needed.

**Acceptance criteria:**
- With user A's entries queued and user B signed in, sync uploads nothing, logs one skip warning per entry, and the entries remain in Hive.
- When user A signs back in (and Step 7's login trigger lands), A's entries upload with `userId == A.uid`.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: record offline as user A → logout → login as user B → go online → tap Sync Now (SyncStatusIndicator dialog) → Firestore shows no new docs for B; logs show the "Leaving in queue for its owner" warnings.

---

### Step 4 — Idempotent uploads via deterministic Firestore document IDs

**Finding IDs:** offline-4, flow5-3
**Goal:** Replace `.add()` (auto-ID) with `.doc(recording.id).set(...)` so a retried upload overwrites the same document instead of duplicating it, and only count a recording as synced when the local mark actually succeeded.

**Files:**
- `lib/services/sync_service.dart`

**Commit title:** `fix(sync): make uploads idempotent with deterministic Firestore doc IDs`

**Exact changes:**

4a. `lib/services/sync_service.dart` — end of `_saveToFirebase` (line 233).

BEFORE:
```dart
    await _firestore.collection('noise_readings').add(data);
  }
```

AFTER:
```dart
    // Deterministic document ID (offline-4/flow5-3): recording.id is unique
    // per reading, so a retry after a lost ack overwrites the same document
    // instead of creating a duplicate.
    await _firestore.collection('noise_readings').doc(recording.id).set(data);
  }
```

4b. Same file — success path inside the sync loop (lines 164–168, unchanged by Step 3).

BEFORE:
```dart
          // Mark as synced in local storage
          await _storage.markAsSynced(recording.id);
          syncedCount++;

          AppLogger.info('[SyncService] Successfully synced: ${recording.id}');
```

AFTER:
```dart
          // Mark as synced in local storage. Only count it if the local
          // mark succeeded; otherwise it stays queued and the retry is
          // harmless because the upload is idempotent (same doc ID).
          final marked = await _storage.markAsSynced(recording.id);
          if (marked) {
            syncedCount++;
            AppLogger.info('[SyncService] Successfully synced: ${recording.id}');
          } else {
            AppLogger.warning(
              '[SyncService] Uploaded ${recording.id} but failed to mark it '
              'synced locally; it will be retried idempotently',
            );
          }
```

**Edge cases to preserve:**
- `recording.id` (`'<ms>_<uid>'`) contains only digits, letters, and `_` — a valid Firestore document ID. No sanitization needed.
- `.set()` without `SetOptions` fully replaces the doc — correct here (retries write identical data).
- Firestore security rules: `create` permission also covers `set()` on a new doc ID; if the project's rules ever restrict `update`, a genuine retry-after-commit performs an update on an identical doc — if rules errors appear in testing, allow update-by-owner on `noise_readings`. (No rules file exists in this repo; this is a deploy-side note, not a code change.)
- Docs written by the ONLINE path (`firebase_service.dart:133`) still use `.add()` auto-IDs — that path has no retry loop, so it is out of scope here; do not change it.

**Acceptance criteria:**
- Killing the app mid-sync and relaunching produces exactly one Firestore document per recording (doc ID equals the Hive queue key).
- A recording whose upload succeeded but whose local mark failed is retried and does not duplicate.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: queue 3 readings offline → go online → immediately force-kill during sync → relaunch → after full sync, Firestore contains exactly 3 docs whose IDs match the recording IDs.

---

### Step 5 — Synced docs carry the true recording time and the userEmail

**Finding IDs:** fb-2, flow2-3
**Goal:** Write the recording's capture time (not sync time) into the `timestamp` field and include `userEmail`, so offline-synced documents have the same shape and temporal meaning as online-written ones.

**Files:**
- `lib/services/sync_service.dart`

**Commit title:** `fix(sync): write true recording time and userEmail on synced readings`

**Exact changes:**

5a. `lib/services/sync_service.dart` — data map in `_saveToFirebase` (lines 211–220, unchanged by Steps 3–4).

BEFORE:
```dart
    final data = <String, dynamic>{
      'userId': userId,
      'decibelLevel': recording.decibelLevel,
      'latitude': recording.latitude,
      'longitude': recording.longitude,
      'locationName': recording.locationName ?? 'Unknown Location',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': recording.timestamp,
      'deviceInfo': 'Mobile Device',
    };
```

AFTER:
```dart
    final data = <String, dynamic>{
      'userId': userId,
      'userEmail': recording.userEmail ?? _auth.currentUser?.email,
      'decibelLevel': recording.decibelLevel,
      'latitude': recording.latitude,
      'longitude': recording.longitude,
      'locationName': recording.locationName ?? 'Unknown Location',
      // fb-2/flow2-3: the true capture time, NOT the sync time. This is a
      // deliberate, documented deviation from the serverTimestamp
      // convention: serverTimestamp() here would stamp the moment of sync,
      // putting offline readings on the wrong day in analytics/history/
      // heatmap. createdAt keeps the client DateTime per the dual-write
      // convention, so readers that handle both fields stay correct.
      'timestamp': Timestamp.fromDate(recording.timestamp),
      'createdAt': recording.timestamp,
      'deviceInfo': 'Mobile Device',
    };
```

**Edge cases to preserve:**
- `FieldValue` import stays (`cloud_firestore` is already imported; `Timestamp` comes from the same package). After this change `FieldValue` may become unused in this file — if `flutter analyze` flags an unused import warning it will not, because the import is the whole package; nothing to remove.
- Keep `'createdAt': recording.timestamp` exactly as-is — readers use it as fallback (dual timestamp convention, memory: readers handle both).
- All period queries still use `isGreaterThan` + `orderBy timestamp descending` on the existing `(userId ASC, timestamp DESC)` index — a `Timestamp` value sorts identically to server-written timestamps; NO new index is needed.
- Device clock skew: an offline device with a wrong clock now propagates that clock to `timestamp`. Accepted trade-off (the audit verifier confirmed this is strictly better than stamping sync time).

**Acceptance criteria:**
- Record offline at time T, sync at time T+N hours → the Firestore doc's `timestamp` equals T (as a `Timestamp`), `createdAt` equals T, and `userEmail` is populated; Community Feed shows the user's email-derived name instead of "Anonymous"; History/Analytics bucket the reading at T.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: airplane mode → record at a noted wall-clock time → wait 10+ minutes → go online, sync → open Firestore console: `timestamp` shows the recording time, not the sync time; open History tab (index 3) and confirm the row shows the recording time; CSV export shows the email.

---

### Step 6 — Reset failed attempts on reconnect/manual sync and surface failed uploads

**Finding IDs:** offline-2, flow2-7
**Goal:** Recordings that hit the 3-attempt cap get their attempts reset whenever connectivity is regained or the user taps Sync Now, and the sync dialog shows a distinct "Failed Uploads" row so the state is never invisible.

**Files:**
- `lib/services/offline_storage_service.dart`
- `lib/services/sync_service.dart`
- `lib/utils/theme_helper.dart`
- `lib/widgets/sync_status_indicator.dart`

**Commit title:** `feat(sync): reset failed attempts and surface failed uploads with retry`

**Exact changes:**

6a. `lib/services/offline_storage_service.dart` — insert two new methods immediately after `updateSyncStatus` (after line 282, before `deleteRecording`):

```dart
  /// Count of unsynced recordings that have reached [maxAttempts] failed
  /// sync attempts (offline-2/flow2-7 dead-letter surface).
  int getFailedCount(int maxAttempts) {
    if (!_isInitialized) return 0;

    int count = 0;
    for (final key in _recordingsBox!.keys.toList()) {
      final value = _recordingsBox!.get(key);
      if (value is Map &&
          !(value['isSynced'] as bool? ?? false) &&
          (value['syncAttempts'] as int? ?? 0) >= maxAttempts) {
        count++;
      }
    }
    return count;
  }

  /// Reset syncAttempts on every unsynced recording that reached
  /// [maxAttempts], making them eligible for sync again. Returns the number
  /// of recordings reset (offline-2/flow2-7).
  Future<int> resetFailedSyncAttempts(int maxAttempts) async {
    if (!_isInitialized) return 0;

    int resetCount = 0;
    try {
      for (final key in _recordingsBox!.keys.toList()) {
        final value = _recordingsBox!.get(key);
        if (value is Map &&
            !(value['isSynced'] as bool? ?? false) &&
            (value['syncAttempts'] as int? ?? 0) >= maxAttempts) {
          final map = Map<String, dynamic>.from(value);
          map['syncAttempts'] = 0;
          map['syncError'] = null;
          await _recordingsBox!.put(key, map);
          resetCount++;
        }
      }
      if (resetCount > 0) {
        AppLogger.info(
          '[OfflineStorage] Reset sync attempts on $resetCount failed recordings',
        );
      }
      return resetCount;
    } catch (e) {
      AppLogger.error('[OfflineStorage] Failed to reset sync attempts', e);
      return resetCount;
    }
  }
```

6b. `lib/services/sync_service.dart` — connectivity handler (lines 82–90): route the back-online path through a helper that resets attempts first.

BEFORE:
```dart
      // If we just came online and have pending recordings, trigger sync
      if (!wasOnline && _isOnline) {
        AppLogger.info('[SyncService] Back online! Checking for pending syncs...');
        final pendingCount = _storage.getPendingCount();
        if (pendingCount > 0) {
          AppLogger.info('[SyncService] Found $pendingCount pending recordings. Starting sync...');
          syncOfflineRecordings();
        }
      }
```

AFTER:
```dart
      // If we just came online and have pending recordings, trigger sync
      if (!wasOnline && _isOnline) {
        AppLogger.info('[SyncService] Back online! Checking for pending syncs...');
        _handleBackOnline();
      }
```

6c. Same file — insert the helper immediately after `_onConnectivityChanged` (after line 96):

```dart
  /// On connectivity restoration, give previously max-attempts-failed
  /// recordings another chance (offline-2/flow2-7), then sync anything
  /// pending. New connection == new circumstances, so the old failures
  /// are no longer meaningful.
  Future<void> _handleBackOnline() async {
    await _storage.resetFailedSyncAttempts(maxSyncAttempts);
    final pendingCount = _storage.getPendingCount();
    if (pendingCount > 0) {
      AppLogger.info(
        '[SyncService] Found $pendingCount pending recordings. Starting sync...',
      );
      await syncOfflineRecordings();
    }
  }
```

6d. Same file — `triggerManualSync` (lines 236–243): Sync Now always retries failed items.

BEFORE:
```dart
  /// Manually trigger sync (user-initiated)
  Future<int> triggerManualSync() async {
    if (!_isOnline) {
      AppLogger.warning('[SyncService] Cannot manually sync while offline');
      return 0;
    }
    return await syncOfflineRecordings();
  }
```

AFTER:
```dart
  /// Manually trigger sync (user-initiated). Explicit user intent resets
  /// the attempt counter on dead-lettered recordings so "Sync Now" always
  /// retries everything (offline-2/flow2-7).
  Future<int> triggerManualSync() async {
    if (!_isOnline) {
      AppLogger.warning('[SyncService] Cannot manually sync while offline');
      return 0;
    }
    await _storage.resetFailedSyncAttempts(maxSyncAttempts);
    return await syncOfflineRecordings();
  }
```

6e. Same file — `getSyncStatus` (lines 246–263): expose the failed count.

BEFORE:
```dart
      return {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'pendingCount': getPendingCount(),
        'lastSyncTime': _storage.getLastSyncTimeSync(), // Use sync version
      };
    } catch (e) {
      AppLogger.error('[SyncService] Error getting sync status', e);
      return {
        'isOnline': false,
        'isSyncing': false,
        'pendingCount': 0,
        'lastSyncTime': null,
      };
    }
```

AFTER:
```dart
      return {
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
        'pendingCount': getPendingCount(),
        'failedCount': _storage.getFailedCount(maxSyncAttempts),
        'lastSyncTime': _storage.getLastSyncTimeSync(), // Use sync version
      };
    } catch (e) {
      AppLogger.error('[SyncService] Error getting sync status', e);
      return {
        'isOnline': false,
        'isSyncing': false,
        'pendingCount': 0,
        'failedCount': 0,
        'lastSyncTime': null,
      };
    }
```

6f. `lib/utils/theme_helper.dart` — add one getter before the closing brace (after `getButtonTextColor`, line 55):

```dart
  // Get error color
  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }
```

6g. `lib/widgets/sync_status_indicator.dart` — import ThemeHelper (line 3 area).

BEFORE:
```dart
import '../services/sync_service.dart';
import '../utils/app_logger.dart';
```

AFTER:
```dart
import '../services/sync_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

6h. Same file — `_showSyncStatusDialog` (lines 148–152): read failedCount.

BEFORE:
```dart
  Future<void> _showSyncStatusDialog(BuildContext context) async {
    final isOnline = _syncStatus['isOnline'] as bool? ?? false;
    final isSyncing = _syncStatus['isSyncing'] as bool? ?? false;
    final pendingCount = _syncStatus['pendingCount'] as int? ?? 0;
    final lastSyncTime = _syncStatus['lastSyncTime'] as DateTime?; // Already sync now
```

AFTER:
```dart
  Future<void> _showSyncStatusDialog(BuildContext context) async {
    final isOnline = _syncStatus['isOnline'] as bool? ?? false;
    final isSyncing = _syncStatus['isSyncing'] as bool? ?? false;
    final pendingCount = _syncStatus['pendingCount'] as int? ?? 0;
    final failedCount = _syncStatus['failedCount'] as int? ?? 0;
    final lastSyncTime = _syncStatus['lastSyncTime'] as DateTime?; // Already sync now
```

6i. Same file — add a "Failed Uploads" row after the Pending row (lines 179–185).

BEFORE:
```dart
            // Pending count
            _buildStatusRow(
              'Pending Uploads:',
              '$pendingCount recording(s)',
              pendingCount > 0 ? Icons.upload_file : Icons.check_circle,
              pendingCount > 0 ? Colors.orange : Colors.green,
            ),
```

AFTER:
```dart
            // Pending count
            _buildStatusRow(
              'Pending Uploads:',
              '$pendingCount recording(s)',
              pendingCount > 0 ? Icons.upload_file : Icons.check_circle,
              pendingCount > 0 ? Colors.orange : Colors.green,
            ),
            if (failedCount > 0) ...[
              const SizedBox(height: 12),
              // Dead-lettered recordings (offline-2/flow2-7): visible and
              // recoverable — "Sync Now" resets their attempts and retries.
              _buildStatusRow(
                'Failed Uploads:',
                '$failedCount recording(s) — Sync Now will retry them',
                Icons.error_outline,
                ThemeHelper.getErrorColor(context),
              ),
            ],
```

**Edge cases to preserve:**
- `getPendingCount()` already includes max-attempts items, so the existing "Sync Now" button condition (`pendingCount > 0 && isOnline && !isSyncing`) already shows the button for failed-only queues — do not change the condition.
- Do NOT auto-reset attempts inside `syncOfflineRecordings()` itself — that would turn the cap into an infinite hot loop on a captive portal. Resets happen only on (a) an offline→online transition and (b) explicit user tap.
- The existing hardcoded `Colors.orange`/`Colors.green` in this widget are pre-existing; do not refactor them in this commit (analyze must stay clean, scope stays tight). All NEW color usage goes through `ThemeHelper.getErrorColor(context)` per convention, and any alpha use must be `withValues(alpha:)`, never `withOpacity`.

**Acceptance criteria:**
- A recording with `syncAttempts >= 3` shows in the dialog as a red "Failed Uploads" row; tapping Sync Now uploads it and the row disappears.
- Toggling airplane mode off (offline→online) automatically retries previously dead recordings without user action.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: simulate 3 failures (e.g. temporarily point the device at a network with no internet / captive portal so connectivity reports online while Firestore writes fail, or set `maxSyncAttempts` to 0 locally for a moment — revert before commit) → dialog shows the Failed row → restore real internet → toggle airplane mode → recording syncs.

---

### Step 7 — Trigger sync at startup, on login, and after a fallback offline save

**Finding IDs:** offline-3
**Goal:** Kick a sync in the three confirmed dead spots: service initialization while already online, user sign-in, and the fallback path where a reading was queued although the device believes it is online.

**Files:**
- `lib/services/sync_service.dart`
- `lib/services/firebase_service.dart`

**Commit title:** `feat(sync): trigger sync at startup, on login, and after fallback saves`

**Exact changes:**

7a. `lib/services/sync_service.dart` — add an auth subscription field (lines 21–24).

BEFORE:
```dart
  bool _isInitialized = false;
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
```

AFTER:
```dart
  bool _isInitialized = false;
  bool _isOnline = false;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _authSubscription;
```

(`User` is already available via the existing `package:firebase_auth/firebase_auth.dart` import.)

7b. Same file — end of `initialize()` (lines 63–65): startup + login triggers.

BEFORE:
```dart
      _isInitialized = true;
      AppLogger.info('[SyncService] Initialized successfully');
      return true;
```

AFTER:
```dart
      _isInitialized = true;
      AppLogger.info('[SyncService] Initialized successfully');

      // offline-3: a fresh launch that is already online never fires an
      // offline→online transition, and neither does signing in. Listen to
      // auth state (fires immediately with the current user, including the
      // restored session at startup) and sync when a user is present.
      _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);

      // Belt-and-braces startup check for the case where auth restore has
      // already completed before this listener attaches.
      if (_isOnline && _storage.getPendingCount() > 0) {
        AppLogger.info(
          '[SyncService] Startup: pending recordings found while online. Starting sync...',
        );
        unawaited(syncOfflineRecordings());
      }
      return true;
```

7c. Same file — insert after `_handleBackOnline` (added in Step 6):

```dart
  /// Sync pending recordings when a user signs in (offline-3). The stream
  /// also fires once on listen with the restored session, covering startup.
  void _onAuthStateChanged(User? user) {
    if (user == null) return;
    if (_isOnline && _storage.getPendingCount() > 0) {
      AppLogger.info(
        '[SyncService] User ${user.uid} signed in with pending recordings. Starting sync...',
      );
      unawaited(syncOfflineRecordings());
    }
  }

  /// Called by FirebaseService after a recording was queued although the
  /// device believes it is online (fallback save after a failed direct
  /// write, offline-3). Kicks a sync instead of waiting for the next
  /// offline→online transition.
  void notifyQueued() {
    if (_isInitialized && _isOnline && !_isSyncing) {
      unawaited(syncOfflineRecordings());
    }
  }
```

(`unawaited` is exported by `dart:async`, which is already imported at line 1. Double-triggering is safe: `syncOfflineRecordings` no-ops when `_isSyncing` is true, and a signed-out state no-ops at the `user == null` guard inside it.)

7d. Same file — `dispose()` (lines 285–290): cancel the auth subscription.

BEFORE:
```dart
  void dispose() {
    _connectivitySubscription?.cancel();
    _storage.close();
    _isInitialized = false;
    AppLogger.info('[SyncService] Disposed');
  }
```

AFTER:
```dart
  void dispose() {
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
    _storage.close();
    _isInitialized = false;
    AppLogger.info('[SyncService] Disposed');
  }
```

7e. `lib/services/firebase_service.dart` — import SyncService (lines 1–6).

BEFORE:
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
import '../utils/app_logger.dart';
import '../models/offline_recording.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';
```

(No import cycle: `sync_service.dart` imports `offline_storage_service.dart` only, never `firebase_service.dart`.)

7f. Same file — fallback save path (lines 72–90): notify after queuing.

BEFORE:
```dart
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
```

AFTER:
```dart
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
          // offline-3: the device thinks it is online (the direct write just
          // failed transiently) — kick a sync now rather than waiting for the
          // next offline→online transition. Bounded by maxSyncAttempts.
          SyncService().notifyQueued();
        }
      } catch (fallbackError) {
        AppLogger.error('[FirebaseService] Fallback offline save also failed', fallbackError);
      }
```

**Edge cases to preserve:**
- Do NOT call `notifyQueued()` in the plain offline branch (line 56–69) — the device is offline there and `notifyQueued` would no-op anyway; the offline→online transition covers it.
- No retry storm: fallback save → notifyQueued → sync attempt fails → `syncAttempts` increments with the 5s `syncRetryDelay`, capped at `maxSyncAttempts` — bounded, no recursion (the sync path never calls `saveNoiseReading`).
- `main.dart:51` runs `SyncService().initialize()` before `runApp` — at that point auth session restore may or may not have completed; the `authStateChanges()` listener covers both orderings. Do not move the `initialize()` call.
- SyncService is a process-lifetime singleton — `dispose()` is effectively never called in production; the auth subscription cancel is for correctness/tests only.

**Acceptance criteria:**
- Record offline → force-quit → relaunch on wifi (no connectivity transition): sync runs automatically within seconds of startup and the pending badge clears.
- User A's entries queued, A logs back in while online: sync runs without toggling airplane mode or opening the dialog.
- A transiently-failed online save (queued via fallback) uploads within the same session without any connectivity change.

**Verify:**
```
flutter analyze
flutter test test/unit/offline_recording_test.dart
```
Manual: (1) airplane mode → record → kill app → airplane off → relaunch → watch logs for "Startup: pending recordings found" / auth-listener sync and confirm the badge clears without touching anything. (2) log out with entries queued, log back in → logs show "signed in with pending recordings".

---

## Risks & rollback

- **Chained diffs:** Steps 3–7 edit overlapping regions of `sync_service.dart`. Apply strictly in order; each BEFORE block above reflects the file state after all previous steps.
- **Legacy queue entries:** Entries written before Step 2 lack `userId`. The id-suffix fallback recovers the owner for every id produced by the current code (`'<ms>_<uid>'`). An entry whose id is malformed yields `userId == null` and is skipped with a log — it remains in Hive (no data destroyed) and can be recovered manually if ever needed. Rollback: revert the commit; old entries were never mutated.
- **Timestamp convention deviation (Step 5):** The offline-sync writer intentionally uses `Timestamp.fromDate(recording.timestamp)` instead of `FieldValue.serverTimestamp()`. This is confined to `SyncService._saveToFirebase`; the online writer keeps `serverTimestamp()`. Readers are unaffected (both are `Timestamp`s in Firestore). Device clock skew now propagates into `timestamp` for offline readings — accepted per the audit verifier. Rollback: revert Step 5's commit only; document shape stays valid either way.
- **Deterministic doc IDs (Step 4):** If Firestore security rules are later tightened, ensure owners may `create`/`update` docs in `noise_readings` (a retried `set()` on an already-committed doc is an update). No rules file exists in this repo today.
- **New sync triggers (Step 7):** More sync entry points mean more concurrent-trigger opportunities; all are serialized by the existing `_isSyncing` guard. Worst case a trigger is dropped (returns 0) — the next trigger picks the queue up. Rollback: revert Step 7's commit; behavior returns to transition-only sync.
- **No new Firestore index** is required by any step; if a future change to this area adds a filtered query (e.g. per-user failed-entry queries against Firestore), it must reuse `userId == X` + `timestamp isGreaterThan` + `orderBy timestamp descending` on the existing index — never `isGreaterThanOrEqualTo`.
- **Test suite:** Gate each commit on `flutter analyze` + `flutter test test/unit/offline_recording_test.dart` only. The full suite has 53 pre-existing failures (audit arch-2) — do not attempt to fix them here and do not let them block these commits.

## Out of scope

Explicitly NOT addressed here (separate findings, mostly unverified — do not drive-by fix):

- offline-8 (no upload timeout / mid-batch online re-check), offline-9 (`last_sync_time` saved on zero-synced runs), offline-10 (per-item try/catch around `fromMap` in queue readers), offline-11 (captive-portal/interface-only connectivity detection), offline-12 (Hive corruption recovery on `openBox`), offline-15 (ignored `onTap` param in SyncStatusIndicator), offline-16 (millisecond id collision)
- fb-1 (silent error swallowing in `saveNoiseReading` — the fallback+notify in Step 7 narrows but does not fix it), sec-2 (email/PII exposure in shared docs)
- Refactoring the pre-existing hardcoded `Colors.*` in `sync_status_indicator.dart`
- The online writer's `.add()` auto-ID path in `firebase_service.dart:133` (no retry loop → no duplication risk)
- Clearing/partitioning the queue on logout (suggested by offline-6's audit note; skip-foreign in Step 3 makes it unnecessary for correctness)
- Any `firestore.indexes.json` change (none exists in the repo; none is needed)
