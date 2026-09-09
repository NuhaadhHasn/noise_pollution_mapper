# Architecture & Code Quality Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **25** (3 High, 10 Medium, 12 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| arch-1 | High | disputed | `lib/screens/settings_screen_enhanced.dart:161` | Settings are written to SharedPreferences but never consumed by any feature | M |
| arch-4 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:893` | Duplicated unchunked Firestore batch logic breaks account deletion/data wipe for users with >500 readings | M |
| arch-3 | High | confirmed | `lib/services/sound_classification_service.dart:34` | Classification threshold is 0.15 (spec says 0.30) and the threshold gates nothing | S |
| arch-8 | Medium | unverified | `lib/screens/community_feed_screen.dart:62` | Six screens bypass FirebaseService and query Firestore directly, duplicating existing service methods | M |
| arch-5 | Medium | unverified | `lib/screens/dashboard_screen.dart:911` | Dashboard today-count query violates the mandated Firestore query pattern (isGreaterThanOrEqualTo, no orderBy) and streams full docs just to count them | S |
| social-11 | Medium | unverified | `lib/services/image_compression_service.dart:12` | ImageCompressionService is fully orphaned — no image pick/compress/upload pipeline exists anywhere | S |
| arch-6 | Medium | unverified | `lib/services/sync_service.dart:211` | Firestore write shape duplicated between FirebaseService and SyncService and has already diverged: offline-synced readings lack userEmail | S |
| arch-9 | Medium | unverified | `lib/main.dart:18` | Inconsistent state management: unused provider dependency, global ValueNotifiers in main.dart imported back by screens (circular), mixed singleton/non-singleton services | M |
| arch-7 | Medium | unverified | `lib/screens/map_view_screen.dart:178` | No typed NoiseReading model: six screens parse raw doc maps with inconsistent null-safety and inconsistent timestamp/createdAt fallback | M |
| boot-3 | Medium | unverified | `lib/main.dart:150` | Auth-state routing is destroyed after splash navigates — authStateChanges only routes at cold start | M |
| arch-10 | Medium | unverified | `lib/screens/dashboard_screen.dart:1174` | God files: 5 files over 1,100 lines; dashboard State class mixes audio capture, DSP, persistence timers, notifications and UI | L |
| arch-14 | Medium | unverified | `pubspec.yaml:54` | Eight declared dependencies are never imported anywhere in lib/ or test/ | S |
| arch-13 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:944` | Logging inconsistency: 7 files with error paths log nothing while the rest of the app uses AppLogger | S |
| arch-17 | Low | unverified | `lib/widgets/decibel_meter_gauge.dart:177` | dB-to-color/label banding duplicated in 7 places | S |
| arch-16 | Low | unverified | `lib/services/firebase_service.dart:243` | Dead FirebaseService methods, one of which fetches the entire collection and ignores all its parameters | S |
| flow7-12 | Low | unverified | `lib/widgets/buy_me_coffee_widget.dart:2` | Two different webview plugins power the two donation webviews | M |
| fb-15 | Low | unverified | `lib/services/firebase_service.dart:250` | Dead FirebaseService methods with latent hazards: full-collection scan, ignored parameters, crash-prone cast | S |
| map-22 | Low | unverified | `lib/widgets/heatmap_settings_panel.dart:6` | HeatmapSettingsPanel and the entire heatmap filter/statistics API are dead code | M |
| flow5-12 | Low | unverified | `lib/services/offline_storage_service.dart:103` | Dead storage API for a nonexistent BackgroundSyncService, including duplicated markAsSynced with divergent schema | S |
| arch-20 | Low | unverified | `lib/main.dart:66` | Startup loads the YAMNet TFLite model twice before the first frame | S |
| arch-18 | Low | unverified | `lib/utils/app_logger.dart:22` | AppLogger level hardcoded to Level.debug with a TODO — verbose logs ship in release builds | S |
| ml-13 | Low | unverified | `lib/services/sound_classification_service.dart:260` | Interpreter is never closed: dispose() and reset() have zero call sites | S |
| offline-17 | Low | unverified | `lib/services/offline_storage_service.dart:123` | Duplicate, drifting storage APIs (two markAsSynced, two attempt-updaters, two pending counters) with inconsistent persistence formats | M |
| arch-19 | Low | unverified | `pubspec.yaml:106` | Dependency hygiene: latlong2 pinned to 'any' and build tool flutter_launcher_icons in runtime dependencies | S |
| arch-15 | Low | unverified | `lib/services/image_compression_service.dart:1` | Dead files: image_compression_service.dart (99 lines), heatmap_settings_panel.dart (285 lines), and the template MyHomePage in main.dart | S |

## Detailed Findings

### High

#### [arch-1] Settings are written to SharedPreferences but never consumed by any feature

