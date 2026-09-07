# Performance Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **22** (5 High, 12 Medium, 5 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| fb-5 | High | disputed | `lib/screens/dashboard_screen.dart:907` | Community-feed card creates a brand-new Firestore snapshots() stream on every dashboard rebuild | S |
| perf-2 | High | confirmed | `lib/screens/dashboard_screen.dart:385` | setState on every NoiseReading rebuilds the entire dashboard tree multiple times per second | M |
| perf-4 | High | disputed | `lib/screens/analytics_screen.dart:122` | Analytics fetches the same unbounded period query three times and aggregates client-side | M |
| perf-5 | High | confirmed | `lib/screens/history_screen.dart:230` | CSV export downloads the entire noise_readings collection (all users, unbounded) and builds the CSV on the UI thread | M |
| perf-3 | High | confirmed | `lib/services/sound_classification_service.dart:108` | YAMNet TFLite inference runs synchronously on the main isolate every 5 seconds during recording | M |
| analytics-7 | Medium | unverified | `lib/screens/analytics_screen.dart:96` | Every load issues three identical Firestore queries for the same data (stream + two .get()s) | S |
| perf-10 | Medium | unverified | `lib/screens/map_view_screen.dart:1471` | HeatmapPainter.shouldRepaint compares only point-list length, and each repaint draws up to 100 blurred circles | S |
| boot-10 | Medium | unverified | `lib/main.dart:48` | runApp is blocked on the notification-permission dialog and a duplicate YAMNet model load | S |
| boot-8 | Medium | unverified | `lib/widgets/main_app_shell.dart:38` | IndexedStack eagerly builds all five tabs at mount — three hidden tabs fire Firestore loads at startup and never refresh on tab switch | M |
| map-17 | Medium | unverified | `lib/screens/map_view_screen.dart:932` | Map autocomplete fires a Nominatim request on every keystroke with no debounce and no out-of-order guard | S |
| fb-8 | Medium | unverified | `lib/screens/search_list_screen.dart:137` | Search screen creates a new getNoiseReadings() stream on every rebuild | S |
| ml-7 | Medium | unverified | `lib/main.dart:66` | YAMNet model is loaded twice at cold start, both times before runApp | S |
| perf-11 | Medium | unverified | `lib/screens/history_screen.dart:458` | FadeInListItem delay scales with absolute list index, hiding deep rows for seconds and allocating a controller per row | S |
| map-13 | Medium | unverified | `lib/screens/map_view_screen.dart:625` | Every bare map tap recreates the whole cluster layer via key bump | M |
| analytics-8 | Medium | unverified | `lib/screens/analytics_screen.dart:1021` | Unbounded period queries with full client-side re-aggregation on every rebuild | M |
| perf-7 | Medium | unverified | `lib/screens/map_view_screen.dart:686` | Cluster builder does an O(n) string scan per marker per cluster with a key that can never match | S |
| fb-10 | Medium | unverified | `lib/services/firebase_service.dart:263` | Period queries (getUserReadingsByPeriod/Once, calculateStatsByPeriod) have no limit | M |
| perf-12 | Low | unverified | `lib/widgets/sync_status_indicator.dart:30` | Sync indicator polls every 2 seconds with unconditional setState and full Hive box iteration | S |
| offline-18 | Low | unverified | `lib/services/sync_service.dart:184` | 5-second delay after each failed item blocks the rest of the batch without actually retrying anything | S |
| dash-18 | Low | unverified | `lib/widgets/decibel_meter_gauge.dart:188` | Both gauge painters return shouldRepaint => true, forcing full repaints on every frame of every rebuild | S |
| perf-13 | Low | unverified | `lib/services/firebase_service.dart:243` | Dead service methods with unbounded full-collection queries are cost traps | S |
| map-19 | Low | unverified | `lib/screens/map_view_screen.dart:631` | Map position written to SharedPreferences on every gesture frame | S |

## Detailed Findings

### High

#### [fb-5] Community-feed card creates a brand-new Firestore snapshots() stream on every dashboard rebuild

