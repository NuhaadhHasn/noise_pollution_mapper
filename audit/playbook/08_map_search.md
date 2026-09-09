# Playbook 08 — Map & Search defect cluster

Implementation spec for the "Map & Search" defect cluster. Written for an executing AI to apply **with zero additional analysis**. All BEFORE blocks are copied verbatim from the current source (verified 2026-07-18). Apply steps in order; each step is exactly one commit. Line numbers cited are for the *pre-change* files and drift after earlier steps — always match on the exact BEFORE text, never on line numbers.

**Project conventions enforced by every step (do not deviate):**

1. The ONLY Firestore composite index is `noise_readings (userId ASC, timestamp DESC)`. No step in this spec adds or changes any Firestore query — no new index is needed anywhere in this playbook.
2. All UI colors via `ThemeHelper.getX(context)` or existing `AppTheme` constants; `color.withValues(alpha:)`, never `withOpacity`.
3. Writes carry both `timestamp` (`FieldValue.serverTimestamp()`) and `createdAt` (client `DateTime`); readers handle both (Step 2 brings `HeatmapPoint.fromFirestore` into compliance).
4. `MainAppShell` IndexedStack tab indices: Map=0, Analytics=1, Dashboard=2, History=3, Settings=4.
5. Classification confidence target is 0.30 (not touched by this playbook).
6. `AppLogger` for logging, never `print`.
7. `flutter analyze` must be clean after **every** commit.

Run all commands from the project root: `C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper`.

---

## Scope

| ID | Status | One-liner |
|---|---|---|
| map-1 / uiux-4 | CONFIRMED | Cluster color key never matches: writer stores `'${lat}_$lng'` but reader interpolates `'$point.latitude_$point.longitude'` (Dart interpolates `point.toString()` + literal `.latitude_`), so `startsWith` never hits and every cluster is orange (`map_view_screen.dart:200` writer, `:685-694` reader). |
| flow3-1 | CONFIRMED | Heatmap reader expects `soundCategory` but every writer stores `soundClass` — classification always null on heatmap points; `filterBySoundCategory` always empty (`heatmap_point.dart:45`). |
| map-3 / uiux-6 | CONFIRMED | Search debounce guard compares raw input to lowercased stored query (`value == _searchQuery` where `_searchQuery = value.toLowerCase()`), so any uppercase input never triggers search-as-you-type (`search_list_screen.dart:287-296`). |
| map-4 | CONFIRMED (silent-failure part; "camera jump" part refuted by verifier) | `Geolocator.requestPermission()` result discarded; denied/deniedForever fail with only a log — no SnackBar, no settings deep-link — and the FAB unconditionally moves the camera to the stale `_currentLocation` after the failed await (`map_view_screen.dart:288-291`, `:1062-1064`). |
| map-2 / uiux-5 | CONFIRMED | Map data loads once in `initState`; the only refresh path is a `RefreshIndicator` wrapping a `Stack`/`FlutterMap` with no Scrollable descendant, so `onRefresh` is physically unreachable — markers/heatmap stale until app restart (`map_view_screen.dart:603`, screen lives permanently in the shell IndexedStack). |

Full finding text + verifier evidence: grep the IDs in `audit/01_BUGS_AND_CORRECTNESS.md` (map-1 §222, map-4 §486, map-3 §574), `audit/02_UI_UX_AUDIT.md` (uiux-4 §170, uiux-5 §126, uiux-6 §104), `audit/03_E2E_FLOW_AUDIT.md` (map-2 §420, flow3-1 §508).

## Pre-reading

Open these files before starting (read fully; the Stack/indentation structure of `map_view_screen.dart` matters for Step 5):

1. `lib/screens/map_view_screen.dart` (1474 lines — writer `_buildMarkersFromSnapshot`, cluster `builder:`, `_getCurrentLocation`, `RefreshIndicator` body, FAB column, `HeatmapPainter`)
2. `lib/screens/search_list_screen.dart` (onChanged debounce at lines 287-296)
3. `lib/models/heatmap_point.dart` (`fromFirestore` factory)
4. `lib/widgets/main_app_shell.dart` (59 lines, IndexedStack shell)
5. `lib/services/firebase_service.dart` lines 106-180 (writer field names `soundClass`/`timestamp`/`createdAt`; `getNoiseReadingsOnce`)
6. `lib/services/heatmap_service.dart` (`convertToHeatmapPoints`, `filterBySoundCategory`)
7. `lib/utils/theme_helper.dart` (available color getters)
8. `pubspec.yaml` (geolocator ^13.0.2, latlong2, flutter_test present; **there is currently NO `test/` directory** — Steps 1 and 2 create it)

