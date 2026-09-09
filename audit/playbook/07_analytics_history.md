# Playbook 07 — Analytics & History Correctness

Implementation spec for the "Analytics & History Correctness" defect cluster.
Written for zero-additional-analysis execution: every change below has line-accurate
BEFORE/AFTER blocks copied from the current code (as of 2026-07-18). Apply steps
**in order** — Step 3's BEFORE state assumes Step 1 has already been applied.

**Project conventions this spec enforces (do not deviate):**

1. The ONLY Firestore composite index is `noise_readings (userId ASC, timestamp DESC)`.
   Every period query uses `isGreaterThan` + `orderBy('timestamp', descending: true)`.
   **No step in this spec changes any query or needs a new index** —
   `firestore.indexes.json` is untouched.
2. All UI colors via `ThemeHelper.getX(context)` or existing `AppTheme` constants;
   `color.withValues(alpha: …)`, never `withOpacity`.
3. Writes carry both `timestamp` (`FieldValue.serverTimestamp()`) and `createdAt`
   (client `DateTime`); readers handle both. The undo/restore in Step 6 re-writes the
   *original* document data verbatim, so both fields are preserved as originally written.
4. MainAppShell IndexedStack tabs: Map=0, Analytics=1, Dashboard=2, History=3, Settings=4
   (relevant for manual verification steps).
5. Readings are saved every **5 seconds** while recording
   (`lib/screens/dashboard_screen.dart:487` — `Timer.periodic(const Duration(seconds: 5), …)`).
   This is the basis of the Duration fix. (Classification confidence target 0.30 is not
   touched by this spec.)
6. `AppLogger` (`lib/utils/app_logger.dart`) for all logging — never `print`.
7. `flutter analyze` must be clean after **every** commit.

---

## Scope

| ID | One-line | Status |
|---|---|---|
| fb-6 / flow3-7 | Duration stat = `count/12` but readings save every 5 s → ~60x overstatement (`analytics_screen.dart:163`) | CONFIRMED |
| analytics-2 | Weekly/Monthly trend buckets use rolling 24 h windows (`difference().inDays`) while x-axis labels claim calendar days → readings attributed to the wrong weekday (`analytics_screen.dart:210`) | CONFIRMED |
| analytics-3 / flow3-4 | Stats/pie/breakdown loaded once in `initState` while the trend chart live-updates → same screen shows contradictory data (`analytics_screen.dart:47,122`) | CONFIRMED |
| perf-4 | The same unbounded period query is fetched three times per load (stream + `calculateStatsByPeriod` + `getUserReadingsByPeriodOnce`) (`analytics_screen.dart:122`) | CONFIRMED |
| fb-3 | History load permanently deadlocks when `userId` is null: `_isLoading` stuck `true` blocks all retries (`history_screen.dart:87`) | CONFIRMED |
| social-2 / uiux-7 | Hard cast `data['decibelLevel'] as num` crashes the whole list when the field is missing (`history_screen.dart:451`) | CONFIRMED |
| social-3 / uiux-2 / flow3-3 | Delete leaves the item visible, count stale, no error handling, no undo (`history_screen.dart:721`) | CONFIRMED |
| flow3-5 | History empty state is not scrollable, so pull-to-refresh can never fire (`history_screen.dart:403`) | CONFIRMED |

## Pre-reading

Open these files in full before starting:

- `lib/screens/analytics_screen.dart` (1158 lines — Steps 1–3)
- `lib/screens/history_screen.dart` (739 lines — Steps 4–7)
- `lib/services/firebase_service.dart` lines 200–320 (period queries, pagination, count — Steps 3 and 6)
- `lib/utils/app_logger.dart` (AppLogger API: `error(String, [dynamic error, StackTrace?])`)
- `lib/theme/app_theme.dart` (confirm `AppTheme.highNoise` const-ness — see Step 6 note)
- `pubspec.yaml` (cloud_firestore ^5.5.0, fl_chart ^0.70.1, flutter_test present; **no `test/` directory exists yet** — Step 2 creates it)
- `lib/screens/dashboard_screen.dart` lines 485–490 (confirms the 5 s save cadence)
- Audit context: grep `audit/*.md` for the IDs above (roadmap: `audit/08_IMPROVEMENTS_ROADMAP.md`, detail tables: `audit/01_BUGS_AND_CORRECTNESS.md`)

Facts verified against the installed packages (do not re-derive):

- `Query.snapshots()` in cloud_firestore 5.x returns a **broadcast** stream — the existing
  in-file comment at `analytics_screen.dart:118-121` already relies on this. Step 3's extra
  `listen()` alongside the chart's `StreamBuilder` is therefore safe.
- `_recordings` is `List<DocumentSnapshot>`; the `DocumentSnapshot<Map<String, dynamic>>`
  returned by `.doc(id).get()` is assignable to its element type (Step 6 undo).
- `SnackBarAction`, `AlwaysScrollableScrollPhysics`, `LayoutBuilder`, `ConstrainedBox`
  are standard Flutter widgets — no new dependencies anywhere in this spec.