**Severity:** High | **Status:** disputed | **Category:** performance | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:907`

**Verifier verdict (PARTIAL):** Variant 1 CONFIRMED: dashboard_screen.dart:900-914 — _buildCommunityFeedCard() is called from build() (line 890) and constructs a fresh .snapshots() query inline as the StreamBuilder stream. The screen calls setState frequently during recording (16+ sites, e.g. lines 199/215/268 updating _dbHistory), so each rebuild hands StreamBuilder a new stream, forcing unsubscribe/resubscribe churn. Variant 2 OVERSTATED: the query (lines 909-913) does use isGreaterThanOrEqualTo with no orderBy, and the builder swallows errors (line 917 renders hasError as count 0), but the "project index rule" concerns the composite (userId ASC, timestamp DESC) index; this query filters only on timestamp, which is served by Firestore's automatic single-field index — no FAILED_PRECONDITION occurs, so there is no "resulting error" to swallow. The project's own audit (10_PERFORMANCE_RECOMMENDATIONS.md:99) confirms "no composite needed." Real defect: stream recreation + silent error handling; the runtime index failure claim is wrong.

**Description:**

_buildCommunityFeedCard constructs the query and calls .snapshots() inline inside the StreamBuilder's stream: parameter (lines 906-914), and it is invoked from build() (line 890). During recording, the noise-meter callback calls setState on every meter event (line 385, several times per second), so each frame tears down the Firestore listener and opens a new one. Each resubscription momentarily has snapshot.hasData == false, so reportCount (line 917) flickers to 0. The query also fetches full documents of all of today's readings from all users just to display docs.length — with no limit.

**Failure scenario:**

User starts a recording session on the Dashboard: setState fires ~several times per second for the duration; each rebuild cancels and recreates the community-feed listener, causing continuous Firestore listener churn (billing reads, network traffic) and the 'reports today' number visibly flickering between 0 and the real count.

**Recommended fix:**

Create the stream once in initState (or cache it in a field like analytics_screen does with _trendStream) and pass the cached stream to StreamBuilder. Better: replace the full-document stream with a periodic count() aggregate query since only the count is displayed.

---

#### [perf-2] setState on every NoiseReading rebuilds the entire dashboard tree multiple times per second

**Severity:** High | **Status:** confirmed | **Category:** performance | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:385`

**Verifier verdict (CONFIRMED):** dashboard_screen.dart:381-439 subscribes to NoiseMeter().noise and calls setState (line 385) inside the listener for every NoiseReading; the noise_meter plugin emits readings several times per second while recording. The State's build() (line 670) returns the full screen — Scaffold, AppBar with SyncStatusIndicator, greeting text, stat cards, DecibelMeterGauge, and the rest of a ~500-line tree — with no ValueListenableBuilder/StreamBuilder isolation, so each reading rebuilds the entire dashboard subtree. Minor caveat: this only occurs while recording is active, and Flutter element reuse limits actual repaint cost, but the defect is real as described.

**Description:**

The noise_meter listener (lines 381-449) wraps ALL of its bookkeeping in one setState (line 385), so every NoiseReading event (noise_meter ^5.0.2 emits per audio buffer, multiple events/second) rebuilds the whole Scaffold body: the greeting Text, three stat cards, DecibelMeterGauge (both painters hardcode shouldRepaint => true at decibel_meter_gauge.dart:188 and 235, and DecibelGaugePainter creates a fresh SweepGradient shader plus lays out 5 TextPainters per paint), NoiseHistoryChart (fl_chart LineChart rebuilt with a fresh 50-element FlSpot list and a 250ms implicit animation restarted per event, noise_history_chart.dart:31-46), the location pill, the classification card, and the community-feed StreamBuilder (see perf-1). Because DashboardScreen lives in MainAppShell's IndexedStack (main_app_shell.dart:38-46), these full rebuilds continue even while the user is viewing another tab during a recording.

**Failure scenario:**

User records on a mid-range Android phone and swipes/scrolls the dashboard: the whole subtree rebuilds and the gauge repaints with shader creation ~4-8 times/second, producing sustained dropped frames; leaving the tab mid-recording keeps the hidden tree rebuilding at the same rate, wasting CPU/battery.

**Recommended fix:**

Store the live values (_currentDb, min/max/avg, _dbHistory) in ValueNotifiers updated from the listener without setState, and wrap only DecibelMeterGauge, the stat row, and NoiseHistoryChart in ValueListenableBuilders. Implement proper shouldRepaint in both gauge painters (repaint only when currentDb/isDark changed) and hoist the SweepGradient shader out of paint().

---

#### [perf-4] Analytics fetches the same unbounded period query three times and aggregates client-side

