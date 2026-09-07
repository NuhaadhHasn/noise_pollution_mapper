# Performance Recommendations - Noise Pollution Mapper

> Generated 2026-07-13. These are PROACTIVE improvement recommendations produced by a multi-agent research pass, complementary to the defect audits (docs 01-08) in this folder. Each is grounded in the current code; implement the related bug fixes first where they overlap. Total: 39 recommendations.

## Executive Summary

This document collects 39 performance recommendations across three areas: the Firestore data layer, app runtime (TFLite inference, live-metering rebuilds, map rendering), and startup/size/build. The highest-leverage themes: (1) stop downloading whole collections for stats - collapse the analytics triple-fetch, use server-side count()/sum()/average() aggregates, and maintain per-user daily aggregate docs so analytics cost is O(days) not O(readings); (2) run YAMNet inference on a background isolate and scope live-metering rebuilds with ValueNotifier instead of whole-screen setState; (3) fix the cold start - the 4MB YAMNet model is loaded twice before the first frame; defer non-critical init and lazy-load the model on first recording; (4) enable R8 minification and ship a split-ABI app bundle instead of a fat APK; (5) trim seven verified-unused dependencies.

**Best impact-to-effort (High impact, Small effort) - do these first:**

- **Collapse the analytics triple-fetch into one query** (lib/screens/analytics_screen.dart + lib/services/firebase_service.dart)
- **Replace the dashboard's today-count StreamBuilder with a count() aggregate** (lib/screens/dashboard_screen.dart)
- **Replace the community-feed doc stream with a Firestore count() aggregation** (lib/screens/dashboard_screen.dart)
- **Scope CSV export to the current user and paginate it** (lib/screens/history_screen.dart)
- **Use server-side sum()/average()/count() aggregates as the quick win before aggregate docs land** (lib/services/firebase_service.dart)
- **Run YAMNet inference on a background isolate with IsolateInterpreter** (lib/services/sound_classification_service.dart)
- **Ship an app bundle / split-per-abi instead of a fat APK** (SIZE)
- **Dependency diet: delete seven verified-unused packages, move flutter_launcher_icons to dev_dependencies** (SIZE)
- **Stop loading the 4MB YAMNet model twice before the first frame; lazy-load on first recording** (STARTUP)

## Priority Matrix