- Only `analytics_screen.dart` calls `calculateStatsByPeriod` /
  `getUserReadingsByPeriodOnce` (verified by grep) — Step 3 orphans them safely.

---

## Steps

### Step 1 — Fix Duration stat: 5 seconds per reading (fb-6 / flow3-7)

**Goal:** Duration shows `count × 5 s` converted to hours instead of `count / 12` (which assumed one reading per 5 minutes), and renders with one decimal so sub-hour sessions don't display as "0 h".

**Files:** `lib/screens/analytics_screen.dart`

**Exact changes**

1a. Line 163, inside the `setState` at the end of `_loadStatistics()`:

BEFORE:
```dart
        _avgDb = stats['avg'] ?? 0;
        _minDb = stats['min'] ?? 0;
        _maxDb = stats['max'] ?? 0;
        _totalHours = (stats['count'] ?? 0) / 12;
```

AFTER:
```dart
        _avgDb = stats['avg'] ?? 0;
        _minDb = stats['min'] ?? 0;
        _maxDb = stats['max'] ?? 0;
        // fb-6/flow3-7: one reading is saved every 5 s while recording
        // (dashboard _saveTimer), so hours = count * 5 s / 3600.
        _totalHours = (stats['count'] ?? 0) * 5 / 3600;
```

1b. Lines 1127–1140, `_buildStatCard` — add an optional `decimals` parameter:

BEFORE:
```dart
  Widget _buildStatCard(
      String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${value.toStringAsFixed(0)} $unit',
```

AFTER:
```dart
  Widget _buildStatCard(
      String label, double value, String unit, Color color,
      {int decimals = 0}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${value.toStringAsFixed(decimals)} $unit',
```

1c. Lines 372–373, the Duration stat card in `build()`:

BEFORE:
```dart
                      _buildStatCard(
                          'Duration', _totalHours, 'h', AppTheme.accentPurple),
```

AFTER:
```dart
                      _buildStatCard(
                          'Duration', _totalHours, 'h', AppTheme.accentPurple,
                          decimals: 1),
```

**Edge cases to preserve**
- `stats['count']` counts only docs with a parseable `decibelLevel` (see
  `calculateStatsByPeriod`, `firebase_service.dart:314`) — keep using `count`, not
  `totalDocs`, so corrupt docs don't inflate duration.
- Average/Lowest/Highest cards keep their current 0-decimal rendering (`decimals`
  defaults to 0 — do not pass it at their call sites).

**Acceptance criteria**
- With 720 readings in the period (= 1 hour of recording at 5 s cadence), the Duration
  card shows "1.0 h" (previously "60 h").
- With 12 readings (1 minute), it shows "0.0 h", not "1 h".

**Verify**
```
flutter analyze
```
Manual: record ~2 minutes on the Dashboard tab (index 2), open Analytics (index 1),
Daily period → Duration ≈ 0.0 h (24 readings × 5 s = 120 s = 0.03 h), not 2 h.

**Commit title:** `fix(analytics): Duration stat uses 5s-per-reading math (fb-6, flow3-7)`

---

### Step 2 — Bucket trend chart by calendar day / clock hour (analytics-2)

**Goal:** Weekly/Monthly buckets align to calendar dates (midnight boundaries) and Daily buckets to clock hours, so readings land under the weekday / date / hour the x-axis label claims — extracted as pure top-level functions with a unit test.

**Files:** `lib/screens/analytics_screen.dart`, `test/analytics_buckets_test.dart` (new)

**Exact changes**

2a. Insert two top-level functions in `analytics_screen.dart` immediately **before**
`class AnalyticsScreen extends StatefulWidget {` (line 11), i.e. after the imports:

BEFORE (lines 9–11):
```dart
import '../utils/theme_helper.dart';

class AnalyticsScreen extends StatefulWidget {
```

AFTER:
```dart
import '../utils/theme_helper.dart';

/// Maps a reading time to a Daily-chart bucket index (0 = 23 clock-hours ago,
/// 23 = the current clock hour), or null if outside the 24-bucket window.
/// Buckets are aligned to clock hours so they match the "HHh" x-axis labels
/// (analytics-2) — NOT rolling 60-minute windows.
/// Top-level (not a State member) so it is unit-testable.
int? dailyBucketFor(DateTime now, DateTime readingTime) {
  final currentHour = DateTime(now.year, now.month, now.day, now.hour);
  final readingHour = DateTime(
      readingTime.year, readingTime.month, readingTime.day, readingTime.hour);
  final hoursAgo = currentHour.difference(readingHour).inHours;
  if (hoursAgo < 0 || hoursAgo > 23) return null;
  return 23 - hoursAgo;
}

/// Maps a reading time to a Weekly/Monthly-chart bucket index
/// (0 = [maxDays] calendar days ago, [maxDays] = today), or null if outside
/// the window. Buckets are aligned to calendar dates (midnight boundaries)
/// so they match the weekday / "MMM d" x-axis labels (analytics-2) — NOT
/// rolling 24-hour windows.
int? dayBucketFor(DateTime now, DateTime readingTime, int maxDays) {
  final today = DateTime(now.year, now.month, now.day);
  final readingDay =
      DateTime(readingTime.year, readingTime.month, readingTime.day);
  final daysAgo = today.difference(readingDay).inDays;
  if (daysAgo < 0 || daysAgo > maxDays) return null;
  return maxDays - daysAgo;
}

class AnalyticsScreen extends StatefulWidget {
```