**Severity:** High | **Status:** disputed | **Category:** architecture | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:161`

**Verifier verdict (PARTIAL):** The anchored setting (db_threshold, settings_screen_enhanced.dart:161) is indeed dead: it is written and read back only by the settings screen itself (line 57); no measurement/alert code reads it. Same for recording_duration, save_frequency, high_noise_alerts, use_fast_response, anonymize_location, daily_reminders, share_data_with_researchers — grep of lib/ shows no consumers outside the settings screen. However, the blanket claim "never consumed by any feature" is overstated: dark_mode is consumed at main.dart:56 (startup theme) and applied live via themeNotifier (settings_screen_enhanced.dart:108), and notifications_enabled is read by notification_service.dart:38 and :65. So most settings including the flagged one are decorative, but two are genuinely wired up.

**Description:**

The settings screen persists 'db_threshold' (line 161) and 'save_frequency' (line 150), plus 'anonymize_location', 'share_data_with_researchers', 'daily_reminders', and 'recording_duration' (loaded at lines 50-57). Grep across lib/ shows every one of these keys is referenced ONLY inside settings_screen_enhanced.dart (notification_service.dart reads only 'notifications_enabled'). Meanwhile dashboard_screen.dart hardcodes the alert threshold at 70 dB (line 428: `if (_currentDb > 70 && !_hasShownHighNoiseAlert)`) and the reset at 65 (line 435), and hardcodes the save interval at 5 seconds (line 487: `Timer.periodic(const Duration(seconds: 5)`). The settings are dead configuration.

**Failure scenario:**

User raises 'Alert Threshold' slider to 100 dB in Settings, then records in a 75 dB environment: the high-noise notification still fires at 70 dB. User sets save frequency to 30s: readings are still written to Firestore every 5 seconds.

**Recommended fix:**

Wire the prefs into their consumers: read 'db_threshold' in dashboard_screen's noise-alert check and pass it to NotificationService.showHighNoiseAlert; read 'save_frequency' when constructing the periodic save Timer. Either implement or remove the four remaining orphaned toggles so the UI does not promise behavior that does not exist.

---

#### [arch-4] Duplicated unchunked Firestore batch logic breaks account deletion/data wipe for users with >500 readings

**Severity:** High | **Status:** confirmed | **Category:** architecture | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:893`

**Verifier verdict (CONFIRMED):** Both halves of the claim hold. In lib/screens/settings_screen_enhanced.dart, _deleteAccount builds a single WriteBatch and loops all query docs into it with no 500-op chunking (lines 893-901: `final batch = firestore.batch(); for (var doc in snapshot.docs) { batch.update(...) } await batch.commit();`), and _clearHistory duplicates the same unchunked pattern with batch.delete (lines 1027-1031). Firestore hard-caps a batch at 500 writes, so with >500 readings commit() throws; in _deleteAccount that aborts before `user.delete()` (line 904), so neither anonymization nor auth deletion completes, and _clearHistory's wipe fails entirely. No chunking helper exists elsewhere in either flow.

**Description:**

The same 'query all user docs, put every update/delete in ONE WriteBatch, commit' block is copy-pasted three times: settings_screen_enhanced.dart:887-901 (anonymize on account delete), settings_screen_enhanced.dart:1021-1031 (delete all data), and edit_profile_screen.dart:127-140 (propagate email change). Firestore WriteBatch is capped at 500 operations; none of the three chunk. Because the dashboard saves a reading every 5 seconds while recording (dashboard_screen.dart:487), a user accumulates 500 documents in ~42 minutes of total recording time, so exceeding the cap is the normal case, not an edge case. All three catch blocks swallow the error into a snackbar with no logging.

**Failure scenario:**

User with 600 readings taps 'Delete Account': `batch.commit()` at settings_screen_enhanced.dart:901 throws INVALID_ARGUMENT (maximum 500 writes), the catch at line 944 shows a generic error snackbar, readings are never anonymized and `user.delete()` (line 904) is never reached — the account-deletion feature is broken for any regular user.

**Recommended fix:**

Extract one FirebaseService method, e.g. `Future<void> batchMutateUserReadings(String userId, void Function(WriteBatch, DocumentReference) op)`, that pages the query and commits in chunks of <=500 operations; replace all three inline copies with it.

---

#### [arch-3] Classification threshold is 0.15 (spec says 0.30) and the threshold gates nothing

**Severity:** High | **Status:** confirmed | **Category:** architecture | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:34`

**Verifier verdict (CONFIRMED):** All claims verified in code. (1) Threshold is 0.15: sound_classification_service.dart:34, with a comment "Lowered to 15%" (lines 28-33), while project memory/session history documents threshold 0.30. (2) Non-gating: the below-threshold branch (lines 126-138) builds and returns a ClassificationResult with the identical five fields as the passing path (lines 146-152) — it only changes a debug log. (3) Persisted as fact: dashboard_screen.dart:641 stores the result unconditionally, and lines 498-500 write soundClass/soundType/confidence to the reading without any confidence check; meetsThreshold (service line 300) is never referenced by any consumer (grep shows only its definition), and confidenceThreshold's only other use is a startup log (main.dart:119). Minor note: README/PRODUCTION_CHECKLIST mention CONFIDENCE_THRESHOLD=0.6, so "0.30" is the memory-documented spec, not the only documented value — but neither 0.30 nor 0.6 matches 0.15, and the gating claim holds regardless.

**Description:**

The project constraint states the classification threshold is 0.30, but `confidenceThreshold = 0.15` (line 34). Worse, the constant is functionally dead: the below-threshold branch (lines 126-138) returns a fully-populated ClassificationResult identical in shape to the above-threshold path (lines 146-152) — only the log level differs. The `meetsThreshold` getter (line 300) is never referenced by any caller (grep across lib/), and dashboard_screen.dart:498-500 passes `_currentClassification?.category/soundType/confidence` into saveNoiseReading unconditionally. The test file additionally asserts a third value, 0.6.

**Failure scenario:**

YAMNet emits a top score of 0.16 ('Silence' misread as 'Traffic') during a quiet recording: the reading is written to Firestore with soundClass='Traffic' and shown in analytics/community feed exactly like a confident classification, inflating pollution counts with noise-floor guesses that the 0.30 spec was meant to filter.

**Recommended fix:**

Set `confidenceThreshold = 0.30` per spec, and make it meaningful: either return null (or category 'Unclassified') from classifySound below the threshold, or have dashboard_screen check `result.meetsThreshold` before persisting soundClass/soundType. Update the stale test assertion in the same change.

---

### Medium

#### [arch-8] Six screens bypass FirebaseService and query Firestore directly, duplicating existing service methods

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/screens/community_feed_screen.dart:62`

**Description:**

A FirebaseService layer exists and is used by map/analytics/history-pagination/search, but screens also hit FirebaseFirestore.instance directly: community_feed_screen.dart:62-67 duplicates FirebaseService.getNoiseReadings() (firebase_service.dart:165-171) verbatim (same collection/orderBy/limit(100)/snapshots); dashboard_screen.dart:906-914 (today count); history_screen.dart:230-233 (CSV export — fetches the ENTIRE collection with no userId filter and no limit, so 'export' downloads and emits every user's readings and emails, unbounded); history_screen.dart:721 (delete doc); settings_screen_enhanced.dart:887-891 and 1021-1024; edit_profile_screen.dart:127-131. Query conventions (index-safe patterns, limits) are enforced only in the service, so the bypasses are where the violations live (see arch-4, arch-5).

**Failure scenario:**

The team renames a field or changes the reading-limit policy in FirebaseService: community feed, export, and settings flows silently keep the old behavior. Concretely today: a user taps 'Export' in History expecting their data and receives a CSV of the whole community's readings (with emails), growing without bound as the collection grows.

**Recommended fix:**

Route all seven call sites through FirebaseService methods (reuse getNoiseReadings() for the feed; add exportUserReadings(userId) with a userId filter, deleteReading(docId), and the batch helper from arch-4). Consider a lint/grep CI check forbidding 'FirebaseFirestore.instance' outside lib/services/.

---

#### [arch-5] Dashboard today-count query violates the mandated Firestore query pattern (isGreaterThanOrEqualTo, no orderBy) and streams full docs just to count them

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:911`

**Description:**

Project constraint: period queries MUST use isGreaterThan plus orderBy('timestamp', descending: true); isGreaterThanOrEqualTo or a missing orderBy is the documented FAILED_PRECONDITION pattern. dashboard_screen.dart:906-914 does `.where('timestamp', isGreaterThanOrEqualTo: ...).where('timestamp', isLessThan: ...).snapshots()` with no orderBy and no userId filter — the exact forbidden shape. It currently executes only because the single-field timestamp index covers it (no userId clause); the moment anyone adds `.where('userId'...)` to scope it, it hits FAILED_PRECONDITION since the only composite index is (userId ASC, timestamp DESC). It also holds a realtime listener that downloads every user's full documents for the whole day solely to render `snapshot.data!.docs.length` (line 917).

**Failure scenario:**

A maintainer scopes the community card to the current user (or the dataset grows to thousands of daily readings): the query either fails with FAILED_PRECONDITION and the card permanently shows 0 reports, or silently burns bandwidth/reads streaming every full document all day to display one integer.

**Recommended fix:**

Move the query into FirebaseService following the house pattern — `.where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart)).orderBy('timestamp', descending: true)` — and use the `.count()` aggregation (already used at firebase_service.dart:233-240) instead of a snapshots() listener over full documents.

---

#### [social-11] ImageCompressionService is fully orphaned — no image pick/compress/upload pipeline exists anywhere

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/image_compression_service.dart:12`