| # | Impact | Effort | Recommendation | Area |
|---|--------|--------|----------------|------|
| 1 | High | S | Collapse the analytics triple-fetch into one query | lib/screens/analytics_screen.dart + lib/services/firebase_service.dart |
| 2 | High | S | Replace the dashboard's today-count StreamBuilder with a count() aggregate | lib/screens/dashboard_screen.dart |
| 3 | High | S | Replace the community-feed doc stream with a Firestore count() aggregation | lib/screens/dashboard_screen.dart |
| 4 | High | S | Scope CSV export to the current user and paginate it | lib/screens/history_screen.dart |
| 5 | High | S | Use server-side sum()/average()/count() aggregates as the quick win before aggregate docs land | lib/services/firebase_service.dart |
| 6 | High | S | Run YAMNet inference on a background isolate with IsolateInterpreter | lib/services/sound_classification_service.dart |
| 7 | High | S | Ship an app bundle / split-per-abi instead of a fat APK | SIZE |
| 8 | High | S | Dependency diet: delete seven verified-unused packages, move flutter_launcher_icons to dev_dependencies | SIZE |
| 9 | High | S | Stop loading the 4MB YAMNet model twice before the first frame; lazy-load on first recording | STARTUP |
| 10 | High | M | Scope live-metering rebuilds with ValueNotifier instead of whole-screen setState | lib/screens/dashboard_screen.dart |
| 11 | High | M | Add a geohash field and viewport-bounded map queries | lib/services/firebase_service.dart + lib/screens/map_view_screen.dart |
| 12 | High | M | Enable R8 minification and resource shrinking in the release build | SIZE |
| 13 | High | M | Build MainAppShell tabs lazily instead of constructing all five screens at login | STARTUP |
| 14 | High | M | Defer notification init, notification permission dialog, sync service, and dotenv until after first frame | STARTUP |
| 15 | High | L | Maintain per-user daily aggregate docs; make analytics O(days) not O(readings) | Data model + lib/services/firebase_service.dart + analytics |
| 16 | Medium | S | Speed up developer builds: enable Gradle build cache + configuration cache, drop Jetifier | BUILD |
| 17 | Medium | S | Cut cold-start time: stop loading the YAMNet model twice before runApp | lib/main.dart |
| 18 | Medium | S | Bound the Firestore cache and memoize period stats in memory | lib/main.dart + lib/screens/analytics_screen.dart |
| 19 | Medium | S | Debounce Nominatim autocomplete and drop stale responses | lib/screens/map_view_screen.dart |
| 20 | Medium | S | Use a cancellable, cached tile provider for the OSM tile layer | lib/screens/map_view_screen.dart |
| 21 | Medium | S | Wire image compression as file-to-file with real upload progress | lib/services/image_compression_service.dart |
| 22 | Medium | S | Fix gauge shouldRepaint and split the static gauge layer from the needle | lib/widgets/decibel_meter_gauge.dart |
| 23 | Medium | S | Throttle NoiseHistoryChart updates to ~1Hz and isolate its repaints | lib/widgets/noise_history_chart.dart |
| 24 | Medium | S | Remove ~1.1MB of dead assets (design-mockup SVGs and launcher-icon source) from the bundle | SIZE |
| 25 | Medium | S | Cut the splash screen's fixed 3-second dead time and add a native splash to kill the white flash | STARTUP |
| 26 | Medium | M | Paginate the community feed instead of streaming 100 docs | lib/screens/community_feed_screen.dart |
| 27 | Medium | M | Eliminate per-sample list churn in the audio capture pipeline with a Float32List ring buffer | lib/screens/dashboard_screen.dart + lib/services/sound_classification_service.dart |
| 28 | Medium | M | Carry dB data on a typed Marker subclass and adopt supercluster for 1k+ points | lib/screens/map_view_screen.dart |
| 29 | Medium | M | Render heatmap blobs with radial-gradient paints instead of per-circle MaskFilter blur | lib/screens/map_view_screen.dart |
| 30 | Medium | M | City leaderboard from maintained city_stats docs instead of last-100 sampling | lib/screens/search_list_screen.dart + data model |
| 31 | Medium | M | Make saves instant: drop the blocking connectivity probe from the write hot path | lib/services/firebase_service.dart |
| 32 | Medium | M | Stop denormalizing userEmail into every reading; resolve display names from users/{uid} | lib/services/firebase_service.dart + edit_profile + settings |
| 33 | Medium | M | Replace flutter_sound with the lightweight `record` package for PCM streaming | SIZE |
| 34 | Medium | M | Quantize yamnet.tflite to float16 to halve the largest asset | SIZE |
| 35 | Medium | M | Consolidate to a single WebView engine (drop flutter_inappwebview, keep webview_flutter) | SIZE |
| 36 | Medium | M | Cache and cancel OpenStreetMap tile requests (the app's cached_network_image equivalent) | STARTUP |
| 37 | Medium | L | Heatmap tiles from geohash-cell aggregate docs at low zoom | Data model + lib/services/heatmap_service.dart + map view |
| 38 | Low | S | Codify the index strategy for the new query shapes | Firestore indexes (firestore.indexes.json) + lib/services/firebase_service.dart |
| 39 | Low | S | Bound the Firestore offline cache instead of CACHE_SIZE_UNLIMITED | SIZE |

## Detailed Recommendations

### 1. Collapse the analytics triple-fetch into one query

**Impact:** High | **Effort:** S | **Area:** lib/screens/analytics_screen.dart + lib/services/firebase_service.dart

**Today:**

Every period-chip change in analytics runs THREE identical full-period queries: (1) analytics_screen.dart:96-97 creates a live stream via getUserReadingsByPeriod (firebase_service.dart:259-266) for the trend chart, (2) analytics_screen.dart:122 calls calculateStatsByPeriod (firebase_service.dart:283-292) which downloads every doc in the period again just to compute avg/min/max/count client-side, and (3) analytics_screen.dart:124 calls getUserReadingsByPeriodOnce (firebase_service.dart:271-279) which downloads the same docs a third time for classification counts. Three server round-trips over identical data on every chip tap.

**Proposal:**

Fetch the period's documents once and derive everything â€” stats, classification counts, and trend-chart buckets â€” from that single snapshot. The trend chart does not need a live stream; the screen already fully reloads on period change. Read-cost saving: at 10k docs (~100 docs/weekly period) this drops ~300 reads to ~100 per period switch (-67%); at 100k docs (~1,000/period) it drops ~3,000 reads to ~1,000. Also removes two loading round-trips, so the screen settles visibly faster.

**How:**

In _loadStatistics, replace the three calls with one: `final snap = await _firebaseService.getUserReadingsByPeriodOnce(userId, since);` then compute stats inline (the avg/min/max fold from calculateStatsByPeriod, the soundType/confidence loop already at analytics_screen.dart:132-153, and pass snap.docs into _buildTimeAggregatedSpots for the chart instead of a StreamBuilder on _trendStream). Delete _trendStream and render the chart from a plain List<FlSpot> held in state. If live updates are wanted later, keep one snapshots() listener and derive all three outputs inside its callback â€” still a single query.

---

### 2. Replace the dashboard's today-count StreamBuilder with a count() aggregate

**Impact:** High | **Effort:** S | **Area:** lib/screens/dashboard_screen.dart

**Today:**

dashboard_screen.dart:906-917 opens a permanent snapshots() stream over ALL of today's community readings (timestamp range on the whole collection) solely to render `snapshot.data!.docs.length` in a badge. Every dashboard visit downloads every document recorded today by every user, and the listener keeps pushing doc payloads all day.

**Proposal:**

Fetch the number with a count() aggregate on screen init and refresh it periodically (e.g., every 60s while the dashboard is visible, or on pull-to-refresh). Read-cost saving: at 10k docs (~100 readings/day community-wide) each dashboard open drops from ~100 reads to 1 (-99%); at 100k (~1,000/day) from ~1,000 reads to 1-2 (-99.8%) â€” and this is the app's home screen, so it multiplies across every session of every user. The badge is a vanity count; 60s staleness is invisible.

**How:**

Convert _buildCommunityFeedCard's StreamBuilder to a state field: in initState (and a `Timer.periodic(Duration(seconds: 60))` guarded by mounted), run `final c = (await FirebaseFirestore.instance.collection('noise_readings').where('timestamp', isGreaterThanOrEqualTo: todayStart).where('timestamp', isLessThan: todayEnd).count().get()).count;` and setState the int. The timestamp range uses the automatic single-field index â€” no composite needed. Cancel the timer in dispose.

---

### 3. Replace the community-feed doc stream with a Firestore count() aggregation

**Impact:** High | **Effort:** S | **Area:** lib/screens/dashboard_screen.dart

**Today:**

_buildCommunityFeedCard (dashboard_screen.dart:900-1020) wraps a StreamBuilder around `collection('noise_readings').where(timestamp >= todayStart).where(timestamp < todayEnd).snapshots()` (:906-914) and uses only `snapshot.data!.docs.length` (:917) to render a badge number. Every full document for every community reading made today is downloaded and kept live. Worse, because the stream is constructed inline in build(), every setState from the noise listener creates a brand-new stream, forcing StreamBuilder to unsubscribe/resubscribe several times per second during recording.

**Proposal:**

Use the count() aggregation query â€” the server returns just an integer (billed at 1 read per 1000 index entries instead of 1 read per doc), nothing is downloaded, and there is no live listener churning during metering. With community members writing a reading every 5 seconds, this measurably cuts both Firestore read costs and dashboard main-thread work.

**How:**

cloud_firestore ^5.5.0 supports aggregations: `final agg = await FirebaseFirestore.instance.collection('noise_readings').where('timestamp', isGreaterThanOrEqualTo: t0).where('timestamp', isLessThan: t1).count().get(); count = agg.count;`. Fetch once in initState into a `ValueNotifier<int>`, refresh with a 60s Timer.periodic (and on didChangeAppLifecycleState resumed). Range filters on a single field need no composite index, so this respects the project's index constraint. Replace the StreamBuilder with a ValueListenableBuilder around only the badge Text.

---

### 4. Scope CSV export to the current user and paginate it

**Impact:** High | **Effort:** S | **Area:** lib/screens/history_screen.dart

**Today:**

history_screen.dart:230-233 exports by fetching the ENTIRE noise_readings collection â€” every user's data, unbounded, in one .get() â€” then builds the CSV in memory (history_screen.dart:244-259). This is the single most expensive query in the app and it also serializes other users' emails into the file.

**Proposal:**

Filter by userId and fetch in pages of 500 using the limit+startAfterDocument pattern the screen already uses for its list (history_screen.dart:136-140). Read-cost saving: at 10k total docs a single export drops from 10,000 reads to ~1,000 (the user's own docs, -90%); at 100k it drops from 100,000 reads (~$0.06 and a likely OOM/jank freeze on-device) to ~10,000. Paging also keeps memory flat so large exports stop risking a UI freeze.

**How:**

Reuse the service method that already exists: loop `snapshot = await _firebaseService.getUserReadingsPaginated(userId: uid, limit: 500, startAfter: last); csvRows.addAll(...); last = snapshot.docs.last;` until fewer than 500 docs return, yielding to the event loop between pages (`await Future.delayed(Duration.zero)`). The query shape (userId == + orderBy timestamp desc) is exactly the existing composite index, so no index work. Optionally stream rows straight to the file via IOSink instead of a StringBuffer.

---

### 5. Use server-side sum()/average()/count() aggregates as the quick win before aggregate docs land

**Impact:** High | **Effort:** S | **Area:** lib/services/firebase_service.dart

**Today:**

calculateStatsByPeriod (firebase_service.dart:283-317) downloads all period docs to compute avg and count client-side; getUserReadingsCount (firebase_service.dart:233-240) already proves the codebase can use count() â€” but sum/average are never used anywhere.

**Proposal:**

cloud_firestore 5.5.0 (pubspec.yaml:35) supports multi-aggregation queries. Replace the doc download in calculateStatsByPeriod with one aggregate call for count + average; keep min/max from recommendation 2's aggregate docs (Firestore has no server min/max), or temporarily from a small raw fetch. Aggregates bill 1 read per 1,000 index entries scanned, so: at 10k docs (100/period) the stats call drops from 100 reads to 1 (-99%); at 100k (1,000/period) from 1,000 reads to 1-2 (-99.8%). Zero data transferred to the device â€” noticeably faster on mobile networks.

**How:**

`final agg = await _firestore.collection('noise_readings').where('userId', isEqualTo: uid).where('timestamp', isGreaterThan: Timestamp.fromDate(since)).aggregate(count(), average('decibelLevel')).get(); final avg = agg.getAverage('decibelLevel'); final n = agg.count;`. This query shape is identical to the existing one, so it is served by the existing (userId ASC, timestamp DESC) composite index â€” no new index needed. Do NOT add orderBy to the aggregate query (aggregates don't need it and it changes index requirements).

---

### 6. Run YAMNet inference on a background isolate with IsolateInterpreter

**Impact:** High | **Effort:** S | **Area:** lib/services/sound_classification_service.dart

**Today:**

classifySound() calls _interpreter!.run(input, output) synchronously on the main isolate (sound_classification_service.dart:108). It is invoked from the dashboard's 5-second classification timer (dashboard_screen.dart:507-514, :634) while the noise meter, audio stream, and UI animations are all live on the same thread. YAMNet inference on a mid-range Android phone takes 50-200ms, so every 5 seconds during metering the UI drops frames: the gauge needle stutters and the record button animation hitches. The debug block at :119-123 additionally full-sorts all 521 scores on every inference just to log the top 3.

**Proposal:**

Move inference off the UI isolate using tflite_flutter's built-in IsolateInterpreter (already available in the pinned ^0.12.1). The gauge and chart stay at 60fps during classification, and the periodic 5s hitch that users feel while recording disappears entirely. Zero new dependencies.

**How:**

In initialize(): `_interpreter = await Interpreter.fromAsset(...); _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);`. In classifySound(): `await _isolateInterpreter!.run(input, output);` (the call becomes genuinely async; the dashboard already awaits it at dashboard_screen.dart:634 so no caller changes). Close both in dispose(). While there, wrap the top-3 debug sort in `if (kDebugMode)` and replace the full sort with a single O(n) pass tracking three maxima.

---

### 7. Ship an app bundle / split-per-abi instead of a fat APK

**Impact:** High | **Effort:** S | **Area:** SIZE

**Today:**

Neither android/app/build.gradle.kts nor gradle.properties configures ABI splits or bundle language/density splitting â€” a plain `flutter build apk` produces one universal APK containing libflutter.so and libtensorflowlite_c/jni .so for arm64-v8a, armeabi-v7a, and x86_64. The Flutter engine alone is roughly 10MB per ABI, and tflite_flutter adds its native library per ABI on top; users download and store every architecture except theirs for nothing.

**Proposal:**

Distribute via `flutter build appbundle` (Play handles per-device splitting automatically) or `flutter build apk --split-per-abi` for direct-APK distribution. This roughly halves (often better) the download and install size for every user with zero code changes â€” the highest size-win-per-effort available.

**How:**

No gradle edits required for --split-per-abi; just change the build/CI command. For Play, `flutter build appbundle --release` (pairs with the R8 recommendation). If direct APKs, publish the three per-abi APKs (app-arm64-v8a-release.apk etc.) and default download links to arm64-v8a. Note build.gradle.kts:44-46 still signs release with debug keys â€” set up a real signing config as part of the same release-pipeline change.

---

### 8. Dependency diet: delete seven verified-unused packages, move flutter_launcher_icons to dev_dependencies

**Impact:** High | **Effort:** S | **Area:** SIZE

**Today:**

Verified by grepping every `package:X/` import under lib/ â€” zero Dart imports for: google_maps_flutter (pubspec.yaml:54 â€” the map UI is entirely flutter_map, map_view_screen.dart:3, yet the plugin still compiles the full Google Maps Android SDK into the APK and registers at startup because Flutter plugins link natively regardless of Dart usage), flutter_paypal_payment (pubspec.yaml:90 â€” the PayPal flow is a hand-rolled InAppWebView in lib/widgets/paypal_webview_widget.dart), flutter_map_heatmap (pubspec.yaml:104 â€” heatmap is custom, lib/services/heatmap_service.dart + HeatmapLayer in map_view_screen.dart:649), provider (pubspec.yaml:62 â€” state is ValueNotifier/setState throughout), flutter_svg (pubspec.yaml:87), image_picker (pubspec.yaml:65), url_launcher (pubspec.yaml:93 â€” only a comment mentions it, buy_me_coffee_widget.dart:107). Additionally flutter_launcher_icons (pubspec.yaml:78) sits in runtime `dependencies` though it is purely a build-time icon generator.

**Proposal:**

Remove all seven from dependencies and relocate flutter_launcher_icons to dev_dependencies. google_maps_flutter alone is one of the largest native SDKs in the Android ecosystem (~3-5MB post-R8); dropping it plus the others cuts APK size, cold-start plugin registration time, dependency-resolution conflicts, and future upgrade surface. Zero user-visible change since none are referenced.

**How:**

Delete the seven entries from pubspec.yaml dependencies; move flutter_launcher_icons under dev_dependencies; `flutter pub get`; `flutter build apk --release` and smoke-test map, donation, and recording flows. Keep webview_flutter and flutter_inappwebview for now (both genuinely used â€” see the WebView-consolidation recommendation). Also delete the empty stray `assetsmodels/` directory at the project root while in there.

---

### 9. Stop loading the 4MB YAMNet model twice before the first frame; lazy-load on first recording

**Impact:** High | **Effort:** S | **Area:** STARTUP

**Today:**

main.dart loads yamnet.tflite (4,126,810 bytes on disk at assets/models/yamnet.tflite) twice, both awaited before runApp(): main.dart:66 calls _testModelLoading() which does Interpreter.fromAsset('assets/models/yamnet.tflite') (main.dart:80-82), logs the tensor shapes, then immediately interpreter.close() (main.dart:94) â€” a pure diagnostic that throws the work away. Then main.dart:69 calls _initializeSoundClassification() which loads the exact same model a second time via SoundClassificationService.initialize() (lib/services/sound_classification_service.dart:56). The model is only ever consumed when the user taps record on the Dashboard â€” dashboard_screen.dart:592 guards on _classificationService.isInitialized and dashboard_screen.dart:634 calls classifySound(). Nothing needs the interpreter at app start.

**Proposal:**

Delete _testModelLoading() entirely (it duplicates the logging already done inside SoundClassificationService.initialize at sound_classification_service.dart:57-58), and remove the awaited _initializeSoundClassification() from main(). Initialize the model lazily the first time the user starts a recording. This removes ~two full 4MB asset reads + interpreter constructions from the cold-start critical path â€” the single biggest first-frame win available â€” with zero behavior change, because the service is a singleton whose initialize() is idempotent (sound_classification_service.dart:49-51 early-returns if already initialized).

**How:**

In dashboard_screen.dart's start-recording path (near line 472 where startRecorder is called), add: `if (!_classificationService.isInitialized) { await _classificationService.initialize(); }` before starting the classification timer. Optionally warm it in the background after first frame so the first recording has no hiccup: in main() after runApp, `WidgetsBinding.instance.addPostFrameCallback((_) { unawaited(SoundClassificationService().initialize()); });`. Also consider Interpreter.fromAsset with InterpreterOptions()..threads for faster inference, unchanged API.

---

### 10. Scope live-metering rebuilds with ValueNotifier instead of whole-screen setState

**Impact:** High | **Effort:** M | **Area:** lib/screens/dashboard_screen.dart

**Today:**

The noise_meter listener calls setState on every NoiseReading event (dashboard_screen.dart:381-439) â€” several times per second while recording. Each call rebuilds the entire dashboard build() (:670-897): AppBar, greeting Text, stat cards, gauge, location pill, classification card, record button, chart, and the community-feed StreamBuilder. _performSoundClassification adds two more full rebuilds per cycle just to toggle _isClassifying (:610-612, :651-655). The average is also recomputed by reducing the full 100-entry _dbHistory on every event (:423-425).

**Proposal:**

Hold the fast-changing values (currentDb, min/max/avg, dbHistory revision, classification result, isClassifying) in ValueNotifiers and rebuild only the widgets that display them. The rest of the screen â€” which is 90% of the widget tree â€” builds once. This is the single biggest smoothness win for the core metering flow and it compounds with every other dashboard fix.

**How:**

Add `final _dbNotifier = ValueNotifier<double>(0);` plus a small immutable Stats record in a ValueNotifier for min/avg/max. In the noise listener, drop setState and just assign notifier values; maintain avg incrementally with a running sum (add new, subtract evicted) instead of reduce(). Wrap DecibelMeterGauge, the stat-card Row, and NoiseHistoryChart each in `ValueListenableBuilder` (and each in a RepaintBoundary). Keep setState only for the rare _isRecording toggle. The classification card listens to a `ValueNotifier<ClassificationResult?>` instead of two setStates per cycle.

---

### 11. Add a geohash field and viewport-bounded map queries

**Impact:** High | **Effort:** M | **Area:** lib/services/firebase_service.dart + lib/screens/map_view_screen.dart

**Today:**

The map and heatmap load the globally most-recent 100 readings regardless of where the user is looking: map_view_screen.dart:42 fixes _kMapReadingLimit=100 and map_view_screen.dart:131-135 calls getNoiseReadingsOnce (firebase_service.dart:174-180, orderBy timestamp desc + limit). getReadingsByLocation (firebase_service.dart:243-255) even fetches the whole collection with a comment admitting geo queries are needed. As the dataset grows, the 100 newest readings will be scattered worldwide and a user's own city shows almost nothing.

**Proposal:**

Write a geohash string on every reading and query by the visible map region (geohash prefix ranges for the viewport, refreshed on map-move-end). Reads stay bounded (â‰¤ limit per visible cell) but become relevant: at 10k docs the cost is roughly unchanged (~100 reads/load) while showing the right data; at 100k docs this is the only strategy that avoids either irrelevant results or a multi-thousand-read regional fetch â€” expect ~100-300 reads per viewport vs 100 useless ones today or 10,000+ for a naive lat/lng range scan. Users immediately see their neighborhood's noise instead of the world's newest 100 points.

**How:**

Add `geoflutterfire_plus` (compatible with cloud_firestore 5.x): on write, store `'geo': GeoFirePoint(GeoPoint(lat, lng)).data` (adds geohash + geopoint). Query: `GeoCollectionReference(_firestore.collection('noise_readings')).subscribeWithin(center: mapCenter, radiusInKm: visibleRadius, field: 'geo', geopointFrom: ...)` or the one-shot fetchWithin. Hook flutter_map's `onMapEvent` (MapEventMoveEnd) to re-fetch, debounced ~500ms. Geohash range queries use orderBy on the single geohash field (automatic index â€” no composite needed). Backfill existing docs with a one-off script computing geohash from stored latitude/longitude. Note: geohash range + timestamp range can't combine in one Firestore query (two range fields), so apply the time-preset filter client-side over the viewport-bounded results â€” heatmap_service.dart:30-50 (filterByTimeRange) already does exactly this.

---

### 12. Enable R8 minification and resource shrinking in the release build

**Impact:** High | **Effort:** M | **Area:** SIZE

**Today:**

android/app/build.gradle.kts:42-48 â€” the release buildType contains only `signingConfig = signingConfigs.getByName("debug")`. There is no isMinifyEnabled, no isShrinkResources, and no proguard-rules.pro in android/app/. All Java/Kotlin bytecode from Firebase (core, auth, firestore, storage), flutter_inappwebview, webview_flutter, flutter_local_notifications, geolocator, flutter_sound, and the unused google_maps_flutter native SDK ships un-shrunk and un-obfuscated.

**Proposal:**

Turn on R8 with resource shrinking for release. On a dependency list this heavy (four Firebase SDKs + two webview engines + Google Maps SDK), R8 typically removes 30-50% of the DEX/resource payload â€” several MB off the APK â€” and dead-code-eliminates unused SDK paths. Also improves cold start slightly (less DEX to load/verify).

**How:**

In build.gradle.kts release block: `isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`. Create android/app/proguard-rules.pro with the known keeps for this stack: `-keep class org.tensorflow.** { *; }` (tflite_flutter JNI), the flutter_local_notifications GSON rules (`-keep class com.dexterous.** { *; }`, generic signature keeps for TypeToken), and `-keep class com.google.firebase.** { *; }` only if smoke tests reveal issues (Firebase ships its own consumer rules). Verify with `flutter build apk --release` + a full smoke test of recording, notifications, and sync.

---

### 13. Build MainAppShell tabs lazily instead of constructing all five screens at login

**Impact:** High | **Effort:** M | **Area:** STARTUP

**Today:**

lib/widgets/main_app_shell.dart:38-46 puts all five tab screens into an IndexedStack as const children, so every screen's initState fires on the first frame after login: MapViewScreen starts location resolution and map/reading loads (map_view_screen.dart:75+), AnalyticsScreen immediately runs _loadStatistics() Firestore queries (analytics_screen.dart:49), HistoryScreen runs _checkConnectivityAndLoad() with a connectivity platform call plus data load (history_screen.dart:39), SettingsScreenEnhanced reads SharedPreferences (settings_screen_enhanced.dart:39), and DashboardScreen opens the flutter_sound recorder, requests mic permission, and starts GPS acquisition (dashboard_screen.dart:93-97). Five screens' worth of I/O, Firestore reads, and platform-channel traffic compete during the first visible frame, and the Firestore reads for tabs the user may never open also cost read quota.

**Proposal:**

Keep the IndexedStack (preserving the existing keep-alive/isInAppShell contract) but only instantiate each child the first time its tab is selected, showing a lightweight placeholder until then. Login-to-interactive gets dramatically cheaper â€” only Dashboard (index 2) does work up front â€” and Firestore reads for unvisited Analytics/History tabs are eliminated entirely, which is a direct cost saving on the reads bill.

**How:**

Classic lazy-IndexedStack pattern: `final List<Widget?> _built = List.filled(5, null);` in _MainAppShellState; in build, `_built[_currentIndex] ??= _buildTab(_currentIndex);` and children: `List.generate(5, (i) => _built[i] ?? const SizedBox.shrink())`. Once built, a screen stays alive in the stack exactly as today, so per-tab state (map camera, dashboard recording) is preserved and the isInAppShell contract is untouched.

---

### 14. Defer notification init, notification permission dialog, sync service, and dotenv until after first frame

**Impact:** High | **Effort:** M | **Area:** STARTUP

**Today:**

main() runs a fully sequential await chain before runApp() (main.dart:26-71): dotenv.load (line 31), Firebase.initializeApp (line 38), NotificationService.initialize() AND NotificationService.requestPermission() (lines 47-48 â€” on Android 13+ this pops the POST_NOTIFICATIONS system dialog over a blank screen before any UI exists), SyncService().initialize() (line 51 â€” opens Hive storage plus a connectivity_plus platform-channel check, sync_service.dart:31-70), SharedPreferences (line 55). Of these, only Firebase and the theme prefs are needed to draw the first frame. dotenv is consumed exclusively by lib/services/donation_service.dart:9-16 (PayPal/BuyMeACoffee config) â€” a screen most users never open.

**Proposal:**

Keep only Firebase.initializeApp + Firestore settings + SharedPreferences (theme) before runApp. Move NotificationService.initialize, SyncService().initialize, and dotenv.load to a post-first-frame callback, and move requestPermission() out of startup entirely â€” request notification permission in context (e.g., when the user enables high-noise alerts in settings, or on first recording alongside the mic permission the Dashboard already requests at dashboard_screen.dart:151-158). Users see the app 0.5-1.5s sooner on mid-range Android, and the cold-start permission dialog â€” which most users reflexively deny when it appears with no context â€” moves to a moment where they understand why, improving grant rates.

**How:**

In main(): `runApp(const MyApp()); WidgetsBinding.instance.addPostFrameCallback((_) => _initDeferredServices());` where _initDeferredServices awaits dotenv.load, NotificationService.initialize(), and SyncService().initialize() (all are already idempotent/guarded: notification_service.dart:12, sync_service.dart:32). DonationService already falls back to '' when dotenv keys are absent, but to be safe make donation_service getters call `dotenv.isInitialized ? dotenv.env[...] : ...` or await a shared init future in the donation screen.

---

### 15. Maintain per-user daily aggregate docs; make analytics O(days) not O(readings)

**Impact:** High | **Effort:** L | **Area:** Data model + lib/services/firebase_service.dart + analytics

**Today:**

All analytics stats are computed by downloading raw readings: calculateStatsByPeriod (firebase_service.dart:283-317) and calculateStats (firebase_service.dart:320-343, currently uncalled but exported) fetch every matching doc and reduce client-side. Classification breakdowns (analytics_screen.dart:126-153) and trend buckets (analytics_screen.dart:184-226) also iterate raw docs. Cost grows linearly with how much a user records.

**Proposal:**

On every reading write, also increment a per-user-per-day aggregate doc `user_daily_stats/{uid}_{yyyyMMdd}` holding {count, sumDb, minDb, maxDb, pollutionCount, ambientCount, confidenceSum, confidenceCount, soundClassCounts: {â€¦}}. Analytics then reads at most 1 (Daily) / 7 (Weekly) / 30 (Monthly) tiny docs regardless of recording volume, and gets min/max and classification counts that Firestore's server aggregates cannot provide. Read-cost saving per analytics view: at 10k docs, weekly drops ~100 reads to 7 (-93%); at 100k docs, ~1,000 reads to 7 (-99.3%). The weekly/monthly trend chart's day buckets map 1:1 onto these docs, so the chart becomes free too (Daily's hourly buckets can keep the raw query â€” it is bounded to 24h of one user's data).

**How:**

In _saveToFirebase (firebase_service.dart:107-134) and SyncService._saveToFirebase (sync_service.dart:210-234), switch from `.add(data)` to a WriteBatch: `batch.set(readingRef, data); batch.set(dailyRef, {'count': FieldValue.increment(1), 'sumDb': FieldValue.increment(db), 'soundClassCounts.$cls': FieldValue.increment(1), ...}, SetOptions(merge: true));` â€” min/max need a transaction or a Cloud Function `onDocumentCreated('noise_readings/{id}')` (functions also backfill historical data via a one-off script). Analytics reads `where(FieldPath.documentId, whereIn: [...ids])` or a `where('userId'==).where('date' >=)` query on the stats collection. Doc IDs of the form `{uid}_{yyyyMMdd}` make writes idempotent and need no new composite index if you embed uid+date fields.

---

### 16. Speed up developer builds: enable Gradle build cache + configuration cache, drop Jetifier

**Impact:** Medium | **Effort:** S | **Area:** BUILD

**Today:**

android/gradle.properties enables `android.enableJetifier=true` (legacy support-library rewriting that adds a transform step to every dependency on every build â€” almost certainly unnecessary since every dependency in this pubspec is AndroidX-native) and `org.gradle.configureondemand=true` (deprecated, incompatible with modern AGP features), while the two settings that actually pay off are absent: org.gradle.caching and the configuration cache. The 8GB heap (-Xmx8G) is already generous.

**Proposal:**

Remove Jetifier and configure-on-demand; add build cache and configuration cache. Typical result on a Flutter+Firebase Android module of this size is 20-40% faster incremental Gradle builds and much faster configuration phases â€” compounding across every `flutter run`/`flutter build` the team does.

**How:**

In gradle.properties: delete `android.enableJetifier=true` and `org.gradle.configureondemand=true`; add `org.gradle.caching=true` and `org.gradle.configuration-cache=true`. Validate with `./gradlew :app:assembleDebug --scan` (or check for jetifier warnings) â€” if any legacy com.android.support artifact sneaks in via a transitive dep the build will say so explicitly, in which case keep Jetifier and file the offender.

---

### 17. Cut cold-start time: stop loading the YAMNet model twice before runApp

**Impact:** Medium | **Effort:** S | **Area:** lib/main.dart

**Today:**

main() awaits _testModelLoading() (main.dart:66), which loads the multi-megabyte yamnet.tflite from assets, reads tensor shapes, and immediately closes it (:75-99), then awaits _initializeSoundClassification() (:69) which loads the exact same model again via SoundClassificationService.initialize(). Both happen before runApp (:71), alongside awaited NotificationService, SyncService, and SharedPreferences init â€” the user stares at the launch screen while the model is parsed twice.

**Proposal:**

Delete the redundant test load and defer classification init until after the first frame. The model isn't needed until the user taps the record button on the Dashboard, so nothing is lost â€” cold start gets faster by roughly the cost of two asset loads plus interpreter allocation.

**How:**

Remove _testModelLoading entirely (initialize() already logs shapes at sound_classification_service.dart:57-58 and fails gracefully). Kick off init without blocking startup: after runApp, `WidgetsBinding.instance.addPostFrameCallback((_) => SoundClassificationService().initialize());` â€” or lazier still, await initialize() inside _startRecording() before starting the classification timer (dashboard_screen.dart:507). The service is a singleton with an _isInitialized guard, so double-init is already safe.

---

### 18. Bound the Firestore cache and memoize period stats in memory

**Impact:** Medium | **Effort:** S | **Area:** lib/main.dart + lib/screens/analytics_screen.dart

**Today:**

main.dart:41-44 enables persistence with `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED`, so the on-device cache grows forever (slow LRU-less SQLite scans on low-end Android as it bloats). Meanwhile nothing memoizes computed results: toggling analytics period chips Dailyâ†’Weeklyâ†’Daily re-runs the full query set each time (_loadStatistics fires on every chip change), and every .get() in the app defaults to Source.serverAndCache, i.e., always bills server reads even when the cache holds the answer.

**Proposal:**

(a) Cap the cache at ~100MB so eviction works: `cacheSizeBytes: 100 * 1024 * 1024`. (b) Memoize analytics period results in a `Map<String, _PeriodStats>` with a short TTL (~5 min), invalidated when the user saves a new reading. Read-cost saving: each repeated chip toggle currently costs ~300 reads at 10k / ~3,000 at 100k (with today's triple-fetch; ~100/~1,000 after rec 1) â€” memoization makes repeats zero. (c) For instant paint on map/history, try cache first: `.get(const GetOptions(source: Source.cache))`, render, then refresh from server â€” perceived load time drops to near-zero on revisits.

**How:**

One-line settings change in main.dart. In _AnalyticsScreenState: `final _statsCache = <String, ({DateTime at, PeriodStats stats})>{};` â€” check `_statsCache[_selectedPeriod]` (age < 5 min) before querying in _loadStatistics; store on success; clear the map from the save flow (expose a static ValueNotifier or clear on screen re-entry after recording). Cache-first reads: wrap getNoiseReadingsOnce with a try `Source.cache` / catch-then-`Source.server` helper in FirebaseService.

---

### 19. Debounce Nominatim autocomplete and drop stale responses

**Impact:** Medium | **Effort:** S | **Area:** lib/screens/map_view_screen.dart

**Today:**

TextField.onChanged calls _autocompleteSearch on every keystroke (map_view_screen.dart:932-934), which fires an HTTP request to Nominatim with limit=50 and addressdetails=1 (:357-368) â€” typing "colombo" issues 7 requests, each response parsed, distance-sorted twice (:408-451), and pushed through setState (:507-509). Responses can also return out of order, so an earlier, slower query can overwrite the results of the latest keystroke, and rapid-fire requests violate Nominatim's 1-req/sec usage policy (risking IP throttling that users experience as search silently breaking).

**Proposal:**

A 350ms debounce plus a request-sequence guard cuts network traffic ~5-7x, keeps the dropdown consistent with what the user actually typed, makes results appear faster (no queue of stale requests ahead), and keeps the app within Nominatim's rate policy.

**How:**

Add `Timer? _debounce; int _searchSeq = 0;`. In onChanged: `_debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 350), () => _autocompleteSearch(value));`. In _autocompleteSearch: `final seq = ++_searchSeq; final results = await _searchNominatim(query); if (seq != _searchSeq || !mounted) return;` before setState. Cancel _debounce in dispose(). Consider dropping limit to 15 â€” the dropdown is capped at 250px tall anyway (:986).

---

### 20. Use a cancellable, cached tile provider for the OSM tile layer

**Impact:** Medium | **Effort:** S | **Area:** lib/screens/map_view_screen.dart

**Today:**

The TileLayer is configured with only urlTemplate and userAgentPackageName (map_view_screen.dart:639-644), so it uses flutter_map's default NetworkTileProvider: tile HTTP requests for tiles panned out of view cannot be aborted and keep consuming bandwidth/decoder time, and every app session re-downloads identical OSM tiles because nothing persists them beyond the small in-memory cache.

**Proposal:**

Adopt the officially recommended cancellable provider so off-screen tile fetches abort mid-flight (flutter_map docs report meaningfully reduced tile loading times and unnecessary requests, biggest on the web/slow networks), and add disk caching so repeat visits to the user's own city â€” the dominant usage pattern for a local noise map â€” render instantly and work better offline.

**How:**

Add flutter_map_cancellable_tile_provider (supports flutter_map v7): `TileLayer(urlTemplate: ..., tileProvider: CancellableNetworkTileProvider())`. For persistence either flutter_map_tile_caching (full FMTC store, also enables offline regions) or the lightweight route: `CachedTileProvider` backed by cached_network_image/dio cache with a ~7-day maxStale matching OSM tile-usage policy.

---

### 21. Wire image compression as file-to-file with real upload progress

**Impact:** Medium | **Effort:** S | **Area:** lib/services/image_compression_service.dart

**Today:**

ImageCompressionService exposes compressImage(Uint8List) via FlutterImageCompress.compressWithList (image_compression_service.dart:20-46), which marshals the full original image across the platform channel and holds both the 2-3MB original and the compressed copy in the Dart heap simultaneously; on failure it silently returns the uncompressed original (:44), which would upload full-size. The file-based variant exists (:51-82) but nothing in lib/ calls either method yet (verified by grep), so when the photo-report feature lands there is no established fast path and no progress UX.

**Proposal:**

Standardize on the fileâ†’file path as the only entry point before call sites exist: the image bytes never enter the Dart heap (native code reads and writes files directly), peak memory drops by the full image size, and the platform-channel copy of multi-MB buffers disappears. Pair it with Firebase Storage's UploadTask progress stream so users see a real percentage during the slow part (upload), not a frozen spinner.

**How:**

Make compressImageFile the primary API; write output to `path_provider` tempDir instead of alongside the source (getTargetPath at :85-90 writes next to the original, which fails for read-only picked files on Android 10+ scoped storage). Add `keepExif: false, autoCorrectionAngle: true` to strip metadata and fix rotation. For progress: `final task = FirebaseStorage.instance.ref(path).putFile(File(compressedPath)); task.snapshotEvents.listen((s) => progressNotifier.value = s.bytesTransferred / s.totalBytes);` driving a LinearProgressIndicator via ValueListenableBuilder. If a bytes-based path is ever unavoidable, at least null out the original reference before awaiting compressWithList.

---

### 22. Fix gauge shouldRepaint and split the static gauge layer from the needle

**Impact:** Medium | **Effort:** S | **Area:** lib/widgets/decibel_meter_gauge.dart

**Today:**

Both DecibelGaugePainter and NeedlePainter return true unconditionally from shouldRepaint (decibel_meter_gauge.dart:188, :235), so the full 320x320 gauge repaints on every frame Flutter paints, even when the dB value hasn't changed. Each repaint re-creates the SweepGradient shader (:93-105) and re-runs TextPainter.layout for all five tick labels (:124-174) â€” the background circle, ticks, and numbers are completely static yet are redrawn with the needle every time.

**Proposal:**

Make repaints value-driven and confine per-reading raster work to just the arc + needle. Combined with rec 2, the gauge becomes a cheap, isolated repaint region â€” the difference is visible as a steadier needle on low-end devices and lower GPU/battery load during long metering sessions.

**How:**

shouldRepaint: `old.currentDb != currentDb || old.isDark != isDark`. Split painting into three stacked layers: (a) static background/ticks/labels in its own CustomPaint wrapped in RepaintBoundary with `shouldRepaint => old.isDark != isDark` (cache the five laid-out TextPainters in static fields); (b) progress arc painter; (c) needle painter. Wrap the whole gauge in one RepaintBoundary so its repaints never merge with the scrollable's layer. Optionally quantize: only push a new value when `(db - last).abs() >= 0.5` to skip imperceptible repaints.

---

### 23. Throttle NoiseHistoryChart updates to ~1Hz and isolate its repaints

**Impact:** Medium | **Effort:** S | **Area:** lib/widgets/noise_history_chart.dart

**Today:**

NoiseHistoryChart rebuilds on every parent setState â€” i.e., on every noise reading, several times per second â€” and each build allocates a fresh list of up to 50 FlSpots (noise_history_chart.dart:43-47) and hands LineChart a 250ms implicit animation (:31-34). Because new data arrives faster than the animation completes, fl_chart is perpetually animating: continuous curve interpolation, gradient area fill, and path rebuilding on the UI thread for a small trend sparkline.

**Proposal:**

A history trend chart does not need 5-10 updates per second â€” updating once per second is visually identical and eliminates the perpetual animation. Combined with rec 2's ValueListenableBuilder scoping, the chart goes from the most expensive recurring widget on the dashboard to near-free.

**How:**

Give the chart its own `ValueNotifier<List<double>>` that the noise listener updates through a 1s throttle (`if (now.difference(_lastChartPush) > const Duration(seconds: 1))`). Wrap the LineChart in RepaintBoundary. Drop the animation (`duration: Duration.zero`) or keep it â€” at 1Hz it can actually finish. If further headroom is ever needed, the no-axes no-grid styling here is trivially replaceable with a ~40-line CustomPaint sparkline, removing fl_chart from the hot path entirely.

---

### 24. Remove ~1.1MB of dead assets (design-mockup SVGs and launcher-icon source) from the bundle

**Impact:** Medium | **Effort:** S | **Area:** SIZE

**Today:**

pubspec.yaml:134-137 bundles `assets/images/backgrounds/` and `assets/icons/`. assets/images/backgrounds/ holds 939,535 bytes of design-mockup SVGs (Search & List View 1.svg 184KB, Onboarding Screen 1.svg 140KB, Map View 1.svg 103KB, etc.) â€” grep finds zero references to 'backgrounds/' anywhere in lib/, and flutter_svg (the only way to render them) is itself never imported. assets/icons/icon.png is 170,309 bytes and is referenced only by flutter_launcher_icons.yaml as the generator's image_path â€” the app never loads it at runtime (no 'assets/icons' references in lib/).

**Proposal:**

Drop both asset directory entries from pubspec.yaml. The files can stay in the repo for design reference and icon regeneration â€” they just should not ship inside every user's APK. Saves ~1.1MB of bundle payload for free.

**How:**

Remove `- assets/images/backgrounds/` and `- assets/icons/` from the flutter.assets list (keep `- assets/models/`). flutter_launcher_icons reads image_path from disk at generation time, not from the asset bundle, so icon generation is unaffected. Verify with `flutter build apk --release --analyze-size` before/after.

---

### 25. Cut the splash screen's fixed 3-second dead time and add a native splash to kill the white flash

**Impact:** Medium | **Effort:** S | **Area:** STARTUP

**Today:**

lib/screens/splash_screen.dart:36-42 hardcodes `Timer(const Duration(seconds: 3), ...)` before navigating to OnboardingScreen, while the fade animation completes at 1500ms (splash_screen.dart:24) â€” every logged-out launch pays 1.5s of dead time staring at a finished animation. Before that, android/app/src/main/res/drawable/launch_background.xml is the default plain white Flutter template with a Theme.Light LaunchTheme (styles.xml), so the cold-start sequence is: white native screen â†’ dark-themed Flutter splash â†’ onboarding, with a jarring white-to-dark flash.

**Proposal:**

Navigate when the animation completes (~1.5s) instead of a fixed 3s â€” or immediately once first-run work is done â€” halving perceived startup for every logged-out user. Add flutter_native_splash so the OS-drawn launch window shows the same dark background and sound-wave mark as the Flutter splash, making the native-to-Flutter handoff invisible.

**How:**

Replace the Timer with `_animationController.forward().whenComplete(() { if (mounted) Navigator.of(context).pushReplacement(...); })` or add a status listener. Add flutter_native_splash to dev_dependencies with `color: "#<AppTheme.darkBackground hex>"` (plus android_12: section for the Android 12+ splash API) and run `dart run flutter_native_splash:create` â€” it rewrites launch_background.xml and styles.xml for you. Also fix the LaunchTheme parent to a dark theme so the status bar matches.

---

### 26. Paginate the community feed instead of streaming 100 docs

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/community_feed_screen.dart

**Today:**

community_feed_screen.dart:62-67 opens a snapshots() stream with limit(100), so every screen open downloads 100 full documents up front and keeps a listener resident while the screen is up. Users typically read the first handful of cards.

**Proposal:**

Load 20 docs initially and fetch more with limit+startAfterDocument on scroll â€” the exact infrastructure history_screen already has (history_screen.dart:117-158 and firebase_service.dart:214-230), minus the userId filter. Keep at most a small snapshots(limit(1)) listener (or the dashboard count from rec 4) to show a 'new reports' pill. Read-cost saving: 100 to 20 reads per screen open (-80%) at both 10k and 100k scale; this screen is reachable from the home card, so it is opened often. First paint is also faster since 5x less data crosses the network.

**How:**

Copy history_screen's pattern: a ScrollController with a -200px threshold (history_screen.dart:161-167), `_firestore.collection('noise_readings').orderBy('timestamp', descending: true).limit(20)` then `.startAfterDocument(_lastDoc)` for subsequent pages; convert the StreamBuilder body to a ListView.builder over accumulated docs with RefreshIndicator re-running page 1. Uses only the automatic timestamp single-field index.

---

### 27. Eliminate per-sample list churn in the audio capture pipeline with a Float32List ring buffer

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/dashboard_screen.dart + lib/services/sound_classification_service.dart

**Today:**

_processAudioData appends samples one-by-one to a growable List<double> (dashboard_screen.dart:521-532) â€” 16,000 boxed-path adds per second for the entire recording session â€” and trims via removeRange, which shifts up to 32k elements left each time (:535-540). Each classification then copies the window with sublist (:618) or List.from+addAll (:624-627), and the service copies again: List.from (sound_classification_service.dart:168), map().toList() in _normalizeAudio (:241), and addAll padding (:181). That's 4-5 transient 15,600-element double lists per cycle plus constant allocation pressure on the UI isolate, showing up as GC pauses during metering.

**Proposal:**

Replace the growable list with a fixed 32,000-slot Float32List ring buffer (write index modulo capacity) and make preprocessing operate in place on one reusable Float32List. Steady-state allocations during recording drop to near zero, GC pauses disappear from the metering hot path, and Float32List matches the float32 tensor input so tflite_flutter avoids a conversion pass.

**How:**

`final _ring = Float32List(32000); int _writeIdx = 0, _filled = 0;` â€” in _processAudioData use ByteData.view(bytes.buffer) with getInt16(i, Endian.little) and write `sample/32767.0` into the ring. For classification, copy the newest 15,600 samples into a single reusable `Float32List(15600)` scratch buffer (two setRange calls handle wraparound; zero-fill handles the padded case). In the service, find peak and divide in place in one loop over the scratch buffer; resampling can write into a second reusable buffer. Pass `[scratch]` directly to the (Isolate)Interpreter.

---

### 28. Carry dB data on a typed Marker subclass and adopt supercluster for 1k+ points

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/map_view_screen.dart

**Today:**

Marker noise levels live in a side-table `Map<String,double> _markerNoiseLevels` keyed by a lat/lng string (map_view_screen.dart:64, :200-201). The cluster builder then does `_markerNoiseLevels.keys.firstWhere(...)` per marker per cluster (:683-694) â€” an O(markers x keys) string scan re-executed every time clusters rebuild (every zoom change). Each of the up-to-100 markers is a Column with two blur BoxShadows (:1093-1145), rasterized anew as the layer repositions children during pan. flutter_map_marker_cluster ^1.4.0 (pubspec.yaml:56) does greedy distance clustering in the widget layer, which degrades noticeably beyond a few hundred markers, and _kMapReadingLimit is capped at 100 (:42) partly because of this.

**Proposal:**

Make the noise level a field on the marker itself so cluster color is an O(cluster-size) average with no lookups, wrap marker children in RepaintBoundary so their rasters are cached while panning, and switch the clustering engine to a supercluster-based index so the map can raise the reading limit to 1k+ without jank â€” the actual product goal for a community map.

**How:**

Define `class NoiseMarker extends Marker { final double db; const NoiseMarker({required this.db, ...super}); }` and build it in _buildMarkersFromSnapshot; in the cluster builder: `final avg = markers.whereType<NoiseMarker>().map((m) => m.db).fold(0.0, (a,b)=>a+b) / markers.length;` â€” delete _markerNoiseLevels. Wrap each marker child (`_buildNoiseMarker` result) in RepaintBoundary and soften/remove the blurRadius:8 marker shadow. For scale, replace flutter_map_marker_cluster with the flutter_map_supercluster package (same Marker API, KD-tree index built once per data load, cluster queries in microseconds at 10k points), then raise _kMapReadingLimit.

---

### 29. Render heatmap blobs with radial-gradient paints instead of per-circle MaskFilter blur

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/map_view_screen.dart

**Today:**

HeatmapLayer.build re-projects every heatmap point through camera.project() on each camera change â€” every frame during a pan/pinch (map_view_screen.dart:1389-1418). HeatmapPainter then draws each visible point as a circle with `MaskFilter.blur(BlurStyle.normal, 20)` (:1446-1452). A sigma-20 Gaussian blur per primitive is one of the most expensive Skia operations; at the current 100 points it is already the priciest layer on the map screen, and at 1k+ points panning with the heatmap on will visibly stutter on mid-range hardware.

**Proposal:**

A radial gradient fading to transparent is visually indistinguishable from a blurred disc for heatmap blobs and costs a fraction of a Gaussian blur. Add paint caching per intensity bucket and the heatmap stays smooth during gestures even at 1k+ points, letting users keep it toggled on while exploring.

**How:**

Replace the MaskFilter paint with `Paint()..shader = ui.Gradient.radial(screenPos, r, [color.withValues(alpha: a), color.withValues(alpha: 0)])` â€” or cheaper, pre-build ~10 Paints (intensity quantized to 0.1 steps) once per opacity change and reuse them, offsetting via canvas.translate. For a bigger step: rasterize all blobs once per data-load+zoom-level into a ui.Image with PictureRecorder.toImage, then paint() just draws that image shifted by the camera delta during pans, re-rendering only on zoom end (listen to MapEventFlingEnd/MapEventMoveEnd via mapController.mapEventStream).

---

### 30. City leaderboard from maintained city_stats docs instead of last-100 sampling

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/search_list_screen.dart + data model

**Today:**

search_list_screen.dart:137 streams getNoiseReadings() â€” the global newest-100 stream (firebase_service.dart:165-171) â€” and _processCityData (search_list_screen.dart:484-514) groups those 100 docs by normalized locationName and averages decibels client-side. The 'city noise levels' grid is therefore a rolling 100-reading sample: cities silently vanish when their readings age out of the window, and averages are statistically meaningless at scale.

**Proposal:**

Maintain `city_stats/{normalizedCityName}` docs {count, sumDb, maxDb, lastReadingAt} incremented on write, and render the grid from that collection. Read-cost: grid load drops from 100 doc reads (plus a resident listener) to ~10-50 reads (one per city) at both 10k and 100k scale â€” but the real win is correctness at 100k, where a true city average over all history would otherwise cost thousands of reads per city. The leaderboard becomes stable, accurate, all-time data.

**How:**

Extend the write batch (recs 2/7): normalize the city name at write time with the same rules _normalizeCityName uses (move that helper into a shared util so write-path and any legacy read-path agree), then `batch.set(cityRef, {'count': increment(1), 'sumDb': increment(db), 'lastReadingAt': serverTimestamp()}, merge)`. Screen: `_firestore.collection('city_stats').orderBy('sumDb'...)` â€” or fetch all (few dozen docs) and keep the existing client-side sort by avg (sumDb/count) or name. Backfill via one-off script. Skip invalid names ('Unknown Location', 'fetchingâ€¦') at write time so garbage cities never get docs.

---

### 31. Make saves instant: drop the blocking connectivity probe from the write hot path

**Impact:** Medium | **Effort:** M | **Area:** lib/services/firebase_service.dart

**Today:**

saveNoiseReading awaits Connectivity().checkConnectivity() before every single write (firebase_service.dart:35), then branches to either an awaited network write (firebase_service.dart:45-55) or the Hive queue. The probe adds up to hundreds of ms of latency per save on some Android devices, and the awaited server write blocks the recording flow on network RTT â€” even though offline persistence is already enabled (main.dart:41-44), meaning the Firestore SDK would queue and retry writes natively.

**Proposal:**

Write through Firestore's built-in offline queue: call the write without awaiting server ack (with persistence enabled, `.add()` resolves against the local cache immediately and syncs in the background), keeping the Hive queue only as the catch-path for genuinely failed writes or signed-out capture. Latency win users feel directly: the save spinner after each recording disappears (~200-800ms saved per save on mobile networks). Read/write cost unchanged, but it also stops the dual-queue system doing duplicate bookkeeping on every save at both 10k and 100k scale.

**How:**

In saveNoiseReading: remove the checkConnectivity branch; do `final future = _firestore.collection('noise_readings').add(data);` and return immediately (or `await future.timeout(Duration(seconds: 5))` with the timeout falling through to the existing _saveOffline fallback at firebase_service.dart:76-85 for the rare hard-failure case). Keep FieldValue.serverTimestamp() â€” it resolves correctly on sync â€” and the existing createdAt client timestamp already covers display-before-sync. SyncService/Hive stays for its current post-hoc retry role. This also composes with recs 2/7/9: the same non-awaited WriteBatch carries the aggregate increments.

---

### 32. Stop denormalizing userEmail into every reading; resolve display names from users/{uid}

**Impact:** Medium | **Effort:** M | **Area:** lib/services/firebase_service.dart + edit_profile + settings

**Today:**

Every reading stores userEmail (firebase_service.dart:119), and the community feed derives display names from it (community_feed_screen.dart:171, 211-214). Consequently a profile email change must rewrite EVERY reading the user ever made: edit_profile_screen.dart:127-140 fetches all their docs and batch-updates them; account deletion does the same anonymization sweep (settings_screen_enhanced.dart:887-901). The users/{uid} doc with displayName/email already exists (edit_profile_screen.dart:90-95).

**Proposal:**

Write only userId on readings and have the feed resolve names from the users collection (readings are already keyed by userId). Cost of a profile change: at 10k total docs (user owns ~1,000) today it is ~1,000 reads + 1,000 writes; after, 1 write to users/{uid} (-99.9%). At 100k (user owns ~10,000) today it is ~10,000 reads + 10,000 writes â€” which also silently exceeds the 500-op WriteBatch ceiling, so this change removes a scaling wall â€” after: 1 write. Account deletion's anonymization sweep shrinks identically. Privacy also improves: raw emails stop being replicated across a community-readable collection.

**How:**

Remove the userEmail field from _saveToFirebase (firebase_service.dart:117-127); in the community feed, collect the distinct userIds of the visible page (â‰¤20 with rec 8), batch-resolve via `_firestore.collection('users').where(FieldPath.documentId, whereIn: ids).get()` (whereIn caps at 30 â€” fine per page), and memoize in a Map<String, String> for the session. Keep a fallback to the legacy userEmail field for old docs during migration. Anonymization on delete becomes: delete/overwrite users/{uid} only.

---

### 33. Replace flutter_sound with the lightweight `record` package for PCM streaming

**Impact:** Medium | **Effort:** M | **Area:** SIZE

**Today:**

flutter_sound (pubspec.yaml:44) is imported in exactly one file, dashboard_screen.dart:8, and used for exactly one capability: streaming mono PCM16 at 16kHz into a buffer for YAMNet (dashboard_screen.dart:472-476 â€” `startRecorder(toStream: ..., codec: Codec.pcm16, sampleRate: 16000, numChannels: 1)`). flutter_sound is a full recording/playback suite with a large native engine (its own Android audio layer, session management, player codecs) â€” heavyweight for a single raw PCM stream, and it has a history of AGP/embedding compatibility churn.

**Proposal:**

Swap to the `record` package (~a tenth the native footprint), which does streamed PCM16 capture as a first-class feature. Cuts APK size, removes an entire native audio engine from cold-start plugin registration, and simplifies maintenance. noise_meter stays untouched for dB readings.

**How:**

`final rec = AudioRecorder(); final stream = await rec.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1)); stream.listen(_onAudioData);` â€” the existing _onAudioData/Uint8List-to-double conversion and _audioBuffer logic in dashboard_screen.dart carries over unchanged since both deliver little-endian PCM16 bytes. Replace openRecorder/closeRecorder lifecycle (dashboard_screen.dart:140-148) with rec.dispose(). Verify classification accuracy is unchanged with a quick side-by-side test.

---

### 34. Quantize yamnet.tflite to float16 to halve the largest asset

**Impact:** Medium | **Effort:** M | **Area:** SIZE

**Today:**

assets/models/yamnet.tflite is 4,126,810 bytes â€” 79% of the entire assets payload (5.2MB total) â€” and is the stock float32 YAMNet export. It ships inside every APK/ABI variant. The service consumes plain top-1 scores against a 0.15 confidence threshold (sound_classification_service.dart:34,108-113), a use case highly tolerant of quantization error.

**Proposal:**

Post-training float16 quantization cuts the model to ~2.1MB (or dynamic-range int8 to ~1.1MB) with negligible accuracy impact for top-1 environmental-sound classification; TFLite dequantizes transparently on CPU so the Dart code and tensor shapes are unchanged. Halves the biggest single file users download and speeds the (now lazy) first model load proportionally.

**How:**

One-off Python script: `converter = tf.lite.TFLiteConverter.from_saved_model(yamnet_dir); converter.optimizations = [tf.lite.Optimize.DEFAULT]; converter.target_spec.supported_types = [tf.float16]; open('yamnet_f16.tflite','wb').write(converter.convert())` â€” or start from Google's published YAMNet TF Hub model. Regression-check by running the repo's existing category mapping (yamnet_class_mapping.dart) against a handful of known clips (traffic, horn, dog, music) and comparing top-3 outputs and confidences to the float32 model before swapping the asset.

---

### 35. Consolidate to a single WebView engine (drop flutter_inappwebview, keep webview_flutter)

**Impact:** Medium | **Effort:** M | **Area:** SIZE

**Today:**

Two full WebView plugin stacks ship in the app: webview_flutter (pubspec.yaml:91) used by lib/widgets/buy_me_coffee_widget.dart:21-32 (WebViewController), and flutter_inappwebview (pubspec.yaml:92) used by lib/widgets/paypal_webview_widget.dart:25,79 (InAppWebView + InAppWebViewSettings). flutter_inappwebview is one of the heaviest Flutter plugins â€” a large native AAR plus a big DEX method count â€” and it is used for exactly one widget whose needs (load a PayPal checkout URL, intercept success/cancel redirect URLs) webview_flutter covers.

**Proposal:**

Port paypal_webview_widget.dart to webview_flutter and remove flutter_inappwebview. One engine means roughly 1-2MB less APK (more before R8), fewer native init paths, and one less high-churn dependency to keep compatible with AGP/Gradle upgrades.

**How:**

Replace InAppWebView with WebViewWidget + `WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (req) { if (req.url.startsWith(successUrl)) { onSuccess(); return NavigationDecision.prevent; } if (req.url.startsWith(cancelUrl)) { onCancel(); return NavigationDecision.prevent; } return NavigationDecision.navigate; }))..loadRequest(Uri.parse(checkoutUrl))`. buy_me_coffee_widget.dart already demonstrates the exact pattern in-repo. Test the sandbox PayPal flow end-to-end before removing the dependency.

---

### 36. Cache and cancel OpenStreetMap tile requests (the app's cached_network_image equivalent)

**Impact:** Medium | **Effort:** M | **Area:** STARTUP

**Today:**

map_view_screen.dart:639-644 configures TileLayer with only urlTemplate ('https://tile.openstreetmap.org/{z}/{x}/{y}.png') and userAgentPackageName â€” the default NetworkTileProvider, which has no disk cache and never cancels in-flight requests when tiles scroll off-screen. Every map open and every pan/zoom re-downloads tiles over the network (the app has no other remote images â€” grep finds zero Image.network/NetworkImage usages â€” so map tiles ARE the remote-image story here). This burns user mobile data, makes the map feel slow on repeat visits, is useless offline despite the app having a whole offline mode (SyncService/Hive), and sits poorly with OSM's tile usage policy, which expects caching.

**Proposal:**

Add request cancellation plus persistent tile caching: instant map loads on revisit, big mobile-data savings, and map tiles that still render in the offline mode the app already advertises.

**How:**

Two-step: (1) drop-in `cancellable_network_tile_provider` package â€” `TileLayer(urlTemplate: ..., tileProvider: CancellableNetworkTileProvider())` â€” which cancels aborted tile fetches (flutter_map's own docs recommend it); (2) add disk caching with `flutter_map_cache` (dio + hive backend, fits the existing Hive stack: `tileProvider: CachedTileProvider(store: HiveCacheStore(path))`) or the heavier flutter_map_tile_caching if region pre-download is ever wanted. Respect OSM policy with a proper User-Agent (already set).

---

### 37. Heatmap tiles from geohash-cell aggregate docs at low zoom

**Impact:** Medium | **Effort:** L | **Area:** Data model + lib/services/heatmap_service.dart + map view

**Today:**

The heatmap is raw readings: map_view_screen.dart:131-135 reuses the marker snapshot (100 newest docs) and heatmap_service.dart:9-27 converts each doc to a HeatmapPoint. All statistics over the heatmap (heatmap_service.dart:101-124) are computed from those same raw points. The heatmap therefore shows only the last 100 readings ever, not accumulated noise history, and scaling it up means downloading raw docs.

**Proposal:**

Maintain `geo_cells/{geohash5}` aggregate docs {count, sumDb, maxDb, lastUpdated} incremented on each write. At city zoom, render the heatmap from cell docs (one HeatmapPoint per cell center, intensity = sumDb/count) and only fall back to raw readings when zoomed into a few cells. Read-cost saving: a city-wide heatmap over 10k docs drops from needing ~10,000 raw reads (if you tried to show real history) to ~100-300 cell reads (-97%); at 100k docs, ~100,000 to the same ~300 cells (-99.7%), because cell count depends on area, not data volume. Product win: the heatmap finally represents ALL historical data instead of a 100-doc sliver.

**How:**

Extend the write batch from recommendation 2: `batch.set(_firestore.collection('geo_cells').doc(geohash.substring(0,5)), {'count': FieldValue.increment(1), 'sumDb': FieldValue.increment(db), 'lastUpdated': FieldValue.serverTimestamp()}, SetOptions(merge: true));` (precision 5 â‰ˆ 4.9km Ã— 4.9km; also write precision-7 cells if you want street-level tiles). Reading: fetch cells whose geohash prefix intersects the viewport (same prefix-range technique as rec 6), map each to `HeatmapPoint(lat: cellCenterLat, lng: cellCenterLng, decibelLevel: sumDb/count)` and feed the existing flutter_map_heatmap layer unchanged. calculateStatistics can sum cell counts/sums instead of iterating points. Backfill with a one-off aggregation script.

---

### 38. Codify the index strategy for the new query shapes

**Impact:** Low | **Effort:** S | **Area:** Firestore indexes (firestore.indexes.json) + lib/services/firebase_service.dart

**Today:**

The project runs on exactly one composite index â€” noise_readings (userId ASC, timestamp DESC) â€” and the code carefully conforms to it (isGreaterThan + orderBy desc, per comments at firebase_service.dart:258 and 282). Everything else (global orderBy timestamp at firebase_service.dart:165-180 and 183-202, today's range at dashboard_screen.dart:906-914) rides automatic single-field indexes. Nothing documents this contract in the repo, and none of the recommended query shapes above are index-planned.

**Proposal:**

Check in a firestore.indexes.json capturing the contract and pre-plan the additions the recommendations need, so index errors never surface in production: (1) geohash prefix queries (rec 6) need only the automatic single-field index on geo.geohash â€” verify no exemption disables it; (2) if analytics later filters aggregates by soundType, add (userId ASC, soundType ASC, timestamp DESC); (3) add field-level index EXEMPTIONS for never-queried payload fields (userEmail, deviceInfo, locationName, confidence, soundClassCounts maps on aggregate docs) â€” each exemption removes 2 index entries per doc, cutting write latency and storage: at 10k docs that is ~80k fewer index entries, at 100k ~800k, plus proportionally cheaper writes forever; (4) document that new aggregate-doc collections (user_daily_stats, geo_cells, city_stats) need no composite indexes as long as they are fetched by ID or single-field range.

**How:**

`firebase firestore:indexes > firestore.indexes.json`, commit it, and wire `firebase deploy --only firestore:indexes` into the release flow. Add exemptions in the same file under fieldOverrides: `{"collectionGroup": "noise_readings", "fieldPath": "userEmail", "indexes": []}` etc. Also delete or fix the two unused unbounded methods while touching the service â€” getUserReadings (firebase_service.dart:205-211, no limit, no callers) and getReadingsByLocation (firebase_service.dart:243-255, full-collection scan) â€” so future callers can't reintroduce O(collection) reads by grabbing the handiest method.

---

### 39. Bound the Firestore offline cache instead of CACHE_SIZE_UNLIMITED

**Impact:** Low | **Effort:** S | **Area:** SIZE

**Today:**

main.dart:41-44 sets `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`. For an app whose core loop appends noise_readings documents every 5 seconds while recording (dashboard save timer) plus community feed and analytics queries, unlimited means the on-device SQLite cache grows forever â€” garbage collection is disabled entirely at CACHE_SIZE_UNLIMITED â€” inflating the app's storage footprint over months and slowing cache scans on low-end devices.

**Proposal:**

Cap the cache at a sensible bound (e.g., 100MB) so Firestore's LRU garbage collection actually runs, keeping 'App storage' in Android settings honest and cache queries fast, while still holding far more readings than any screen displays. Also migrates off the deprecated persistenceEnabled/cacheSizeBytes fields onto the current API.

**How:**

`FirebaseFirestore.instance.settings = const Settings(persistentCacheSettings: PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024));` â€” cloud_firestore ^5.x supports PersistentCacheSettings; persistence is on by default within it. One-line change in main.dart plus a smoke test of offline mode (SyncService/history offline path) to confirm cached reads still serve.

---

## Suggested Implementation Order

### Wave 1 - Quick wins (S effort, 21 items)

- [ ] [High] Collapse the analytics triple-fetch into one query
- [ ] [High] Replace the community-feed doc stream with a Firestore count() aggregation
- [ ] [High] Replace the dashboard's today-count StreamBuilder with a count() aggregate
- [ ] [High] Scope CSV export to the current user and paginate it
- [ ] [High] Use server-side sum()/average()/count() aggregates as the quick win before aggregate docs land
- [ ] [High] Run YAMNet inference on a background isolate with IsolateInterpreter
- [ ] [High] Dependency diet: delete seven verified-unused packages, move flutter_launcher_icons to dev_dependencies
- [ ] [High] Ship an app bundle / split-per-abi instead of a fat APK
- [ ] [High] Stop loading the 4MB YAMNet model twice before the first frame; lazy-load on first recording
- [ ] [Medium] Speed up developer builds: enable Gradle build cache + configuration cache, drop Jetifier
- [ ] [Medium] Cut cold-start time: stop loading the YAMNet model twice before runApp
- [ ] [Medium] Bound the Firestore cache and memoize period stats in memory
- [ ] [Medium] Use a cancellable, cached tile provider for the OSM tile layer
- [ ] [Medium] Debounce Nominatim autocomplete and drop stale responses
- [ ] [Medium] Wire image compression as file-to-file with real upload progress
- [ ] [Medium] Fix gauge shouldRepaint and split the static gauge layer from the needle
- [ ] [Medium] Throttle NoiseHistoryChart updates to ~1Hz and isolate its repaints
- [ ] [Medium] Remove ~1.1MB of dead assets (design-mockup SVGs and launcher-icon source) from the bundle
- [ ] [Medium] Cut the splash screen's fixed 3-second dead time and add a native splash to kill the white flash
- [ ] [Low] Codify the index strategy for the new query shapes
- [ ] [Low] Bound the Firestore offline cache instead of CACHE_SIZE_UNLIMITED

### Wave 2 - Next sprint (M effort, 16 items)

- [ ] [High] Scope live-metering rebuilds with ValueNotifier instead of whole-screen setState
- [ ] [High] Add a geohash field and viewport-bounded map queries
- [ ] [High] Enable R8 minification and resource shrinking in the release build
- [ ] [High] Defer notification init, notification permission dialog, sync service, and dotenv until after first frame
- [ ] [High] Build MainAppShell tabs lazily instead of constructing all five screens at login
- [ ] [Medium] Paginate the community feed instead of streaming 100 docs
- [ ] [Medium] Eliminate per-sample list churn in the audio capture pipeline with a Float32List ring buffer
- [ ] [Medium] Render heatmap blobs with radial-gradient paints instead of per-circle MaskFilter blur
- [ ] [Medium] Carry dB data on a typed Marker subclass and adopt supercluster for 1k+ points
- [ ] [Medium] City leaderboard from maintained city_stats docs instead of last-100 sampling
- [ ] [Medium] Make saves instant: drop the blocking connectivity probe from the write hot path
- [ ] [Medium] Stop denormalizing userEmail into every reading; resolve display names from users/{uid}
- [ ] [Medium] Consolidate to a single WebView engine (drop flutter_inappwebview, keep webview_flutter)
- [ ] [Medium] Quantize yamnet.tflite to float16 to halve the largest asset
- [ ] [Medium] Replace flutter_sound with the lightweight `record` package for PCM streaming
- [ ] [Medium] Cache and cancel OpenStreetMap tile requests (the app's cached_network_image equivalent)

### Wave 3 - Larger initiatives (L effort, 2 items)

- [ ] [High] Maintain per-user daily aggregate docs; make analytics O(days) not O(readings)
- [ ] [Medium] Heatmap tiles from geohash-cell aggregate docs at low zoom