API existence notes (verified against installed versions): `Geolocator.checkPermission()`, `Geolocator.requestPermission()`, `Geolocator.openAppSettings()`, and enum values `LocationPermission.denied` / `.deniedForever` all exist in geolocator 13.x (already imported in `map_view_screen.dart`). `listEquals` is exported via `package:flutter/material.dart` (already imported). `Timestamp` is a plain Dart class in cloud_firestore usable in unit tests without Firebase initialization. Dart records (`(Offset, double)`) have structural `==`, so `listEquals` over them is valid (SDK ^3.10.3).

---

## Steps

### Step 1 — map-1 / uiux-4: shared marker-key helper, exact cluster lookup, regression test

**Goal:** Make the cluster-color key writer and reader use one shared helper so the key formats can never drift apart again, fixing the always-orange clusters.

**Files:**
- NEW `lib/utils/marker_key.dart`
- `lib/screens/map_view_screen.dart`
- NEW `test/marker_key_test.dart`

**Exact changes:**

1. Create `lib/utils/marker_key.dart` with full contents:

```dart
/// Builds the lookup key linking a marker's coordinates to its noise level.
///
/// The marker writer (_buildMarkersFromSnapshot) and the cluster-color reader
/// (MarkerClusterLayerOptions.builder) in map_view_screen.dart MUST both use
/// this function. Audit finding map-1/uiux-4: the two sides previously built
/// keys with different string interpolations ('${lat}_$lng' vs the broken
/// '$point.latitude_...') so the lookup never matched and every cluster
/// rendered orange.
String markerNoiseKey(double latitude, double longitude) =>
    '${latitude}_$longitude';
```

2. In `lib/screens/map_view_screen.dart`, add the import after the existing `app_logger` import.

BEFORE:
```dart
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

AFTER:
```dart
import '../utils/app_logger.dart';
import '../utils/marker_key.dart';
import '../utils/theme_helper.dart';
```

3. Writer (inside `_buildMarkersFromSnapshot`, currently lines 199-201):

BEFORE:
```dart
      // Store noise level for cluster coloring
      final markerKey = '${lat}_$lng';
      _markerNoiseLevels[markerKey] = db;
```

AFTER:
```dart
      // Store noise level for cluster coloring (shared helper — marker_key.dart)
      _markerNoiseLevels[markerNoiseKey(lat, lng)] = db;