2b. Lines 204–216, inside `_buildTimeAggregatedSpots` — replace the rolling-window
bucket computation:

BEFORE:
```dart
      final int bucket;
      if (_selectedPeriod == 'Daily') {
        final hoursAgo = now.difference(readingTime).inHours;
        if (hoursAgo > 23) continue;
        bucket = 23 - hoursAgo;
      } else {
        final daysAgo = now.difference(readingTime).inDays;
        final maxDays = _selectedPeriod == 'Monthly' ? 29 : 6;
        if (daysAgo > maxDays) continue;
        bucket = maxDays - daysAgo;
      }

      buckets[bucket] = (buckets[bucket] ?? [])..add(db);
```

AFTER:
```dart
      final int? bucket;
      if (_selectedPeriod == 'Daily') {
        bucket = dailyBucketFor(now, readingTime);
      } else {
        final maxDays = _selectedPeriod == 'Monthly' ? 29 : 6;
        bucket = dayBucketFor(now, readingTime, maxDays);
      }
      if (bucket == null) continue;

      buckets[bucket] = (buckets[bucket] ?? [])..add(db);
```
(Dart promotes the local `final int? bucket` to `int` after the null check — no `!` needed.)

2c. New file `test/analytics_buckets_test.dart` — full contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/analytics_screen.dart';

void main() {
  group('dayBucketFor (weekly, maxDays = 6)', () {
    // Saturday 2026-07-18 14:30 local time.
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading earlier today lands in the last bucket (today)', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 18, 0, 5), 6), 6);
    });

    test('reading late yesterday lands in bucket 5 even though <24h ago', () {
      // 23:50 yesterday is only ~14.7 h before now — the old rolling-window
      // code put this reading in TODAY's bucket (analytics-2).
      expect(dayBucketFor(now, DateTime(2026, 7, 17, 23, 50), 6), 5);
    });

    test('reading 6 calendar days ago lands in bucket 0', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 12, 9, 0), 6), 0);
    });

    test('reading 7 calendar days ago is outside the window', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 11, 23, 59), 6), isNull);
    });

    test('future reading (clock skew) is rejected, not mis-bucketed', () {
      expect(dayBucketFor(now, DateTime(2026, 7, 19, 1, 0), 6), isNull);
    });
  });

  group('dayBucketFor (monthly, maxDays = 29)', () {
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading 29 calendar days ago lands in bucket 0', () {
      expect(dayBucketFor(now, DateTime(2026, 6, 19, 23, 0), 29), 0);
    });

    test('reading 30 calendar days ago is outside the window', () {
      expect(dayBucketFor(now, DateTime(2026, 6, 18, 12, 0), 29), isNull);
    });
  });

  group('dailyBucketFor', () {
    final now = DateTime(2026, 7, 18, 14, 30);

    test('reading in the current clock hour lands in bucket 23', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 18, 14, 5)), 23);
    });

    test('reading in the previous clock hour lands in bucket 22', () {
      // 13:55 is only 35 min before now, but belongs to the 13h label bucket.
      expect(dailyBucketFor(now, DateTime(2026, 7, 18, 13, 55)), 22);
    });

    test('reading 23 clock hours ago lands in bucket 0', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 17, 15, 10)), 0);
    });

    test('reading 24+ clock hours ago is outside the window', () {
      expect(dailyBucketFor(now, DateTime(2026, 7, 17, 13, 59)), isNull);
    });
  });
}
```

**Edge cases to preserve**
- Keep the existing dB sanity filter above the bucket code untouched
  (`if (db == null || !db.isFinite || db < 0 || db > 120) continue;`).
- Keep the timestamp resolution untouched — it already handles both `timestamp`
  and `createdAt` (convention 3).
- Do NOT change `_getPeriodStartDate()` or any Firestore query: the query window
  (rolling `now - 24h/7d/30d`, `isGreaterThan` + `orderBy desc`) is intentionally a
  superset of the chart window; the new `null` return safely drops readings between
  the calendar window edge and the query edge. The composite index is untouched
  (convention 1).
- Do NOT change `_getXAxisWidget` — its labels (`now.subtract(Duration(days: daysAgo))`)
  are weekday/date-of-day computations that now agree with calendar bucketing.

**Acceptance criteria**
- A reading recorded yesterday at 23:50, viewed today at 14:00 on the Weekly chart,
  appears under yesterday's weekday label (previously appeared under today's).
- `flutter test test/analytics_buckets_test.dart` passes (all 11 tests).

**Verify**
```
flutter analyze
flutter test test/analytics_buckets_test.dart
```
Manual: with readings from late last night in Firestore, open Analytics → Weekly and
confirm the spot sits on yesterday's weekday label.

**Commit title:** `fix(analytics): bucket trend chart by calendar day/hour (analytics-2)`

---

### Step 3 — One live stream drives ALL analytics aggregates (analytics-3 / flow3-4, perf-4)

**Goal:** Replace the three Firestore fetches per load (live stream for the chart + `calculateStatsByPeriod` `.get()` + `getUserReadingsByPeriodOnce` `.get()`) with a single debounced subscription to the existing period stream, from whose snapshots ALL aggregates (avg/min/max/duration, pie counts, category breakdown, confidence, total count) are derived — so stats can never contradict the live chart.

**Files:** `lib/screens/analytics_screen.dart`

**Prerequisite:** Step 1 already applied (its Duration line is inside the method deleted below; the formula is carried into the new `_applySnapshot`).

**Exact changes**

3a. Line 1 — add the `dart:async` import (needed for `StreamSubscription` and `Timer`):

BEFORE:
```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
```

AFTER:
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
```