**Severity:** High | **Status:** disputed | **Category:** performance | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:122`

**Verifier verdict (PARTIAL):** Core defect real, one wording wrong. The identical query (userId==, timestamp>since, orderBy desc) IS run three times per load: as a live stream for the trend chart (firebase_service.dart:259-265 via analytics_screen.dart:96-97), one-shot in calculateStatsByPeriod (firebase_service.dart:287-292, analytics_screen.dart:122), and one-shot in getUserReadingsByPeriodOnce (firebase_service.dart:271-279, analytics_screen.dart:124) — all aggregated client-side with no .limit() (doc count unbounded within the period, though time-bounded). Mixing live+static is also real: the chart updates on new readings via snapshots() while stats/pie stay stale, so the screen can show inconsistent data. However, "loaded once at app start" is false — _loadStatistics reruns on every period-chip tap (analytics_screen.dart:490-494), so stats refresh on user interaction, just not on new data arrival.

**Description:**

_loadStatistics() issues three separate reads of the identical data set with no .limit(): (1) calculateStatsByPeriod (line 122 → firebase_service.dart:287-292) downloads every period doc to compute avg/min/max via reduce; (2) getUserReadingsByPeriodOnce (line 124 → firebase_service.dart:271-279) downloads the same docs again for category/pollution counting (lines 132-153); (3) _trendStream (line 96-97 → firebase_service.dart:259-266) opens a live snapshot listener over the same unbounded query for the chart, which stays subscribed for the lifetime of the IndexedStack tab and re-buckets all docs in _buildTimeAggregatedSpots on every emission. Cost estimate at 10k readings in the Monthly window: ~30,000 billed document reads and roughly 3 × 5-10MB of transfer per screen load, then repeated in full every time the user taps a period chip; parsing 10k docs three times happens on the main isolate (visible freeze while the loops run). The queries correctly use isGreaterThan + orderBy timestamp desc per the index constraint — the problem is purely volume and duplication.

**Failure scenario:**

A power user with 10k readings in the last 30 days opens Analytics and taps Daily → Weekly → Monthly: the app performs ~90k document reads in a few seconds, the UI freezes noticeably during each doc-parsing loop, and the Firestore free tier (50k reads/day) is exhausted by one user in one session, breaking the app for everyone until quota reset.

**Recommended fix:**

Fetch the period docs ONCE (the existing getUserReadingsByPeriodOnce) and derive stats, category counts, AND chart buckets from that single snapshot; drop calculateStatsByPeriod's duplicate query. For avg/min/max/count use Firestore aggregate queries (count/sum/average) which bill 1 read per 1000 docs instead of 1 per doc. Add a defensive .limit() (e.g. 5000) and consider pre-aggregated daily rollup docs written at save time for the Monthly view.

---

#### [perf-5] CSV export downloads the entire noise_readings collection (all users, unbounded) and builds the CSV on the UI thread

**Severity:** High | **Status:** confirmed | **Category:** performance | **Effort:** M

**Location:** `lib/screens/history_screen.dart:230`

**Verifier verdict (CONFIRMED):** Real. history_screen.dart:230-233 queries the entire `noise_readings` collection with no userId filter and no limit — every user's data. Line 248/262 put `User Email` in the CSV header and write `data['userEmail']` per row (line 273), exposing all users' emails. The CSV is built in a synchronous StringBuffer loop (lines 245-274) on the main isolate (no compute/isolate offload), so for a large collection it blocks the UI thread. Both variant wordings are accurate as stated.

**Description:**

_exportDataToCSV queries `collection('noise_readings').orderBy('timestamp', descending: true).get()` with no userId filter and no limit (lines 230-233), then loops every doc building a StringBuffer with a DateFormat('yyyy-MM-dd HH:mm:ss').format() call per row (lines 251-274) followed by file.writeAsString — all on the main isolate. At 10k total readings this is 10,000 billed document reads and a ~5-10MB download per export tap, plus a 1-3 second frozen UI while 10k rows are formatted and concatenated. It also exports every other user's readings and emails, contradicting the screen's paginated, per-user design (getUserReadingsPaginated with _pageSize 50).

**Failure scenario:**

User taps the download icon in History when the community collection holds 10k readings: the app silently pulls the entire collection over mobile data, the History screen freezes with no progress indicator during CSV assembly, and the export costs 10k reads — repeated in full on every tap.

**Recommended fix:**

Scope the query to the current user (`.where('userId', isEqualTo: uid)` + orderBy timestamp desc, matching the existing composite index) and page through with startAfterDocument in chunks; move row formatting + file write into compute() (pass plain maps, return the CSV string) so the UI stays responsive.

---

#### [perf-3] YAMNet TFLite inference runs synchronously on the main isolate every 5 seconds during recording

**Severity:** High | **Status:** confirmed | **Category:** performance | **Effort:** M

**Location:** `lib/services/sound_classification_service.dart:108`

**Verifier verdict (CONFIRMED):** lib/services/sound_classification_service.dart:108 calls `_interpreter!.run(input, output)` — tflite_flutter's synchronous API — plus synchronous preprocessing (resample/normalize, lines 167-242), all inside an async method that never leaves the main isolate. Call site: lib/screens/dashboard_screen.dart:507-513 fires a `Timer.periodic(Duration(seconds: 5))` during recording that invokes `_performSoundClassification()`, which awaits `classifySound` (line 634). A grep of lib/ shows no `Isolate`, `compute(`, or `IsolateInterpreter` usage anywhere, so the YAMNet inference blocks the UI isolate every 5 seconds exactly as claimed.

**Description:**

classifySound() calls `_interpreter!.run(input, output)` (line 108) directly on the calling isolate. It is invoked from the dashboard's classification timer (_performSoundClassification, dashboard_screen.dart:634) on the UI thread. YAMNet inference over a [1,15600] float input plus the surrounding Dart work — _preprocessAudio copies the 15600-sample list (line 168), _normalizeAudio does a full pass then `map().toList()` (line 241), a 521-way argmax and a full 521-element sort for debug logging (lines 119-120) — all execute on the main isolate, typically costing tens to hundreds of milliseconds on mid-range hardware. Additionally, the continuous PCM16-to-double conversion in _processAudioData (dashboard_screen.dart:521-541) and the O(n) `removeRange` on a 32k-element List<double> run on the UI thread for every audio buffer. tflite_flutter ^0.12.1 (pubspec) already ships IsolateInterpreter for off-thread inference.

**Failure scenario:**

User records while watching the gauge: every 5 seconds the classification tick blocks the UI thread for the duration of preprocessing + inference, producing a visible stutter/frozen needle that repeats like clockwork for the whole session (compounding with the per-reading rebuilds of perf-2).

**Recommended fix:**

Replace Interpreter with tflite_flutter's IsolateInterpreter (await IsolateInterpreter.create(address: interpreter.address)) and `await isolateInterpreter.run(...)`, or move preprocess+inference into compute(). Use a Float32List ring buffer for _audioBuffer instead of List<double> with removeRange, and drop the per-inference 521-element sort (only needed for debug logs).

---

### Medium

#### [analytics-7] Every load issues three identical Firestore queries for the same data (stream + two .get()s)

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:96`

**Description:**

_loadStatistics creates the snapshots() stream via getUserReadingsByPeriod (line 96-97), then awaits calculateStatsByPeriod (line 122) and getUserReadingsByPeriodOnce (line 123-124). All three run the exact same query — noise_readings where userId == uid, timestamp > since, orderBy timestamp desc (firebase_service.dart:259-292). Every document in the period is read three times per screen load / period switch, tripling Firestore read billing and latency for zero benefit: the stats in calculateStatsByPeriod could be computed from the getUserReadingsByPeriodOnce snapshot (it already iterates the same docs at lines 132-153).

**Failure scenario:**

A heavy user with 20,000 readings in the last 30 days taps the Monthly chip: 60,000 document reads are billed and downloaded (3 x 20k) where 20k (or one stream subscription alone) would suffice; on a slow connection the stats area stays zeroed for several extra seconds.

**Recommended fix:**

Fetch once: drop calculateStatsByPeriod and compute avg/min/max/count/totalDocs inside the existing snapshot.docs loop in _loadStatistics (lines 132-153). Better still, compute everything from the first emission of the cached _trendStream inside the StreamBuilder, reducing to a single query that also fixes the staleness in analytics-3.

---

#### [perf-10] HeatmapPainter.shouldRepaint compares only point-list length, and each repaint draws up to 100 blurred circles

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:1471`

**Description:**

shouldRepaint (lines 1470-1472) returns true only when opacity or screenPoints.length changes. During pan/zoom the point COUNT never changes (screenPoints always contains all loaded points; off-screen culling happens inside paint at lines 1440-1443), so the painter reports 'no repaint needed' even though every point's projected Offset moved — correctness then depends on an ancestor happening to repaint the shared layer, risking heatmap blobs frozen at stale screen positions while tiles move underneath. When paint does run, it draws up to _kMapReadingLimit (100) circles each with `MaskFilter.blur(BlurStyle.normal, 20)` (line 1450) — a per-draw Gaussian blur that is expensive during continuous pan gestures — and _colorForIntensity re-sorts the gradient keys for every point on every frame (line 1457).

**Failure scenario:**

User enables the heatmap and drags the map: either blobs visibly lag/stick to old positions until something else forces a repaint (misaligned overlay), or — when repaints do occur each camera frame — 100 blurred draws per frame drop the pan below 60fps on mid-range devices.

**Recommended fix:**

Make shouldRepaint compare the actual data (e.g. store the camera's center/zoom hash or use listEquals on screenPoints) so it returns true when positions change. Hoist the sorted gradient keys to a static final. For scale, pre-render the blobs into a ui.Image once per data load and draw the transformed image during gestures.

---

#### [boot-10] runApp is blocked on the notification-permission dialog and a duplicate YAMNet model load

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/main.dart:48`

**Description:**

main() awaits NotificationService.requestPermission() (line 48) before runApp: on Android 13+ requestNotificationsPermission() (notification_service.dart:22-32) shows a system dialog, so the OS permission prompt appears over a blank/native-splash screen and first frame waits for the user's answer — also a UX anti-pattern (permission requested with no context, and Dashboard separately requests microphone permission immediately after at dashboard_screen.dart:95, stacking two prompts at first launch). Additionally _testModelLoading (main.dart:66, 75-99) loads the full YAMNet TFLite model just to log its shapes and close it, then _initializeSoundClassification (line 69) loads the exact same asset again via the singleton service (sound_classification_service.dart:56) — the multi-MB model is parsed twice on every cold start, all before the first frame.

**Failure scenario:**

First launch on an Android 13 device: the user stares at a blank screen while a notification-permission dialog appears with no explanation; after answering, the app still loads the YAMNet model twice before showing anything — several seconds of dead time on a low-end phone on every subsequent cold start too (model double-load happens every launch).

**Recommended fix:**

Delete _testModelLoading (the service's initialize already logs success/failure), and move NotificationService.requestPermission and _initializeSoundClassification to after runApp (e.g., addPostFrameCallback or lazily before first recording), keeping only Firebase + prefs on the critical path.

---

#### [boot-8] IndexedStack eagerly builds all five tabs at mount — three hidden tabs fire Firestore loads at startup and never refresh on tab switch

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** M

**Location:** `lib/widgets/main_app_shell.dart:38`

**Description:**

The IndexedStack (lines 38-46) constructs all five screens the moment the shell mounts, so every initState runs at once even though only Dashboard (index 2) is visible: MapViewScreen._loadNoiseMarkers() queries up to 100 noise_readings (map_view_screen.dart:101, limit at line 42), AnalyticsScreen._loadStatistics() runs its period query (analytics_screen.dart:49), and HistoryScreen._checkConnectivityAndLoad() triggers _loadInitialRecordings (history_screen.dart:39). That is three concurrent Firestore query bursts competing with the visible Dashboard's own permission/location/recorder init (dashboard_screen.dart:91-98) right after login. The inverse problem also holds: the shell's onTap only does setState on _currentIndex (lines 50-54) with no visibility notification, so a tab first opened 20 minutes later still shows data fetched at app start (Map's comment at map_view_screen.dart:100 confirms markers load 'once on startup').

**Failure scenario:**

User logs in and lands on Dashboard: the app immediately runs Map, Analytics, and History Firestore queries for tabs the user may never open, slowing first meaningful paint on a mid-range phone and burning reads. Later the user records five new readings, opens the Map tab for the first time — their new readings are missing because markers were loaded before they existed.

**Recommended fix:**

Lazy-build tabs (keep a Set of visited indices and render a placeholder until first selection), or keep IndexedStack but move data loading out of initState into an 'onTabVisible' callback: pass the current index down (or use a ChangeNotifier) so each screen loads/refreshes when it actually becomes visible.

---

#### [map-17] Map autocomplete fires a Nominatim request on every keystroke with no debounce and no out-of-order guard

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:932`

**Description:**

onChanged (lines 932-934) calls _autocompleteSearch directly; _autocompleteSearch/_searchNominatim (lines 495-516, 357-468) issue an HTTP request per keystroke. Nominatim's usage policy is max 1 request/second — typing 'colombo fort' fires ~12 rapid requests, risking 429s/temporary IP blocks (breaking search entirely). Responses are applied unconditionally in setState, so a slow response for 'co' arriving after 'colombo' overwrites the newer, correct results.

**Failure scenario:**

User types quickly; requests race. Final visible dropdown shows results for a 2-letter prefix instead of the full query, or search stops returning anything because Nominatim throttled the app.

**Recommended fix:**

Add a 400ms Timer debounce (cancel previous timer per keystroke) and a monotonically increasing request token; discard responses whose token is not the latest.

---

#### [fb-8] Search screen creates a new getNoiseReadings() stream on every rebuild

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:137`

**Description:**

The StreamBuilder's stream parameter calls _firebaseService.getNoiseReadings() inline inside build() (line 137). getNoiseReadings() returns a fresh _firestore...snapshots() stream each call (firebase_service.dart lines 165-171). Every setState on this screen — each search-field keystroke (lines 287-290), clearing the search (lines 271-277), and every sort-menu selection (lines 116-120) — recreates the Firestore listener, forcing an unsubscribe/resubscribe cycle, a loading spinner flash (connectionState.waiting branch at line 139), and duplicate reads.

**Failure scenario:**

User opens Search Cities and changes the sort from 'Noise Level' to 'Name': setState rebuilds, a brand-new snapshots() listener is opened, the grid briefly swaps to a full-screen spinner, then re-renders — and this repeats on every subsequent UI interaction on the screen.

**Recommended fix:**

Create the stream once: late final Stream<QuerySnapshot> _readingsStream = _firebaseService.getNoiseReadings(); in the State (or assign in initState) and pass _readingsStream to the StreamBuilder.

---

#### [ml-7] YAMNet model is loaded twice at cold start, both times before runApp

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/main.dart:66`

**Description:**

main() awaits _testModelLoading() (line 66), which loads the full 4.1MB interpreter from asset, reads tensor shapes, and immediately closes it (lines 74-99), then awaits _initializeSoundClassification() (line 69) which loads the exact same asset again inside SoundClassificationService.initialize() (sound_classification_service.dart:56). Both loads complete before runApp (line 71), so the redundant test load directly adds asset-decompression + interpreter-construction time to time-to-first-frame on every launch. The interpreter-lifecycle guard inside the service itself is correct (singleton, _isInitialized check at line 49 prevents repeated loads afterwards).

**Failure scenario:**

Every cold start: the app parses the 4.1MB model, throws the interpreter away, parses it again, and only then shows the first frame — roughly doubling the model-related portion of startup latency for zero benefit (the 'test' proves nothing initialize() would not report itself).

**Recommended fix:**

Delete _testModelLoading() and its call at line 66; initialize() already logs shapes and returns false on failure. Optionally also make initialization lazy (kick it off unawaited, or initialize on first use from the dashboard) so it never blocks first frame.

---

#### [perf-11] FadeInListItem delay scales with absolute list index, hiding deep rows for seconds and allocating a controller per row

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/history_screen.dart:458`

**Description:**

Every history row is wrapped in FadeInListItem(index: index) (line 458). FadeInListItem schedules its entrance animation with `Future.delayed(widget.delay * widget.index)` (animations.dart:402) where delay defaults to 100ms. ListView.builder builds rows lazily, so a row first built when the user scrolls to index 60 starts fully transparent (opacity 0, animations.dart:390) and stays invisible for 6 seconds; after loading a few 50-item pages, index 150+ rows are blank for 15+ seconds. Each row also creates its own AnimationController + Ticker (animations.dart:385) that outlives the stagger purpose.

**Failure scenario:**

User with 200 recordings fast-scrolls the History list: rows beyond the first screen appear as empty card-sized gaps that fade in one-by-one many seconds later, making the paginated list look broken; dozens of live tickers accumulate for off-screen-then-visible rows.

**Recommended fix:**

Cap the stagger to the initially visible rows (e.g. `delay * min(index, 10)`) or, simpler, animate only on first page load and pass index 0 for subsequently loaded pages; alternatively drop the per-row controller for rows built with index > ~15 and render them immediately.

---

#### [map-13] Every bare map tap recreates the whole cluster layer via key bump

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** M

**Location:** `lib/screens/map_view_screen.dart:625`

**Description:**

MapOptions.onTap (lines 625-630) increments _clusterRebuildKey on EVERY tap to collapse spiderfy; the ValueKey on MarkerClusterLayerWidget (line 657) then destroys and rebuilds the entire cluster tree — full re-clustering of all markers plus a whole-screen setState — even when no spiderfy is open. Combined with the O(N*M) key scan in the cluster builder (map-1), casual taps while panning cause visible jank as the marker count grows toward the hundreds the clustering is meant to support.

**Failure scenario:**

With ~100 markers loaded, user taps the map a few times while exploring: each tap triggers a full rebuild/re-cluster and the cluster pins flicker; on low-end devices frames are dropped.

**Recommended fix:**

Only bump the key when a spiderfy is actually open (track it via MarkerClusterLayerOptions callbacks such as onMarkerTap/spiderfy state, or use the plugin's zoomToBoundsOnClick behavior), and fix map-1 so builder cost is O(M).

---

#### [analytics-8] Unbounded period queries with full client-side re-aggregation on every rebuild

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:1021`

**Description:**

The period queries have no limit() and no server-side aggregation; at the app's 5-second save cadence (dashboard_screen.dart:487) a Monthly window can hold tens of thousands of docs, all streamed to the client and kept live. _buildTimeAggregatedSpots(snapshot.data!.docs) (line 1021) then re-iterates every doc inside the StreamBuilder builder, which re-runs on ANY setState of the screen — including sound-filter chip taps (line 543-545) that don't affect the chart at all — recomputing 24/7/30 bucket averages over the full doc list each time.

**Failure scenario:**

User with a month of recordings (≈20k docs) opens Analytics on Monthly and taps between All/Pollution/Ambient chips: each tap re-runs an O(20k) aggregation on the UI thread, causing visible jank, and the open snapshots() listener holds the whole result set in memory for the lifetime of the app shell.

**Recommended fix:**

Memoize the computed spots keyed by (snapshot identity, period) so chip taps don't re-aggregate; and cap the data: use Firestore aggregate queries (count/average) per bucket, or maintain daily rollup documents at write time so the chart reads at most 30 small docs.

---

#### [perf-7] Cluster builder does an O(n) string scan per marker per cluster with a key that can never match

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:686`

**Description:**

The MarkerClusterLayerOptions builder (lines 681-694) runs `_markerNoiseLevels.keys.firstWhere((k) => k.startsWith('$point.latitude_$point.longitude'))` for every marker in every cluster. Two problems: (a) the interpolation is broken — `'$point.latitude'` stringifies the LatLng object then appends the literal text '.latitude', producing e.g. 'LatLng(latitude:6.9, ...).latitude_...', which never matches keys stored as '${lat}_$lng' (line 200), so every marker falls through orElse to the 50.0 default (all clusters render moderate-orange regardless of real noise); (b) even if it matched, firstWhere over all keys is O(n) per marker, making cluster building O(n²) string comparisons, re-executed every time clusters rebuild during zoom/pan and on every _clusterRebuildKey bump from a map tap (line 627-630). At the current 100-marker limit that is ~10k startsWith calls per rebuild; raising _kMapReadingLimit makes it quadratic.

**Failure scenario:**

User pans/zooms the map with 100 markers: every cluster regeneration performs thousands of futile string scans on the UI thread during gesture frames, and all cluster pins show the same orange color even over clusters of 90dB readings (wrong data + wasted work).

**Recommended fix:**

Store the dB values keyed by '${lat}_${lng}' and look them up with a direct map access using '${marker.point.latitude}_${marker.point.longitude}' (O(1)); better, attach the dB to the marker itself (subclass Marker or use a parallel Map<Marker,double> built once in _buildMarkersFromSnapshot).

---

#### [fb-10] Period queries (getUserReadingsByPeriod/Once, calculateStatsByPeriod) have no limit

**Severity:** Medium | **Status:** unverified | **Category:** performance | **Effort:** M

**Location:** `lib/services/firebase_service.dart:263`

**Description:**

getUserReadingsByPeriod (lines 259-266), getUserReadingsByPeriodOnce (lines 271-279), and calculateStatsByPeriod (lines 287-292) all query a user's readings for up to 30 days with no .limit(). Because the dashboard saves a reading every 5 seconds while recording (dashboard_screen.dart line 487), one hour of daily recording produces ~21,600 docs per month; the Monthly analytics view fetches all of them (three times, per fb-9), with corresponding memory, bandwidth, and billing costs. getUserReadings (lines 205-211) is similarly unbounded.

**Failure scenario:**

A heavy user who records ~1 hour per day selects 'Monthly' in Analytics: each load pulls tens of thousands of documents into memory on a phone, causing multi-second load times, jank while the docs loop runs, and potential OOM on low-end devices.

**Recommended fix:**

Add a sane .limit() (e.g. 5,000) to the period queries and surface truncation to the caller, or aggregate server-side: use count()/sum()/average() aggregate queries for calculateStatsByPeriod, and downsample the trend data (the chart only needs 24-30 buckets).

---

### Low

#### [perf-12] Sync indicator polls every 2 seconds with unconditional setState and full Hive box iteration

**Severity:** Low | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:30`

**Description:**

A Timer.periodic (lines 30-33) calls _updateStatus every 2 seconds, which always calls setState even when nothing changed; getSyncStatus → OfflineStorageService.getPendingCount (offline_storage_service.dart:340-358) copies the box's key list and calls box.get() per key plus a debug log on every tick. Two instances are permanently mounted (Dashboard app bar, dashboard_screen.dart:680, and the Map's Positioned overlay, map_view_screen.dart:614) inside MainAppShell's IndexedStack, so this runs forever in the background even when the sync state is idle and unchanged.

**Failure scenario:**

App sits open on any tab: 2 widgets × every 2s rebuild themselves and iterate the offline queue (plus log spam), consuming CPU/battery for a status that changes only on connectivity events or saves.

**Recommended fix:**

Replace polling with event-driven updates: expose a ValueNotifier/stream from SyncService updated on connectivity changes and queue mutations (Hive's box.listenable() works directly), and only setState when the composed status actually differs from the previous one.

---

#### [offline-18] 5-second delay after each failed item blocks the rest of the batch without actually retrying anything

**Severity:** Low | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/services/sync_service.dart:184`

**Description:**

Lines 183-186: after a failed upload, the loop awaits `syncRetryDelay` (5 s) 'before retry' — but the loop then moves to the *next* recording; the failed item is not retried in this run (its next chance is a future sync trigger, which per offline-3 may never come). So the delay punishes healthy items: with N failing items, the batch stalls N*5 seconds while `_isSyncing` keeps the indicator spinning and blocks any new sync trigger.

**Failure scenario:**

10 queued recordings all fail against a flaky backend: the sync run spends 45+ seconds mostly sleeping, the indicator spins the whole time, and a reconnect event during that window is ignored because _isSyncing is true.

**Recommended fix:**

Remove the inter-item delay, or implement a real per-item retry loop (retry the same recording up to maxSyncAttempts with short backoff before moving on). Correct the misleading comment either way.

---

#### [dash-18] Both gauge painters return shouldRepaint => true, forcing full repaints on every frame of every rebuild

**Severity:** Low | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:188`

**Description:**

DecibelGaugePainter.shouldRepaint (line 188) and NeedlePainter.shouldRepaint (line 235) unconditionally return true. Combined with the dashboard calling setState on every noise reading (dashboard_screen.dart line 385) — including filtered-out readings, since the early `return` at line 400 is inside the setState closure and the rebuild still happens — the 320x320 gauge (background ring, sweep-gradient shader, ticks, text layout) is fully repainted several times per second even when currentDb hasn't changed.

**Failure scenario:**

During recording on a low-end device, the gauge repaints ~10x/second including for readings that were rejected by the 10-130 dB filter, contributing measurable jank and battery drain on the busiest screen in the app.

**Recommended fix:**

Implement real checks: `bool shouldRepaint(covariant DecibelGaugePainter old) => old.currentDb != currentDb || old.maxDb != maxDb || old.isDark != isDark;` (same for NeedlePainter). In the dashboard, perform the range filter BEFORE calling setState so rejected readings trigger no rebuild.

---

#### [perf-13] Dead service methods with unbounded full-collection queries are cost traps

**Severity:** Low | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/services/firebase_service.dart:243`

**Description:**

Three FirebaseService methods have no call sites in lib/ but contain dangerous query shapes waiting to be used: getReadingsByLocation (lines 243-255) executes `collection('noise_readings').get()` — the ENTIRE collection, all users — and ignores its lat/lng/radius parameters entirely (returns everything unfiltered); calculateStats() (lines 320-343) downloads all of a user's readings ever recorded with no limit; getUserReadings() (lines 205-211) opens an unbounded snapshot listener over a user's full history. At 10k collection docs, one call to getReadingsByLocation bills 10k reads and downloads ~5-10MB while returning data that does not match its contract.

**Failure scenario:**

A future feature ('nearby readings') calls the innocuously-named getReadingsByLocation(lat, lng, 5): it silently downloads the whole global collection on every invocation and returns readings from the wrong side of the planet, reproducing the perf-5 cost profile in a hot path.

**Recommended fix:**

Delete the three unused methods, or fix them before anyone wires them up: implement geo bounding-box filtering (geohash/GeoFlutterFire) with a limit for getReadingsByLocation, and add .limit() plus aggregate queries to calculateStats/getUserReadings.

---

#### [map-19] Map position written to SharedPreferences on every gesture frame

**Severity:** Low | **Status:** unverified | **Category:** performance | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:631`

**Description:**

onPositionChanged (lines 631-635) calls _saveMapPosition on each camera change with hasGesture, which fires per frame during a pan/pinch — three prefs writes (lat/lng/zoom) dozens of times per second for the whole drag.

**Failure scenario:**

User pans across the city for a few seconds: hundreds of async platform-channel writes queue up, wasting battery/IO and potentially delaying other prefs operations.

**Recommended fix:**

Debounce with a Timer (e.g., persist 500ms after the last onPositionChanged) or save in MapOptions' gesture-end (onMapEvent MapEventMoveEnd) instead.

---

## Quick Wins (under 1 hour each)

- [ ] **analytics-7** - Every load issues three identical Firestore queries for the same data (stream + two .get()s) (`lib/screens/analytics_screen.dart:96`)
- [ ] **perf-10** - HeatmapPainter.shouldRepaint compares only point-list length, and each repaint draws up to 100 blurred circles (`lib/screens/map_view_screen.dart:1471`)
- [ ] **fb-5** - Community-feed card creates a brand-new Firestore snapshots() stream on every dashboard rebuild (`lib/screens/dashboard_screen.dart:907`)
- [ ] **perf-12** - Sync indicator polls every 2 seconds with unconditional setState and full Hive box iteration (`lib/widgets/sync_status_indicator.dart:30`)
- [ ] **boot-10** - runApp is blocked on the notification-permission dialog and a duplicate YAMNet model load (`lib/main.dart:48`)
- [ ] **offline-18** - 5-second delay after each failed item blocks the rest of the batch without actually retrying anything (`lib/services/sync_service.dart:184`)
- [ ] **dash-18** - Both gauge painters return shouldRepaint => true, forcing full repaints on every frame of every rebuild (`lib/widgets/decibel_meter_gauge.dart:188`)
- [ ] **map-17** - Map autocomplete fires a Nominatim request on every keystroke with no debounce and no out-of-order guard (`lib/screens/map_view_screen.dart:932`)
- [ ] **fb-8** - Search screen creates a new getNoiseReadings() stream on every rebuild (`lib/screens/search_list_screen.dart:137`)
- [ ] **ml-7** - YAMNet model is loaded twice at cold start, both times before runApp (`lib/main.dart:66`)
- [ ] **perf-11** - FadeInListItem delay scales with absolute list index, hiding deep rows for seconds and allocating a controller per row (`lib/screens/history_screen.dart:458`)
- [ ] **perf-13** - Dead service methods with unbounded full-collection queries are cost traps (`lib/services/firebase_service.dart:243`)
- [ ] **map-19** - Map position written to SharedPreferences on every gesture frame (`lib/screens/map_view_screen.dart:631`)
- [ ] **perf-7** - Cluster builder does an O(n) string scan per marker per cluster with a key that can never match (`lib/screens/map_view_screen.dart:686`)