```

4. Reader (inside `MarkerClusterLayerOptions`, currently lines 681-694). This also replaces the O(N×M) `startsWith` scan with an exact map lookup.

BEFORE:
```dart
                        builder: (context, markers) {
                          // Extract noise levels for this cluster
                          final clusterNoiseLevels = markers.map((marker) {
                            final point = marker.point;
                            final key = _markerNoiseLevels.keys.firstWhere(
                              (k) => k.startsWith(
                                '$point.latitude_$point.longitude',
                              ),
                              orElse: () => '',
                            );
                            return key.isNotEmpty
                                ? _markerNoiseLevels[key]!
                                : 50.0;
                          }).toList();
```

AFTER:
```dart
                        builder: (context, markers) {
                          // Extract noise levels for this cluster via exact
                          // key lookup (same shared helper as the writer).
                          final clusterNoiseLevels = markers.map((marker) {
                            final point = marker.point;
                            return _markerNoiseLevels[markerNoiseKey(
                                  point.latitude,
                                  point.longitude,
                                )] ??
                                50.0;
                          }).toList();
```

5. Create `test/marker_key_test.dart` with full contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:noise_pollution_mapper/utils/marker_key.dart';

void main() {
  group('markerNoiseKey (regression for audit map-1/uiux-4)', () {
    test('writer and reader produce the identical key for the same point', () {
      const lat = 6.9271;
      const lng = 79.8612;
      // Writer side: keyed by raw doubles from Firestore.
      final noiseLevels = <String, double>{markerNoiseKey(lat, lng): 85.0};
      // Reader side: keyed from a flutter_map marker's LatLng.
      final point = LatLng(lat, lng);
      final db = noiseLevels[markerNoiseKey(point.latitude, point.longitude)];
      expect(db, 85.0);
    });

    test('key is lat_lng with no LatLng.toString() artifacts', () {
      final point = LatLng(1.5, 2.5);
      final key = markerNoiseKey(point.latitude, point.longitude);
      expect(key, '1.5_2.5');
      expect(key.contains('LatLng'), isFalse,
          reason: 'Unbraced \$point interpolation regression');
    });

    test('distinct coordinates produce distinct keys', () {
      expect(markerNoiseKey(1.0, 2.0), isNot(markerNoiseKey(2.0, 1.0)));
    });
  });
}
```

**Edge cases to preserve:**
- Markers with coordinates absent from `_markerNoiseLevels` (map cleared mid-rebuild) still fall back to `50.0` — the `?? 50.0` keeps that behavior.
- Two readings at *identical* coordinates still share one key (last write wins) — pre-existing behavior, unchanged; do not attempt to fix here.
- `_markerNoiseLevels.clear()` at the top of `_buildMarkersFromSnapshot` stays untouched.

**Acceptance criteria:**
- Zooming out over an area whose readings average ≥70 dB shows a **red** cluster pin; <50 dB average shows **green**; only genuine 50-70 dB averages show orange.
- No behavior change for individual (non-clustered) markers.

**Verify:**
```
flutter analyze
flutter test test/marker_key_test.dart
```
Manual: run the app with ≥2 readings above 70 dB close together (or temporarily seed `_markerNoiseLevels`), zoom out until they cluster, confirm the pin is red, not orange.

**Commit title:** `fix(map): cluster color key mismatch — shared markerNoiseKey helper + regression test`

---

### Step 2 — flow3-1: HeatmapPoint reads soundClass (with soundCategory fallback) + timestamp/createdAt reader compliance

**Goal:** Stop losing classification on every heatmap point by reading the field writers actually persist (`soundClass`), keeping `soundCategory` as a legacy fallback, and make the timestamp read handle both `timestamp` and `createdAt` per project convention 3.

**Files:**
- `lib/models/heatmap_point.dart`
- NEW `test/heatmap_point_test.dart`

**Exact changes:**

1. In `lib/models/heatmap_point.dart`, `fromFirestore` factory (currently lines 34-47):

BEFORE:
```dart
    // Weight based on recency (newer readings have higher weight)
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final weight = _calculateWeight(timestamp);

    return HeatmapPoint(
      latitude: latitude,
      longitude: longitude,
      intensity: intensity,
      weight: weight,
      decibelLevel: decibelLevel,
      timestamp: timestamp,
      soundCategory: data['soundCategory'] as String?,
    );
```

AFTER:
```dart
    // Weight based on recency (newer readings have higher weight).
    // Convention: writers store both 'timestamp' (FieldValue.serverTimestamp())
    // and 'createdAt' (client DateTime, stored as Timestamp) — readers handle
    // both, since 'timestamp' is null while a serverTimestamp is pending.
    final rawTimestamp = data['timestamp'];
    final rawCreatedAt = data['createdAt'];
    final timestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : rawCreatedAt is Timestamp
            ? rawCreatedAt.toDate()
            : DateTime.now();
    final weight = _calculateWeight(timestamp);

    return HeatmapPoint(
      latitude: latitude,
      longitude: longitude,
      intensity: intensity,
      weight: weight,
      decibelLevel: decibelLevel,
      timestamp: timestamp,
      // Audit flow3-1: writers persist classification under 'soundClass'
      // (firebase_service.dart, sync_service.dart). 'soundCategory' is kept
      // only as a legacy-document fallback.
      soundCategory:
          (data['soundClass'] ?? data['soundCategory']) as String?,
    );
```

2. Create `test/heatmap_point_test.dart` with full contents:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/models/heatmap_point.dart';

void main() {
  Map<String, dynamic> baseDoc() => {
        'decibelLevel': 82.0,
        'latitude': 6.9271,
        'longitude': 79.8612,
        'timestamp': Timestamp.fromDate(DateTime(2026, 7, 1)),
      };

  group('HeatmapPoint.fromFirestore (regression for audit flow3-1)', () {
    test('reads classification from soundClass (the writer field)', () {
      final point =
          HeatmapPoint.fromFirestore({...baseDoc(), 'soundClass': 'Traffic'});
      expect(point.soundCategory, 'Traffic');
    });

    test('falls back to legacy soundCategory field', () {
      final point = HeatmapPoint.fromFirestore(
          {...baseDoc(), 'soundCategory': 'Nature'});
      expect(point.soundCategory, 'Nature');
    });

    test('soundClass wins when both fields are present', () {
      final point = HeatmapPoint.fromFirestore({
        ...baseDoc(),
        'soundClass': 'Traffic',
        'soundCategory': 'Nature',
      });
      expect(point.soundCategory, 'Traffic');
    });

    test('null when neither classification field is present', () {
      final point = HeatmapPoint.fromFirestore(baseDoc());
      expect(point.soundCategory, isNull);
    });

    test('falls back to createdAt when timestamp is missing/pending', () {
      final created = DateTime(2026, 6, 15);
      final doc = baseDoc()
        ..remove('timestamp')
        ..['createdAt'] = Timestamp.fromDate(created);
      final point = HeatmapPoint.fromFirestore(doc);
      expect(point.timestamp, created);
    });

    test('intensity is normalized dB / 120', () {
      final point = HeatmapPoint.fromFirestore(baseDoc());
      expect(point.intensity, closeTo(82.0 / 120.0, 1e-9));
    });
  });
}
```

**Edge cases to preserve:**
- Docs with neither `timestamp` nor `createdAt` still default to `DateTime.now()` (weight 1.0) — preserved by the final `: DateTime.now()` branch.
- Docs where `soundClass` exists but is an empty string: `('' ?? ...)` yields `''`, same as the pre-change behavior for empty `soundCategory` — acceptable; `filterBySoundCategory` compares exact strings and `''` never equals a real category.
- `rawTimestamp is Timestamp` type-check (rather than a hard cast) means a legacy doc storing a String/int in either field degrades to the next fallback instead of throwing.

**Acceptance criteria:**
- For a reading saved with `soundClass: 'Traffic'`, the resulting `HeatmapPoint.soundCategory == 'Traffic'`, and `HeatmapService.filterBySoundCategory(points, category: 'Traffic')` returns it.
- Heatmap rendering (intensity/weight/positions) is unchanged for docs with a valid `timestamp`.

**Verify:**
```
flutter analyze
flutter test test/heatmap_point_test.dart
```

**Commit title:** `fix(heatmap): read soundClass with soundCategory fallback in HeatmapPoint + tests`

---

### Step 3 — map-3 / uiux-6: case-insensitive, cancellable search debounce

**Goal:** Make search-as-you-type fire for capitalized input by replacing the broken `value == _searchQuery` guard with a proper cancellable `Timer` debounce.

**Files:**
- `lib/screens/search_list_screen.dart`

**Exact changes:**

1. Add the `dart:async` import (first import block, currently lines 1-8):

BEFORE:
```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
```

AFTER:
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
```

2. Add the debounce field and cancel it in `dispose` (currently lines 21-33):

BEFORE:
```dart
  String _searchQuery = '';
  String _sortBy = 'noise'; // 'noise' or 'name'

  // Nominatim API search results
  List<Map<String, dynamic>> _nominatimResults = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
```

AFTER:
```dart
  String _searchQuery = '';
  String _sortBy = 'noise'; // 'noise' or 'name'

  // Debounce for search-as-you-type (audit map-3/uiux-6): cancelled and
  // restarted on every keystroke so only the final pause triggers a request.
  Timer? _searchDebounce;

  // Nominatim API search results
  List<Map<String, dynamic>> _nominatimResults = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
```

3. Replace the broken guard in `onChanged` (currently lines 287-296):

BEFORE:
```dart
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (value == _searchQuery) {
                          _searchWithNominatim(value);
                        }
                      });
                    },
```

AFTER:
```dart
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                      _searchDebounce?.cancel();
                      _searchDebounce =
                          Timer(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          _searchWithNominatim(value);
                        }
                      });
                    },
```

**Edge cases to preserve:**
- `_searchQuery` stays lowercased — it drives the UI conditions `_searchQuery.isEmpty` (grid visibility, line 134), `isNotEmpty` (clear button line 263, dismiss overlay line 231) and `length >= 3` (results section line 304). Do NOT change what is stored in `_searchQuery`.
- `_searchWithNominatim` receives the RAW `value` (original casing) — Nominatim queries are sent as typed, same as before.
- `onSubmitted` (immediate search on Enter) is untouched.
- Clearing via the suffix icon already resets `_searchQuery`/`_nominatimResults`; a pending timer that fires after clear calls `_searchWithNominatim` with the old text — same as pre-change `Future.delayed` behavior for lowercase input, and harmless (guard `query.trim().isEmpty` handles empty). The `mounted` check prevents setState-after-dispose if the user backs out during the 500 ms window (an improvement over the old code).

**Acceptance criteria:**
- Typing `Colombo` (capital C) in Search Cities shows the "Searching worldwide..." spinner ~500 ms after the last keystroke, then results — without pressing Enter.
- Typing rapidly fires at most one Nominatim request per pause (Timer cancellation), not one per keystroke.

**Verify:**
```
flutter analyze
```
Manual: open Map tab → history icon → Search Cities; type `Kandy` — results must appear without pressing Enter. Then type `colombo` (all lowercase) — still works. Check logcat/AppLogger for exactly one `Nominatim search for:` line per typing pause.

**Commit title:** `fix(search): case-insensitive Timer-based search debounce in SearchListScreen`

---

### Step 4 — map-4: consume location permission result; visible denied/deniedForever UI with settings deep-link

**Goal:** Handle `denied`/`deniedForever` explicitly with a SnackBar (and an "Open Settings" action for deniedForever), and only move the camera when a position was actually obtained.

**Files:**
- `lib/screens/map_view_screen.dart`

**Exact changes:**

1. Replace the whole `_getCurrentLocation` method (currently lines 266-327; the method starting `Future<void> _getCurrentLocation({bool forceRefresh = false}) async {` through its closing `}` after the `finally` block):

BEFORE:
```dart
  Future<void> _getCurrentLocation({bool forceRefresh = false}) async {
    // Prevent concurrent location requests (unless force refresh)
    if (!forceRefresh && _isGettingLocation) {
      AppLogger.debug('Map: Location request already in progress, skipping');
      return;
    }

    // Debounce rapid requests (except for force refresh)
    if (!forceRefresh) {
      final now = DateTime.now();
      if (_lastLocationRequestTime != null &&
          now.difference(_lastLocationRequestTime!) <
              _locationRequestDebounce) {
        AppLogger.debug('Map: Location request debounced (too soon)');
        return;
      }
    }

    _isGettingLocation = true;
    _lastLocationRequestTime = DateTime.now();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        _isGettingLocation = false;
        // Show native Android location settings dialog
        _showNativeLocationDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Move map to current location
        _mapController.move(_currentLocation, 13.0);
      }
    } catch (e) {
      AppLogger.error('Map: Error getting location', e);
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } finally {
      _isGettingLocation = false;
    }
  }
```

AFTER:
```dart
  /// Returns true only when a real position was obtained (audit map-4:
  /// denied/deniedForever must be surfaced, and callers must not move the
  /// camera on failure).
  Future<bool> _getCurrentLocation({bool forceRefresh = false}) async {
    // Prevent concurrent location requests (unless force refresh)
    if (!forceRefresh && _isGettingLocation) {
      AppLogger.debug('Map: Location request already in progress, skipping');
      return false;
    }

    // Debounce rapid requests (except for force refresh)
    if (!forceRefresh) {
      final now = DateTime.now();
      if (_lastLocationRequestTime != null &&
          now.difference(_lastLocationRequestTime!) <
              _locationRequestDebounce) {
        AppLogger.debug('Map: Location request debounced (too soon)');
        return false;
      }
    }

    _isGettingLocation = true;
    _lastLocationRequestTime = DateTime.now();

    if (!mounted) {
      _isGettingLocation = false;
      return false;
    }
    // Capture context-dependent values before async gaps
    final messenger = ScaffoldMessenger.of(context);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppLogger.info('Map: Location permission not granted ($permission)');
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                permission == LocationPermission.deniedForever
                    ? 'Location permission permanently denied. '
                          'Enable it in app settings to use your location.'
                    : 'Location permission denied.',
              ),
              backgroundColor: AppTheme.highNoise,
              duration: const Duration(seconds: 4),
              action: permission == LocationPermission.deniedForever
                  ? SnackBarAction(
                      label: 'Settings',
                      textColor: Colors.white,
                      onPressed: () {
                        Geolocator.openAppSettings();
                      },
                    )
                  : null,
            ),
          );
        }
        return false;
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        _isGettingLocation = false;
        // Show native Android location settings dialog
        _showNativeLocationDialog();
        return false;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Move map to current location
        _mapController.move(_currentLocation, 13.0);
      }
      return true;
    } catch (e) {
      AppLogger.error('Map: Error getting location', e);
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
      return false;
    } finally {
      _isGettingLocation = false;
    }
  }
```

2. The my-location FAB handler (currently lines 1059-1067) must only move the camera on success:

BEFORE:
```dart
                    FloatingActionButton(
                      heroTag: 'map_location_btn',
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      onPressed: () async {
                        await _getCurrentLocation(forceRefresh: true);
                        _mapController.move(_currentLocation, 13.0);
                      },
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
```

AFTER:
```dart
                    FloatingActionButton(
                      heroTag: 'map_location_btn',
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      onPressed: () async {
                        final located =
                            await _getCurrentLocation(forceRefresh: true);
                        // Only recenter when a real position was obtained
                        // (audit map-4: never fly to the stale default).
                        if (located) {
                          _mapController.move(_currentLocation, 13.0);
                        }
                      },
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
```

**Edge cases to preserve:**
- `_showNativeLocationDialog` (line 330) awaits `_getCurrentLocation(forceRefresh: true)` and ignores the result — that call site needs NO change (Dart allows awaiting a `Future<bool>` where the value is discarded).
- The concurrent-request guard and 30 s debounce return `false` without UI — correct, since the FAB always uses `forceRefresh: true` and bypasses both.
- `LocationPermission.whileInUse`, `.always`, and `.unableToDetermine` fall through to the service-enabled check and `getCurrentPosition()` exactly as before.
- The `finally { _isGettingLocation = false; }` reset must remain so a denied path never wedges the guard flag.
- Colors: `AppTheme.highNoise` is the project's themed red (same constant used for high-noise markers); `Colors.white` on a colored SnackBar matches `ThemeHelper.getButtonTextColor` and the file's existing on-color text convention. Do NOT use `withOpacity` anywhere.

**Acceptance criteria:**
- With permission previously denied ("Don't allow"): tapping the my-location FAB shows a red SnackBar "Location permission denied." (or the permanently-denied variant with a working **Settings** action that opens the OS app-settings page) and the camera does **not** move.
- With permission granted: FAB behavior is unchanged (camera moves to the obtained position at zoom 13).

**Verify:**
```
flutter analyze
```
Manual (Android emulator/device): 1) Deny location for the app in system settings ("Don't allow"), open Map, tap the my-location FAB → SnackBar with Settings action appears, camera stays put; tap Settings → app-settings page opens. 2) Grant permission, tap FAB → camera recenters on the device location.