3b. Lines 42–50 (fields + `initState`) — add subscription/debounce fields and a `dispose`:

BEFORE:
```dart
  // Cached trend stream — only recreated when _selectedPeriod changes,
  // NOT on every setState (prevents Firestore re-subscription + chart flicker)
  Stream<QuerySnapshot>? _trendStream;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }
```

AFTER:
```dart
  // Cached trend stream — only recreated when _selectedPeriod changes,
  // NOT on every setState (prevents Firestore re-subscription + chart flicker)
  Stream<QuerySnapshot>? _trendStream;

  // Single subscription that drives ALL aggregates from the same live stream
  // the trend chart renders (analytics-3/flow3-4), debounced so bursts of
  // snapshot events (5 s save cadence while recording) coalesce into one
  // rebuild (perf-4).
  StreamSubscription<QuerySnapshot>? _statsSubscription;
  Timer? _statsDebounce;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  @override
  void dispose() {
    _statsDebounce?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }
```

3c. Replace the ENTIRE `_loadStatistics()` method (after Step 1 it spans from
`Future<void> _loadStatistics() async {` at line 81 down to the closing `}` after the
`catch (e)` block that logs `'Error loading statistics'` — originally lines 81–176)
with the following two methods:

BEFORE (whole method — anchors shown; delete all of it):
```dart
  Future<void> _loadStatistics() async {
    // Capture period NOW — used at the end to detect if the user changed
    // period again while this async call was in flight (race condition guard).
    final capturedPeriod = _selectedPeriod;
    ...
      final stats = await _firebaseService.calculateStatsByPeriod(since);
      final snapshot =
          await _firebaseService.getUserReadingsByPeriodOnce(userId, since);
    ...
    } catch (e) {
      AppLogger.error('Error loading statistics', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }
```

AFTER (full replacement):
```dart
  Future<void> _loadStatistics() async {
    // Capture period NOW — used to ignore late events if the user changed
    // period again while this subscription is live (race condition guard).
    final capturedPeriod = _selectedPeriod;

    // Check userId FIRST, before any Firestore calls.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final since = _getPeriodStartDate();
    final newStream = _firebaseService.getUserReadingsByPeriod(userId, since);

    // Atomically update the stream AND clear all analytics data from
    // the previous period. Without this, switching Monthly (0 data) →
    // Weekly would show stale values until the new query resolves.
    if (mounted) {
      setState(() {
        _trendStream = newStream;
        _soundTypeCounts = {};
        _pollutionCount = 0;
        _ambientCount = 0;
        _avgConfidence = 0.0;
        _avgDb = 0;
        _minDb = 0;
        _maxDb = 0;
        _totalHours = 0;
        _totalCount = 0;
      });
    }

    // ONE query per period (perf-4): the chart's StreamBuilder and this
    // listener share the same broadcast snapshots() stream, and every
    // aggregate on the screen is derived from its events — so stats, pie,
    // breakdown, and chart always describe the same data and live-update
    // together (analytics-3/flow3-4).
    await _statsSubscription?.cancel();
    _statsSubscription = newStream.listen(
      (snapshot) {
        // Debounce bursts (a new reading lands every 5 s while recording).
        _statsDebounce?.cancel();
        _statsDebounce = Timer(const Duration(milliseconds: 250), () {
          _applySnapshot(snapshot, capturedPeriod);
        });
      },
      onError: (Object e, StackTrace st) {
        AppLogger.error('Error loading statistics', e, st);
        if (mounted && _selectedPeriod == capturedPeriod) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  /// Derives every aggregate shown on this screen from one query snapshot.
  void _applySnapshot(QuerySnapshot snapshot, String capturedPeriod) {
    // Race condition guard: only apply results if the period the user sees
    // right now is still the one this subscription was created for.
    if (!mounted || _selectedPeriod != capturedPeriod) return;

    final soundTypeCounts = <String, int>{};
    int pollutionCount = 0;
    int ambientCount = 0;
    double totalConfidence = 0.0;
    int confidenceCount = 0;
    final dbValues = <double>[];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Null-safe: skip docs with missing/invalid decibelLevel for the
      // dB stats (mirrors the old calculateStatsByPeriod behavior).
      final db = (data['decibelLevel'] as num?)?.toDouble();
      if (db != null && db.isFinite) dbValues.add(db);

      final soundClass = data['soundClass'] as String?;
      final soundType = data['soundType'] as String?;
      final confidence = data['confidence'] as num?;

      if (soundClass != null && soundClass.isNotEmpty) {
        soundTypeCounts[soundClass] = (soundTypeCounts[soundClass] ?? 0) + 1;
      }

      if (soundType == 'Pollution') {
        pollutionCount++;
      } else if (soundType == 'Ambient') {
        ambientCount++;
      }

      if (confidence != null) {
        totalConfidence += confidence.toDouble();
        confidenceCount++;
      }
    }

    setState(() {
      _avgDb = dbValues.isEmpty
          ? 0
          : dbValues.reduce((a, b) => a + b) / dbValues.length;
      _minDb = dbValues.isEmpty ? 0 : dbValues.reduce((a, b) => a < b ? a : b);
      _maxDb = dbValues.isEmpty ? 0 : dbValues.reduce((a, b) => a > b ? a : b);
      // fb-6/flow3-7: one reading is saved every 5 s while recording
      // (dashboard _saveTimer), so hours = count * 5 s / 3600.
      _totalHours = dbValues.length * 5 / 3600;
      _totalCount = snapshot.docs.length; // incl. unclassified docs
      _soundTypeCounts = soundTypeCounts;
      _pollutionCount = pollutionCount;
      _ambientCount = ambientCount;
      _avgConfidence =
          confidenceCount > 0 ? totalConfidence / confidenceCount : 0.0;
      _isLoading = false;
    });
  }
```