**Description:**

Grep across lib/ shows zero references to ImageCompressionService outside its own file, zero uses of ImagePicker, and zero uses of FirebaseStorage in Dart code — yet pubspec.yaml declares firebase_storage ^12.3.8 (line 34) and image_picker ^1.1.2 (line 65), and native plugin registrants bundle firebase_storage into every build. The advertised 'compress before upload' pipeline (file header, lines 6-11) is dead code: no size caps are enforced anywhere, no upload failure paths exist, and the compressed `*_compressed.jpg` temp files it would create are never cleaned up (getTargetPath, lines 85-90).

**Failure scenario:**

App binary ships with firebase_storage + image_picker plugins and a 100-line service that can never execute; future contributors assume photo attachment works and debug a feature that was never wired up, or the unused Storage plugin widens the attack/maintenance surface for nothing.

**Recommended fix:**

Either delete lib/services/image_compression_service.dart and remove firebase_storage + image_picker from pubspec.yaml, or actually wire the pipeline (pick -> compress -> enforce a max-size cap -> upload with error handling and temp-file cleanup) into the report flow.

---

#### [arch-6] Firestore write shape duplicated between FirebaseService and SyncService and has already diverged: offline-synced readings lack userEmail

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/sync_service.dart:211`

**Description:**

FirebaseService._saveToFirebase (firebase_service.dart:117-133) and SyncService._saveToFirebase (sync_service.dart:211-233) build the noise_readings document independently. They have diverged: the online path writes `'userEmail': _auth.currentUser?.email` (firebase_service.dart:119); the sync path omits userEmail entirely. Both correctly write dual timestamp+createdAt, but only by manual discipline — there is no single writer enforcing the document contract.

**Failure scenario:**

User records while offline, comes back online, SyncService uploads the queued readings: those documents have no userEmail field, so the Community Feed (community_feed_screen.dart:171 `report['userEmail'] ?? 'Anonymous'`) and the CSV export (history_screen.dart:262 `?? 'N/A'`) show 'Anonymous'/'N/A' for readings that belong to a known signed-in user, while their online readings show their name.

**Recommended fix:**

Extract one shared document builder (e.g. `Map<String, dynamic> buildNoiseReadingDoc(...)` in FirebaseService or a NoiseReading model with toFirestore()) used by both save paths; add userEmail to the sync path in the same change.

---

#### [arch-9] Inconsistent state management: unused provider dependency, global ValueNotifiers in main.dart imported back by screens (circular), mixed singleton/non-singleton services

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/main.dart:18`