**Commit title:** `fix(map): handle denied/deniedForever location permission with visible feedback`

---

### Step 5 — map-2 / uiux-5: reachable refresh — tab-activation reload, refresh FAB, remove dead RefreshIndicator

**Goal:** Give the map two working refresh paths — automatic reload when the Map tab is activated (covers "after new recording/deletion on other tabs") and a manual refresh FAB — and remove the physically unreachable `RefreshIndicator`.

**Files:**
- `lib/screens/map_view_screen.dart`
- `lib/widgets/main_app_shell.dart`

Design note: the state class becomes public (`MapViewScreenState`) so `MainAppShell` can hold a `GlobalKey<MapViewScreenState>` and call `refreshMapData()` on tab activation. This is the MainAppShell-callback option named in the audit's recommended fix; no `visibility_detector` dependency is added. Saves happen on Dashboard/Report and deletes on History — all other tabs — so tab-activation refresh covers the post-save/post-delete flows. `_loadNoiseMarkers`'s existing `_isLoadingMarkers` guard makes rapid re-triggers safe. The `HeatmapPainter.shouldRepaint` length-only comparison is also fixed here because the audit explicitly notes (01_BUGS_AND_CORRECTNESS.md:1438) that after fixing map-2, a reload replacing N points with N different points would otherwise skip repainting — the refresh would silently not render for the heatmap.