3d. `lib/services/firebase_service.dart`: `calculateStatsByPeriod` and
`getUserReadingsByPeriodOnce` now have **no callers** (grep-verified:
analytics_screen was the only one). LEAVE THEM IN PLACE this commit — unused public
methods produce no analyzer diagnostics, and removing service API is out of scope.

**Edge cases to preserve**
- Period switch race: the old subscription is cancelled before the new one is created,
  AND `_applySnapshot` re-checks `capturedPeriod` — keep both.
- Stat semantics unchanged: `_totalCount` still counts all docs (was `totalDocs`); dB
  stats and `_totalHours` count only docs with a valid `decibelLevel` (was `count`).
- Debounce timer may fire after dispose: `dispose()` cancels it AND `_applySnapshot`
  checks `mounted` — keep both.
- `getUserReadingsByPeriod` is unchanged: `isGreaterThan` +
  `orderBy('timestamp', descending: true)` on the one composite index (convention 1).
  Do not touch it.
- Pull-to-refresh is deliberately NOT added: the whole screen now live-updates, which
  is the "refresh stats on stream events (debounced)" option the audit prescribed.

**Acceptance criteria**
- Start recording on Dashboard, switch to Analytics, keep it open: within ~5–6 s of each
  new reading, the readings badge, stats grid, pie chart, category breakdown, confidence
  card AND the trend chart all update together. Previously only the chart moved.
- Switching Daily/Weekly/Monthly still clears stale values immediately and repopulates.
- Exactly ONE Firestore query runs per period selection (previously three).
- Navigating away from Analytics while the stream is live produces no
  "setState() called after dispose()" errors.

**Verify**
```
flutter analyze
flutter test test/analytics_buckets_test.dart
```
Manual: (a) the live-update scenario above; (b) rapidly toggle Weekly → Monthly → Weekly
and confirm no stale/flashing wrong-period stats; (c) leave Analytics mid-load — no
console exceptions.

**Commit title:** `refactor(analytics): derive all aggregates from one live stream (analytics-3, flow3-4, perf-4)`

---

### Step 4 — History loading never deadlocks: reset `_isLoading` in `finally` (fb-3)

**Goal:** Every exit path of `_loadInitialRecordings` and `_loadMoreRecordings` (including the `userId == null` and `_lastDocument == null` early returns) resets `_isLoading`, so retries are never blocked, and failures are logged via AppLogger.

**Files:** `lib/screens/history_screen.dart`

**Exact changes**

4a. Add the AppLogger import. Lines 11–12:

BEFORE:
```dart
import '../services/firebase_service.dart';
import 'report_noise_screen.dart';
```

AFTER:
```dart
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';
import 'report_noise_screen.dart';
```

4b. Replace `_loadInitialRecordings` (lines 77–115) entirely:

BEFORE:
```dart
  // Load initial recordings
  Future<void> _loadInitialRecordings() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Get total count
      _totalCount = await _firebaseService.getUserReadingsCount(userId);

      // Load first page
      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _recordings = snapshot.docs;
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }
```
(Note: the line after `if (_isLoading) return;` has trailing whitespace in the current
file — the AFTER block removes it.)

AFTER:
```dart
  // Load initial recordings
  Future<void> _loadInitialRecordings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return; // fb-3: finally still resets _isLoading

      // Get total count
      _totalCount = await _firebaseService.getUserReadingsCount(userId);

      // Load first page
      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _recordings = snapshot.docs;
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
          _isOffline = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load history', e);
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    } finally {
      // fb-3: ALWAYS reset — every path, including the userId-null early
      // return. Otherwise _isLoading is stuck true and every retry no-ops.
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
```