**Description:**

provider is declared (pubspec.yaml:62) but never imported anywhere. Actual state management is four ad-hoc mechanisms: (1) global mutable ValueNotifiers defined in the app entrypoint (main.dart:18-24) and imported back by settings_screen_enhanced.dart:6 (`import '../main.dart' show themeNotifier, themeColorNotifier`), creating a main -> main_app_shell -> settings -> main import cycle; (2) a static mutable flag class SharedAppState (lib/utils/shared_app_state.dart:4); (3) singleton services via factory constructors (SoundClassificationService:43, SyncService:13, OfflineStorageService:10); (4) FirebaseService, which is NOT a singleton and is instantiated separately in 6 screens (analytics_screen.dart:21, dashboard_screen.dart:36, history_screen.dart:24, map_view_screen.dart:45, report_noise_screen.dart:19, search_list_screen.dart:18), each constructing its own Connectivity instance.

**Failure scenario:**

A developer adds a cache or a connectivity listener to FirebaseService assuming one instance: six independent copies exist, so state diverges per tab (e.g. a memoized userEmail or listener registered 6 times). The settings->main import cycle also means anything main.dart later imports from a screen file becomes a hard circular-dependency compile hazard.

**Recommended fix:**

Pick one mechanism: either remove provider from pubspec and standardize on documented singletons (make FirebaseService a factory singleton, move themeNotifier/themeColorNotifier into a ThemeController in lib/utils/ or lib/services/), or actually adopt provider/ChangeNotifier and register services once above MaterialApp. Break the main.dart import cycle either way.

---

#### [arch-7] No typed NoiseReading model: six screens parse raw doc maps with inconsistent null-safety and inconsistent timestamp/createdAt fallback

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/screens/map_view_screen.dart:178`

**Description:**

Every consumer parses `Map<String, dynamic>` ad hoc. Hard casts that throw on missing/odd-typed fields: map_view_screen.dart:176-178 (`data['latitude'] as double`, `(data['decibelLevel'] as num).toDouble()`), history_screen.dart:451, search_list_screen.dart:505, models/heatmap_point.dart:26. Null-safe variants exist elsewhere: analytics_screen.dart:190, community_feed_screen.dart:168, and firebase_service.dart:301-303 (explicitly fixed to skip null decibelLevel — the fix never propagated). The mandated timestamp-then-createdAt fallback is implemented in analytics_screen.dart:194-201 and community_feed_screen.dart:173-183 but MISSING in history_screen.dart:253 and 453, which read only 'timestamp' (violating the 'readers must handle both' constraint).

**Failure scenario:**

A reading written offline is synced while the client has a pending serverTimestamp, or a legacy/foreign document lacks decibelLevel: `_buildMarkers` in map_view_screen throws a TypeError and the entire map renders no markers; the same document shows time 'N/A' in History even though createdAt is present.

**Recommended fix:**

Create `lib/models/noise_reading.dart` with a defensive `NoiseReading.fromFirestore(doc)` (num?-safe casts, timestamp??createdAt resolution in one place) and replace the six inline parsers with it.

---

#### [boot-3] Auth-state routing is destroyed after splash navigates — authStateChanges only routes at cold start

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/main.dart:150`

**Description:**

The authStateChanges StreamBuilder (main.dart:150-174) lives inside the MaterialApp home route's widget tree. When logged out, it returns SplashScreen, and SplashScreen then calls Navigator.pushReplacement (splash_screen.dart:38), which disposes the home route AND the StreamBuilder with it. From that point on, no widget listens to auth state: Onboarding→Login→MainAppShell are all manual pushReplacements (onboarding_screen.dart:38, login_screen.dart:57, registration_screen.dart:79). Sign-out only works because settings_screen_enhanced.dart:912-915 manually does pushAndRemoveUntil(LoginScreen). Any auth change not paired with manual navigation (server-side token revocation, user disabled/deleted in Firebase console, password reset elsewhere) leaves the UI on authenticated screens while FirebaseAuth.currentUser is null, so every Firestore query silently fails or returns nothing.

**Failure scenario:**

Admin disables a user's account in the Firebase console while the app is open on a session that started logged-out (splash already replaced the home route). authStateChanges emits null, nothing listens, the user stays inside MainAppShell where Dashboard/History/Analytics show errors or empty data with no explanation and no route back to Login.

**Recommended fix:**