**Exact changes in `lib/screens/map_view_screen.dart`:**

1. Make the state class public.

BEFORE:
```dart
  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
```

AFTER:
```dart
  @override
  State<MapViewScreen> createState() => MapViewScreenState();
}

class MapViewScreenState extends State<MapViewScreen> {
```

(These are the only two occurrences of `_MapViewScreenState` in the codebase.)

2. Replace the now-orphaned private refresh helper with the public hook.

BEFORE:
```dart
  // Refresh both markers and heatmap (single query, for pull-to-refresh)
  Future<void> _refreshAllData() async {
    await _loadNoiseMarkers();
  }
```

AFTER:
```dart
  /// Public refresh hook — invoked by MainAppShell when the Map tab is
  /// activated and by the refresh FAB (audit map-2/uiux-5). Reloads markers
  /// and heatmap points from the same single Firestore query; re-entry is
  /// guarded by _isLoadingMarkers inside _loadNoiseMarkers.
  Future<void> refreshMapData() async {
    await _loadNoiseMarkers();
  }
```

3. Remove the dead `RefreshIndicator` — opening side:

BEFORE:
```dart
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        // FIXED: Pull-to-refresh instead of continuous StreamBuilder listening
        body: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Pull-to-refresh: Reloading markers and heatmap...');
            await _refreshAllData();
          },
          child: Stack(
```