4c. Replace `_loadMoreRecordings` (lines 117–158) entirely — it has the identical
`userId == null` hole plus a `_lastDocument == null` path:

BEFORE:
```dart
  // Load more recordings (infinite scroll)
  Future<void> _loadMoreRecordings() async {
    if (_isLoading || !_hasMore || _isOffline) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      if (_lastDocument == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
        startAfter: _lastDocument,
      );

      if (mounted) {
        setState(() {
          _recordings.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Don't show error for load more, just stop loading
      }
    }
  }
```

AFTER:
```dart
  // Load more recordings (infinite scroll)
  Future<void> _loadMoreRecordings() async {
    if (_isLoading || !_hasMore || _isOffline) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return; // fb-3: finally still resets _isLoading

      if (_lastDocument == null) return; // finally resets _isLoading

      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
        startAfter: _lastDocument,
      );

      if (mounted) {
        setState(() {
          _recordings.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
        });
      }
    } catch (e) {
      // Don't show a user-facing error for load-more; log and stop loading.
      AppLogger.error('Failed to load more history', e);
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
```

**Edge cases to preserve**
- The `if (_isLoading) return;` re-entrancy guards at the top of both methods stay.
- `_checkConnectivityAndLoad` / `_onRefresh` / `_onScroll` are untouched.
- `getUserReadingsPaginated` keeps `userId ==` + `orderBy timestamp desc` — the one
  composite index (convention 1). No query changes.
- The `finally` uses `if (mounted && _isLoading)` so it never setStates after dispose
  and doesn't double-fire when a path already reset the flag.

**Acceptance criteria**
- Reproduce fb-3: with `currentUser` null while History is mounted, trigger a load
  (pull-to-refresh) → spinner clears, and a later pull-to-refresh after signing back in
  loads data (previously permanently dead).
- Airplane-mode load failure shows the offline UI; Retry works after re-enabling network.

**Verify**
```
flutter analyze
```
Manual: History tab (index 3): (a) normal load; (b) airplane mode → Retry after network
restore; (c) the signed-out scenario above.

**Commit title:** `fix(history): always reset _isLoading in finally (fb-3)`

---

### Step 5 — Safe decibelLevel parse in the list item (social-2 / uiux-7)

**Goal:** A document missing `decibelLevel` renders as 0 dB instead of throwing a cast error that kills the whole list.

**Files:** `lib/screens/history_screen.dart`