Keep a persistent auth gate: make the StreamBuilder the permanent root (e.g., an AuthGate widget that itself decides SplashScreen/OnboardingScreen/LoginScreen/MainAppShell as its own child, never via Navigator.pushReplacement of the root route), or attach a global authStateChanges listener with a navigatorKey that does pushAndRemoveUntil(LoginScreen) whenever user becomes null.

---

#### [arch-10] God files: 5 files over 1,100 lines; dashboard State class mixes audio capture, DSP, persistence timers, notifications and UI

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** L

**Location:** `lib/screens/dashboard_screen.dart:1174`

**Description:**

Exact line counts (wc -l): lib/services/yamnet_class_mapping.dart 1536, lib/screens/map_view_screen.dart 1473, lib/screens/dashboard_screen.dart 1174, lib/screens/analytics_screen.dart 1158, lib/screens/settings_screen_enhanced.dart 1107 (together 6,448 of 16,897 lib lines = 38%). dashboard_screen's single State class owns mic permission flow, noise_meter subscription, flutter_sound PCM stream, byte-level PCM16 decoding (_processAudioData lines 521-541), audio ring buffer, classification orchestration (591-657), two periodic timers including Firestore persistence (486-514), notification triggering (428-437), plus ~500 lines of widget tree. map_view_screen embeds three CustomPainters and marker/cluster/heatmap logic. yamnet_class_mapping is a data table living in services/.

**Failure scenario:**

Any change to the recording pipeline (e.g. honoring the save_frequency setting from arch-1) requires editing UI build code in a 1,174-line State class where business logic is reachable only through widget lifecycle, making review diffs large and regressions likely; none of the embedded logic can be unit tested (see arch-12).

**Recommended fix:**

Extract from dashboard_screen: a RecordingController (noise meter + audio buffer + timers + save policy) and keep the State class as pure presentation; move map painters and marker-building out of map_view_screen into lib/widgets/; relocate yamnet_class_mapping.dart to lib/data/ or lib/models/ (pure data, no service behavior).

---

#### [arch-14] Eight declared dependencies are never imported anywhere in lib/ or test/

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `pubspec.yaml:54`

**Description:**

Verified by grepping all package: imports and API symbols (GoogleMap, ImagePicker, FirebaseStorage, SvgPicture, PaypalCheckout, launchUrl, HeatMapLayer, Provider) across lib/ and test/: google_maps_flutter (pubspec.yaml:54 — a second, unused map stack alongside the used flutter_map), firebase_storage (line 34), provider (line 62), image_picker (line 65), flutter_svg (line 87), flutter_paypal_payment (line 90 — donations actually use flutter_inappwebview/webview_flutter), url_launcher (line 93), flutter_map_heatmap (line 104 — heatmap is custom-built in heatmap_service). Zero references for all eight. google_maps_flutter and firebase_storage in particular pull native Android/iOS SDKs into every build.

**Failure scenario:**

Every developer and CI build resolves, downloads and compiles eight unused packages (two with native SDKs), inflating APK size and build time; `flutter pub upgrade` can also fail on version conflicts caused solely by packages nothing uses.

**Recommended fix:**

Delete the eight entries from pubspec.yaml and run `flutter pub get` + a full build to confirm; if PayPal-SDK checkout or photo attachment is genuinely planned, track it in an issue instead of a live dependency.

---

#### [arch-13] Logging inconsistency: 7 files with error paths log nothing while the rest of the app uses AppLogger