AFTER:
```dart
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        // Refresh paths: tab activation (MainAppShell -> refreshMapData) and
        // the refresh FAB. A RefreshIndicator can never fire here because
        // FlutterMap consumes drag gestures and has no Scrollable descendant
        // (audit map-2/uiux-5), so it was removed.
        body: Stack(
```

4. Remove the dead `RefreshIndicator` — closing side. The body's closing brackets before `bottomNavigationBar` currently read (this exact sequence appears once, immediately before `bottomNavigationBar`):

BEFORE:
```dart
            ],
          ),
        ),
        bottomNavigationBar: null,
```

AFTER:
```dart
            ],
          ),
        bottomNavigationBar: null,
```

(One `)` removed — it belonged to the deleted `RefreshIndicator(`.) After edits 3 and 4, run `dart format lib/screens/map_view_screen.dart` to normalize the now-shallower indentation of the body subtree; formatting-only diff noise in this file is expected and acceptable in this commit.

5. Add the manual refresh FAB above the heatmap FAB in the bottom-right column:

BEFORE:
```dart
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heatmap FAB (toggles heatmap on/off)
                    HeatmapFab(
```

AFTER:
```dart
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Manual refresh FAB — reloads markers + heatmap
                    // (audit map-2/uiux-5: pull-to-refresh was unreachable).
                    FloatingActionButton(
                      heroTag: 'map_refresh_btn',
                      mini: true,
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await refreshMapData();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Map updated: ${_cachedMarkers.length} readings',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    // Heatmap FAB (toggles heatmap on/off)
                    HeatmapFab(
```