**Exact changes** — line 449–451 (inside `ListView.builder`'s `itemBuilder`):

BEFORE:
```dart
                        final doc = _recordings[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final db = (data['decibelLevel'] as num).toDouble();
```

AFTER:
```dart
                        final doc = _recordings[index];
                        final data = doc.data() as Map<String, dynamic>;
                        // social-2/uiux-7: docs from older app versions or
                        // manual reports may lack decibelLevel — never hard-cast.
                        final db =
                            ((data['decibelLevel'] as num?) ?? 0).toDouble();
```

**Edge cases to preserve**
- `0.0` fallback flows into `_buildHistoryItem` → `dbColor = AppTheme.lowNoise` and
  label "Low Noise - Safe" — acceptable degraded rendering; do not add extra UI.
- Leave the neighbouring nullable reads (`locationName`, `timestamp`, `soundClass`,
  `soundType`, `confidence`) exactly as they are — they are already safe.

**Acceptance criteria**
- With one Firestore doc whose `decibelLevel` field is removed (Firebase console), the
  History list renders all rows; the affected row shows "0" in a green circle instead of
  the list being replaced by a red error screen.

**Verify**
```
flutter analyze
```
Manual: temporarily delete `decibelLevel` from one test doc in the Firebase console,
open History, confirm the list renders; restore the field afterwards.

**Commit title:** `fix(history): safe-parse decibelLevel with 0 fallback (social-2, uiux-7)`

---

### Step 6 — Delete updates the list, with undo and error handling (social-3 / uiux-2 / flow3-3)

**Goal:** Deleting a recording removes it from the on-screen list and decrements the count immediately on success, shows a snackbar with a working Undo, and surfaces failures with an error snackbar instead of silently claiming success.

**Files:** `lib/services/firebase_service.dart`, `lib/screens/history_screen.dart`

**Exact changes**

6a. `lib/services/firebase_service.dart` — add two methods directly after
`getUserReadingsCount` (after line 240, before the `// Get readings by location` comment):

BEFORE (lines 232–242):
```dart
  // Get total count of user's readings (for "Showing X of Y" display)
  Future<int> getUserReadingsCount(String userId) async {
    final snapshot = await _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // Get readings by location (for specific city)
```

AFTER:
```dart
  // Get total count of user's readings (for "Showing X of Y" display)
  Future<int> getUserReadingsCount(String userId) async {
    final snapshot = await _firestore
        .collection('noise_readings')
        .where('userId', isEqualTo: userId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // Delete a single noise reading by document id.
  Future<void> deleteNoiseReading(String docId) {
    return _firestore.collection('noise_readings').doc(docId).delete();
  }

  // Restore a previously deleted reading (undo support). Re-writes the
  // original document data verbatim under the same id, preserving the
  // original timestamp/createdAt pair (project convention: dual timestamps).
  Future<void> restoreNoiseReading(String docId, Map<String, dynamic> data) {
    return _firestore.collection('noise_readings').doc(docId).set(data);
  }

  // Get readings by location (for specific city)
```

6b. `lib/screens/history_screen.dart` — replace `_showDeleteConfirmation`
(lines 703–737, the final method before the State class's closing `}`) with the
confirmation dialog plus two new methods:

BEFORE:
```dart
  // Delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text('Delete Recording', style: TextStyle(color: ThemeHelper.getTextColor(context))),
        content: Text(
          'Are you sure you want to delete this recording?',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('noise_readings').doc(docId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
```

AFTER:
```dart
  // Delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text('Delete Recording', style: TextStyle(color: ThemeHelper.getTextColor(context))),
        content: Text(
          'Are you sure you want to delete this recording?',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog first
              _deleteRecording(docId); // then delete + update the list
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.highNoise)),
          ),
        ],
      ),
    );
  }

  // social-3/uiux-2/flow3-3: delete with immediate local-list update,
  // undo support, and an error path.
  Future<void> _deleteRecording(String docId) async {
    final index = _recordings.indexWhere((d) => d.id == docId);
    if (index == -1) return;
    final removedData = _recordings[index].data() as Map<String, dynamic>;

    try {
      await _firebaseService.deleteNoiseReading(docId);
    } catch (e) {
      AppLogger.error('Failed to delete recording $docId', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recording. Please try again.'),
            backgroundColor: AppTheme.highNoise,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _recordings.removeAt(index);
      if (_totalCount > 0) _totalCount--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recording deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoDelete(docId, removedData, index),
        ),
      ),
    );
  }

  Future<void> _undoDelete(
      String docId, Map<String, dynamic> data, int index) async {
    try {
      await _firebaseService.restoreNoiseReading(docId, data);
      // Re-fetch so the local list holds a real DocumentSnapshot again.
      final restored = await FirebaseFirestore.instance
          .collection('noise_readings')
          .doc(docId)
          .get();
      if (!mounted || !restored.exists) return;
      setState(() {
        _recordings.insert(index.clamp(0, _recordings.length), restored);
        _totalCount++;
      });
    } catch (e) {
      AppLogger.error('Failed to restore recording $docId', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not restore recording.'),
            backgroundColor: AppTheme.highNoise,
          ),
        );
      }
    }
  }
```

**Const note:** `const SnackBar(... backgroundColor: AppTheme.highNoise)` compiles only
if `AppTheme.highNoise` is a `static const Color`. Check `lib/theme/app_theme.dart`
first; if it is `static final`, drop the `const` before `SnackBar(` in the two error
snackbars (keep the inner `const Text(...)`). `flutter analyze` will confirm.

**Edge cases to preserve**
- The dialog is popped with its OWN context (`dialogContext`); snackbars use the
  State's `context` after the dialog is gone — this fixes the old code's use of the
  (about-to-be-disposed) dialog context for the snackbar.
- Undo re-writes the original map verbatim, so the original `timestamp` (Timestamp)
  and `createdAt` survive — convention 3 for restores; the dual-timestamp write rule
  applies only to genuinely new documents.
- Undo after the snackbar's 4 s window is impossible by construction (action gone).
- Deleting the last visible item with `_hasMore == true` keeps infinite scroll working:
  `_lastDocument` is untouched. It may reference the deleted doc — Firestore
  `startAfterDocument` still accepts a deleted doc as a cursor. Do not "fix" this here.
- `AppTheme.highNoise` replaces the previous hardcoded `Colors.red` on the Delete label
  and error snackbars (convention 2). The success snackbar loses its bizarre red
  background (default styling) — intended.

**Acceptance criteria**
- Delete → row disappears immediately; "Showing X of Y" decrements both sides on the
  next build; snackbar with Undo appears.
- Undo within 4 s → row reappears at (or near) its original position with identical
  timestamp/classification data; count restored.
- Delete failure (e.g. Firestore rules temporarily denying delete) → row STAYS, red
  error snackbar appears, no "Recording deleted" message. (Note: with plain airplane
  mode, cloud_firestore buffers the delete locally and reports success — that is
  standard offline behavior, not a bug; use a rules-deny or a temporary throw in
  `deleteNoiseReading` to exercise the error path during dev.)

**Verify**
```
flutter analyze
```
Manual: the three acceptance scenarios above on the History tab (index 3).

**Commit title:** `fix(history): delete updates list, adds undo and error handling (social-3, uiux-2, flow3-3)`

---

### Step 7 — Empty state scrollable so pull-to-refresh works (flow3-5)

**Goal:** The "No recordings yet" empty state (and the populated list even when items fit on one screen) is always scrollable, so `RefreshIndicator` can fire.

**Files:** `lib/screens/history_screen.dart`

**Exact changes** — the `Expanded` child inside `build()` (lines 399–434 region).
Replace the empty-state `Center(...)` branch and add `physics` to the `ListView.builder`:

BEFORE:
```dart
            // List view
            Expanded(
              child: _isOffline
                  ? _buildOfflineUI()
                  : _recordings.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recordings yet',
                            style: TextStyle(
                              color: ThemeHelper.getSecondaryTextColor(context),
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start recording to build your history',
                            style: TextStyle(
                              color: ThemeHelper.getSecondaryTextColor(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
```

AFTER:
```dart
            // List view
            Expanded(
              child: _isOffline
                  ? _buildOfflineUI()
                  : _recordings.isEmpty && !_isLoading
                  ? LayoutBuilder(
                      // flow3-5: the empty state must be scrollable, otherwise
                      // RefreshIndicator can never fire pull-to-refresh.
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 80,
                                    color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No recordings yet',
                                    style: TextStyle(
                                      color: ThemeHelper.getSecondaryTextColor(context),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start recording to build your history',
                                    style: TextStyle(
                                      color: ThemeHelper.getSecondaryTextColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
```
(The rest of the `ListView.builder` — `itemCount`, `itemBuilder` — is unchanged.)

**Edge cases to preserve**
- `RefreshIndicator`'s default `notificationPredicate` requires scroll depth 0: the new
  `ListView` sits under Column → Expanded (non-scrollable ancestors), so it IS depth 0 —
  do not wrap it in any additional scrollable.
- The offline branch (`_buildOfflineUI`) is intentionally untouched — it has its own
  Retry button; making it scrollable is not flow3-5.
- The populated `ListView.builder` keeps its `controller` (infinite scroll) — only
  `physics` is added, so pull-to-refresh also works when items fit on one screen.

**Acceptance criteria**
- With zero recordings, pulling down on the empty state shows the refresh spinner and
  triggers `_onRefresh`.
- With 1–3 recordings (less than a screenful), pull-to-refresh also fires.
- Empty-state content stays vertically centered on tall screens.

**Verify**
```
flutter analyze
```
Manual: fresh account with 0 readings → History tab → pull down → spinner appears; add a
reading via the Firebase console → pull down again → it appears in the list.

**Commit title:** `fix(history): scrollable empty state enables pull-to-refresh (flow3-5)`

---

## Risks & rollback

- **Step 3 is the only structural change.** Risk: a second listener on the period
  stream. cloud_firestore's `snapshots()` is broadcast (the existing comment at
  `analytics_screen.dart:118-121` depends on this), so it is safe; if a regression
  appears (chart stops updating, duplicate reads), revert only the Step 3 commit —
  Steps 1–2 stand alone. The now-orphaned `calculateStatsByPeriod` /
  `getUserReadingsByPeriodOnce` remain in the service as an instant rollback path.
- **Intended behavior change:** analytics stats now live-update; users mid-recording
  will see numbers move every ~5 s. The 250 ms debounce prevents rebuild storms.
- **Step 2 date math:** calendar bucketing uses local midnight; in DST-shifting locales
  `difference().inDays` across a DST boundary can be off by one on the shift day.
  Target market (Sri Lanka) has no DST; accepted and documented.
- **Step 6 undo:** restore re-creates the doc with its original id/data. If Firestore
  security rules ever forbid client `set` with an arbitrary `timestamp`, undo fails
  into its error snackbar (graceful). Offline deletes buffer locally and appear to
  succeed — standard Firestore semantics, unchanged from before.
- **Const pitfall (Step 6):** `const SnackBar(backgroundColor: AppTheme.highNoise)`
  requires `highNoise` to be `const`; if analyze complains, drop that `const`.
- **Index safety:** no query is added or modified in any step — the single composite
  index `noise_readings (userId ASC, timestamp DESC)` covers everything;
  `firestore.indexes.json` is untouched.
- **Rollback unit = one commit per step.** Steps 4–7 are mutually independent; Step 3
  assumes Step 1 landed; Step 6 uses the AppLogger import added in Step 4 (if
  cherry-picking Step 6 alone, also add `import '../utils/app_logger.dart';`).

## Out of scope

- Removing the now-orphaned `calculateStatsByPeriod` and `getUserReadingsByPeriodOnce`
  from `firebase_service.dart` (safe cleanup, separate later commit).
- fb-4 (CSV export downloads the entire global collection incl. every user's email —
  `history_screen.dart:230`): security cluster, separate spec.
- Making the offline UI (`_buildOfflineUI`) scrollable (not part of flow3-5).
- `_lastDocument` pagination cursor referencing a deleted doc (pre-existing, benign).
- Adding pull-to-refresh to Analytics (superseded by live updates in Step 3).
- flow2-6 (confidence threshold 0.30), flow6-06, dash-2, dash-4, flow2-1 and all other
  audit findings outside the eight IDs in Scope.
- Any change to `_getPeriodStartDate()` query windows, Firestore queries, or
  `firestore.indexes.json`.