**Severity:** Medium | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:944`

**Description:**

Positive baseline verified: zero `print(`/`debugPrint(` calls anywhere in lib/, and 18 files use AppLogger consistently. But grep -c shows 0 AppLogger references in: settings_screen_enhanced.dart (catches at 806, 944, 1061 — the account-deletion and delete-all-data failure paths), history_screen.dart (catches at 61, 107, 150, 319), edit_profile_screen.dart (193), login_screen.dart (61), registration_screen.dart (111), community_feed_screen.dart, and services/notification_service.dart. These catch blocks reduce errors to a generic snackbar (or nothing), so the most destructive flows in the app are the least observable.

**Failure scenario:**

Account deletion fails (e.g. the >500 batch limit from arch-4, or requires-recent-login from Firebase Auth): the user sees 'Error deleting account' and reports it; there is no log line anywhere to diagnose which step threw, while trivial flows like map loading log verbosely.

**Recommended fix:**

Add `AppLogger.error('[Screen] <operation> failed', e, stackTrace)` to each cited catch block (S-sized mechanical change); adopt the convention that every catch either rethrows or logs via AppLogger.

---

### Low

#### [arch-17] dB-to-color/label banding duplicated in 7 places

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:177`

**Description:**

The <50 / <70 / >=70 banding is independently implemented in: community_feed_screen.dart:18-30 (_getNoiseColor + _getNoiseLevelLabel), map_view_screen.dart:1284-1294 (_getNoiseColor + _getNoiseLevel), decibel_meter_gauge.dart:177-185 (_getDbColor), history_screen.dart:507-513 (inline dbColor), search_list_screen.dart:570-577 (inline cardColor), models/heatmap_point.dart:84-87, and heatmap_service.dart:119-121 (quiet/moderate point counting). Labels have also already drifted ('Safe' vs 'Low Noise - Safe').

**Failure scenario:**

Product decides to align bands with WHO guidance (e.g. moderate starts at 55 dB): the change lands in 5 of 7 copies, so the map marker shows red while the history row for the same reading shows orange and heatmap statistics still count it as quiet.

**Recommended fix:**

Add lib/utils/noise_level.dart with `Color noiseColor(double db)`, `String noiseLabel(double db)` and the band constants; replace all seven copies and unit test it (feeds arch-11).

---

#### [arch-16] Dead FirebaseService methods, one of which fetches the entire collection and ignores all its parameters

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/firebase_service.dart:243`

**Description:**

Grep of all call sites shows three methods are never called from lib/: getReadingsByLocation (firebase_service.dart:243-255) — accepts lat/lng/radiusKm but ignores them and does an unbounded `.collection('noise_readings').get()` of every document; calculateStats (320-343) — superseded by calculateStatsByPeriod, and still contains the crash-prone non-null-safe cast `(doc.data()['decibelLevel'] as num).toDouble()` at line 334 that was explicitly fixed in its sibling (lines 300-304); getNoiseReadingsForHeatmap (183-202) — heatmap_service.dart runs its own query instead. The only 'usage' is firebase_service_test.dart:39 asserting getReadingsByLocation `isA<Function>()`.

**Failure scenario:**

A developer needing nearby readings finds getReadingsByLocation, calls it with a 1 km radius, and ships code that silently downloads the entire collection on every call (cost + latency) while appearing radius-filtered; or calls calculateStats and crashes on the first document missing decibelLevel.

**Recommended fix:**

Delete all three methods (and the test line referencing getReadingsByLocation). If geo-queries are needed later, implement them properly (geohash/GeoFirestore) rather than resurrecting the trap.

---

#### [flow7-12] Two different webview plugins power the two donation webviews

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/widgets/buy_me_coffee_widget.dart:2`

**Description:**

PayPalWebViewWidget uses flutter_inappwebview (paypal_webview_widget.dart line 2) while BuyMeACoffeeWidget uses webview_flutter (line 2); both are declared in pubspec.yaml (lines 91-92). Two native webview stacks are compiled into the app for one feature, and the two screens have divergent capabilities and bug surfaces (different navigation-delegate semantics, different error callbacks - see flow7-14 vs BMC's simpler handling).

**Failure scenario:**

A fix made to navigation/back handling in one widget (e.g. flow7-05 host parsing) is forgotten in the other because the APIs differ; APK size and maintenance cost increase for no functional gain.

**Recommended fix:**

Standardize on one plugin (flutter_inappwebview covers both use cases), port BuyMeACoffeeWidget to it, and drop webview_flutter from pubspec.yaml.

---

#### [fb-15] Dead FirebaseService methods with latent hazards: full-collection scan, ignored parameters, crash-prone cast

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/firebase_service.dart:250`

**Description:**

Four methods have no call sites anywhere in lib/ (verified by grep): getReadingsByLocation (lines 243-255) fetches the ENTIRE noise_readings collection with no where/limit AND completely ignores its lat/lng/radiusKm parameters — the promised in-code filtering never happens, so it returns every reading; getUserReadings (lines 205-211) is an unbounded per-user stream; getNoiseReadingsForHeatmap (lines 183-202) is unused; calculateStats (lines 320-343) is unbounded and uses the crash-prone (doc.data()['decibelLevel'] as num).toDouble() cast (line 334) that its sibling calculateStatsByPeriod was already fixed to avoid (lines 301-304).

**Failure scenario:**

A future feature wires up getReadingsByLocation expecting radius-filtered results: it silently downloads the whole collection (cost/latency blowup) and returns unfiltered global data, showing wrong 'nearby' readings; or wires calculateStats and crashes on the first doc missing decibelLevel.

**Recommended fix:**

Delete the four unused methods, or if kept: implement the haversine filter and add where/limit clauses in getReadingsByLocation, add .limit() to getUserReadings/calculateStats, and make calculateStats's cast null-safe like calculateStatsByPeriod.

---

#### [map-22] HeatmapSettingsPanel and the entire heatmap filter/statistics API are dead code

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/widgets/heatmap_settings_panel.dart:6`

**Description:**

HeatmapSettingsPanel is imported by no file (verified project-wide grep) — its opacity slider, time-range chips, and statistics UI are unreachable. Correspondingly, HeatmapService.filterByTimeRange/filterByDecibelRange/filterBySoundCategory/calculateStatistics/getTimeRangeBoundaries/getGradientColors (services/heatmap_service.dart:30-138) have zero callers, and the map's _heatmapOpacity is a final 0.7 (map_view_screen.dart:69) that can never change. The heatmap FAB only toggles on/off.

**Failure scenario:**

A maintainer changes the gradient in HeatmapService.getGradientColors expecting the map to update; nothing changes because the painter uses its own private _gradientColors (map_view_screen.dart:1429), and the settings panel they test against never mounts.

**Recommended fix:**

Either wire HeatmapSettingsPanel into MapViewScreen (making opacity/time-range functional, and fixing map-11/map-12 first) or delete the panel and the unused HeatmapService methods to remove the divergent duplicate gradient definitions.

---

#### [flow5-12] Dead storage API for a nonexistent BackgroundSyncService, including duplicated markAsSynced with divergent schema

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/offline_storage_service.dart:103`

**Description:**

getPendingSyncRecordings (line 103), markRecordingAsSynced (line 123), incrementSyncAttempts (line 146), async getLastSyncTime (line 188), getAllOfflineRecordings (line 214), and getRecording (line 225) have zero callers in lib/ (verified by grep); comments reference a 'BackgroundSyncService' that does not exist anywhere in the project — confirming there is no background sync and the flow only works while the app is foregrounded. The dead markRecordingAsSynced writes an extra 'syncedAt' field the live markAsSynced (line 235) does not, and the dead getAllOfflineRecordings/getRecording contain the same fatal Map cast as flow5-1, waiting to crash any future caller.

**Failure scenario:**

A developer wiring up background sync later calls the plausible-looking getAllOfflineRecordings() and gets an immediate TypeError on disk-loaded data, or mixes markRecordingAsSynced/markAsSynced and ends up with two record shapes in the same Hive box.

**Recommended fix:**

Delete the six dead methods (or keep exactly one markAsSynced and one pending-getter, fixed per flow5-1) and remove the BackgroundSyncService comments; centralize the Hive map schema in OfflineRecording toMap/fromMap.

---

#### [arch-20] Startup loads the YAMNet TFLite model twice before the first frame

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/main.dart:66`

**Description:**

main() awaits _testModelLoading() (main.dart:66, defined 75-99), which loads yamnet.tflite from assets, reads tensor shapes, and immediately closes the interpreter — a leftover verification step (comment: 'Step 1-3') — then awaits _initializeSoundClassification() (line 69), which loads the exact same model again inside SoundClassificationService.initialize(). Both run before runApp (line 71), so the duplicate multi-MB model parse happens on the critical startup path.

**Failure scenario:**

User cold-starts the app on a mid-range device: the splash/first frame is delayed by a redundant full TFLite model load+parse that contributes nothing (its only output is debug log lines), roughly doubling the model-init portion of startup.

**Recommended fix:**

Delete _testModelLoading and its call; SoundClassificationService.initialize already logs input/output shapes on success. Optionally move initialization off the pre-runApp path entirely and let the dashboard await isInitialized.

---

#### [arch-18] AppLogger level hardcoded to Level.debug with a TODO — verbose logs ship in release builds

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/utils/app_logger.dart:22`

**Description:**

app_logger.dart:22: `level: Level.debug, // TODO: Change to Level.error for production`. There is no kReleaseMode branch, so release builds emit every debug line, including per-classification YAMNet top-3 dumps every 5 seconds (sound_classification_service.dart:121-123) and location names in log messages, with PrettyPrinter formatting overhead on the audio-processing path.

**Failure scenario:**

App is built with `flutter build apk --release`: the 5-second classification loop formats and emits multi-line pretty-printed logs continuously during recording, costing CPU/battery on the hot path and leaking users' location names into device logcat.

**Recommended fix:**

Replace the constant with `level: kReleaseMode ? Level.warning : Level.debug` (import package:flutter/foundation.dart) and delete the TODO.

---

#### [ml-13] Interpreter is never closed: dispose() and reset() have zero call sites

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:260`

**Description:**

The service correctly loads the model once (singleton + _isInitialized guard at lines 40-51), but dispose() (lines 260-265) and reset() (lines 268-271) are never called from anywhere in lib/ (grep confirms; DashboardScreen.dispose at dashboard_screen.dart:659-667 closes the recorder but not the classification service). The native interpreter and its ~4MB+ of tensors stay resident for the entire app lifetime, including when the app is backgrounded indefinitely. Minor secondary issue: if initialize() ever failed after assigning _interpreter (line 56 succeeded, line 57/58 threw), a subsequent initialize() call would overwrite _interpreter without closing the old one, leaking a native interpreter.

**Failure scenario:**

App is backgrounded for hours; the TFLite native buffers remain allocated, increasing the chance the OS kills the app under memory pressure. On the failure edge case, a retry of initialize() leaks the previously constructed native interpreter.

**Recommended fix:**

Acceptable as a deliberate app-lifetime singleton, but make it explicit: close the interpreter from a WidgetsBindingObserver on AppLifecycleState.detached (and re-initialize on resume), and in initialize()'s catch block call _interpreter?.close() before nulling it.

---

#### [offline-17] Duplicate, drifting storage APIs (two markAsSynced, two attempt-updaters, two pending counters) with inconsistent persistence formats

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** M

**Location:** `lib/services/offline_storage_service.dart:123`

**Description:**

The service exposes parallel methods that do the same job differently: `markRecordingAsSynced` (line 123, writes `syncedAt` as an ISO *string* and mutates the cached map in place) vs `markAsSynced` (line 235, no syncedAt, copies the map); `incrementSyncAttempts` (146, writes `lastSyncAttempt`) vs `updateSyncStatus` (258, writes `syncError`); `getPendingSyncCount` (170, async) vs `getPendingCount` (340, sync); `getPendingSyncRecordings` (103) documented 'for BackgroundSyncService' — a class that does not exist anywhere in lib/. Only one of each pair is used by SyncService, so the queue's persisted shape depends on which code path touched an entry (some entries get syncedAt/lastSyncAttempt strings, others don't), and the unused `getAllOfflineRecordings` (220) and `getRecording` (229) carry the crash-prone `as Map<String,dynamic>` cast from offline-1.

**Failure scenario:**

A future feature calls markRecordingAsSynced while SyncService uses markAsSynced; entries now have two subtly different 'synced' shapes, and debugging why some rows have ISO-string syncedAt and others none wastes hours. Meanwhile dead methods with known-broken casts invite reuse that crashes.

**Recommended fix:**

Delete the unused half of each pair (or make one delegate to the other), remove the BackgroundSyncService-oriented dead code, standardize the map schema in one place (ideally a single toStorageMap/fromStorageMap on OfflineRecording that also owns syncedAt/lastSyncAttempt), and fix or delete getAllOfflineRecordings/getRecording.

---

#### [arch-19] Dependency hygiene: latlong2 pinned to 'any' and build tool flutter_launcher_icons in runtime dependencies

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `pubspec.yaml:106`

**Description:**

pubspec.yaml:106 declares `latlong2: any` — no version constraint at all, unlike every other dependency — so a breaking major release of latlong2 (used by the map screen) can be silently picked up by any fresh `pub get`. pubspec.yaml:78 places flutter_launcher_icons (a code-gen/build tool, never imported at runtime — verified) under `dependencies:` instead of `dev_dependencies:`, shipping it in the app's dependency closure.

**Failure scenario:**

A teammate clones the repo and runs `flutter pub get` after latlong2 publishes a breaking 1.x: their build fails (or subtly changes distance math on the map) while CI with an old pubspec.lock passes — non-reproducible builds.

**Recommended fix:**

Change line 106 to a caret constraint matching the lockfile (e.g. `latlong2: ^0.9.1`) and move flutter_launcher_icons to dev_dependencies.

---

#### [arch-15] Dead files: image_compression_service.dart (99 lines), heatmap_settings_panel.dart (285 lines), and the template MyHomePage in main.dart

**Severity:** Low | **Status:** unverified | **Category:** architecture | **Effort:** S

**Location:** `lib/services/image_compression_service.dart:1`

**Description:**

A full import-graph walk (package: and relative imports, lib + test) confirms lib/services/image_compression_service.dart and lib/widgets/heatmap_settings_panel.dart are imported by NOBODY and unreachable from main.dart. image_compression_service.dart is also the sole user of the flutter_image_compress dependency (pubspec.yaml:101), so that package ships for nothing. Additionally main.dart:183-267 still contains the Flutter template MyHomePage/_MyHomePageState counter widget (85 lines), referenced only by the broken default widget_test.dart.

**Failure scenario:**

A developer 'fixes' heatmap behavior by editing heatmap_settings_panel.dart (its name suggests it drives the map's heatmap settings) and nothing changes in the app, because the live panel logic lives elsewhere; the dead 384+ lines keep absorbing refactor effort (e.g. ThemeHelper migrations).

**Recommended fix:**

Delete lib/services/image_compression_service.dart (and flutter_image_compress from pubspec), lib/widgets/heatmap_settings_panel.dart, and main.dart lines 183-267 (with test/widget_test.dart per arch-2). If image compression is planned for photo reports, restore it alongside the actual feature.

---

## Quick Wins (under 1 hour each)

- [ ] **arch-17** - dB-to-color/label banding duplicated in 7 places (`lib/widgets/decibel_meter_gauge.dart:177`)
- [ ] **arch-16** - Dead FirebaseService methods, one of which fetches the entire collection and ignores all its parameters (`lib/services/firebase_service.dart:243`)
- [ ] **fb-15** - Dead FirebaseService methods with latent hazards: full-collection scan, ignored parameters, crash-prone cast (`lib/services/firebase_service.dart:250`)
- [ ] **arch-5** - Dashboard today-count query violates the mandated Firestore query pattern (isGreaterThanOrEqualTo, no orderBy) and streams full docs just to count them (`lib/screens/dashboard_screen.dart:911`)
- [ ] **social-11** - ImageCompressionService is fully orphaned — no image pick/compress/upload pipeline exists anywhere (`lib/services/image_compression_service.dart:12`)
- [ ] **arch-6** - Firestore write shape duplicated between FirebaseService and SyncService and has already diverged: offline-synced readings lack userEmail (`lib/services/sync_service.dart:211`)
- [ ] **flow5-12** - Dead storage API for a nonexistent BackgroundSyncService, including duplicated markAsSynced with divergent schema (`lib/services/offline_storage_service.dart:103`)
- [ ] **arch-20** - Startup loads the YAMNet TFLite model twice before the first frame (`lib/main.dart:66`)
- [ ] **arch-3** - Classification threshold is 0.15 (spec says 0.30) and the threshold gates nothing (`lib/services/sound_classification_service.dart:34`)
- [ ] **arch-18** - AppLogger level hardcoded to Level.debug with a TODO — verbose logs ship in release builds (`lib/utils/app_logger.dart:22`)
- [ ] **ml-13** - Interpreter is never closed: dispose() and reset() have zero call sites (`lib/services/sound_classification_service.dart:260`)
- [ ] **arch-19** - Dependency hygiene: latlong2 pinned to 'any' and build tool flutter_launcher_icons in runtime dependencies (`pubspec.yaml:106`)
- [ ] **arch-14** - Eight declared dependencies are never imported anywhere in lib/ or test/ (`pubspec.yaml:54`)
- [ ] **arch-15** - Dead files: image_compression_service.dart (99 lines), heatmap_settings_panel.dart (285 lines), and the template MyHomePage in main.dart (`lib/services/image_compression_service.dart:1`)
- [ ] **arch-13** - Logging inconsistency: 7 files with error paths log nothing while the rest of the app uses AppLogger (`lib/screens/settings_screen_enhanced.dart:944`)