6. Fix `HeatmapPainter.shouldRepaint` so a reload with the same point count still repaints (`listEquals` is available via the existing `package:flutter/material.dart` import; `(Offset, double)` records compare structurally):

BEFORE:
```dart
  @override
  bool shouldRepaint(covariant HeatmapPainter old) =>
      old.opacity != opacity || old.screenPoints.length != screenPoints.length;
```

AFTER:
```dart
  @override
  bool shouldRepaint(covariant HeatmapPainter old) =>
      old.opacity != opacity || !listEquals(old.screenPoints, screenPoints);
```

**Exact changes in `lib/widgets/main_app_shell.dart`** — replace the FULL file contents with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen_enhanced.dart';
import 'shared_bottom_navbar.dart';

class MainAppShell extends StatefulWidget {
  final int initialIndex;

  const MainAppShell({super.key, this.initialIndex = 2});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;

  // Lets the shell trigger a map data reload when the Map tab is activated
  // (audit map-2/uiux-5). Tab indices: Map=0, Analytics=1, Dashboard=2,
  // History=3, Settings=4.
  final GlobalKey<MapViewScreenState> _mapKey =
      GlobalKey<MapViewScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            MapViewScreen(key: _mapKey, isInAppShell: true), // Index 0
            const AnalyticsScreen(isInAppShell: true), // Index 1
            const DashboardScreen(isInAppShell: true), // Index 2 (home)
            const HistoryScreen(isInAppShell: true), // Index 3
            const SettingsScreenEnhanced(isInAppShell: true), // Index 4
          ],
        ),
        bottomNavigationBar: SharedBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            final previousIndex = _currentIndex;
            setState(() {
              _currentIndex = index;
            });
            // Reload map data whenever the user lands on the Map tab so
            // recordings/deletions made on other tabs appear without an
            // app restart (audit map-2). Safe to call repeatedly:
            // _loadNoiseMarkers self-guards with _isLoadingMarkers.
            if (index == 0 && previousIndex != 0) {
              _mapKey.currentState?.refreshMapData();
            }
          },
        ),
      ),
    );
  }
}
```

**Edge cases to preserve:**
- The IndexedStack children can no longer be a `const` list (the map child carries a runtime GlobalKey) — the other four children keep individual `const` constructors, so they are still not rebuilt-from-scratch on tab switches, and IndexedStack still keeps all five states alive.
- `isInAppShell: true` stays on all five children (existing contract per app-architecture-reference).
- Re-tapping the already-active Map tab (`previousIndex == 0`) does NOT re-trigger a reload (guard `previousIndex != 0`).
- `_mapKey.currentState?.` null-safe call: on the very first frame the map state may not exist yet; `initState`'s own `_loadNoiseMarkers()` covers initial load.
- Firestore query is untouched: still `getNoiseReadingsOnce(limit: 100)` — `orderBy timestamp desc`, no composite-index implications.
- The refresh FAB captures the `ScaffoldMessenger` before the `await` (satisfies `use_build_context_synchronously`).
- Keep `heroTag` unique (`'map_refresh_btn'`) — two other Hero-tagged FABs exist on this screen.

**Acceptance criteria:**
- Record a reading on Dashboard, switch to the Map tab: the new marker appears within the reload (no app restart).
- Delete a reading in History, switch to Map: its marker is gone after the tab-activation reload.
- Tapping the refresh FAB reloads data and shows "Map updated: N readings"; with heatmap toggled on, heatmap blobs update even when the total point count is unchanged.
- Dragging the map still pans (no refresh indicator appears); search autocomplete overscroll no longer triggers any phantom refresh.

**Verify:**
```
dart format lib/screens/map_view_screen.dart
flutter analyze
flutter test
```
Manual: 1) Dashboard → record ≥1 reading → Map tab → new marker visible. 2) History → delete a reading → Map tab → marker gone. 3) Tap refresh FAB → SnackBar "Map updated: N readings". 4) Toggle heatmap on, tap refresh → blobs redraw. 5) Confirm AppLogger line `[Map] Loaded N markers + N heatmap points` on every tab activation into Map.

**Commit title:** `feat(map): reachable refresh — tab-activation reload, refresh FAB, remove dead RefreshIndicator`

---

## Risks & rollback

- **Step 5 is the only structurally risky step.** Removing the `RefreshIndicator` wrapper shifts bracket depth in a 470-line widget subtree; a mismatched `)` breaks the build immediately and loudly (compile error, caught by `flutter analyze`). Mitigation: apply edits 3 and 4 exactly as given (they remove one matched open/close pair), then `dart format`. Rollback: revert the single commit — no data or schema impact.
- **Public `MapViewScreenState`:** widens API surface; any future rename must update `main_app_shell.dart`. Low risk — single consumer.
- **Tab-activation reload adds one Firestore read (100 docs) per landing on the Map tab.** Bounded by `_isLoadingMarkers` re-entry guard and the existing `_kMapReadingLimit`. If read volume becomes a concern, add a min-interval throttle later (out of scope).
- **`shouldRepaint` via `listEquals`** is O(n) per frame comparison with n ≤ 100 — negligible; behavior change is strictly "repaints when it previously wrongly skipped".
- **Step 2 fallback ordering** (`soundClass` wins over legacy `soundCategory`): if any external/legacy doc has both fields with different values, the writer-canonical field now wins — intended.
- **Step 4 SnackBar on deniedForever** relies on `Geolocator.openAppSettings()`; on some OEM Android builds this opens the generic settings page instead of the app page — acceptable degradation.
- **No Firestore index risk anywhere:** no query in this playbook is added or modified; the single map query remains `orderBy('timestamp', descending: true).limit(100)` on an automatic single-field index.
- Rollback for every step: each is one self-contained commit; `git revert <sha>` restores prior behavior with no migration.

## Out of scope

- flow3-15 beyond the reader-side `createdAt` fallback done in Step 2 (writer-side audit of `createdAt` across sync_service/offline path).
- map-2's sibling issues in other tabs: History delete not updating local list (uiux-2), history pull-to-refresh empty-state (flow3-5) — covered by the History/Analytics playbook.
- Duplicate-coordinate key collision in `_markerNoiseLevels` (two readings at the exact same lat/lng share one entry) — pre-existing, unchanged by Step 1.
- Replacing the `_markerNoiseLevels` side-map with a Marker subclass carrying its dB (audit's "better" fix for map-1) — deliberate minimal fix instead.
- Nominatim request-generation/race handling for the map screen's autocomplete (`uiux` recommendation at 02_UI_UX_AUDIT.md:434) — only the SearchListScreen debounce (map-3) is in scope.
- Report screen's separate permission-handling defect (social-4) and Dashboard location flows.
- Any change to Firestore indexes, security rules, or query shapes.
- Wiring saves to push-refresh the map directly (ChangeNotifier/stream); tab-activation reload covers the user-visible flow.
