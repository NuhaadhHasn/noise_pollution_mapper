# Bugs & Correctness Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **92** (3 Critical, 31 High, 39 Medium, 19 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| critic-01 | Critical | confirmed | `ios/Runner/Info.plist:4` | Info.plist has no permission usage descriptions - app crashes on iOS | S |
| offline-1 | Critical | confirmed | `lib/services/offline_storage_service.dart:93` | Queue is permanently unsyncable after app restart: Hive returns Map<dynamic,dynamic>, fromMap cast throws | S |
| settings-1 | Critical | confirmed | `lib/screens/settings_screen_enhanced.dart:887` | Delete Account anonymizes all readings BEFORE auth deletion, orphaning data when delete fails | M |
| ml-1 | High | confirmed | `lib/services/yamnet_class_mapping.dart:52` | Hardcoded indexToClassName table does not match the official YAMNet 521-class map | M |
| fb-2 | High | confirmed | `lib/services/sync_service.dart:217` | Offline-synced readings get the sync time, not the recording time, as their 'timestamp' | S |
| map-1 | High | confirmed | `lib/screens/map_view_screen.dart:687` | Cluster color lookup key never matches — all clusters render as 'moderate' orange | S |
| offline-4 | High | confirmed | `lib/services/sync_service.dart:233` | Uploads are not idempotent: `.add()` with auto-ID plus mark-after-upload produces duplicate Firestore documents on retry | S |
| fb-1 | High | confirmed | `lib/services/firebase_service.dart:29` | saveNoiseReading silently drops readings and swallows all errors; callers show false success | M |
| critic-03 | High | refuted | `android/app/src/main/AndroidManifest.xml:7` | POST_NOTIFICATIONS permission missing from AndroidManifest - high-noise alerts never appear on Android 13+ | S |
| fb-3 | High | confirmed | `lib/screens/history_screen.dart:87` | History load permanently deadlocks when userId is null: _isLoading stuck true blocks all retries | S |
| analytics-2 | High | confirmed | `lib/screens/analytics_screen.dart:210` | Weekly/Monthly buckets use rolling 24h windows but x-axis labels claim calendar days — readings attributed to the wrong weekday | S |
| fb-6 | High | confirmed | `lib/screens/analytics_screen.dart:163` | Analytics 'Duration' stat is off by 60x: divides reading count by 12 but readings are saved every 5 seconds | S |
| dash-2 | High | confirmed | `lib/screens/dashboard_screen.dart:364` | Double-start race: _isRecording set only after awaits, leaking a noise subscription and a duplicate save timer | S |
| donate-4 | High | confirmed | `lib/widgets/buy_me_coffee_widget.dart:106` | 'Open in Browser' button does nothing except show a misleading 'Opening in browser...' snackbar | S |
| donate-6 | High | confirmed | `lib/widgets/paypal_webview_widget.dart:63` | LateInitializationError crash if Reload/Try Again is tapped before the webview controller is created | S |
| donate-3 | High | confirmed | `lib/widgets/paypal_webview_widget.dart:134` | Any failed non-'paypal.com' subresource replaces a working checkout with a full-screen error - including PayPal's own CDN | S |
| dash-4 | High | confirmed | `lib/screens/dashboard_screen.dart:492` | Readings saved with hardcoded Colombo fallback coordinates when location is denied or unavailable | S |
| map-4 | High | disputed | `lib/screens/map_view_screen.dart:288` | Location permission result ignored; denied/deniedForever fail silently and camera jumps to default location | S |
| settings-4 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:180` | 'High Noise Alerts' toggle and 'Alert Threshold' slider have no effect — alert logic is hardcoded | S |
| dash-5 | High | disputed | `lib/screens/dashboard_screen.dart:911` | Community Feed count query violates the project Firestore index rule (isGreaterThanOrEqualTo, no orderBy) and swallows the resulting error | S |
| ml-2 | High | confirmed | `lib/services/yamnet_class_mapping.dart:1011` | Range fallbacks (0-15 Speech, 16-35 Body Sounds, 229-309 Domestic, ...) are dead code due to 'Unknown_Class_' vs 'YAMNet_Class_' prefix mismatch | S |
| map-3 | High | confirmed | `lib/screens/search_list_screen.dart:292` | Debounce guard compares raw input to lowercased query — search never fires for capitalized input | S |
| settings-6 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:90` | All four Measurement settings (dBA/dBC, Response Time, Recording Duration, Save Frequency) are silent no-ops | L |
| offline-2 | High | confirmed | `lib/services/sync_service.dart:151` | Recordings that fail 3 sync attempts are stranded forever: attempts are never reset and there is no recovery path | M |
| social-3 | High | confirmed | `lib/screens/history_screen.dart:721` | Deleting a recording never updates the on-screen list or the 'Showing X of Y' count | S |
| analytics-4 | High | confirmed | `lib/screens/analytics_screen.dart:746` | Manual 'Speech-Pollution' readings appear under the Ambient filter and vanish from the Pollution filter in the category breakdown | S |
| ml-4 | High | confirmed | `lib/services/sound_classification_service.dart:126` | Threshold logic has zero behavioral effect: below-threshold results are returned identically and persisted to Firestore | S |
| settings-5 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:189` | 'Daily Reminders' toggle does nothing — no scheduling exists and showDailyReminder() is never called | M |
| arch-2 | High | confirmed | `test/unit/sound_classification_test.dart:71` | Test suite is broken: 53 of 149 tests fail on a clean `flutter test` run | L |
| donate-5 | High | confirmed | `lib/models/category_guide_data.dart:144` | Classification guide contradicts the actual YAMNet mapping for Market, Alarm, Body Sounds, Nature, Other, and Transport | S |
| social-2 | High | disputed | `lib/screens/history_screen.dart:451` | Hard cast `data['decibelLevel'] as num` crashes list rendering on any doc missing decibelLevel | S |
| ml-3 | High | confirmed | `lib/services/sound_classification_service.dart:34` | Confidence threshold is 0.15, violating the documented project threshold of 0.30 | S |
| boot-1 | High | confirmed | `lib/main.dart:38` | No error handling around Firebase init or any pre-runApp startup await — failure leaves a permanent blank screen | S |
| dash-1 | High | confirmed | `lib/screens/dashboard_screen.dart:424` | AVG decibel uses arithmetic mean instead of energy-based (logarithmic) averaging | S |
| flow7-02 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:123` | _paymentComplete set outside setState so the 'Payment Complete!' overlay never renders | S |
| map-12 | Medium | unverified | `lib/models/heatmap_point.dart:35` | Timestamp read ignores createdAt fallback — violates the project's dual-timestamp convention | S |
| arch-11 | Medium | unverified | `test/unit/decibel_calculation_test.dart:6` | Half the unit-test files never import application code — they test reimplemented local helpers and tautologies | M |
| ml-8 | Medium | unverified | `lib/screens/analytics_screen.dart:729` | Analytics ambientCategories list omits 'Other', so 'Other' readings vanish from both Pollution and Ambient filters | S |
| dash-13 | Medium | unverified | `lib/screens/dashboard_screen.dart:747` | Gauge scale tops out at 100 dB while readings are clamped to 120 dB: needle pegs, digits keep climbing | S |
| boot-4 | Medium | unverified | `lib/screens/login_screen.dart:61` | Login has no generic catch and its error mapping misses the codes modern Firebase Auth actually returns | S |
| settings-12 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:944` | Error handlers in _deleteAccount/_clearHistory pop the Settings route when the loading dialog was never shown | S |
| dash-8 | Medium | unverified | `lib/screens/dashboard_screen.dart:482` | setState and timer creation after dispose in _startRecording (no mounted check after await) | S |
| map-5 | Medium | unverified | `lib/screens/map_view_screen.dart:330` | _showNativeLocationDialog shows no dialog — geolocator throws instead when location services are off | S |
| fb-12 | Medium | unverified | `lib/screens/map_view_screen.dart:176` | Unsafe casts in marker/heatmap building: one malformed doc silently blanks the entire map | S |
| social-18 | Medium | unverified | `lib/screens/report_noise_screen.dart:183` | SharedAppState.locationDialogShown is set true but almost never reset — location dialog shows at most once per session on error paths | S |
| dash-11 | Medium | unverified | `lib/screens/dashboard_screen.dart:639` | In-flight classification resurrects _currentClassification after stop; stale label attached to next session's saves | S |
| offline-12 | Medium | unverified | `lib/services/offline_storage_service.dart:35` | No Hive corruption recovery: a corrupt box file permanently disables the offline feature and the indicator lies about it | M |
| offline-11 | Medium | unverified | `lib/services/sync_service.dart:104` | Connectivity detection equates any network interface (including bluetooth/VPN) with internet reachability | M |
| analytics-6 | Medium | unverified | `lib/services/firebase_service.dart:311` | Average dB uses arithmetic mean instead of energy (Leq) averaging — understates true noise exposure | S |
| dash-7 | Medium | unverified | `lib/screens/dashboard_screen.dart:1040` | MIN stat card renders the literal text 'Infinity' until the first reading arrives | S |
| social-9 | Medium | unverified | `lib/screens/history_screen.dart:111` | Every load failure is misreported as 'No Internet Connection' | S |
| boot-9 | Medium | unverified | `lib/widgets/main_app_shell.dart:48` | Microphone keeps recording on a hidden tab with no indicator — tab switch never notifies Dashboard | M |
| arch-12 | Medium | unverified | `lib/services/yamnet_class_mapping.dart:1052` | Highest-value pure logic (YAMNet mapping fallbacks, audio preprocessing, analytics bucket math) has no tests and is mostly private/untestable | M |
| analytics-9 | Medium | unverified | `lib/screens/analytics_screen.dart:191` | Trend chart silently drops readings >120 dB or <0 dB that the stat cards still include | S |
| ml-5 | Medium | unverified | `lib/services/sound_classification_service.dart:223` | Peak normalization amplifies the noise floor to full scale, distorting YAMNet input and making 'Silence' undetectable | S |
| dash-16 | Medium | unverified | `lib/screens/dashboard_screen.dart:664` | dispose() races closeRecorder against the still-running async _stopRecording | S |
| dash-9 | Medium | unverified | `lib/screens/dashboard_screen.dart:132` | setState after dispose in _checkAndRefreshLocation: mounted not re-checked after await | S |
| map-7 | Medium | unverified | `lib/screens/map_view_screen.dart:1395` | Heatmap projection ignores map rotation — blobs misalign when the user rotates the map | S |
| settings-14 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:789` | Change Password maps only legacy 'wrong-password' code; modern Firebase returns 'invalid-credential' so users get a generic error | S |
| offline-9 | Medium | unverified | `lib/services/sync_service.dart:191` | last_sync_time is saved even when zero recordings synced, so 'Last Sync: just now' is shown after total failure | S |
| fb-14 | Medium | unverified | `lib/models/heatmap_point.dart:45` | Read/write field mismatch: heatmap reads 'soundCategory' but every writer stores 'soundClass' | S |
| fb-11 | Medium | unverified | `lib/services/firebase_service.dart:43` | Connectivity check trusts interface state: connected-without-internet hangs the online save path indefinitely | M |
| map-8 | Medium | unverified | `lib/screens/map_view_screen.dart:1471` | HeatmapPainter.shouldRepaint compares only list length — equal-count data changes can render stale | S |
| donate-9 | Medium | unverified | `lib/services/donation_service.dart:98` | Donation history entries are corrupted on read: split(':') breaks on ISO-8601 timestamps | S |
| map-16 | Medium | unverified | `lib/screens/map_view_screen.dart:362` | Nominatim query string is not URL-encoded | S |
| settings-15 | Medium | unverified | `lib/services/notification_service.dart:14` | Notification permission requested only at cold start and init is Android-only — toggle-on can never recover a denial, iOS silently unsupported | S |
| dash-10 | Medium | unverified | `lib/screens/dashboard_screen.dart:544` | Stop is not immediate: _isRecording stays true through async teardown (up to 3s), and a second stop tap re-enters concurrently | S |
| dash-14 | Medium | unverified | `lib/widgets/noise_history_chart.dart:61` | Chart maxY is 100 but data reaches 120 dB; line draws outside the plot with no clipping | S |
| offline-10 | Medium | unverified | `lib/services/offline_storage_service.dart:86` | One malformed queue entry blocks the entire queue: no per-item error handling around fromMap | S |
| donate-7 | Medium | unverified | `lib/widgets/buy_me_coffee_widget.dart:56` | Any failed subresource on the Buy Me a Coffee page triggers the full-screen error overlay | S |
| offline-8 | Medium | unverified | `lib/services/sync_service.dart:149` | Sync loop has no upload timeout and no mid-batch online re-check; with Firestore persistence enabled a dropped connection hangs the sync indefinitely | S |
| map-6 | Medium | unverified | `lib/screens/map_view_screen.dart:611` | SyncStatusIndicator is painted beneath the map and is never visible | S |
| social-10 | Medium | unverified | `lib/screens/report_noise_screen.dart:174` | Location pill spinner sticks on and the refresh button stays disabled — _isGettingLocation is cleared without setState | S |
| boot-11 | Low | unverified | `lib/screens/login_screen.dart:159` | Email validation is nearly a no-op on both auth forms | S |
| offline-16 | Low | unverified | `lib/services/offline_storage_service.dart:58` | Queue key collisions silently overwrite recordings: ID is millisecond timestamp + userId | S |
| map-20 | Low | unverified | `lib/screens/map_view_screen.dart:105` | MapController is never disposed | S |
| analytics-13 | Low | unverified | `lib/screens/analytics_screen.dart:239` | Daily x-axis labels claim clock hours but buckets are rolling 60-minute windows anchored to 'now' | S |
| analytics-12 | Low | unverified | `lib/screens/analytics_screen.dart:206` | Negative elapsed time (server timestamp ahead of device clock) produces bucket indices beyond maxX, drawing spots outside the chart | S |
| flow2-15 | Low | unverified | `lib/screens/dashboard_screen.dart:311` | Mic permission dialog uses BuildContext across an async gap without a mounted check | S |
| map-15 | Low | unverified | `lib/screens/map_view_screen.dart:768` | Duplicate current-location MarkerLayer mislabeled as 'Searched location marker' | S |
| flow7-13 | Low | unverified | `lib/widgets/paypal_webview_widget.dart:287` | Recorded donation amount is the app-side amount, never verified against the actual transaction | M |
| ml-11 | Low | unverified | `lib/screens/dashboard_screen.dart:529` | Int16-to-float scaling divides by 32767, producing samples below -1.0 | S |
| ml-12 | Low | unverified | `lib/services/sound_classification_service.dart:192` | Latent resampler defects: no anti-aliasing filter and output can be shorter than the computed length | M |
| fb-18 | Low | unverified | `lib/screens/search_list_screen.dart:505` | Hard (as num) decibelLevel casts in list/grid builders crash the whole view on a single bad doc | S |
| settings-21 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:678` | Change Password dialog leaks TextEditingControllers | S |
| offline-15 | Low | unverified | `lib/widgets/sync_status_indicator.dart:102` | SyncStatusIndicator's onTap constructor parameter is silently ignored | S |
| social-12 | Low | unverified | `lib/services/image_compression_service.dart:44` | Compression failure silently returns the original full-size image with no size cap (latent) | S |
| social-13 | Low | unverified | `lib/services/image_compression_service.dart:34` | Compression stats divide by zero for images under 1 KB — logs 'Infinity% reduction' or 'NaN' | S |
| analytics-11 | Low | unverified | `lib/screens/analytics_screen.dart:157` | capturedPeriod race guard fails for A→B→A period toggles — a stale in-flight load can overwrite the newer one | S |
| map-21 | Low | unverified | `lib/screens/map_view_screen.dart:241` | Saved map position restore races the first FlutterMap layout | S |
| map-24 | Low | unverified | `lib/screens/map_view_screen.dart:1438` | Heatmap paints oldest readings on top of newest at the same location | S |
| ml-10 | Low | unverified | `lib/screens/dashboard_screen.dart:498` | Stale classification is re-saved to Firestore when subsequent classifications fail or return null | S |

## Detailed Findings

### Critical

#### [critic-01] Info.plist has no permission usage descriptions - app crashes on iOS

**Severity:** Critical | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `ios/Runner/Info.plist:4`

**Verifier verdict (CONFIRMED):** ios/Runner/Info.plist:4-48 contains zero usage-description keys; grep for NSMicrophone|NSLocation across ios/ finds nothing. pubspec.yaml:42-50 declares noise_meter ^5.0.2 (mic), permission_handler ^11.3.1, geolocator ^13.0.2, so the app accesses mic and location. iOS kills an app that touches the microphone without NSMicrophoneUsageDescription (TCC privacy crash), so "crashes on first recording" is accurate. Missing NSLocationWhenInUseUsageDescription is also real (location requests silently fail/deny rather than crash, a minor overstatement in one variant, but the core defect is exactly as described).

**Description:**

The app records audio (noise_meter, flutter_sound), reads GPS (geolocator), and picks photos (image_picker), but ios/Runner/Info.plist contains zero usage-description keys: no NSMicrophoneUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription, or NSCameraUsageDescription. On iOS, accessing a protected resource without its usage string makes the OS terminate the process immediately (TCC crash), and App Store review rejects the binary. README.md line 235 claims 'iOS (configured, not extensively tested)' - it is not configured.

**Failure scenario:**

User installs the iOS build, taps the record button on the Dashboard; the first AVAudioSession/microphone access kills the app instantly with 'This app has crashed because it attempted to access privacy-sensitive data without a usage description.' Same on first location fix and on picking a profile photo.

**Recommended fix:**

Add NSMicrophoneUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription (and NSCameraUsageDescription if camera capture is offered) with user-facing justification strings to ios/Runner/Info.plist, plus the geolocator-required entries. Alternatively, update README to state iOS is unsupported.

---

#### [offline-1] Queue is permanently unsyncable after app restart: Hive returns Map<dynamic,dynamic>, fromMap cast throws

**Severity:** Critical | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/offline_storage_service.dart:93`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. Writer stores plain maps in a dynamic Hive box (offline_storage_service.dart:58, `put(recording.id, recording.toMap())`, no TypeAdapters per line 34-35). After an app restart, Hive deserializes those entries from disk as Map<dynamic,dynamic>. getQueuedRecordings() at line 93 does `.map((v) => OfflineRecording.fromMap(v))` with `v` typed dynamic — a dynamic invocation of `OfflineRecording.fromMap(Map<String, dynamic> map)` (offline_recording.dart:34) — which throws TypeError at runtime for Map<dynamic,dynamic> input; there is no Map<String,dynamic>.from conversion on this path. This is the ONLY path to Firestore: SyncService.syncOfflineRecordings (sync_service.dart:140) calls it, the throw occurs during list construction before any upload, is swallowed by the catch at sync_service.dart:200 (logged, returns 0), and recurs on every retry (connectivity trigger line 88, manual sync via sync_status_indicator.dart:214). The safe alternative getPendingSyncRecordings() (line 103, which does Map<String,dynamic>.from) has zero callers — the BackgroundSyncService it references does not exist in the codebase. Cleanup (clearSyncedRecordings) only removes synced entries, so poisoned pre-restart entries persist and additionally block syncing of any NEW recordings queued after restart, since the exception aborts the whole enumeration. Only caveat: within the same session (before restart) sync works because Hive's in-memory cache returns the original Map<String,dynamic> instance — but the finding already scopes itself to "after app restart", so this is not an overstatement.

**Description:**

`saveOfflineRecording` (line 58) puts a `Map<String,dynamic>` into the dynamic Hive box. Within the same session, `get` returns the cached typed map and everything works. After an app restart, Hive deserializes stored maps from disk as `Map<dynamic,dynamic>`. `getQueuedRecordings` line 93 calls `OfflineRecording.fromMap(v)` where `fromMap` (lib/models/offline_recording.dart:34) declares `Map<String,dynamic>` — the implicit downcast from dynamic throws `TypeError: _InternalLinkedHashMap<dynamic,dynamic> is not a subtype of Map<String,dynamic>` at runtime. The exception propagates into `syncOfflineRecordings`'s catch-all (sync_service.dart:200) and is only logged, so sync returns 0 silently, forever. Meanwhile `getPendingCount` (line 340-358) never parses the map, so the indicator keeps showing N pending. The same broken cast exists explicitly in `getAllOfflineRecordings` (line 220, `v as Map<String, dynamic>`) and `getRecording` (line 229).

**Failure scenario:**

User records readings while offline, kills the app, relaunches, walks into wifi. Connectivity handler fires, `getQueuedRecordings()` throws on the first disk-loaded entry, sync logs an error and returns 0. Every future sync (auto and manual) fails identically. The recordings never reach Firestore — permanent data loss for the community map — while the badge shows them as 'pending' indefinitely.

**Recommended fix:**

In getQueuedRecordings map with `OfflineRecording.fromMap(Map<String, dynamic>.from(v))` (as getPendingSyncRecordings line 114 already does correctly), or change `fromMap` to accept `Map<dynamic, dynamic>`. Apply the same to getAllOfflineRecordings:220 and getRecording:229. Add a restart-then-sync integration test.

---

#### [settings-1] Delete Account anonymizes all readings BEFORE auth deletion, orphaning data when delete fails

**Severity:** Critical | **Status:** confirmed | **Category:** bug | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:887`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. In C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/lib/screens/settings_screen_enhanced.dart, _deleteAccount() (lines 864-959) performs the operations in this order: (1) lines 887-901 query all noise_readings where userId == uid and commit a batch that overwrites 'userEmail' to 'Deleted User' and 'userId' to 'deleted_user_${uid.substring(0, 8)}'; (2) only then, line 904, calls `await user.delete()`. There is no rollback anywhere: the `on FirebaseAuthException` handler (lines 924-943) merely closes the loading dialog and shows a snackbar — for 'requires-recent-login' it tells the user "Please log out and log in again before deleting your account" — leaving the already-committed anonymization in place. A grep for 'deleted_user_'/rollback/restore across lib/ shows no code that ever re-associates readings. Since every read path in the app filters by userId == currentUser.uid, a user who hits requires-recent-login (a routine Firebase failure when the session is stale — the handler explicitly anticipates it) keeps their account but permanently loses ownership of all their readings and their history/analytics data. The screen is live code, mounted in MainAppShell (lib/widgets/main_app_shell.dart:45, tab index 4) and dashboard_screen.dart:711. The only minor nuance is that the reading documents themselves are anonymized rather than deleted (anonymization is the intended success-path behavior), and an admin could theoretically re-link via the 8-char uid prefix — but from the app's perspective the ownership destruction is irreversible, which is what the finding claims. Severity as Critical is fair: irreversible data mutation ordered before a fallible, commonly-failing operation, with no compensation logic.

**Description:**

_deleteAccount() first rewrites every noise_readings doc (userId -> 'deleted_user_XXXXXXXX', userEmail -> 'Deleted User', lines 887-901) and only then calls user.delete() (line 904). Firebase requires a recent login for account deletion, so 'requires-recent-login' (handled at line 932) is the common outcome for any session older than ~5 minutes. When that happens the account still exists, but the user's entire history has already been irreversibly re-keyed: History screen queries where('userId', isEqualTo: uid) and returns nothing, Analytics/Dashboard stats are empty, and there is no way to restore the link.

**Failure scenario:**

User logged in yesterday opens Settings > Delete Account > Delete. Batch anonymization commits, then user.delete() throws requires-recent-login. Snackbar says 'Please log out and log in again before deleting your account' — user logs back in, keeps the account, but all recordings are permanently gone from their history.

**Recommended fix:**

Re-authenticate first (prompt for password, reauthenticateWithCredential like _showChangePassword does), and only run the anonymization batch after reauth succeeds and immediately before user.delete(); alternatively delete the auth user first and anonymize via a Cloud Function trigger so the two operations cannot be partially applied.

---

### High

#### [ml-1] Hardcoded indexToClassName table does not match the official YAMNet 521-class map

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** M

**Location:** `lib/services/yamnet_class_mapping.dart:52`

**Verifier verdict (CONFIRMED):** The defect is real and load-bearing. (1) The table is the sole index-to-name source: sound_classification_service.dart:116 does `YAMNetClassMapping.indexToClassName[maxIndex]` on the raw argmax of the 521-dim model output, and no labels CSV is bundled (assets/models contains only yamnet.tflite). The resulting name drives getCategoryFromClassName and is persisted to Firebase (yamnetClass/soundClass/soundType). (2) I fetched the official yamnet_class_map.csv from tensorflow/models and compared: only indices 0-8 match. Examples of divergence — official 9=Yell (code: Screaming), 16=Snicker (code: Breathing), 18='Chuckle, chortle' (code: Cough), 132=Music but code puts Music at 137 (official 137=Bass guitar), 310=Truck (code: Vehicle), 313='Reversing beeps' (code: Vehicle horn), 388='Busy signal' (code: Jackhammer), 420=Explosion (code: 'Environmental noise'), 481=Rustle (code: 'Water polo'), 494=Silence (code: Skiing), 504='Outside, rural or natural' (code: Printer), 520='Field recording' (code: 'Talk show'). Entire blocks (420-430, 470-520 'sports'/'office' names like Cubicle, Conference call, Fencing) are fabricated and exist nowhere in the AudioSet ontology. Concrete failure: model outputs index 388 (Busy signal, a telephone tone) -> app reports 'Jackhammer' -> category Construction -> soundType Pollution, stored to Firestore and shown in UI. The only mitigation is that indices 0-8 (Speech-family) are correct, so the very common Speech detections happen to be right, but virtually all non-speech classifications report wrong class names and frequently wrong categories/pollution types, exactly as the finding states.

**Description:**

The bundled model is the standard 4.1MB yamnet.tflite (assets/models/yamnet.tflite, 4,126,810 bytes; numClasses=521 in sound_classification_service.dart:26), whose class order is fixed by the official yamnet_class_map.csv (0='Speech', 1='Child speech, kid speaking', 132='Music', 294='Vehicle', 494='Silence', 520='Field recording'). The hand-written table diverges almost everywhere: it claims 1='Male speech, man speaking' (a class YAMNet removed from AudioSet-527), 137='Music', 310='Vehicle', 331='Silence', 520='Talk show'. Ranges 380-387 ('Bowling', 'Swimming'), 420-430 ('Room tone', 'Noise floor'), 470-503 ('Forest ambience', 'Water polo', 'Fencing') and 504-519 ('Copier', 'Cubicle', 'Meeting room') are names that do not exist in AudioSet at all. In-file proof the table cannot be the real bijective class map: the same name is assigned to two indices three times — 'Engine starting' at 317 (line 193) and 302 (line 367), 'Wind chime' at 94 (line 275) and 328 (line 382), 'Scissors' at 253 (line 316) and 261 (line 324). Every classification result therefore reports the wrong yamnetClass and, via getCategoryFromClassName, frequently the wrong category, and this wrong label is persisted to Firestore (ClassificationResult.toMap, sound_classification_service.dart:303-312) and shown on the map/history.

**Failure scenario:**

Music plays near the phone; the model outputs argmax index 132 ('Music' in the real class map). The app's table has no entry for 132 (it is one of the 119 gap indices: 109-136, 348-379, 400-419, 431-469), so classifySound labels it 'Unknown_Class_132' and the category becomes 'Other'. A silent room (real index 494 'Silence') is labeled 'Ice skating' by the app's table and categorized 'Sports'; heavy road traffic (real 294 'Vehicle') is labeled 'Aircraft' and categorized 'Transport'.

**Recommended fix:**

Replace the hand-written map with the official yamnet_class_map.csv: bundle the CSV as an asset (add to pubspec assets/models/) and parse it at initialize(), or code-generate the Dart map from the CSV verbatim. Then re-verify classMapping keys against the real 521 names (e.g. real classes 'Bellow', 'Whoop', 'Crying, sobbing', 'Chatter', 'Inside, small room' currently have no mapping entry).

---

#### [fb-2] Offline-synced readings get the sync time, not the recording time, as their 'timestamp'

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/sync_service.dart:217`

**Verifier verdict (CONFIRMED):** Both variants hold. (1) sync_service.dart:217 writes 'timestamp': FieldValue.serverTimestamp() and puts the actual recording time only in 'createdAt' (line 218: recording.timestamp). Readers sort and display by 'timestamp' (history_screen.dart:232 orderBy('timestamp'), :253/:453 display it), so offline-synced readings show the sync time, not the recording time. (2) The online writer firebase_service.dart:119 includes 'userEmail': _auth.currentUser?.email, while the offline-sync writer's data map (sync_service.dart:211-220) omits userEmail entirely. Readers consume it: community_feed_screen.dart:171 (falls back to 'Anonymous') and history_screen.dart:262 ('N/A'). No crash due to fallbacks, but offline-synced readings render as Anonymous/N/A — a real writer/writer field mismatch as described.

**Description:**

firebase_service._saveOffline (firebase_service.dart line 153) stores the true recording time in OfflineRecording.timestamp. When sync_service._saveToFirebase uploads it, it writes 'timestamp': FieldValue.serverTimestamp() (sync moment) and puts the real recording time only in 'createdAt' (line 218). Every reader prefers 'timestamp' first: analytics bucketing (analytics_screen.dart lines 195-201 uses createdAt only when timestamp is missing), history display (history_screen.dart line 453), CSV export (line 253), and all orderBy('timestamp') queries in firebase_service.dart.

**Failure scenario:**

User records 20 readings offline on Saturday morning; the phone regains internet Sunday evening and the queue syncs. Analytics 'Daily' view and the trend chart bucket all 20 readings into Sunday evening, History shows Sunday's date on each row, and heatmap recency weights treat them as brand new — the actual Saturday noise data appears at the wrong time everywhere.

**Recommended fix:**

In sync_service._saveToFirebase write 'timestamp': Timestamp.fromDate(recording.timestamp) (the true recording time) and keep 'createdAt': recording.timestamp for the dual-write convention. This keeps the composite index and all existing readers correct.

---

#### [map-1] Cluster color lookup key never matches — all clusters render as 'moderate' orange

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:687`

**Verifier verdict (CONFIRMED):** Verified in C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/lib/screens/map_view_screen.dart. Writer (line 200) stores keys as '${lat}_$lng' (e.g. "3.21_73.09"). Reader (line 687) builds the startsWith prefix as '$point.latitude_$point.longitude'; in Dart, unbraced $point interpolates point.toString() (a LatLng, rendering as "LatLng(latitude:..., longitude:...)") followed by the LITERAL text ".latitude_" — it never accesses the .latitude property. The prefix can therefore never match any stored key, firstWhere always takes orElse '' (line 689), every marker falls back to 50.0 (line 693), avgNoise is always exactly 50.0, and since 50.0 < 70, clusterColor is always AppTheme.moderateNoise (orange) at lines 706-707. The defect, its location, and the stated symptom are all accurate. Fix: use '${point.latitude}_${point.longitude}'.

**Description:**

Marker noise levels are stored under key '${lat}_$lng' (line 200), but the cluster builder searches with the interpolation '$point.latitude_$point.longitude' (lines 685-688). In Dart this interpolates point.toString() twice (producing 'LatLng(latitude:6.9, ...).latitude_LatLng(...).longitude'), never the numeric fields. startsWith() therefore never matches, orElse returns '', and every marker falls back to 50.0 dB (line 693). The average is always exactly 50.0, so the branch at lines 704-710 always picks AppTheme.moderateNoise. As a bonus, the failed firstWhere scans all N keys for each of M markers per cluster per rebuild (O(N*M)).

**Failure scenario:**

User records several 85+ dB readings in one street; zooming out clusters them. Expected a red cluster pin; the cluster is always orange regardless of underlying readings, misrepresenting community noise data.

**Recommended fix:**

Use '${point.latitude}_${point.longitude}' and a direct map lookup: final db = _markerNoiseLevels['${point.latitude}_${point.longitude}'] ?? 50.0. Better: attach the dB to each Marker via a Marker subclass or key so no side-map is needed (also removes the duplicate-coordinate key collision).

---

#### [offline-4] Uploads are not idempotent: `.add()` with auto-ID plus mark-after-upload produces duplicate Firestore documents on retry

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/sync_service.dart:233`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. sync_service.dart:233 executes `await _firestore.collection('noise_readings').add(data)` — an auto-ID create with no deterministic document ID, no dedup field, and no existence check — even though a stable local key (recording.id) is available. The sync loop (lines 158-187) marks the recording synced only after the upload returns; on any thrown error it increments syncAttempts and leaves the recording queued for retry (maxSyncAttempts=3, plus a fresh sync on every reconnect). Duplicates therefore occur whenever (a) the Firestore write commits server-side but the client throws before the ack, (b) the app dies between a successful add() and markAsSynced persisting, or (c) markAsSynced fails — it swallows exceptions and returns false (offline_storage_service.dart:235-255), and sync_service.dart:165 ignores that return value, so the recording silently stays pending and is re-uploaded. No reader-side or server-side dedup compensates. The fix (e.g., .doc(recording.id).set(data)) is straightforward, confirming the operation was avoidably non-idempotent.

**Description:**

`_saveToFirebase` uses `collection('noise_readings').add(data)` (line 233) — a new auto-generated document ID every call. The queue item is marked synced only after the upload resolves (lines 162-165), which is the right order for durability but means any failure *between* the two steps causes a re-upload of an already-persisted document. Concrete windows: (a) app killed/crashed between add() resolving and markAsSynced completing; (b) `markAsSynced` returns false on a Hive write error or missing key (offline_storage_service.dart:240-254 catches and returns false) and sync_service line 165 ignores the return value — syncedCount++ anyway, item stays pending; (c) main.dart:41-44 enables Firestore offline persistence, so if connectivity drops mid-add the write is committed to Firestore's local queue while the awaiting future never resolves — if the app is then killed, on next launch Firestore flushes its queued write AND SyncService re-uploads the still-unsynced Hive item.

**Failure scenario:**

Sync starts on flaky mobile data; add() commits to Firestore's local persistence queue, the device drops offline, the user kills the app. On relaunch with wifi, Firestore's internal queue sends the document, and SyncService uploads the same recording again — the reading appears twice on the community map and doubles its weight in analytics.

**Recommended fix:**

Use a deterministic document ID so retries overwrite instead of duplicate: `_firestore.collection('noise_readings').doc(recording.id).set(data)`. Also check the boolean from `markAsSynced` and log/abort the cleanup for that item if it failed instead of counting it as synced.

---

#### [fb-1] saveNoiseReading silently drops readings and swallows all errors; callers show false success

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** M

**Location:** `lib/services/firebase_service.dart:29`

**Verifier verdict (CONFIRMED):** Verified against lib/services/firebase_service.dart, lib/services/offline_storage_service.dart, and both call sites. (1) Swallows all errors: saveNoiseReading (firebase_service.dart:16-92) is Future<void>; the outer catch (line 70) and the fallback catch (line 88) only log via AppLogger and never rethrow, so the method cannot complete with an error. Worse, the fallback is itself hollow: OfflineStorageService.saveOfflineRecording (offline_storage_service.dart:51-77) never throws — it returns false when Hive is uninitialized (line 52-55) or when put fails (line 73-75) — and FirebaseService._saveOffline (firebase_service.dart:161) discards that bool, so the fallback catch at line 88 is effectively unreachable and fallback failures are doubly swallowed. (2) Silently drops readings: at line 27-30 (the flagged line 29 region) a null currentUser causes a bare `return` — the reading is discarded with only a log; and on the offline path, if Hive is uninitialized/failing the reading is dropped while line 68 still logs "Queued reading for later sync". (3) Callers show false success: report_noise_screen.dart:224-243 awaits saveNoiseReading and then unconditionally shows a green "Noise report submitted successfully!" snackbar and pops the screen — its catch at line 245 can never fire from a save failure because saveNoiseReading cannot throw, so users see success even when the reading was dropped (e.g. logged out, or Firestore write failed and Hive was uninitialized). dashboard_screen.dart:492 fire-and-forgets the call from a 5-second timer with no error surface at all. One minor nuance that does not downgrade the finding: when the online write fails but the Hive fallback actually works, the reading is queued rather than lost — but the defect as stated (drops in real paths, total error swallowing, unconditional success UI) is real.

**Description:**

saveNoiseReading returns void and never lets an error escape: if _auth.currentUser is null it logs a warning and returns (lines 27-30) without saving anywhere (the offline fallback at lines 74-87 also requires user != null, so the reading is discarded entirely). The outer catch (lines 70-91) swallows every other failure. Consequently the catch block in report_noise_screen.dart _submitReport (line 245) is unreachable dead code, and the success SnackBar 'Noise report submitted successfully!' (lines 234-244) plus Navigator.pop always run, even when nothing was persisted. dashboard_screen.dart's 5-second save timer (line 492) has the same blind spot.

**Failure scenario:**

User's auth session becomes null (signed out on another flow, account deleted, or app resumed before auth restore) and they submit a manual noise report: saveNoiseReading returns normally having saved nothing — no Firestore doc, no Hive queue entry — and the UI shows 'Noise report submitted successfully!' then pops back. The reading is permanently lost with a false success message.

**Recommended fix:**

Make saveNoiseReading return a result (e.g. enum SaveResult { savedOnline, queuedOffline, failedNotLoggedIn, failed }) or rethrow after the offline fallback fails. Update report_noise_screen to branch on the result and show an error/queued message instead of unconditional success; treat failedNotLoggedIn as an explicit 'please log in' error.

---

#### [critic-03] POST_NOTIFICATIONS permission missing from AndroidManifest - high-noise alerts never appear on Android 13+

**Severity:** High | **Status:** refuted | **Category:** bug | **Effort:** S

**Location:** `android/app/src/main/AndroidManifest.xml:7`

**Verifier verdict (REFUTED):** POST_NOTIFICATIONS is indeed absent from the app manifest (android/app/src/main/AndroidManifest.xml:4-7), but it is supplied via Android manifest merging by the plugin: flutter_local_notifications 18.0.1 (pubspec.lock:597) declares `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` in its own AndroidManifest.xml (Pub\Cache\...\flutter_local_notifications-18.0.1\android\src\main\AndroidManifest.xml:4), so the merged APK manifest contains the permission. The runtime grant is also requested at startup via NotificationService.requestPermission() (lib/main.dart:48 -> lib/services/notification_service.dart:22-32, calling requestNotificationsPermission()). High-noise alerts (dashboard_screen.dart:429) therefore work on Android 13+ once the user accepts the prompt. The claimed defect does not exist.

**Description:**

The manifest declares only RECORD_AUDIO, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION and INTERNET (lines 4-7). flutter_local_notifications requires `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` for API 33+. Because the permission is not declared, the runtime request in lib/services/notification_service.dart line 28 (requestNotificationsPermission) is auto-denied without ever showing a dialog, and every _notifications.show() call is silently dropped. README line 29 advertises 'Local Notifications: High noise level alerts at 70dB threshold' as a key feature.

**Failure scenario:**

On any Android 13/14/15 device, the user records in a 90 dB environment; dashboard_screen.dart line 428-429 calls NotificationService.showHighNoiseAlert(), but no notification is ever posted and no permission prompt was ever shown - the flagship safety feature is dead on ~all modern devices.

**Recommended fix:**

Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to android/app/src/main/AndroidManifest.xml. Also move the permission request out of main() (audit 02 already flagged the pre-frame prompt) so the dialog appears with context after first frame.

---

#### [fb-3] History load permanently deadlocks when userId is null: _isLoading stuck true blocks all retries

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/history_screen.dart:87`

**Verifier verdict (CONFIRMED):** Real. history_screen.dart:81-83 sets _isLoading=true; line 87 `if (userId == null) return;` exits the try without resetting it. There is no finally, and the catch (line 107) doesn't run because nothing throws. _isLoading is only reset at lines 103/110, both unreachable on this path. The guard at line 79 (`if (_isLoading) return;`) and line 119 then block all retries — _loadInitialRecordings, _loadMoreRecordings, and RefreshIndicator's _onRefresh (line 384) — permanently, as long as the State stays alive. Identical flaw at line 127 in _loadMoreRecordings. Trigger requires currentUser to be null (e.g., during sign-out/auth race), but when it occurs the deadlock is as described.

**Description:**

_loadInitialRecordings sets _isLoading = true (lines 81-83), then checks userId and bails with a bare 'return' (lines 86-87) without resetting _isLoading. The re-entry guard 'if (_isLoading) return;' at line 79 then blocks every future call — including pull-to-refresh (_onRefresh → _checkConnectivityAndLoad → _loadInitialRecordings) and the offline-UI Retry button. _loadMoreRecordings has the identical bug at lines 126-127. The build method shows an endless bottom spinner because _recordings is empty while _isLoading is true.

**Failure scenario:**

App cold-starts and MainAppShell's IndexedStack constructs HistoryScreen (tab 3) before FirebaseAuth finishes restoring the session; initState fires _checkConnectivityAndLoad, userId is momentarily null, and the method returns with _isLoading stuck true. When auth restores a moment later, the user opens History: the count never loads, and pull-to-refresh is silently ignored forever until the widget is disposed.

**Recommended fix:**

Before returning on null userId, reset state: if (userId == null) { if (mounted) setState(() => _isLoading = false); return; } in both _loadInitialRecordings and _loadMoreRecordings, or move the userId check above the setState(_isLoading = true).

---

#### [analytics-2] Weekly/Monthly buckets use rolling 24h windows but x-axis labels claim calendar days — readings attributed to the wrong weekday

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:210`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. At lib/screens/analytics_screen.dart:210, Weekly/Monthly bucketing uses `now.difference(readingTime).inDays`, which truncates whole 24-hour periods anchored to the current wall-clock time — i.e., rolling 24h windows, not calendar days. There is no midnight normalization anywhere: `_getPeriodStartDate()` (lines 60-63) is also rolling (`now.subtract(Duration(days: 7/30))`). Meanwhile the x-axis labels (lines 244-256) present calendar semantics: Weekly buckets are labeled with weekday abbreviations via `now.subtract(Duration(days: daysAgo)).weekday`, and Monthly buckets with `DateFormat('MMM d')` dates. Concrete failure: at Tuesday 10:00, a reading from Monday 23:00 is 11h old, so inDays=0, placing it in the bucket labeled "Tue" even though it occurred Monday. More generally every bucket spans parts of two calendar days (e.g., Mon 10:00 → Tue 10:00) while its label names one day, so any reading taken after the current time-of-day on a prior day is attributed to the wrong weekday/date. Nothing in the query window, aggregation, or chart configuration mitigates this. Location, mechanism, and consequence in the finding are all accurate.

**Description:**

In _buildTimeAggregatedSpots, daysAgo = now.difference(readingTime).inDays (line 210) floors ELAPSED time in 24h units, so bucket boundaries are 'now minus N*24h', not midnights. But _getXAxisWidget labels each bucket with a calendar weekday: dayAbbr[now.subtract(Duration(days: 6 - bucketIdx)).weekday - 1] (lines 246-249) and Monthly with DateFormat('MMM d') (lines 253-256). Any reading whose elapsed time is under 24h but which was recorded before the last midnight lands in the 'today' bucket, and generally every bucket mixes two calendar days.

**Failure scenario:**

It is Saturday 00:30. A reading recorded Friday 23:45 (45 min ago, daysAgo=0) AND a reading recorded Friday 01:00 (23.5h ago, daysAgo=0) both land in bucket 6, which is labeled 'Sat'. Friday's bucket ('Fri') meanwhile contains data from Thursday afternoon onward. The weekly chart systematically shows readings under the wrong weekday name.

**Recommended fix:**

Bucket by calendar-day difference instead of elapsed time: final nowDay = DateTime(now.year, now.month, now.day); final readingDay = DateTime(readingTime.year, readingTime.month, readingTime.day); final daysAgo = nowDay.difference(readingDay).inDays;. Also widen the query start to midnight of the oldest bucket (e.g. nowDay minus 6 days for Weekly) so the oldest calendar day is complete rather than truncated at now-7*24h.

---

#### [fb-6] Analytics 'Duration' stat is off by 60x: divides reading count by 12 but readings are saved every 5 seconds

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:163`

**Verifier verdict (CONFIRMED):** analytics_screen.dart:163 computes _totalHours = stats['count'] / 12 and displays it as hours ('Duration', 'h' at line 373). stats['count'] from firebase_service.dart calculateStatsByPeriod (lines 283-317) is a raw count of noise_readings docs in the period. dashboard_screen.dart:487 saves one reading every 5 seconds via Timer.periodic(Duration(seconds: 5)) during recording, i.e., 720 readings/hour. Correct conversion is count/720; count/12 yields minutes labeled as hours — exactly 60x too high, as the finding states. (Manual one-off reports from report_noise_screen.dart add slight approximation but do not change the 60x error for the continuous-monitoring data that dominates the count.)

**Description:**

_loadStatistics computes _totalHours = (stats['count'] ?? 0) / 12 (line 163), which assumes 12 readings per hour (one every 5 minutes). But dashboard_screen.dart's save timer writes a reading every 5 seconds (Timer.periodic(const Duration(seconds: 5)) at line 487), i.e. 720 readings per hour. The 'Duration' stat card therefore overstates recording time by a factor of 60.

**Failure scenario:**

User records for 1 hour on the Dashboard (≈720 readings saved). Analytics 'Duration' card displays '60 h' instead of '1 h'.

**Recommended fix:**

Change the divisor to match the actual save cadence: _totalHours = (stats['count'] ?? 0) / 720, or better, derive duration from the min/max timestamps of the period's readings so it stays correct if the save interval ever changes.

---

#### [dash-2] Double-start race: _isRecording set only after awaits, leaking a noise subscription and a duplicate save timer

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:364`

**Verifier verdict (CONFIRMED):** CONFIRMED. dashboard_screen.dart: guard `if (_isRecording) return` (line 364) but `_isRecording = true` set only at line 483, after `await Future.delayed(200ms)` (374) and `await _audioRecorder!.startRecorder(...)` (472). The mic button (line 837) calls `_startRecording` whenever `_isRecording` is false, so a double-tap during the await window re-enters past the guard. Second entry overwrites `_noiseSubscription` (381) — the first is never cancelled since `_stopRecording` (545) cancels only the current field reference — and both entries create `Timer.periodic` save timers (487), with `_saveTimer` keeping only the second; the leaked first timer's `!_isRecording` guard (489) passes and it duplicates Firebase writes every 5s. No re-entrancy flag or button disable mitigates this.

**Description:**

The double-start guard at line 364 checks `_isRecording`, but `_isRecording` is only set true at line 482-484, AFTER the async gap of `await _audioRecorder!.startRecorder(...)` (line 472). A second tap during that await passes the guard, creates a second NoiseMeter subscription (line 381, overwriting `_noiseSubscription` so the first is never cancelled) and a second `_saveTimer` (line 487, overwriting the first Timer reference). The leaked timer is never cancelled — its callback guard `if (!_isRecording || !mounted) return;` (line 489) returns but does not cancel — so while recording is active, BOTH timers fire, calling `saveNoiseReading` twice every 5 seconds, writing duplicate documents to Firestore for the life of the State. The second `startRecorder` call may also throw against the already-running recorder (swallowed at line 515).

**Failure scenario:**

User double-taps the record button (common on a laggy frame). From then on, every recording session writes each reading to Firestore twice, doubling the user's data on the community map and in analytics; one mic-level noise subscription also leaks and fires setState twice per reading.

**Recommended fix:**

Set a synchronous guard at the very top of _startRecording (e.g. `if (_isRecording || _isStarting) return; _isStarting = true;`), set `_isRecording = true` before the first await or use the _isStarting latch, and defensively `_noiseSubscription?.cancel(); _saveTimer?.cancel(); _classificationTimer?.cancel();` before creating new ones. In the timer callbacks, call `timer.cancel()` instead of plain return when `!_isRecording`.

---

#### [donate-4] 'Open in Browser' button does nothing except show a misleading 'Opening in browser...' snackbar

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/buy_me_coffee_widget.dart:106`

**Verifier verdict (CONFIRMED):** lib/widgets/buy_me_coffee_widget.dart:106-115 — the 'Open in Browser' IconButton's onPressed only calls AppLogger.info and shows a SnackBar('Opening in browser...'); there is no launchUrl/intent call. Line 107 comment even says "You may need to add url_launcher package", though url_launcher IS already a dependency in pubspec.yaml, so the fix was never wired up. The button is misleading exactly as described.

**Description:**

The app bar action at lines 104-117 logs the URL and shows a SnackBar saying 'Opening in browser...' but never launches anything - the comment at line 107 says 'You may need to add url_launcher package', yet url_launcher ^6.3.0 is already declared in pubspec.yaml (line 93) and is imported nowhere in lib/ (verified by grep). The button is a no-op with false success feedback.

**Failure scenario:**

The BMC page renders poorly in the webview (or the user prefers their browser with saved payment methods). User taps the open-in-browser icon, sees 'Opening in browser...', waits, and nothing ever opens. Repeated taps do nothing; the user cannot complete the donation the way they wanted.

**Recommended fix:**

Import url_launcher and call: await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication); show the snackbar only on failure (canLaunchUrl false).

---

#### [donate-6] LateInitializationError crash if Reload/Try Again is tapped before the webview controller is created

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:63`

**Verifier verdict (CONFIRMED):** lib/widgets/paypal_webview_widget.dart:25 declares `late final InAppWebViewController _controller;` with no guard flag. It is assigned only in onWebViewCreated (line 97). The AppBar Reload button (lines 60-69) is visible immediately from first build and calls `_controller.reload()` at line 63; the error-overlay "Try Again" button does the same at line 255. If tapped before the platform webview fires onWebViewCreated (a real window on slow devices/first frame), Dart throws LateInitializationError, crashing per the claim. No try/catch or null check exists anywhere in the file. Minor nuance: Try Again is less exposed since _hasError is set in onReceivedError, which normally implies the controller exists — but the always-visible Reload button alone makes the defect real as described. Also, `late final` means a webview recreation would throw on reassignment, compounding the fragility.

**Description:**

_controller is declared 'late final InAppWebViewController' (line 25) and assigned only in onWebViewCreated (line 97). The AppBar refresh button (lines 60-71) and the error state's 'Try Again' button (lines 253-261) call _controller.reload() unconditionally. On the first webview initialization in a process (which can take 1-2s on low-end devices) or if platform-view creation fails, tapping either button before onWebViewCreated fires throws LateInitializationError and crashes the screen. Additionally, 'late final' would throw if onWebViewCreated ever ran twice.

**Failure scenario:**

User with a slow device opens the donation screen, sees 'Loading PayPal...', impatiently taps the refresh icon in the app bar within the first second. LateInitializationError: field '_controller' has not been initialized - unhandled exception, red screen in debug / broken screen in release.

**Recommended fix:**

Change to 'InAppWebViewController? _controller;' and guard: onPressed: () { _controller?.reload(); ... } (or disable the refresh action until onWebViewCreated has run).

---

#### [donate-3] Any failed non-'paypal.com' subresource replaces a working checkout with a full-screen error - including PayPal's own CDN

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:134`

**Verifier verdict (CONFIRMED):** lib/widgets/paypal_webview_widget.dart:130-139 — onReceivedError sets _hasError=true whenever `!requestUrl.contains('paypal.com')`, without checking `request.isForMainFrame`. In flutter_inappwebview this callback fires for subresource failures too, so any failed third-party script/image/analytics request flips _hasError, and lines 222-278 render an opaque full-screen "Failed to Load PayPal" Container over the working WebView. The CDN claim is also literally true: PayPal's static assets are served from paypalobjects.com (the code itself acknowledges this domain at line 146 in shouldOverrideUrlLoading), and the string "paypalobjects.com" does NOT contain the substring "paypal.com", so a failed paypalobjects.com asset triggers the error overlay. Same for braintreegateway.com (line 147). The finding is accurate as described.

**Description:**

onReceivedError (lines 130-140) sets _hasError=true for any error whose URL does not contain 'paypal.com', without checking request.isForMainFrame. I verified in flutter_inappwebview_android 1.1.3 (InAppWebViewClient.java onReceivedError, line 272-295) that the callback is forwarded for ALL resources, subframes and subresources included. Critically, PayPal serves most static assets from paypalobjects.com, and the string 'paypalobjects.com' does NOT contain 'paypal.com', so even a single failed image/script from PayPal's own CDN trips the filter. The error Container (lines 222-278) then covers the entire, possibly still-functional, checkout page.

**Failure scenario:**

User is mid-payment on the PayPal page; one tracking pixel or a static asset from paypalobjects.com times out on a flaky mobile connection. The whole screen is replaced by 'Failed to Load PayPal' with a Try Again button, even though the checkout page underneath loaded fine; tapping Try Again reloads and can lose the entered payment state.

**Recommended fix:**

Only enter the error state for main-frame failures: if (request.isForMainFrame == true) { setState(...) }. Drop the substring domain filter entirely once isForMainFrame is checked.

---

#### [dash-4] Readings saved with hardcoded Colombo fallback coordinates when location is denied or unavailable

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:492`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. Evidence chain: (1) lib/screens/dashboard_screen.dart:62-63 initializes `_latitude = 6.9271; // Colombo default` and `_longitude = 79.8612;`. (2) These fields are only ever overwritten on GPS success (lines 241-242 inside _getCurrentLocation). Every failure path returns early leaving the Colombo defaults intact: permission denied/deniedForever (lines 195-208), location services disabled (lines 212-224), and timeout/exception (catch at lines 292-303) — each merely sets _locationName and shows a dialog, never blocking measurement. (3) _startRecording (line 361) has no location precondition; line 377 explicitly says "Location already fetched on screen start, no need to request again", so recording starts fine with denied location. (4) The save timer (lines 487-503) guards only on dB validity (`_currentDb > 0 && _currentDb.isFinite`) and passes `_latitude`/`_longitude` unconditionally to saveNoiseReading at lines 492-495 — line 492 is precisely the flagged call. (5) lib/services/firebase_service.dart saveNoiseReading (line 16) performs no coordinate validation on either the online path (_saveToFirebase) or the offline Hive queue path, so the fake coordinates persist to Firestore. (6) The map reader (lib/screens/map_view_screen.dart:176) reads `data['latitude']` from noise_readings and plots it with no filter for the sentinel coordinates, so denied-location readings genuinely appear as fake data pinned at Colombo (6.9271, 79.8612). Every 5 seconds of recording writes another such reading. Note the same fallback pattern also exists in report_noise_screen.dart:22-23 (same class of bug at a second write site), but that does not diminish the flagged instance.

**Description:**

`_latitude`/`_longitude` default to 6.9271/79.8612 (lines 62-63) and are only overwritten on a successful GPS fix (lines 240-243). Every location failure path (permission denied lines 195-208, services disabled 212-224, timeout/exception 292-303) leaves the defaults in place but does NOT prevent recording. The save timer (lines 491-501) has no location-validity guard — it checks only `_currentDb > 0 && _currentDb.isFinite` — so it writes readings geotagged at the hardcoded Colombo point with locationName 'Location permission denied'/'Location services disabled' every 5 seconds.

**Failure scenario:**

A user in Kandy with location permission denied records a 2-minute session: 24 readings are written to Firestore pinned at exactly (6.9271, 79.8612) in Colombo, polluting the community noise map and analytics for every other user with false hotspot data at that coordinate.

**Recommended fix:**

Add a `bool _hasLocationFix = false` set true only after a real Geolocator fix; in the save timer, skip the save (or save with null coordinates if the schema allows) when `!_hasLocationFix`, and surface a one-time SnackBar 'Readings not saved to map: location unavailable'. Alternatively block starting a recording until a fix exists, with an explanatory dialog.

---

#### [map-4] Location permission result ignored; denied/deniedForever fail silently and camera jumps to default location

**Severity:** High | **Status:** disputed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:288`

**Verifier verdict (PARTIAL):** Core defect is real: at map_view_screen.dart:288-291, `Geolocator.requestPermission()`'s return value is discarded and `LocationPermission.deniedForever` is never checked. If the user denies, `getCurrentPosition()` (line 307) throws, caught at 317-323 which only logs via AppLogger and clears the spinner — no SnackBar/dialog, so denial is indeed silent. But the "camera jumps to default location" part is wrong: `_mapController.move()` runs only on success (line 315); on failure the camera stays put. The Colombo default (line 49-52) is just the initialCenter (line 621) used when no saved position exists (initState 92-98 loads saved position), not a jump triggered by denial. So: silent-failure claim confirmed, camera-jump claim refuted.

**Description:**

_getCurrentLocation checks permission and calls Geolocator.requestPermission() but discards its return value (lines 288-291). If the user denies (or is deniedForever, where no dialog even appears), the code falls through to getCurrentPosition(), which throws PermissionDeniedException; the catch at lines 317-323 only logs it — no SnackBar, no openAppSettings path. Worse, the FAB handler (lines 1062-1064) unconditionally runs _mapController.move(_currentLocation, 13.0) after the await, so on failure it animates to the stale default (Colombo 6.9271,79.8612) as if it were the user's position.

**Failure scenario:**

User previously chose 'Don't allow' for location. They tap the my-location FAB: no dialog, no error message, and the map confidently flies to Colombo even though the user is in Galle — wrong location presented as 'my location'.

**Recommended fix:**

Consume the result: permission = await Geolocator.requestPermission(); if denied → show SnackBar and return; if deniedForever → SnackBar with an 'Open Settings' action calling Geolocator.openAppSettings(). Have _getCurrentLocation return bool success and only move the camera in the FAB handler when true.

---

#### [settings-4] 'High Noise Alerts' toggle and 'Alert Threshold' slider have no effect — alert logic is hardcoded

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:180`

**Verifier verdict (CONFIRMED):** Real. Settings write prefs `high_noise_alerts` (settings_screen_enhanced.dart:186) and `db_threshold` (:161), but no code ever reads them outside the settings screen itself. The alert trigger is hardcoded: dashboard_screen.dart:428 uses `if (_currentDb > 70 && !_hasShownHighNoiseAlert)` — a literal 70, not the saved threshold. NotificationService.showHighNoiseAlert (notification_service.dart:35-40) only checks `notifications_enabled`, never `high_noise_alerts`. So toggling High Noise Alerts off or changing the slider has zero effect on alert behavior; only the master Enable Notifications switch works.

**Description:**

The toggle saves 'high_noise_alerts' (line 186) and the slider saves 'db_threshold' 50-100 dB (line 161), but neither key is ever read. NotificationService.showHighNoiseAlert only checks 'notifications_enabled' (lib/services/notification_service.dart line 38), and the dashboard triggers alerts with hardcoded thresholds: `_currentDb > 70` (lib/screens/dashboard_screen.dart line 428) and reset at `< 65` (line 435).

**Failure scenario:**

User disables 'High Noise Alerts' but leaves master notifications on, then records in traffic at 75 dB — the high-noise notification fires anyway. Conversely a user who sets the threshold slider to 90 dB still gets alerts at 71 dB.

**Recommended fix:**

In showHighNoiseAlert also check prefs.getBool('high_noise_alerts') ?? true; in dashboard load prefs.getDouble('db_threshold') (default 70.0) when starting a recording session and compare _currentDb against it (reset hysteresis at threshold - 5).

---

#### [dash-5] Community Feed count query violates the project Firestore index rule (isGreaterThanOrEqualTo, no orderBy) and swallows the resulting error

**Severity:** High | **Status:** disputed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:911`

**Verifier verdict (PARTIAL):** Variant 1 CONFIRMED: dashboard_screen.dart:900-914 — _buildCommunityFeedCard() is called from build() (line 890) and constructs a fresh .snapshots() query inline as the StreamBuilder stream. The screen calls setState frequently during recording (16+ sites, e.g. lines 199/215/268 updating _dbHistory), so each rebuild hands StreamBuilder a new stream, forcing unsubscribe/resubscribe churn. Variant 2 OVERSTATED: the query (lines 909-913) does use isGreaterThanOrEqualTo with no orderBy, and the builder swallows errors (line 917 renders hasError as count 0), but the "project index rule" concerns the composite (userId ASC, timestamp DESC) index; this query filters only on timestamp, which is served by Firestore's automatic single-field index — no FAILED_PRECONDITION occurs, so there is no "resulting error" to swallow. The project's own audit (10_PERFORMANCE_RECOMMENDATIONS.md:99) confirms "no composite needed." Real defect: stream recreation + silent error handling; the runtime index failure claim is wrong.

**Description:**

The StreamBuilder query (lines 907-914) on `noise_readings` uses `.where('timestamp', isGreaterThanOrEqualTo: ...)` plus `.where('timestamp', isLessThan: ...)` with no `orderBy`. The project's documented constraint states the ONLY composite index is (userId ASC, timestamp DESC) and that period queries MUST use isGreaterThan + orderBy('timestamp', descending: true) — isGreaterThanOrEqualTo or a missing orderBy causes FAILED_PRECONDITION. When the stream errors, the builder ignores `snapshot.hasError` (lines 915-917: `snapshot.hasData ? docs.length : 0`), so the badge permanently and silently shows 0.

**Failure scenario:**

User opens the Dashboard: the community-feed query fails with FAILED_PRECONDITION per the project's index configuration, the error is swallowed, and the 'Community Feed' badge shows 0 reports every day even when dozens exist — a silently broken feature.

**Recommended fix:**

Rewrite to the sanctioned pattern: `.where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart.subtract(const Duration(milliseconds: 1)))).orderBy('timestamp', descending: true)` and filter the upper bound client-side (or restructure to match the (userId, timestamp) index). Also handle `snapshot.hasError` explicitly (show '--' or an error state) instead of defaulting to 0, and prefer the count() aggregate over streaming full documents just to count them.

---

#### [ml-2] Range fallbacks (0-15 Speech, 16-35 Body Sounds, 229-309 Domestic, ...) are dead code due to 'Unknown_Class_' vs 'YAMNet_Class_' prefix mismatch

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/yamnet_class_mapping.dart:1011`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. sound_classification_service.dart:116 is the sole producer of synthetic class names and uses the prefix 'Unknown_Class_$maxIndex' for the ~119 gap indices (indexToClassName has only 402 of 521 entries, so this path is genuinely exercised, e.g. index 355 is absent). getCategoryFromClassName (yamnet_class_mapping.dart:1011) only parses the index when the name starts with 'YAMNet_Class_'; 'Unknown_Class_N' fails that check, takes the else branch, finds no exact or partial classMapping match, and reaches _categorizeByKeywords(actualClassName, null) at line 1042 with classIndex=null. The range-fallback block at line 1052 requires both classIndex != null and className.startsWith('YAMNet_Class_') — conditions no string produced anywhere in the codebase can satisfy (project-wide grep shows 'YAMNet_Class_' appears only inside the mapping file's own checks and audit docs; no writer constructs it). Therefore all range buckets (0-15 Speech, 16-35 Body Sounds, 36-136 Nature, 229-309 Domestic, 310-373 Traffic, 374-387 Sports, 388-399 Construction/Industrial) are unreachable dead code, and gap-index sounds fall through to generic keyword matching on the meaningless string 'unknown_class_N' instead.

**Description:**

classifySound builds the placeholder name for unmapped indices as 'Unknown_Class_$maxIndex' (sound_classification_service.dart:116), but getCategoryFromClassName only parses the prefix 'YAMNet_Class_' (line 1011), and the range-based fallback additionally requires className.startsWith('YAMNet_Class_') with a non-null classIndex (line 1052). For an 'Unknown_Class_N' input the else branch (line 1023) keeps the raw string, exact match fails, the partial-match loop (lines 1034-1039) matches nothing, and _categorizeByKeywords is invoked with classIndex explicitly null (line 1042), so the documented range fallbacks 0-15 Speech, 16-35 Body Sounds, 36-136 Nature, 229-309 Domestic, 310-373 Traffic, 374-387 Sports, 388-393 Construction, 394-399 Industrial (lines 1053-1061) can never execute from the live code path. A grep confirms nothing in lib/ ever produces a 'YAMNet_Class_' string. All 119 gap indices (109-136, 348-379, 400-419, 431-469) therefore land on categoryOther (line 1452) instead of their range category.

**Failure scenario:**

The model outputs argmax index 355 (a gap index; 348-379 have no indexToClassName entries). Per the project's documented fallback rules index 355 should fall in a defined range bucket, but the app produces 'Unknown_Class_355', skips the range logic entirely, and stores category 'Other' with soundType 'Ambient' in Firestore.

**Recommended fix:**

In sound_classification_service.dart:116 change the placeholder to 'YAMNet_Class_$maxIndex' (one-line fix), and in getCategoryFromClassName pass the parsed classIndex through to _categorizeByKeywords at line 1042 for named-but-unmapped classes as well. Better: add a getCategoryFromIndex(int index) API so the int never round-trips through a string.

---

#### [map-3] Debounce guard compares raw input to lowercased query — search never fires for capitalized input

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:292`

**Verifier verdict (CONFIRMED):** Verified at lib/screens/search_list_screen.dart:287-296. onChanged sets `_searchQuery = value.toLowerCase()` (line 289), then the 500ms debounce fires only `if (value == _searchQuery)` (line 292) before calling `_searchWithNominatim(value)`. For any input containing an uppercase letter, `value` (raw) can never equal `_searchQuery` (lowercased), so the debounced search never executes — exactly as both variant wordings describe. The only mitigation is `onSubmitted` (line 297-299), which searches on explicit Enter, but that is not search-as-you-type, matching the finding's scope. Also, the results section (line 304) still renders for 3+ char queries, showing stale/empty `_nominatimResults`.

**Description:**

onChanged stores _searchQuery = value.toLowerCase() (line 289), then the 500ms delayed callback runs _searchWithNominatim only if (value == _searchQuery) (line 292). Any input containing an uppercase letter fails this comparison ('Colombo' != 'colombo'), so the Nominatim search silently never executes. Only all-lowercase typing or pressing Enter (onSubmitted, line 297-299) works.

**Failure scenario:**

User opens Search Cities and types 'Colombo' or 'Kandy'. The spinner never appears and no results are shown, appearing as if search is broken; typing 'colombo' magically works.

**Recommended fix:**

Compare case-insensitively: if (value.toLowerCase() == _searchQuery) — or better, replace the Future.delayed hack with a proper Timer-based debounce that is cancelled and restarted on every keystroke.

---

#### [settings-6] All four Measurement settings (dBA/dBC, Response Time, Recording Duration, Save Frequency) are silent no-ops

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** L

**Location:** `lib/screens/settings_screen_enhanced.dart:90`

**Verifier verdict (CONFIRMED):** All four prefs keys are written and read only inside settings_screen_enhanced.dart: 'use_dba' (line 92), 'use_fast_response' (line 101), 'recording_duration' (line 139), 'save_frequency' (line 150), loaded back at lines 46-47, 55-56. Project-wide grep finds no other consumer in lib/. The actual measurement pipeline ignores them: dashboard_screen.dart:487 hardcodes the save timer as Timer.periodic(const Duration(seconds: 5)); no code implements dBC weighting, response-time (fast/slow) handling, or a recording-duration cutoff anywhere. The settings persist and reload correctly in the UI, but they change no runtime behavior — silent no-ops as claimed.

**Description:**

Keys 'use_dba' (line 92), 'use_fast_response' (line 101), 'recording_duration' (line 139) and 'save_frequency' (line 150) are written but never read outside this screen's own _loadSettings — verified by project-wide grep. The dashboard recording pipeline uses noise_meter output with a fixed calibration offset and no frequency weighting selection, no fast/slow time constant, no auto-stop after the chosen duration, and no configurable save interval. The user is shown a Measurement section implying the app measures dBC when selected — it does not, so the displayed values are wrong relative to what the UI claims.

**Failure scenario:**

User selects 'dBC' and sets Recording Duration to 5 seconds. Recording behaves exactly as before: same weighting, and it runs until manually stopped rather than 5 seconds.

**Recommended fix:**

Wire each pref into DashboardScreen._startRecording (read prefs at session start: apply duration via a Timer that calls _stopRecording, throttle Firestore saves by save_frequency, and label/compute weighting accordingly), or delete the controls until the pipeline supports them.

---

#### [offline-2] Recordings that fail 3 sync attempts are stranded forever: attempts are never reset and there is no recovery path

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** M

**Location:** `lib/services/sync_service.dart:151`

**Verifier verdict (CONFIRMED):** Real. sync_service.dart:151 skips any recording with syncAttempts >= 3 with `continue`, and this same gate applies to manual sync (triggerManualSync:237 just calls syncOfflineRecordings). Grep for `syncAttempts` shows attempts are only ever incremented (sync_service.dart:171-176, offline_storage_service.dart:146-167, 258-282) — no code path resets them to 0 for an existing record. deleteRecording/clearAllRecordings (offline_storage_service.dart:285, 326) have zero callers in lib/. Stranded records stay counted in pendingCount (getPendingCount counts all !isSynced), so the sync indicator shows a pending count that can never drain, with no failure state, retry, or purge exposed to the user. Minor nuance: items are indirectly visible via the perpetual pending count, but there is no recovery path — the finding stands.

**Description:**

Line 151 skips any recording with `syncAttempts >= maxSyncAttempts` (3). Nothing anywhere resets `syncAttempts` (verified: only writers are updateSyncStatus, incrementSyncAttempts — both increment), nothing deletes or re-queues failed items (`clearSyncedRecordings` only removes `isSynced == true` entries), and no UI exposes them. Attempts are consumed by transient failures: flaky captive-portal wifi (see offline-11), server hiccups, or user not being logged in mid-flap. Because `getPendingCount` counts all `!isSynced` entries regardless of attempts, the badge shows a count that 'Sync Now' can never clear.

**Failure scenario:**

Device connects to hotel wifi with a captive portal three separate times; each transition triggers a sync whose uploads fail, incrementing attempts to 3. Later on real internet, the recording is skipped forever: it never reaches Firestore, the indicator permanently shows '1 recording pending upload', and the Sync Now button silently does nothing.

**Recommended fix:**

Reset syncAttempts (or use time-based exponential backoff instead of a hard lifetime cap) whenever connectivity is regained or the user taps Sync Now. Alternatively surface a dead-letter state in the dialog with a 'Retry failed' action that zeroes attempts, and exclude permanently-failed items from the 'pending' badge count or mark them distinctly.

---

#### [social-3] Deleting a recording never updates the on-screen list or the 'Showing X of Y' count

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/history_screen.dart:721`

**Verifier verdict (CONFIRMED):** CONFIRMED. The list is local paginated state, not a stream: _recordings is a List<DocumentSnapshot> filled by one-time paginated .get() queries (history_screen.dart:27, 93-105, 136-148). The delete handler (lines 719-731) calls FirebaseFirestore...doc(docId).delete() with no try/catch, then only pops the dialog and shows a "Recording deleted" snackbar — it never removes the doc from _recordings, calls no setState, doesn't decrement _totalCount, and doesn't call _loadInitialRecordings. So the deleted item stays visible and "Showing ${_recordings.length} of $_totalCount" (line 392) is stale until pull-to-refresh. If delete() throws, the unhandled await leaves the dialog open with no error feedback. All variant wordings are accurate.

**Description:**

The Delete action (lines 720-731) awaits Firestore delete and pops the dialog, but never removes the doc from `_recordings`, never decrements `_totalCount`, and never calls setState or reload. The 'Recording deleted' snackbar shows while the deleted row stays fully visible and the header count (line 392) stays stale until the user manually pull-to-refreshes.

**Failure scenario:**

User taps the trash icon on a recording, confirms Delete, sees 'Recording deleted' — but the row is still there and the count is unchanged. User assumes the delete failed and taps delete again (or loses trust in the app).

**Recommended fix:**

In the Delete handler, after the successful await: `setState(() { _recordings.removeWhere((d) => d.id == docId); _totalCount--; });` before showing the snackbar. Pass the parent state's setState correctly since the handler lives in the dialog builder.

---

#### [analytics-4] Manual 'Speech-Pollution' readings appear under the Ambient filter and vanish from the Pollution filter in the category breakdown

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:746`

**Verifier verdict (CONFIRMED):** Manual reports write soundClass='Speech-Pollution' with soundType='Pollution' (report_noise_screen.dart:44, 229-230). Analytics keys _soundTypeCounts by soundClass (analytics_screen.dart:139-140), so the key is 'Speech-Pollution'. The breakdown filter (analytics_screen.dart:746-752) uses substring matching: pollutionCategories = [Traffic, Construction, Industrial, Tuk-tuk, Transport, Alarm] — 'Speech-Pollution' contains none of these, so it is dropped under the Pollution filter; ambientCategories includes 'Speech' (line 732), and 'Speech-Pollution'.contains('Speech') is true, so it appears under the Ambient filter. Exactly as claimed.

**Description:**

The breakdown filter uses substring matching: category.contains(c) against hardcoded lists (lines 742-752). report_noise_screen.dart:44 writes soundClass='Speech-Pollution' with soundType='Pollution'. 'Speech-Pollution' contains none of the pollutionCategories entries (lines 721-728: Traffic, Construction, Industrial, Tuk-tuk, Transport, Alarm), so it is excluded from the Pollution view — but it DOES contain 'Speech', which is in ambientCategories (line 732), so it is included in the Ambient view. The pie chart, which uses the stored soundType field (lines 143-147), counts the same reading as Pollution — the two widgets directly contradict each other.

**Failure scenario:**

User manually reports a loudspeaker announcement as 'Speech-Pollution'. On Analytics, the pie chart counts it as Pollution, but tapping the 'Pollution' chip removes it from the Sound Categories list, and tapping 'Ambient' shows it — labeled as an ambient sound with wrong percentages in both views.

**Recommended fix:**

Stop substring-matching category names. Classify each breakdown entry via YAMNetClassMapping.getSoundType(category) (special-casing the two manual 'Speech-Pollution'/'Speech-Ambient' values by their suffix), or better, tally per-category counts split by the document's own soundType field during _loadStatistics so breakdown and pie share one source of truth.

---

#### [ml-4] Threshold logic has zero behavioral effect: below-threshold results are returned identically and persisted to Firestore

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:126`

**Verifier verdict (CONFIRMED):** The finding is accurate. In lib/services/sound_classification_service.dart, the below-threshold branch (lines 126-138) constructs and returns a ClassificationResult using the exact same mapping calls (YAMNetClassMapping.getCategoryFromClassName + getSoundType) and the exact same five fields as the above-threshold branch (lines 140-152). The only difference between the branches is the log statement (AppLogger.debug vs AppLogger.info). The threshold therefore changes nothing about the returned value.

Downstream, the sole call site of classifySound is lib/screens/dashboard_screen.dart:634. It stores every non-null result into _currentClassification (lines 639-642) with no confidence check, and a 5-second Timer (lines 487-503) passes _currentClassification?.category/soundType/confidence into FirebaseService.saveNoiseReading, which persists them to Firestore (lib/services/firebase_service.dart:16-55) with no confidence filtering anywhere. So below-threshold classifications are indeed persisted to Firestore identically to above-threshold ones.

Additionally, the ClassificationResult.meetsThreshold getter (sound_classification_service.dart:300) is defined but never referenced anywhere else in lib/ (grep confirms its only occurrence is its own definition), so no consumer distinguishes low-confidence results either. The confidenceThreshold constant's only other use is a startup log line in main.dart:119. The threshold logic has zero behavioral effect exactly as the finding describes.

**Description:**

The `if (confidence < confidenceThreshold)` branch (lines 126-138) constructs and returns a ClassificationResult with exactly the same fields (category, soundType, confidence, yamnetClass, yamnetClassIndex) as the above-threshold path (lines 146-152); the only difference is a debug log line. The caller (dashboard_screen.dart:639-647) accepts any non-null result, sets _currentClassification, and the 5-second save timer (dashboard_screen.dart:487-503) writes _currentClassification?.category / soundType / confidence to Firestore unconditionally — meetsThreshold is never consulted anywhere in lib/ (grep confirms zero call sites). The threshold is effectively decorative: a 1%-confidence argmax is displayed and stored the same as a 90% one.

**Failure scenario:**

In a quiet room the model's top score is 0.04 for a class the broken table labels 'Traffic'. classifySound returns a full result via the low-confidence branch, the dashboard displays 'Traffic', and every 5 seconds a noise_readings document is written with soundClass='Traffic', confidence=0.04 — polluting the map, history, and analytics with guesses.

**Recommended fix:**

Either return null from the low-confidence branch (dashboard already handles null by keeping the previous state), or keep returning the result but have the dashboard gate both display and the Firestore save on result.meetsThreshold, storing soundClass=null (or 'Other') when below 0.30.

---

#### [settings-5] 'Daily Reminders' toggle does nothing — no scheduling exists and showDailyReminder() is never called

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:189`

**Verifier verdict (CONFIRMED):** The 'Daily Reminders' toggle (lib/screens/settings_screen_enhanced.dart:189-197) only saves the 'daily_reminders' pref, which is read solely by the settings screen itself (line 50) — no other code consumes it. NotificationService.showDailyReminder (lib/services/notification_service.dart:63-85) has zero call sites anywhere in lib/. Grep for zonedSchedule/periodicallyShow across lib/ returns nothing, and the method itself only calls _notifications.show() (immediate, line 79), so no daily scheduling can ever occur. Finding is accurate as stated.

**Description:**

The toggle saves 'daily_reminders' (line 195); the key is never read anywhere. NotificationService.showDailyReminder (lib/services/notification_service.dart lines 63-85) is dead code with zero call sites, and even if called it uses show() (immediate) rather than zonedSchedule() — there is no scheduling machinery (no timezone init, no periodicallyShow) in the codebase at all.

**Failure scenario:**

User enables 'Daily Reminders' expecting a daily prompt to record. No reminder ever appears, on any day, under any conditions.

**Recommended fix:**

On toggle-on, call _notifications.zonedSchedule (or periodicallyShow with RepeatInterval.daily) with matchDateTimeComponents: DateTimeComponents.time and initialize flutter_timezone; on toggle-off, cancel the reminder notification id. Or remove the toggle.

---

#### [arch-2] Test suite is broken: 53 of 149 tests fail on a clean `flutter test` run

**Severity:** High | **Status:** confirmed | **Category:** testing | **Effort:** L

**Location:** `test/unit/sound_classification_test.dart:71`

**Verifier verdict (CONFIRMED):** Independently re-ran `flutter test`: output ends "01:35 +96 -53: Some tests failed." — 96 pass + 53 fail = 149 tests, exactly as claimed. Root causes verified in code: (1) test/unit/sound_classification_test.dart:71 expects confidenceThreshold == 0.6, but lib/services/sound_classification_service.dart:34 has `static const double confidenceThreshold = 0.15`; (2) test/unit/firebase_service_test.dart:10 constructs FirebaseService whose field initializer `FirebaseFirestore.instance` (lib/services/firebase_service.dart:9) throws without Firebase.initializeApp; (3) widget tests pump screens calling FirebaseAuth.instance (e.g. lib/screens/analytics_screen.dart:87); (4) test/widget_test.dart:14-29 is the stale template counter test run against the real MyApp and fails with exceptions. All variant wordings accurate.

**Description:**

Verified by execution: `flutter test` finishes '+96 -53: Some tests failed.' Root causes confirmed: (1) stale assertion `expect(SoundClassificationService.confidenceThreshold, equals(0.6))` at test/unit/sound_classification_test.dart:71 while the code constant is 0.15 (verified failure: 'Expected: <0.6> Actual: <0.15>'); (2) test/unit/firebase_service_test.dart:10 constructs FirebaseService, whose field initializer `FirebaseFirestore.instance` (lib/services/firebase_service.dart:9) throws [core/no-app] without Firebase.initializeApp — all its tests fail; (3) widget tests (e.g. test/widget/analytics_screen_test.dart:8-18) pump screens whose initState calls FirebaseAuth.instance, same no-app failure; (4) test/widget_test.dart:14-28 still runs the Flutter template counter test against MyApp, which renders an auth StreamBuilder, not a counter.

**Failure scenario:**

Developer makes any change and runs `flutter test` as a regression gate: the run is red regardless of whether the change is correct, so real regressions are indistinguishable from the 53 pre-existing failures and CI on this suite can never pass.

**Recommended fix:**

Fix the stale 0.6 assertion to match the intended threshold; delete test/widget_test.dart or rewrite it for the real MyApp; introduce fake_cloud_firestore + firebase_auth_mocks (or constructor injection of FirebaseFirestore/FirebaseAuth into FirebaseService and screens) so unit/widget tests run without a live Firebase app; then make the suite green a required CI gate.

---

#### [donate-5] Classification guide contradicts the actual YAMNet mapping for Market, Alarm, Body Sounds, Nature, Other, and Transport

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/models/category_guide_data.dart:144`

**Verifier verdict (CONFIRMED):** Each named category's guide contradicts yamnet_class_mapping.dart. Market (guide:137-144 "Crowd noise", "15+ classes mapped"): zero classes map to categoryMarket — 'Crowd'/'Hubbub' are commented out and mapped to Speech (mapping:562-563, 696-697); Market is reachable only via keyword fallback (1361-1366). Alarm (guide:185-189 "Sirens (emergency vehicles)"): 'Siren', 'Police car (siren)', 'Ambulance (siren)', 'Fire engine (siren)' all map to Traffic (748, 755-757); Alarm has only 6 entries, not "10+". Body Sounds (guide:200 "Laughing, crying"): 'Laughter' maps to Speech (557); crying/snoring unmapped. Nature (guide:154-155 "Wind and rustling leaves", "Rain and thunder"): Wind/Rain/Thunder map to Weather (857-865). Other (guide:274 "Finger snap, clapping"): both map to Body Sounds (575-576). Transport (guide:216-217 "Ships and boats", "Public transport"): no boat/ship classes exist in the mapping (only 'Foghorn' 753), and 'Bus' maps to Traffic (503). All six contradictions are real.

**Description:**

Verified against lib/services/yamnet_class_mapping.dart: (1) Market claims '15+ market and crowd YAMNet classes mapped' (line 144) but ZERO classMapping entries map to categoryMarket - 'Crowd' and 'Hubbub' map to Speech (mapping lines 562-563; the Market entries are commented out at 696-697); Market is only reachable via keyword fallback. (2) Alarm lists 'Sirens (emergency vehicles)' (guide line 185) but 'Siren', 'Emergency vehicle', 'Police car (siren)', 'Ambulance (siren)', 'Fire engine, fire truck (siren)' all map to Traffic (mapping lines 748, 754-757). (3) Body Sounds lists 'Laughing' (guide line 200) but 'Laughter'/'Chuckle'/'Giggle'/'Snicker' map to Speech (mapping 557-561). (4) Other lists 'Finger snap, clapping' (guide line 274) but 'Clapping' and 'Finger snapping' map to Body Sounds (mapping 575-576). (5) Nature lists 'Wind and rustling leaves' and 'Rain and thunder' (guide lines 154-156) but 'Wind', 'Rain', 'Thunder', 'Thunderstorm' map to Weather (mapping 857-865). (6) Transport lists 'Public transport' (guide line 217) but 'Bus' maps to Traffic (mapping 503). Several yamnetInfo counts are also inflated (e.g., Traffic '40+' vs ~26 actual entries, Speech '35+' vs ~23).

**Failure scenario:**

A user hears an ambulance siren, records it, and the app labels it 'Traffic'. They open the Sound Classification Guide, which says sirens belong to 'Alarm', and conclude the classifier is broken and file a bad report / lose trust. Same for laughter labeled Speech, clapping labeled Body Sounds, and rain labeled Weather.

**Recommended fix:**

Rewrite the examples and yamnetInfo strings in getAllCategories() to match classMapping ground truth: move sirens examples to Traffic, laughing to Speech, clapping/finger-snap to Body Sounds, rain/wind/thunder to Weather only; for Market either state it is keyword-derived or actually map crowd-related classes to Market; recount the 'N+ classes mapped' figures from classMapping.

---

#### [social-2] Hard cast `data['decibelLevel'] as num` crashes list rendering on any doc missing decibelLevel

**Severity:** High | **Status:** disputed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/history_screen.dart:451`

**Verifier verdict (PARTIAL):** The hard cast is real: history_screen.dart:451 `(data['decibelLevel'] as num).toDouble()` throws on null/missing field, and it's inconsistent with the same codebase's defensive handling — same file line 261 uses `?? 0.0`, analytics_screen.dart:190 uses `as num?`, and firebase_service.dart:300 even has a comment "Null-safe: skip docs with missing/null decibelLevel instead of crashing", showing the risk is acknowledged. However, overstated in two ways: (1) all in-app writers always include decibelLevel (firebase_service.dart:120, sync_service.dart:213), so a null requires legacy/externally written docs; (2) an itemBuilder exception yields Flutter's ErrorWidget for the failing item, not a hard crash of the whole screen. Defect exists but severity is exaggerated.

**Description:**

Line 451: `final db = (data['decibelLevel'] as num).toDouble();` throws a TypeError if the field is null/absent. The codebase itself acknowledges such docs exist: firebase_service.dart lines 300-304 were explicitly made null-safe with the comment 'skip docs with missing/null decibelLevel instead of crashing'. The CSV export in this same file also defends with `data['decibelLevel'] ?? 0.0` (line 261), but the list itemBuilder does not.

**Failure scenario:**

A legacy or malformed reading without decibelLevel is in the user's history. Scrolling to that item makes the itemBuilder throw: red error widget in debug, grey box in release, and the FadeInListItem row never renders — the history list appears broken from that point.

**Recommended fix:**

Use `final db = (data['decibelLevel'] as num?)?.toDouble() ?? 0.0;` (matching the defensive pattern already used at line 261) or skip rendering docs without a decibel level.

---

#### [ml-3] Confidence threshold is 0.15, violating the documented project threshold of 0.30

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:34`

**Verifier verdict (CONFIRMED):** All claims verified in code. (1) Threshold is 0.15: sound_classification_service.dart:34, with a comment "Lowered to 15%" (lines 28-33), while project memory/session history documents threshold 0.30. (2) Non-gating: the below-threshold branch (lines 126-138) builds and returns a ClassificationResult with the identical five fields as the passing path (lines 146-152) — it only changes a debug log. (3) Persisted as fact: dashboard_screen.dart:641 stores the result unconditionally, and lines 498-500 write soundClass/soundType/confidence to the reading without any confidence check; meetsThreshold (service line 300) is never referenced by any consumer (grep shows only its definition), and confidenceThreshold's only other use is a startup log (main.dart:119). Minor note: README/PRODUCTION_CHECKLIST mention CONFIDENCE_THRESHOLD=0.6, so "0.30" is the memory-documented spec, not the only documented value — but neither 0.30 nor 0.6 matches 0.15, and the gating claim holds regardless.

**Description:**

confidenceThreshold is declared as 0.15 (line 34) with a comment 'Lowered to 15%'. The project constraint (and session history: '4 new sound categories + threshold 0.30') fixes the classification threshold at 0.30. Everything derived from the constant is affected: the threshold check in classifySound (line 126), ClassificationResult.meetsThreshold (line 300), and the startup log in main.dart:119 which prints '15%' to the console as the active threshold.

**Failure scenario:**

A sound is classified with 0.22 confidence. Per the project spec (0.30) this is a low-confidence result, but the code treats it as passing (0.22 >= 0.15 is implied by the < 0.15 early branch not firing), logs it as '✅ Classified', and meetsThreshold returns true for any UI that checks it.

**Recommended fix:**

Change line 34 to `static const double confidenceThreshold = 0.30;` and update the stale doc comment (lines 28-33) that justifies 15%.

---

#### [boot-1] No error handling around Firebase init or any pre-runApp startup await — failure leaves a permanent blank screen

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/main.dart:38`

**Verifier verdict (CONFIRMED):** lib/main.dart:26-72 confirms the defect. Line 38 `await Firebase.initializeApp(...)` has no try/catch, and neither do the subsequent pre-runApp awaits: Firestore settings (41-44), NotificationService.initialize/requestPermission (47-48), SyncService().initialize() (51), SharedPreferences.getInstance() (55). runApp is only reached at line 71; any throw in those awaits propagates out of main(), leaving the engine attached with no widget tree — a permanent blank screen with no error UI. Only dotenv (30-36) and the TFLite/sound-classification steps (75-127) are wrapped in try/catch, so the "any pre-runApp startup await" wording is accurate for the Firebase/notification/sync/prefs chain. There is no runZonedGuarded, PlatformDispatcher.onError, or fallback error app anywhere in main.dart.

**Description:**

main() awaits Firebase.initializeApp (line 38), Firestore settings (41-44), NotificationService.initialize/requestPermission (47-48), and SyncService().initialize() (51) with no try/catch before runApp (line 71). Only dotenv.load (30-36) is guarded. If any of these throws (missing/invalid google-services config, no Google Play services, plugin channel error, Firestore settings failure), the exception escapes main(), runApp is never called, and the user is stuck on the native splash/blank screen with zero feedback. Contrast: _testModelLoading and _initializeSoundClassification ARE wrapped in try/catch, so the pattern exists but the most critical calls are unguarded.

**Failure scenario:**

Device without Google Play services (or a corrupted Firebase config after an OTA update) launches the app: Firebase.initializeApp throws, main() aborts before runApp, and the app shows a frozen blank/native-splash screen forever with no error message or retry.

**Recommended fix:**

Wrap Firebase.initializeApp and the subsequent service initializations in try/catch; on failure still call runApp with a minimal error screen ('Could not start — check connection' + Retry button that re-attempts init). Non-critical services (notifications, sync) should be individually guarded so their failure never blocks startup.

---

#### [dash-1] AVG decibel uses arithmetic mean instead of energy-based (logarithmic) averaging

**Severity:** High | **Status:** confirmed | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:424`

**Verifier verdict (CONFIRMED):** The defect is real, exactly at the cited location. In C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/lib/screens/dashboard_screen.dart line 424, the AVG stat is computed as `_avgDb = _dbHistory.reduce((a, b) => a + b) / _dbHistory.length;` — a plain arithmetic mean over `_dbHistory`, which holds calibrated decibel values (line 394: `reading.meanDecibel - calibrationOffset`, clamped at line 403). Decibels are logarithmic, so the acoustically correct average (Leq) is 10*log10(mean(10^(dB/10))). By Jensen's inequality the arithmetic mean of dB values is always <= the energy-based average, so brief loud events (e.g., a 100 dB spike among 60 dB readings) are heavily understated — exactly as the finding claims. A repo-wide grep confirms no log10/pow(10)/energy averaging exists anywhere in lib/; heatmap_service.dart line 116 makes the same arithmetic-mean error, so there is no correct implementation elsewhere that this line could be delegating to. The value is displayed as the 'AVG' stat card (line 739). One severity nuance that does not change the verdict: `_avgDb` is display-only — the periodic Firebase save (lines 491-502) persists instantaneous `_currentDb` samples, not `_avgDb` — so stored data is not corrupted by this line; the understatement affects the dashboard AVG readout (and the analytics/heatmap averages, which repeat the same mistake independently).

**Description:**

Line 424 computes `_avgDb = _dbHistory.reduce((a, b) => a + b) / _dbHistory.length` — a plain arithmetic mean of dB values. Decibels are logarithmic; the correct equivalent-level average is 10*log10(mean(10^(dB/10))). Arithmetic averaging systematically understates the true equivalent noise level whenever readings vary (which they always do), e.g. history [50, 90] shows AVG 70 when the energy-correct value is ~87 dB. This wrong AVG is displayed in the stat card (line 739).

**Failure scenario:**

User records in an environment alternating between 50 dB quiet and 90 dB traffic bursts. The AVG card shows ~70 dB, dramatically underreporting the acoustically correct equivalent level of ~87 dB — the user concludes the environment is 'moderate' when it is 'dangerous'.

**Recommended fix:**

Replace with energy averaging: `_avgDb = 10 * math.log(_dbHistory.map((db) => math.pow(10, db / 10)).reduce((a, b) => a + b) / _dbHistory.length) / math.ln10;` (import dart:math). Compute it outside the per-reading loop or incrementally to avoid O(n) per reading.

---

### Medium

#### [flow7-02] _paymentComplete set outside setState so the 'Payment Complete!' overlay never renders

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:123`

**Description:**

In onLoadStop, setState is called at lines 108-110 (before the URL checks), then '_paymentComplete = true;' at line 123 is a bare assignment with no setState. The overlay guarded by 'if (_paymentComplete)' at line 195 will not appear until some unrelated rebuild occurs. showDialog (via _onPaymentSuccess) pushes an overlay route and does not rebuild this State.

**Failure scenario:**

Even after flow7-01 is fixed and a success redirect is detected, the green 'Payment Complete!' overlay (lines 195-219) stays invisible; the user only sees the delayed dialog, and after closing it, the raw PayPal page again.

**Recommended fix:**

Wrap the success/cancel handling in setState: setState(() { _paymentComplete = true; }); before calling _onPaymentSuccess().

---

#### [map-12] Timestamp read ignores createdAt fallback — violates the project's dual-timestamp convention

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/models/heatmap_point.dart:35`

**Description:**

fromFirestore reads only (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now() (line 35). Project convention requires readers to handle both timestamp (serverTimestamp) and createdAt (client DateTime), because serverTimestamp is null on latency-compensated/pending-write docs. Falling back to DateTime.now() instead of createdAt gives such docs weight 1.0 (line 36 → _calculateWeight) and wrong positions in filterByTimeRange (services/heatmap_service.dart:43-46).

**Failure scenario:**

A reading synced from the offline queue surfaces in a snapshot before server ack: its timestamp is null, so the point is stamped 'now', gets maximum recency weight, and would pass a '1 Hour' time filter even if recorded days ago.

**Recommended fix:**

Fall back to createdAt before now(): final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? (data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : data['createdAt'] as DateTime?) ?? DateTime.now();

---

#### [arch-11] Half the unit-test files never import application code — they test reimplemented local helpers and tautologies

**Severity:** Medium | **Status:** unverified | **Category:** testing | **Effort:** M

**Location:** `test/unit/decibel_calculation_test.dart:6`

**Description:**

Verified with grep (files lacking 'package:noise_pollution_mapper'): test/unit/audio_processing_test.dart, data_validation_test.dart, datetime_formatting_test.dart, decibel_calculation_test.dart, location_utils_test.dart. They assert against helper functions redefined inside the test file (`_categorizeNoiseLevel`, `_isValidEmail`, `_isValidLatitude`) or literal tautologies (audio_processing_test.dart:8-10 `const expectedSize = 15600; expect(expectedSize, equals(15600))`; lines 24-26 `const channels = 1; expect(channels, equals(1))`). These 5 of 10 unit-test files exercise zero production code.

**Failure scenario:**

Someone changes the production dB banding in map_view_screen._getNoiseColor from <50/<70 to <55/<75: decibel_calculation_test.dart still passes because it tests its own private copy of the thresholds, so the suite green-lights a user-visible behavior change it claims to cover.

**Recommended fix:**

Delete the tautology tests and repoint the rest at real code: once arch-17's shared NoiseLevelHelper and arch-7's NoiseReading model exist, test those; move email/coordinate validation into lib/utils/ functions used by the screens and import them in the tests.

---

#### [ml-8] Analytics ambientCategories list omits 'Other', so 'Other' readings vanish from both Pollution and Ambient filters

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:729`

**Description:**

The hardcoded ambientCategories list (analytics_screen.dart:729-740: Music, Nature, Speech, Religious, Market, Domestic, Body Sounds, Sports, Weather, Office) is missing 'Other', while YAMNetClassMapping.getSoundType classifies categoryOther as Ambient (yamnet_class_mapping.dart:993-999). pollutionCategories (lines 721-728) correctly matches the six Pollution categories. In the filter loop (lines 742-753) a reading whose category is 'Other' matches neither list, so it appears under 'All' but disappears when the user selects 'Ambient'. This is amplified by ml-1/ml-2, which funnel all 119 unmapped indices into 'Other' — potentially a large share of all readings. The lists also duplicate getSoundType's logic by hand with fragile substring matching (category.contains(c)), which is exactly the drift that produced this bug.

**Failure scenario:**

A user with many readings classified 'Other' opens Analytics and taps the 'Ambient' filter: the Sound Category Breakdown silently drops all 'Other' entries, so counts and percentages don't add up against the 'All' view, and if most readings are 'Other' the panel shows 'No ambient sounds in <period>' despite data existing.

**Recommended fix:**

Replace both hardcoded lists with the single source of truth: filter using `YAMNetClassMapping.getSoundType(category) == YAMNetClassMapping.typePollution` (or typeAmbient), using exact equality rather than contains(). Minimal fix: add 'Other' to ambientCategories.

---

#### [dash-13] Gauge scale tops out at 100 dB while readings are clamped to 120 dB: needle pegs, digits keep climbing

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:747`

**Description:**

Dashboard passes `maxDb: 100` to DecibelMeterGauge (line 747), but `_currentDb` is clamped to 0-120 (line 403) and readings up to 130 raw pass the filter (line 398). In lib/widgets/decibel_meter_gauge.dart both the arc progress (line 108) and needle angle (line 203) compute `(currentDb / maxDb).clamp(0.0, 1.0)`, so for 100-120 dB the needle and arc are pegged at the 100 mark while the digital readout (line 37) shows 101-120 — needle and number contradict each other exactly in the danger zone. Additionally, the tick labels in _drawTickMarksAndNumbers are hardcoded 0-100 (line 136 `for (int db = 0; db <= 100; db += 25)`) and ignore the widget's `maxDb` parameter, so simply passing maxDb: 120 would silently mislabel the dial. At the other edge (0 dB) progress is 0 and only the background ring renders, which is correct.

**Failure scenario:**

A concert measures 112 dB: the digital display reads 112 while the needle points at the '100' tick — the user cannot tell whether the meter is maxed out or broken, at precisely the levels where accuracy matters most.

**Recommended fix:**

Pass `maxDb: 120` from the dashboard and derive the ticks from maxDb in _drawTickMarksAndNumbers (e.g. `for (int db = 0; db <= maxDb; db += (maxDb ~/ 4))`), keeping gauge scale and data clamp (line 403) driven by one shared constant.

---

#### [boot-4] Login has no generic catch and its error mapping misses the codes modern Firebase Auth actually returns

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/login_screen.dart:61`

**Description:**

_handleLogin (lines 48-88) only has `on FirebaseAuthException`. Any other exception (PlatformException from the plugin, TypeError, etc.) propagates unhandled — the finally block resets the spinner but the user gets zero feedback and the error surfaces only as an unhandled async exception. Additionally, the mapping (lines 65-71) only handles 'user-not-found', 'wrong-password', 'invalid-email'. Firebase projects created/updated since Sept 2023 have email-enumeration protection on by default and return 'invalid-credential' / 'INVALID_LOGIN_CREDENTIALS' instead of the first two, so the most common failure (wrong password) shows the unhelpful generic 'Login failed'. 'network-request-failed', 'too-many-requests', and 'user-disabled' are also unmapped. Contrast: registration_screen.dart falls back to e.message (line 100) and has a generic catch (111-119); login has neither.

**Failure scenario:**

User types the wrong password: FirebaseAuthException(code: 'invalid-credential') is thrown, none of the three mapped codes match, and the snackbar reads just 'Login failed' with no hint that the password is wrong. With airplane mode on, the 'network-request-failed' code likewise yields the same generic message.

**Recommended fix:**

Add cases for 'invalid-credential'/'INVALID_LOGIN_CREDENTIALS' ('Incorrect email or password'), 'network-request-failed', 'too-many-requests', and 'user-disabled'; fall back to e.message like the registration screen does; and add a trailing `catch (e)` that shows a generic error snackbar so non-FirebaseAuthException failures are surfaced.

---

#### [settings-12] Error handlers in _deleteAccount/_clearHistory pop the Settings route when the loading dialog was never shown

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:944`

**Description:**

All catch blocks (lines 926-928, 944-948 in _deleteAccount; 1049-1051, 1062-1065 in _clearHistory) call Navigator.pop(context) assuming the loading dialog is open. But the `user == null` guard throws at line 868 / line 1002 BEFORE showDialog runs, so the pop removes whatever route hosts the Settings screen instead. When Settings is the tab inside MainAppShell (the home route), popping the root route triggers a navigator assertion / black screen.

**Failure scenario:**

User's session is invalidated in the background (token revoked, account disabled). They open Settings > Delete Account > Delete: currentUser is null, the exception is caught, Navigator.pop(context) fires with no dialog open, and the MainAppShell route is popped — black screen.

**Recommended fix:**

Track dialog state explicitly (bool dialogShown = false; set true after showDialog) and only pop when dialogShown; or move the null check before showDialog and return early with a snackbar instead of throwing.

---

#### [dash-8] setState and timer creation after dispose in _startRecording (no mounted check after await)

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:482`

**Description:**

After `await _audioRecorder!.startRecorder(...)` (line 472), _startRecording calls `setState` at line 482 and creates `_saveTimer`/`_classificationTimer` at lines 487 and 507 with no mounted/_isDisposed check. If the State is disposed during the await (logout uses pushAndRemoveUntil at lines 694-699, which disposes the whole shell), setState throws 'setState() called after dispose()', and worse, the two periodic timers are created AFTER dispose already ran _stopRecording — nothing ever cancels them, so they fire every 5 seconds for the remaining app lifetime (their `!mounted` guard returns without cancelling, line 489/511).

**Failure scenario:**

User taps record and immediately taps Logout while startRecorder is awaiting: a FlutterError is thrown from line 482, and two orphaned periodic timers keep firing every 5 seconds until the app is killed.

**Recommended fix:**

After the startRecorder await add `if (!mounted || _isDisposed) { await _audioRecorder?.stopRecorder(); _noiseSubscription?.cancel(); await _audioStreamController?.close(); return; }` before line 482. Also make the timer callbacks self-cancel: `if (!_isRecording || !mounted) { timer.cancel(); return; }`.

---

#### [map-5] _showNativeLocationDialog shows no dialog — geolocator throws instead when location services are off

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:330`

**Description:**

The method claims to show 'the native Android location settings dialog' but just calls Geolocator.getCurrentPosition(locationSettings: ...) (lines 337-342). geolocator does not surface a resolution dialog when location services are disabled — it throws LocationServiceDisabledException immediately, which is swallowed by the catch at lines 350-353. The user receives zero feedback and location is never enabled.

**Failure scenario:**

GPS/location services are turned off system-wide. User taps the my-location FAB: _getCurrentLocation detects serviceEnabled == false, calls _showNativeLocationDialog, which throws instantly and logs a debug line. Nothing visible happens; the button appears dead.

**Recommended fix:**

Replace with Geolocator.openLocationSettings() preceded by a SnackBar/dialog explaining that location services are off; on return, re-check isLocationServiceEnabled and retry _getCurrentLocation.

---

#### [fb-12] Unsafe casts in marker/heatmap building: one malformed doc silently blanks the entire map

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:176`

**Description:**

_buildMarkersFromSnapshot uses hard casts: data['latitude'] as double, data['longitude'] as double (lines 176-177), (data['decibelLevel'] as num).toDouble() (line 178), and data['confidence'] as double? (line 190). A doc where any of these is null — or where a numeric value deserializes as int (e.g. confidence: 1.0 written from a web build is stored as integer 1, and manual reports always write exactly 1.0 per report_noise_screen.dart line 231) — throws, and the try/catch in _loadNoiseMarkers (lines 148-155) swallows it, leaving _cachedMarkers empty. HeatmapPoint.fromFirestore has the same hard casts (heatmap_point.dart lines 26-28) and heatmap_service.convertToHeatmapPoints's catch returns [] (heatmap_service.dart lines 23-26), so one bad doc erases the whole heatmap too.

**Failure scenario:**

A single reading document is created with a missing decibelLevel or an integer-typed confidence/latitude (console edit, schema drift, or a web client): every user's map thereafter shows zero markers and an empty heatmap with only a log line, because the per-doc cast exception aborts the entire loop inside a swallowing catch.

**Recommended fix:**

Use tolerant per-doc parsing and skip bad docs: final lat = (data['latitude'] as num?)?.toDouble(); if (lat == null) continue; — same for longitude/decibelLevel, and (data['confidence'] as num?)?.toDouble(). Move the try/catch inside the per-doc loop (or make fromFirestore return null on bad data) so one bad document costs one marker, not all of them.

---

#### [social-18] SharedAppState.locationDialogShown is set true but almost never reset — location dialog shows at most once per session on error paths

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/report_noise_screen.dart:183`

**Description:**

_showNativeLocationDialog sets the app-global flag at line 183. It is only reset when the screen detects the exact transition from the literal string 'Location services disabled' (line 86-91) or when the user manually taps the pill while services are off (line 518). If the user declines the native dialog (catch at lines 201-204) or the dialog succeeds, the flag stays true, so every future error path in _getCurrentLocation is suppressed by the guard at line 169 (`!SharedAppState.locationDialogShown`) — on this screen and on every other screen sharing the flag — for the rest of the app session. Note also that nothing in this screen ever sets a locationName containing 'denied', making the 'denied' check at line 92 dead.

**Failure scenario:**

User declines the location dialog once on the Report screen, later re-enables interest and GPS fails again (e.g. times out indoors): no dialog appears anywhere in the app, _locationName silently stays 'Fetching location...', and the user can submit a mislocated report (see social-4).

**Recommended fix:**

Reset the flag in _showNativeLocationDialog's finally (or on dispose), or replace the boolean with a timestamped debounce (e.g. suppress re-show for 60s) instead of a one-way latch.

---

#### [dash-11] In-flight classification resurrects _currentClassification after stop; stale label attached to next session's saves

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:639`

**Description:**

_stopRecording clears `_currentClassification` (line 581), but a classification already awaiting `classifySound` (line 634) completes afterwards and the result guard at line 639 checks only `result != null && mounted && !_isDisposed` — not `_isRecording` — so it writes the stale result back (lines 640-642). _startRecording never resets `_currentClassification`, so when the user starts the next session, the save timer (lines 497-500) attaches the previous session's soundClass/soundType/confidence to the new readings until the first new classification lands (up to 5s, line 507).

**Failure scenario:**

User stops recording just as a 'Traffic' classification is being computed, walks indoors, starts a new session in a quiet office: the first reading(s) are saved to Firestore labeled 'Traffic' with the old confidence, corrupting category analytics.

**Recommended fix:**

Add `_isRecording` to the guard at line 639 (`if (result != null && mounted && !_isDisposed && _isRecording)`), and defensively set `_currentClassification = null` in _startRecording before starting timers.

---

#### [offline-12] No Hive corruption recovery: a corrupt box file permanently disables the offline feature and the indicator lies about it

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/services/offline_storage_service.dart:35`

**Description:**

If `Hive.openBox` throws (corrupt/truncated box file after a crash mid-write), `initialize()` returns false (lines 44-47), SyncService.initialize returns false (sync_service.dart:41-45), and main.dart:51 ignores the return value. From then on every storage method short-circuits on `!_isInitialized` (returning 0/[]/false), `_isOnline` stays false in SyncService, and the status indicator permanently renders the calm 'Offline' state with 0 pending — the user gets no signal that offline recording/sync is dead, and firebase_service's offline saves (which call `saveOfflineRecording` on the same broken singleton) silently drop every reading (returns false at line 53-55, ignored by _saveOffline at firebase_service.dart:161).

**Failure scenario:**

The app is killed mid-write leaving recordings_queue.hive truncated. On next launch openBox throws; thereafter the user records in the subway and every reading is silently discarded — the UI shows 'Offline' as if queuing were working.

**Recommended fix:**

Catch the openBox failure, call `Hive.deleteBoxFromDisk(_recordingsBoxName)` and retry opening (accepting loss of the corrupt queue as the lesser evil), log/report the event, and expose an `isHealthy` flag that the indicator renders as an explicit error state instead of 'Offline'.

---

#### [offline-11] Connectivity detection equates any network interface (including bluetooth/VPN) with internet reachability

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/services/sync_service.dart:104`

**Description:**

`_isConnectedToInternet` (lines 99-109) returns true for any `ConnectivityResult != none` — connectivity_plus 6.x reports interface state only, so `bluetooth`, `vpn`, or wifi behind a captive portal all count as 'online'. Consequences within this service: `_isOnline` is true with no real internet, sync attempts run and either hang (offline-8) or fail and burn the 3-attempt lifetime budget (offline-2), and the indicator shows the green/orange 'online' states while uploads cannot possibly succeed. The identical copy-pasted check exists in firebase_service.dart:95-104, where it routes writes down the 'online' path.

**Failure scenario:**

Phone auto-joins a coffee-shop captive portal. Indicator shows 'online, 4 pending'; auto-sync fires, each upload fails or hangs, syncAttempts increments toward the permanent-skip cap — all while the user believes syncing is working.

**Recommended fix:**

Treat connectivity_plus as a hint only: verify reachability with a lightweight probe (e.g. a HEAD request or `InternetAddress.lookup`) before flipping `_isOnline`, or simply let upload success/failure be the source of truth and stop pre-gating on `_isOnline` (attempt sync on every connectivity event, backing off on failure without a permanent cap).

---

#### [analytics-6] Average dB uses arithmetic mean instead of energy (Leq) averaging — understates true noise exposure

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/firebase_service.dart:311`

**Description:**

calculateStatsByPeriod computes 'avg' as readings.reduce((a,b)=>a+b)/readings.length (firebase_service.dart:311), and the trend chart buckets do the same per bucket (analytics_screen.dart:221). Decibels are logarithmic; the acoustically correct average of sound levels is the energy mean: 10*log10(mean(10^(dB/10))). Arithmetic averaging of dB substantially underestimates the equivalent continuous level whenever readings vary, which is the core metric of a noise-pollution app.

**Failure scenario:**

A period contains two readings: 50 dB (quiet room) and 90 dB (traffic). The 'Average' stat card shows 70 dB; the true equivalent level is ≈87 dB. A location that is dangerously loud half the time is reported as moderate, and trend-chart bucket averages flatten short loud spikes the same way.

**Recommended fix:**

Compute avg (and bucket averages in _buildTimeAggregatedSpots) as 10 * log10(readings.map((d) => pow(10, d/10)).reduce(sum) / readings.length). If arithmetic mean is intentionally kept for simplicity, label the card 'Mean dB' and document the choice; min/max are unaffected.

---

#### [dash-7] MIN stat card renders the literal text 'Infinity' until the first reading arrives

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:1040`

**Description:**

`_minDb` is initialized to `double.infinity` (line 56) and `_buildStatCard` renders `value.toStringAsFixed(0)` (line 1040), which for double.infinity produces the string 'Infinity'. The stat row builds immediately (line 738), so every fresh open of the Dashboard shows MIN = 'Infinity' in 28px bold until the user records and the first valid reading replaces it (lines 416-420).

**Failure scenario:**

User installs the app and lands on the Dashboard: the MIN card prominently displays 'Infinity' instead of a number or placeholder — visible on every session before the first recording.

**Recommended fix:**

In _buildStatCard (or at the call site line 738) render a placeholder when the value is not finite: `value.isFinite ? value.toStringAsFixed(0) : '--'`.

---

#### [social-9] Every load failure is misreported as 'No Internet Connection'

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/history_screen.dart:111`

**Description:**

The catch block of _loadInitialRecordings (lines 107-114) sets `_isOffline = true` for ANY exception — Firestore FAILED_PRECONDITION (missing index), PERMISSION_DENIED, count() aggregation failure, etc. — and the UI then shows the offline screen 'Please turn on internet to view history' (lines 175-216). Real errors are invisible to both the user and to developers debugging index problems, which this project is specifically sensitive to (the single composite index constraint).

**Failure scenario:**

A future query change breaks the composite index contract and Firestore throws FAILED_PRECONDITION. Users on perfect Wi-Fi see 'No Internet Connection' and keep tapping Retry; the actual index error is never surfaced or logged.

**Recommended fix:**

In the catch, log the error (AppLogger.error) and distinguish network errors (check connectivity again or FirebaseException.code == 'unavailable') from other FirebaseException codes; show a generic 'Failed to load history' state with the retry button for non-network errors.

---

#### [boot-9] Microphone keeps recording on a hidden tab with no indicator — tab switch never notifies Dashboard

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/widgets/main_app_shell.dart:48`

**Description:**

Because IndexedStack keeps DashboardScreen alive, its _isRecording session (dashboard_screen.dart:41, started via the mic button at line 837) continues running when the user switches tabs: the SharedBottomNavBar onTap handler (main_app_shell.dart:50-54) only updates _currentIndex and no visibility signal reaches the Dashboard, whose only lifecycle hook is app-level didChangeAppLifecycleState (dashboard_screen.dart:102-114). The recording UI (spinner, 'Recording...' label, live classification at lines 825-875) is on the hidden Dashboard, and neither the nav bar nor the other four screens show any recording indicator, so the mic captures audio invisibly.

**Failure scenario:**

User taps the mic to start a measurement, then taps the Settings tab to check something and forgets about it: the microphone continues recording and classifying audio indefinitely with zero on-screen indication anywhere in the visible UI — a battery drain and a privacy surprise (mic active without indication inside the app).

**Recommended fix:**

Either auto-stop (or pause) the recording when the Dashboard tab is deselected — pass the active index into DashboardScreen or expose a callback from MainAppShell's onTap — or surface a persistent recording indicator (e.g., a red dot on the home button in SharedBottomNavBar and a 'Recording…' banner) while _isRecording is true on a hidden tab.

---

#### [arch-12] Highest-value pure logic (YAMNet mapping fallbacks, audio preprocessing, analytics bucket math) has no tests and is mostly private/untestable

**Severity:** Medium | **Status:** unverified | **Category:** testing | **Effort:** M

**Location:** `lib/services/yamnet_class_mapping.dart:1052`

**Description:**

Untested pure logic with real branching: (1) YAMNetClassMapping range fallbacks (yamnet_class_mapping.dart:1052-1062 — the spec'd 0-15 Speech / 16-35 Body Sounds / 229-309 Domestic contract) and the partial-match + keyword-precedence cascade in getCategoryFromClassName/_categorizeByKeywords — existing tests only check a few exact-match entries; (2) SoundClassificationService._preprocessAudio/_resampleAudio/_normalizeAudio (sound_classification_service.dart:167-242) — private, so resampling ratio and pad/trim edge cases are unreachable from tests; (3) analytics time-bucket math _buildTimeAggregatedSpots (analytics_screen.dart:184-226) — a private method on a private State class, untestable without pumping the Firebase-dependent widget; (4) PCM16 little-endian decode _processAudioData (dashboard_screen.dart:521-541).

**Failure scenario:**

A maintainer edits the range-fallback boundaries (exactly what sessions 23-29 did when adding categories): nothing fails, and e.g. index 229 silently flips from Domestic to Music, miscategorizing every domestic-sound reading saved thereafter — detectable today only by manual audio testing.

**Recommended fix:**

getCategoryFromClassName/_categorizeByKeywords are already static and public-enough — add a table-driven test asserting the three spec'd ranges and keyword precedence. Mark the audio preprocessing methods @visibleForTesting (or extract an AudioPreprocessor class) and test resample/pad/trim/normalize with synthetic buffers. Extract bucket math to a top-level function `List<FlSpot> buildTimeAggregatedSpots(docs, period, now)` taking `now` as a parameter, and test Daily/Weekly/Monthly boundaries.

---

#### [analytics-9] Trend chart silently drops readings >120 dB or <0 dB that the stat cards still include

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:191`

**Description:**

_buildTimeAggregatedSpots skips any reading with db < 0 || db > 120 (line 191), but calculateStatsByPeriod applies no range filter (firebase_service.dart:301-314) — it only null-checks. The dashboard save guard (dashboard_screen.dart:491) checks _currentDb > 0 && isFinite but has no upper bound, so >120 dB values can be persisted. The same reading is therefore counted in Average/Lowest/Highest but excluded from the chart, and the maxY headroom formula (dataMax + 15).clamp(60.0, 140.0) at line 1037 is computed on the filtered set only.

**Failure scenario:**

A firecracker produces a stored 125 dB reading. The 'Highest' card shows 125 dB, but the trend chart's bucket for that hour omits the reading entirely (or shows a much lower average), so the visible chart never reaches anywhere near the reported maximum and users assume one of the two is broken.

**Recommended fix:**

Apply one shared validity predicate in both places (e.g. a static isValidDb(double) used by calculateStatsByPeriod and _buildTimeAggregatedSpots). If 120 dB is the intended hard ceiling, also clamp/reject at write time in saveNoiseReading.

---

#### [ml-5] Peak normalization amplifies the noise floor to full scale, distorting YAMNet input and making 'Silence' undetectable

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:223`

**Description:**

_normalizeAudio (lines 223-242) divides every window by its own peak absolute value, so any window whose peak is e.g. 0.01 (quiet room mic hiss) is amplified 100x to full scale. The input samples are already in [-1.0, 1.0] from the PCM16 conversion in dashboard_screen.dart:521-532, so no normalization is needed at all; YAMNet expects waveforms at their natural level and absolute loudness is part of what distinguishes e.g. 'Silence'/background from real events. The comment on line 222 ('preserves original signal dynamics') is incorrect — per-window peak normalization destroys absolute level information. It also amplifies the zero-padding boundary artifacts from the 50%-buffer padding path (dashboard_screen.dart:598-628).

**Failure scenario:**

User records in a near-silent bedroom. The 15600-sample window contains only low-level mic self-noise (peak ~0.005). _normalizeAudio scales it to peak 1.0, presenting YAMNet with full-scale broadband noise; the model confidently predicts a noise-like class instead of 'Silence', and the reading is saved with a spurious loud-sound category.

**Recommended fix:**

Delete the _normalizeAudio call at line 176 (samples are already normalized by the /32767 conversion); at most clamp samples to [-1.0, 1.0]. If gain conditioning is ever needed, use a fixed calibration gain, never per-window peak scaling.

---

#### [dash-16] dispose() races closeRecorder against the still-running async _stopRecording

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:664`

**Description:**

dispose (lines 660-667) calls `_stopRecording()` — an async void that returns at its first await (`stopRecorder`, line 553) — and then immediately calls `_audioRecorder?.closeRecorder()` (line 664) without awaiting either. closeRecorder can therefore execute while stopRecorder is still in flight inside _stopRecording, and flutter_sound throws when the recorder session is closed mid-stop; because neither future is observed, this surfaces as an unhandled async exception. `await _audioStreamController?.close()` (line 569) similarly runs after closeRecorder may have torn down the session.

**Failure scenario:**

User logs out while a recording is active: dispose fires, closeRecorder runs while stopRecorder is awaiting on the platform channel, and an unhandled flutter_sound state exception is thrown during teardown (crash-reporting noise at best, aborted cleanup leaving the mic session open at worst).

**Recommended fix:**

Change _stopRecording to `Future<void>` and in dispose chain the cleanup without awaiting in dispose itself: `_stopRecording().whenComplete(() => _audioRecorder?.closeRecorder());` — or move closeRecorder to the end of _stopRecording behind a `dispose` flag.

---

#### [dash-9] setState after dispose in _checkAndRefreshLocation: mounted not re-checked after await

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:132`

**Description:**

_checkAndRefreshLocation checks `mounted` at line 118, then awaits `Geolocator.isLocationServiceEnabled()` (line 121), then calls setState at lines 132-135 without re-checking mounted. The method is triggered by the app-resume lifecycle callback via a 300ms Future.delayed (lines 108-112); if the State is disposed during the isLocationServiceEnabled await (e.g. user logs out right after resume), setState throws on a defunct State.

**Failure scenario:**

App resumes from background, the delayed callback fires and passes the initial mounted check, the user taps Logout while the platform-channel call to isLocationServiceEnabled is in flight — setState at line 132 throws 'setState() called after dispose()'.

**Recommended fix:**

Add `if (!mounted) return;` immediately after the `await Geolocator.isLocationServiceEnabled();` on line 121 (before the branch at line 123).

---

#### [map-7] Heatmap projection ignores map rotation — blobs misalign when the user rotates the map

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:1395`

**Description:**

HeatmapLayer computes screen positions as halfW/halfH + (project(point) - project(center)) (lines 1395-1409), which is only valid for an unrotated camera. MapOptions (lines 620-636) sets no interactionOptions, so flutter_map's default InteractiveFlag.all applies and two-finger rotation is enabled. After rotation, tiles and MarkerLayer rotate correctly but heatmap blobs stay in unrotated coordinates, detaching from their geographic locations.

**Failure scenario:**

Heatmap enabled, user two-finger-rotates the map 90 degrees: every heat blob drifts away from its marker/street, showing noise pollution in the wrong places.

**Recommended fix:**

Either disable rotation (interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)) or rotate the offsets by camera.rotation around the viewport center (or use camera.latLngToScreenPoint, which accounts for rotation).

---

#### [settings-14] Change Password maps only legacy 'wrong-password' code; modern Firebase returns 'invalid-credential' so users get a generic error

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:789`

**Description:**

The reauthentication error mapping (lines 786-796) handles 'wrong-password', but Firebase Auth with email-enumeration protection (default for all projects since late 2023) returns 'invalid-credential' / INVALID_LOGIN_CREDENTIALS when the current password is wrong. The friendly 'Current password is incorrect' message is therefore unreachable and users see 'Failed to change password' with no hint of the cause.

**Failure scenario:**

User mistypes their current password in the Change Password dialog. reauthenticateWithCredential throws FirebaseAuthException(code: 'invalid-credential'); the snackbar shows the generic 'Failed to change password', so the user cannot tell whether the app is broken or their password was wrong.

**Recommended fix:**

Add `e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS'` to the wrong-password branch at line 789.

---

#### [offline-9] last_sync_time is saved even when zero recordings synced, so 'Last Sync: just now' is shown after total failure

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/sync_service.dart:191`

**Description:**

`saveLastSyncTime(DateTime.now())` at line 191 runs unconditionally after the loop — including when every upload failed or all items were skipped for exceeding max attempts (syncedCount == 0). The dialog (sync_status_indicator.dart:194-202) presents this as 'Last Sync', which users read as the last *successful* sync. Combined with the badge still showing pending items, the UI contradicts itself: 'Last Sync: Just now' next to '3 recording(s) pending'.

**Failure scenario:**

All 3 pending uploads fail against a captive portal. The user opens the sync dialog and sees 'Last Sync: Just now', concludes their data is safe, and leaves the wifi — the 3 recordings are still local-only.

**Recommended fix:**

Only call `saveLastSyncTime` when `syncedCount > 0`, or store two keys (last_attempt_time, last_success_time) and label them distinctly in the dialog.

---

#### [fb-14] Read/write field mismatch: heatmap reads 'soundCategory' but every writer stores 'soundClass'

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/models/heatmap_point.dart:45`

**Description:**

HeatmapPoint.fromFirestore reads data['soundCategory'] (line 45), but both writers store the classification under 'soundClass' (firebase_service.dart line 129, sync_service.dart line 224). No code ever writes a 'soundCategory' field, so HeatmapPoint.soundCategory is always null, and heatmap_service.filterBySoundCategory (heatmap_service.dart lines 87-98) returns an empty list for any concrete category (only 'All'/null passes through).

**Failure scenario:**

Any feature invoking filterBySoundCategory(points, category: 'Traffic') gets zero points even though the map has dozens of Traffic-classified readings — the heatmap goes blank the moment a category filter is applied.

**Recommended fix:**

Change line 45 to soundCategory: data['soundClass'] as String? (optionally keeping data['soundCategory'] as a fallback for any legacy docs).

---

#### [fb-11] Connectivity check trusts interface state: connected-without-internet hangs the online save path indefinitely

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/services/firebase_service.dart:43`

**Description:**

_isConnectedToInternet (lines 95-104) returns true for ANY non-none interface, including ConnectivityResult.bluetooth (which history_screen deliberately excludes at lines 47-50) and Wi-Fi behind captive portals. When it returns true but there is no actual internet, _saveToFirebase's add() Future (line 133) never completes (Firestore write Futures resolve only on server ack), so the awaited saveNoiseReading never returns, the outer catch never fires, and the Hive offline fallback is never used.

**Failure scenario:**

User is on hotel Wi-Fi behind a captive portal (or paired to a Bluetooth device with no internet) and submits a manual noise report: report_noise_screen awaits saveNoiseReading forever, the finally block never runs, and the submit button spins indefinitely; the reading is not queued in the Hive offline store and only reaches Firestore if/when real connectivity returns while the app process is alive.

**Recommended fix:**

Wrap the Firestore add in a timeout — await _firestore.collection('noise_readings').add(data).timeout(const Duration(seconds: 10)) — and on TimeoutException fall through to _saveOffline. Also exclude ConnectivityResult.bluetooth in _isConnectedToInternet to match history_screen's logic.

---

#### [map-8] HeatmapPainter.shouldRepaint compares only list length — equal-count data changes can render stale

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:1471`

**Description:**

shouldRepaint returns true only when opacity or screenPoints.length changed (lines 1470-1472). Positions and intensities are ignored. Because the marker limit is a hard 100 (_kMapReadingLimit), any reload once the collection has >=100 docs produces a new list of the SAME length with different points, and pan/zoom rebuilds also keep the length constant — the painter contract says these need no repaint, so whether the heatmap updates depends entirely on incidental ancestor repaints (fragile, e.g., if flutter_map or Flutter adds a repaint boundary around the layer).

**Failure scenario:**

Collection has 100+ readings, heatmap visible. Data is reloaded (e.g., after fixing map-2): 100 new points replace 100 old ones, shouldRepaint returns false and the canvas may keep drawing the old blobs.

**Recommended fix:**

Compare contents: return old.opacity != opacity || !listEquals(old.screenPoints, screenPoints); (record tuples support ==), or simply return true since the layer rebuilds only when the camera or data changed anyway.

---

#### [donate-9] Donation history entries are corrupted on read: split(':') breaks on ISO-8601 timestamps

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/donation_service.dart:98`

**Description:**

recordDonation stores entries as '${now.toIso8601String()}:$amount' (line 86), e.g. '2026-07-12T10:45:30.123456:20.0'. getDonationHistory (lines 97-103) does entry.split(':') and reads parts[0] as the date and parts[1] as the amount - but ISO-8601 contains colons, so parts[0]='2026-07-12T10' (date truncated to the hour) and parts[1]='45' (the MINUTES field parsed as the dollar amount). Every stored donation reads back with a wrong date and an amount equal to the minute-of-day it was made. Currently latent because getDonationHistory has no call sites and recordDonation is only reachable via the dead success path (see donate-1), but it corrupts data the moment either is wired up.

**Failure scenario:**

After donate-1 is fixed, a user donates $20.00 at 10:45. Any future 'donation history' UI calling getDonationHistory shows a $45.00 donation dated 2026-07-12 10:00 - wrong amount and wrong time.

**Recommended fix:**

Split on the LAST colon: final i = entry.lastIndexOf(':'); date = DateTime.parse(entry.substring(0, i)); amount = double.parse(entry.substring(i + 1)); - or store each entry as a JSON object string.

---

#### [map-16] Nominatim query string is not URL-encoded

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:362`

**Description:**

The search URL is built by direct interpolation 'q=$query' (lines 362-364), and identically in search_list_screen.dart:55-57. A '&' in the input terminates the q parameter ('H&M Colombo' searches only 'H' and injects a bogus 'M Colombo' parameter); '#' truncates everything after it into a fragment; '+' is interpreted as a space.

**Failure scenario:**

User searches 'Arpico Super Centre & Pharmacy': results correspond to a different, truncated query or the request fails — silently wrong search results.

**Recommended fix:**

Build the URI with Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'json', 'q': query, 'limit': '50', 'addressdetails': '1', ...}) in both files so all parameters are encoded.

---

#### [settings-15] Notification permission requested only at cold start and init is Android-only — toggle-on can never recover a denial, iOS silently unsupported

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/notification_service.dart:14`

**Description:**

requestPermission() is called once in main.dart line 48, before login/onboarding. If the user denies the Android 13+ POST_NOTIFICATIONS prompt there, enabling 'Enable Notifications' or 'High Noise Alerts' in Settings (settings_screen_enhanced.dart lines 171-188) never re-requests permission, so alerts silently never fire while the toggles show ON. Additionally InitializationSettings is built with android: only (lines 14-15) — no DarwinInitializationSettings — so on the iOS target that exists in the repo (ios/ folder), initialize() sets nothing up and requestPermission() returns false unconditionally (lines 27-31).

**Failure scenario:**

Android 14 user taps 'Don't allow' on the launch permission prompt weeks ago, later enables High Noise Alerts in Settings and records at 90 dB — no notification appears and no explanation is given.

**Recommended fix:**

When the notifications toggle is switched on, call NotificationService.requestPermission() and reflect denial in the UI (snackbar + keep toggle off, deep-link to app settings). Add DarwinInitializationSettings and the iOS permission request if iOS is a supported target.

---

#### [dash-10] Stop is not immediate: _isRecording stays true through async teardown (up to 3s), and a second stop tap re-enters concurrently

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:544`

**Description:**

_stopRecording cancels subscriptions/timers synchronously (lines 545-548) but only flips `_isRecording = false` in the setState at lines 578-584, AFTER `await stopRecorder()` (3s timeout, line 553) and `await _audioStreamController?.close()` (line 569). Until then the button still renders the stop icon and 'Recording...' (lines 837, 864, 873), so the user sees no response to their tap for up to 3 seconds, and a second tap during that window calls _stopRecording again concurrently — `stopRecorder()` can then be invoked twice against flutter_sound while the first call is in flight. The same late-setState also underlies the restart race at lines 370-374, where _startRecording fire-and-forgets _stopRecording with only a 200ms delay: stop's trailing `_isRecording = false` can land after start's `_isRecording = true`, leaving the mic and subscriptions running while the UI shows 'Tap to measure' and the timers' guards suppress all saves and classification.

**Failure scenario:**

User taps stop; the recorder takes 3s to stop (the timeout the code itself anticipates at line 555). The UI still says 'Recording...', the user taps again, triggering a concurrent second stopRecorder call; in the restart variant, the recording ends up running with _isRecording false — mic on, zero saves, UI claiming idle.

**Recommended fix:**

Set `_isRecording = false` (and null the classification) in a synchronous setState at the TOP of _stopRecording, add a `_isStopping` latch to make it re-entrancy-safe, and in _startRecording await a Future-returning `Future<void> _stopRecording()` instead of the 200ms sleep.

---

#### [dash-14] Chart maxY is 100 but data reaches 120 dB; line draws outside the plot with no clipping

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/noise_history_chart.dart:61`

**Description:**

LineChartData sets `maxY: 100` (line 61) while the dashboard feeds `_dbHistory` values clamped to 0-120 (dashboard_screen.dart line 403). fl_chart's default `clipData` is FlClipData.none(), so spots above 100 are drawn beyond the chart's coordinate space — the curve escapes the 150px card (line 16), painting over the container's padding and rounded corner, and the peak's actual magnitude is unreadable against the missing scale.

**Failure scenario:**

User records near a construction site with sustained 105-115 dB readings: the purple line and its gradient fill spill out of the top of the history card over surrounding UI, and the shape above 100 is geometrically wrong relative to the card.

**Recommended fix:**

Set `maxY: 120` to match the dashboard's clamp (share one constant), or compute `maxY` from the data (`dataToShow.reduce(math.max).ceilToDouble().clamp(60, 120)`), and add `clipData: const FlClipData.all()` as a belt-and-braces guard.

---

#### [offline-10] One malformed queue entry blocks the entire queue: no per-item error handling around fromMap

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/offline_storage_service.dart:86`

**Description:**

`getQueuedRecordings` (lines 86-94) eagerly maps every pending entry through `OfflineRecording.fromMap` inside a single `.toList()`. `fromMap` (lib/models/offline_recording.dart:36-47) uses hard casts — `map['id'] as String`, `(map['decibelLevel'] as num)`, `map['timestamp'] as DateTime` — so a single entry with a missing/null/wrong-typed field (written by an older app version, a partial Hive write, or the ISO-string `syncedAt`-era format drift) throws and aborts the whole call. Because syncOfflineRecordings catches at the top level (sync_service.dart:200), one poisoned entry silently blocks syncing of every healthy recording behind it.

**Failure scenario:**

An app update adds a field or changes a type; one pre-update entry remains in the box. After the update, getQueuedRecordings throws on that entry every sync, and 12 perfectly valid newer recordings never upload while the badge count keeps growing.

**Recommended fix:**

Wrap the per-item conversion in try/catch: skip (and log) entries that fail to parse, or move them to a quarantine key so the rest of the queue syncs. Consider tolerant parsing in fromMap (nullable reads with defaults, accept int-epoch or ISO-string timestamps).

---

#### [donate-7] Any failed subresource on the Buy Me a Coffee page triggers the full-screen error overlay

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/buy_me_coffee_widget.dart:56`

**Description:**

onWebResourceError (lines 55-61) sets _hasError=true for every resource error with no isForMainFrame check and no domain filter at all. webview_flutter on Android reports subresource failures (WebResourceError exposes isForMainFrame for exactly this reason). One blocked analytics script, failed font, or 404 image flips the whole screen to 'Failed to Load' (lines 157-212), covering a fully functional donation page.

**Failure scenario:**

User on a network with DNS ad-blocking (or a flaky connection) opens Buy Me a Coffee; the page renders and is usable, but one third-party tracker request fails. The app replaces the working page with a full-screen 'Failed to Load' error and a Try Again button, so the user believes donations are broken.

**Recommended fix:**

Only set the error state when error.isForMainFrame == true (null-check: if (error.isForMainFrame ?? true) to stay safe on platforms that do not report it).

---

#### [offline-8] Sync loop has no upload timeout and no mid-batch online re-check; with Firestore persistence enabled a dropped connection hangs the sync indefinitely

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/sync_service.dart:149`

**Description:**

main.dart:41-44 enables Firestore offline persistence, so `add()` futures do not throw when connectivity is lost — they stay pending until the backend acks. The loop at lines 149-188 awaits `_saveToFirebase` (line 162 → add at 233) with no `.timeout(...)` and never re-checks `_isOnline` between items. If the network drops mid-batch, the await hangs for the whole offline window: `_isSyncing` stays true (finally at 202-203 never runs), the indicator shows a spinning 'Syncing…' while the device is offline, and both the reconnect trigger and Sync Now bail out at line 119-122.

**Failure scenario:**

Sync of 10 recordings starts on the train; the connection drops at item 3. The status indicator spins 'Syncing 8 recording(s)…' for the entire hour offline, and when wifi briefly reappears the auto-trigger returns 0 because `_isSyncing` is still true — the batch only resumes if that original hung future eventually resolves.

**Recommended fix:**

Wrap the upload: `await _saveToFirebase(recording, user.uid).timeout(const Duration(seconds: 30));` treating TimeoutException as a failed attempt (note: with persistence the write may still commit later — combine with the deterministic-doc-ID fix in offline-4 to keep this safe), and add `if (!_isOnline) break;` at the top of each loop iteration.

---

#### [map-6] SyncStatusIndicator is painted beneath the map and is never visible

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:611`

**Description:**

In the body Stack, the Positioned SyncStatusIndicator (lines 610-615) is the FIRST child; FlutterMap (line 618) is a later, non-positioned child that expands to fill the Stack and its opaque tile layer paints on top. The indicator is fully occluded and untappable on the map screen.

**Failure scenario:**

User records offline; the app's offline-sync status indicator should be visible at the top-right of the map. It never appears because map tiles cover it, so users get no pending-sync feedback on this screen.

**Recommended fix:**

Move the Positioned SyncStatusIndicator after the FlutterMap child (e.g., just before the search bar SafeArea) so it paints above the map.

---

#### [social-10] Location pill spinner sticks on and the refresh button stays disabled — _isGettingLocation is cleared without setState

**Severity:** Medium | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/report_noise_screen.dart:174`

**Description:**

_isGettingLocation is set true at line 119 and reset in the finally block at line 174 with NO setState. The last rebuild during a successful fetch happens at the placemark setState (lines 161-165) while the flag is still true, so the pill (line 535) keeps rendering the CircularProgressIndicator and onTap stays null (line 511) after the fetch has finished. The UI only recovers when an unrelated setState fires (moving the dB slider, changing the dropdown).

**Failure scenario:**

User opens Report Noise; location resolves in ~2s. The location pill continues spinning indefinitely and tapping it does nothing until the user happens to drag the slider, which forces a rebuild and 'fixes' it.

**Recommended fix:**

Reset the flag inside setState in the finally block: `if (mounted) setState(() => _isGettingLocation = false);` (and similarly wrap the assignment at line 140).

---

### Low

#### [boot-11] Email validation is nearly a no-op on both auth forms

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/login_screen.dart:159`

**Description:**

Login's validator (lines 155-163) accepts any string containing '@' ('a@b' passes, 'user@@' passes). Registration (registration_screen.dart:267-275) additionally requires a '.', but 'a@b.' and '.a@b' still pass while some valid emails are irrelevantly stricter. Invalid input therefore reaches Firebase, which rejects it with the 'invalid-email' round trip instead of an instant inline message — and on login the 'invalid-credential' fallback problem (boot-4) makes the resulting message even less helpful.

**Failure scenario:**

User typos 'name@gmail' (no TLD) into the registration form: client validation passes, the network call is made, and they get a snackbar error after a delay instead of an immediate inline 'Please enter a valid email' under the field.

**Recommended fix:**

Use one shared regex validator, e.g. RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$').hasMatch(value.trim()), in both screens (extract to a validators util so login and registration stay consistent).

---

#### [offline-16] Queue key collisions silently overwrite recordings: ID is millisecond timestamp + userId

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/offline_storage_service.dart:58`

**Description:**

IDs are generated as `'${DateTime.now().millisecondsSinceEpoch}_$userId'` (firebase_service.dart:148) and used as the Hive key in `_recordingsBox!.put(recording.id, ...)` (line 58). Two saves for the same user within the same millisecond produce the same key, and `put` overwrites the first entry without any error — the earlier reading is lost before it ever syncs. Plausible when the error-fallback path (firebase_service.dart:70-90) and a normal offline save race, or if callers ever batch-save readings in a loop.

**Failure scenario:**

A burst of two readings is saved in the same millisecond while offline; the queue ends up holding only the second one, and the first reading vanishes with no log at any level above debug.

**Recommended fix:**

Add entropy to the ID (e.g. a monotonic counter or short random suffix: `'${ms}_${userId}_${_seq++}'`), or use a uuid package. Optionally have saveOfflineRecording refuse to overwrite an existing unsynced key.

---

#### [map-20] MapController is never disposed

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:105`

**Description:**

_mapController is created at line 44 but dispose() (lines 104-108) only disposes _mapSearchController. flutter_map's MapController owns a stream/notifier that should be released; the leak persists across login/logout cycles that recreate MainAppShell.

**Failure scenario:**

User signs out and back in repeatedly: each MapViewScreen instance leaks its MapController's resources.

**Recommended fix:**

Add _mapController.dispose(); in dispose().

---

#### [analytics-13] Daily x-axis labels claim clock hours but buckets are rolling 60-minute windows anchored to 'now'

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:239`

**Description:**

Daily buckets are elapsed-hour windows: hoursAgo = now.difference(readingTime).inHours (line 206), so bucket b covers [now-(24-b)h, now-(23-b)h). The label (lines 239-242) prints the clock hour of now.subtract(Duration(hours: 23 - bucketIdx)) — the hour at the END of the window. Unless 'now' is exactly on the hour, every bucket straddles two clock hours and the printed 'NNh' is wrong for most of the bucket's contents.

**Failure scenario:**

At 14:40, bucket 18 (5 hours ago) is labeled '09h' but contains readings from 08:40-09:40 — two-thirds of its data was recorded during hour 08. A user checking 'what was the noise at 9am' reads the wrong bucket.

**Recommended fix:**

Bucket by clock hour instead of elapsed hours: compute hoursAgo as DateTime(now.y, now.m, now.d, now.hour).difference(DateTime(rt.y, rt.m, rt.d, rt.hour)).inHours, mirroring the calendar-day fix in analytics-2, so labels and bucket boundaries align on hour marks.

---

#### [analytics-12] Negative elapsed time (server timestamp ahead of device clock) produces bucket indices beyond maxX, drawing spots outside the chart

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:206`

**Description:**

The bucket guards only check the upper bound: 'if (hoursAgo > 23) continue' (line 207) and 'if (daysAgo > maxDays) continue' (line 212). If a reading's resolved timestamp is in the future relative to DateTime.now() — which happens when the device clock lags the Firestore server clock that populated the serverTimestamp field (firebase_service.dart:124) — now.difference(readingTime) is negative, inHours/inDays truncates toward zero or goes negative, and bucket = 23 - (-2) = 25 (or 6-(-1)=7, 29-(-1)=30), exceeding maxX (23/6/29 set at lines 956-960). fl_chart then renders the spot and its connecting line beyond the plot's right edge over the padding/labels since no clipData is set (LineChartData at line 1040).

**Failure scenario:**

A device whose clock is 2 hours slow records a reading; the server timestamp resolves 2 hours 'in the future' from the device's perspective. On the Daily chart, a dot and line segment render past the right edge of the chart area on top of the card padding.

**Recommended fix:**

Clamp both bounds: if (hoursAgo < 0 || hoursAgo > 23) continue; and if (daysAgo < 0 || daysAgo > maxDays) continue; (or clamp negatives into the newest bucket). Optionally set clipData: const FlClipData.all() as defense in depth.

---

#### [flow2-15] Mic permission dialog uses BuildContext across an async gap without a mounted check

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:311`

**Description:**

_requestPermissions awaits Permission.microphone.request() (dashboard_screen.dart:152) and on denial calls _showPermissionDeniedDialog (:156) which uses 'context' in showDialog (:311-312) with no mounted guard. If the widget was disposed while the system permission prompt was up (e.g. logout stream event rebuilds home), this throws 'Looking up a deactivated widget's ancestor'.

**Failure scenario:**

App opens dashboard, the OS permission prompt appears, an auth-state change (token expiry -> signed out) swaps MainAppShell for SplashScreen while the prompt is up; user taps Deny -> _showPermissionDeniedDialog runs on a defunct context -> exception.

**Recommended fix:**

Guard with 'if (!mounted) return;' after the await in _requestPermissions before calling _showPermissionDeniedDialog.

---

#### [map-15] Duplicate current-location MarkerLayer mislabeled as 'Searched location marker'

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:768`

**Description:**

Lines 767-789 are a copy-paste of the current-location layer: guarded by _searchedLocation != null but rendering point: _currentLocation with the person icon. The real searched marker follows at lines 791-832. Effect: the current-location marker is drawn twice when a search is active, and it appears even while _isLoadingLocation is true (bypassing the gate at line 744).

**Failure scenario:**

User searches a location before granting location permission: a person marker appears at the default Colombo coordinates (drawn by the mislabeled layer) implying the user is there.

**Recommended fix:**

Delete the duplicated MarkerLayer block at lines 767-789.

---

#### [flow7-13] Recorded donation amount is the app-side amount, never verified against the actual transaction

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/widgets/paypal_webview_widget.dart:287`

**Description:**

_onPaymentSuccess calls DonationService.recordDonation(widget.amount) (line 287) based purely on spotting a success-looking URL. The classic _donations flow lets the donor edit the amount on the PayPal page, and there is no IPN/webhook or transaction lookup, so the locally recorded figure can differ from what was actually paid. Impact is limited because the data is local-only SharedPreferences stats (donation_service.dart lines 67-90).

**Failure scenario:**

Donor selects $5 in the app, raises it to $50 on PayPal's page, completes payment; the app records $5. Or the success URL is hit after a declined capture and $5 is recorded for a payment that never settled.

**Recommended fix:**

Treat local recording as unverified telemetry (label it as such in any future UI), or pass amount via the return URL parameters set in the flow7-01 fix, or verify server-side via PayPal webhooks if accurate totals ever matter.

---

#### [ml-11] Int16-to-float scaling divides by 32767, producing samples below -1.0

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:529`

**Description:**

The PCM16 conversion (lines 523-531) correctly decodes little-endian signed 16-bit, but normalizes with `signedSample / 32767.0` (line 529). A full-scale negative sample (-32768) yields -1.0000305, outside YAMNet's documented [-1.0, 1.0] input range (sound_classification_service.dart:18). The effect is currently masked by the peak normalization in _normalizeAudio (which itself is ml-5); once ml-5 is fixed this becomes the live scaling path.

**Failure scenario:**

Loud clipping audio (horn right at the mic) produces -32768 samples; the tensor fed to the model contains values slightly outside the specified range. Impact is marginal today but it is an incorrect scale factor that surfaces once peak normalization is removed.

**Recommended fix:**

Divide by 32768.0 (the conventional PCM16 float conversion), which maps [-32768, 32767] into [-1.0, 0.99997].

---

#### [ml-12] Latent resampler defects: no anti-aliasing filter and output can be shorter than the computed length

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** M

**Location:** `lib/services/sound_classification_service.dart:192`

**Description:**

_resampleAudio (lines 192-219) does plain linear interpolation with no low-pass filtering, so any future caller downsampling (e.g. 44.1kHz to 16kHz) would alias all content above 8kHz into the band YAMNet analyzes. Additionally, when srcIndex.floor() >= audio.length (possible because newLength uses .round() at line 200), neither branch at lines 208-215 appends anything, so the returned list can be shorter than newLength. Currently unreachable in practice: the only caller passes _targetSampleRate=16000 (dashboard_screen.dart:634-637) so line 171's guard skips resampling — but the API advertises 'any sample rate' (line 78).

**Failure scenario:**

A future caller (e.g. background service using a 44.1kHz recorder) passes originalSampleRate=44100. High-frequency content aliases into 0-8kHz, degrading classification, and the resampled array occasionally comes back 1 sample short of the computed length (harmless today only because zero-padding follows).

**Recommended fix:**

Either document/assert that only 16kHz input is supported and remove the resampler, or fix it properly: apply a simple FIR/biquad low-pass at the target Nyquist before decimation and pad the tail deterministically so output length always equals newLength.

---

#### [fb-18] Hard (as num) decibelLevel casts in list/grid builders crash the whole view on a single bad doc

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:505`

**Description:**

search_list_screen._processCityData does (data['decibelLevel'] as num).toDouble() (line 505) inside the StreamBuilder's builder, and history_screen's itemBuilder does the same (line 451). If any document lacks decibelLevel or has it null, the cast throws during build: the Search Cities grid dies entirely (exception propagates out of _processCityData into build), and the History list shows a red error item. calculateStatsByPeriod was already hardened against exactly this (firebase_service.dart lines 301-304), so the codebase acknowledges the risk but these two readers were missed.

**Failure scenario:**

One document in the latest-100 window has a null/missing decibelLevel (console edit, partial write, schema drift): every user opening Search Cities gets a build exception instead of the city grid; the affected History page renders an error widget for that row or the whole list in debug.

**Recommended fix:**

Use the null-safe pattern: final db = (data['decibelLevel'] as num?)?.toDouble(); if (db == null) continue; in _processCityData, and skip/placeholder the row in history_screen's itemBuilder.

---

#### [settings-21] Change Password dialog leaks TextEditingControllers

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:678`

**Description:**

currentPasswordController and newPasswordController (lines 678-679) are created per invocation of _showChangePassword and never disposed — there is no dispose hook because the dialog isn't a StatefulWidget. Each open/close of the dialog leaks two controllers (and their listeners) for the app's lifetime.

**Failure scenario:**

User opens and cancels the Change Password dialog repeatedly; each cycle leaks controller objects, and in debug mode Flutter's leak diagnostics flag undisposed ChangeNotifiers.

**Recommended fix:**

Extract the dialog content into a small StatefulWidget that owns and disposes the controllers, or dispose both in showDialog(...).then((_) { ... }).

---

#### [offline-15] SyncStatusIndicator's onTap constructor parameter is silently ignored

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:102`

**Description:**

The widget declares `final VoidCallback? onTap;` (lines 9-14) but the GestureDetector's onTap (lines 102-104) unconditionally calls `_showSyncStatusDialog(context)` and never invokes `widget.onTap`. Current call sites (dashboard_screen.dart:680, map_view_screen.dart:614) pass no callback, so it's a latent API trap: any future caller supplying onTap will get the dialog instead of their handler with no error.

**Failure scenario:**

A developer adds `SyncStatusIndicator(onTap: () => openSyncSettings())` expecting custom behavior; taps still open the built-in dialog and the callback never fires, costing debugging time.

**Recommended fix:**

Either honor it — `onTap: () => widget.onTap != null ? widget.onTap!() : _showSyncStatusDialog(context)` — or delete the unused parameter.

---

#### [social-12] Compression failure silently returns the original full-size image with no size cap (latent)

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/image_compression_service.dart:44`

**Description:**

compressImage's catch (lines 41-45) returns the uncompressed original bytes, so a caller that trusts this service to bound upload size would upload the raw image (e.g. a 12 MB HEIC that flutter_image_compress fails to decode) straight to Storage. There is no post-check like 'if result still > N bytes, reject'. compressImageFile at least signals failure via null (line 80), but compressImage gives the caller no way to know compression failed. Latent today because the service is unused (see social-11), but it is the documented contract of the service.

**Failure scenario:**

Once wired up: user picks a corrupt/unsupported 12 MB image, compression throws, the service hands back all 12 MB, and the app uploads it on mobile data — defeating the service's entire stated purpose (header says 2-3MB -> 300-500KB).

**Recommended fix:**

Either rethrow / return null on failure so callers can abort, or enforce a hard cap after compression (e.g. if bytes.length > 1 MB, throw ImageTooLargeException) and document it.

---

#### [social-13] Compression stats divide by zero for images under 1 KB — logs 'Infinity% reduction' or 'NaN'

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/services/image_compression_service.dart:34`

**Description:**

Lines 32-34 compute `originalSize = imageData.length ~/ 1024` then `(1 - (compressedSize / originalSize)) * 100`. For any input under 1024 bytes, originalSize is 0, producing -Infinity or NaN in the log line (line 36-38). No crash, but garbage telemetry.

**Failure scenario:**

A tiny thumbnail (900 bytes) is compressed; the log reads 'Image compressed: 0KB -> 0KB (-Infinity% reduction)', polluting logs used for diagnosing the pipeline.

**Recommended fix:**

Compute the ratio from raw byte lengths and guard: `final reduction = imageData.isEmpty ? '0' : ((1 - result.length / imageData.length) * 100).toStringAsFixed(1);`

---

#### [analytics-11] capturedPeriod race guard fails for A→B→A period toggles — a stale in-flight load can overwrite the newer one

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:157`

**Description:**

The guard (line 157) compares only the period STRING: if (!mounted || _selectedPeriod != capturedPeriod) return;. If the user taps Daily → Weekly → Daily quickly, three loads are in flight with capturedPeriod values 'Daily', 'Weekly', 'Daily'. When the FIRST Daily load's awaits complete after the third load's, its guard passes (period matches) and its older results — computed with an earlier 'since' (line 94) and an earlier snapshot — overwrite the fresher third load's setState at lines 159-171. Firestore .get() completion order is not guaranteed, especially when the first call hits the network and the retry is served from cache.

**Failure scenario:**

User on Daily taps Weekly then immediately Daily again while a reading syncs in the background. The first Daily request resolves last and clobbers the newer stats: the banner count and averages exclude the just-synced reading even though the trend stream shows it.

**Recommended fix:**

Replace the string comparison with a monotonically increasing request id: int _loadSeq = 0; final seq = ++_loadSeq; ... if (!mounted || seq != _loadSeq) return;. This also future-proofs the guard if other filters ever start triggering loads.

---

#### [map-21] Saved map position restore races the first FlutterMap layout

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:241`

**Description:**

_loadSavedMapPosition (called from initState, line 93) awaits SharedPreferences and then calls _mapController.move (line 241). If prefs resolve before FlutterMap has rendered once (likely when the prefs instance is already cached by the Dashboard tab, since IndexedStack builds all tabs at startup), move() throws; the try/catch at lines 244-246 swallows it and the saved position is silently not restored — the map stays at the Colombo default.

**Failure scenario:**

Cold start on a fast device: user's last-viewed area is not restored; the map opens at the hardcoded default despite valid saved coordinates.

**Recommended fix:**

Load prefs before building (make initialCenter/initialZoom come from the saved values), or defer the move with MapOptions.onMapReady / WidgetsBinding.addPostFrameCallback as done for initialLocation at lines 89-91.

---

#### [map-24] Heatmap paints oldest readings on top of newest at the same location

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:1438`

**Description:**

The query returns docs ordered timestamp descending (firebase_service.dart:177), convertToHeatmapPoints preserves that order, and HeatmapPainter draws sequentially (lines 1438-1453) — so the newest reading is drawn FIRST and the oldest LAST, ending up visually on top wherever blobs overlap.

**Failure scenario:**

A junction was 90 dB last month (red) but recent readings are 45 dB (green): the stale red-ish blob is painted over the fresh green ones, so the heatmap shows the location as loud based on the oldest data.

**Recommended fix:**

Iterate in reverse (for (final p in screenPoints.reversed)) or sort points by timestamp ascending before painting so recent readings dominate.

---

#### [ml-10] Stale classification is re-saved to Firestore when subsequent classifications fail or return null

**Severity:** Low | **Status:** unverified | **Category:** bug | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:498`

**Description:**

The save timer writes _currentClassification?.category/soundType/confidence every 5 seconds (lines 487-503), but _currentClassification is only replaced when classifySound returns non-null (lines 639-642). classifySound returns null on any inference exception (sound_classification_service.dart:154-157) and _performSoundClassification also skips runs while the buffer is under 50% (lines 597-606), so after a failure the previous result — possibly from a different acoustic scene — keeps being persisted with its old confidence attached to new decibel readings.

**Failure scenario:**

User walks from a traffic junction into a quiet office while recording; inference starts throwing (or the buffer refill lags after an audio-route change). The saved readings for the office continue to carry soundClass='Traffic' with the old confidence for every 5-second save until a new classification succeeds.

**Recommended fix:**

Record a timestamp on _currentClassification when set, and in the save timer only include classification fields if the result is fresher than ~10 seconds (2 classification intervals); otherwise save nulls.

---

## Quick Wins (under 1 hour each)

- [ ] **flow7-02** - _paymentComplete set outside setState so the 'Payment Complete!' overlay never renders (`lib/widgets/paypal_webview_widget.dart:123`)
- [ ] **map-12** - Timestamp read ignores createdAt fallback — violates the project's dual-timestamp convention (`lib/models/heatmap_point.dart:35`)
- [ ] **fb-2** - Offline-synced readings get the sync time, not the recording time, as their 'timestamp' (`lib/services/sync_service.dart:217`)
- [ ] **map-1** - Cluster color lookup key never matches — all clusters render as 'moderate' orange (`lib/screens/map_view_screen.dart:687`)
- [ ] **boot-11** - Email validation is nearly a no-op on both auth forms (`lib/screens/login_screen.dart:159`)
- [ ] **offline-16** - Queue key collisions silently overwrite recordings: ID is millisecond timestamp + userId (`lib/services/offline_storage_service.dart:58`)
- [ ] **critic-01** - Info.plist has no permission usage descriptions - app crashes on iOS (`ios/Runner/Info.plist:4`)
- [ ] **map-20** - MapController is never disposed (`lib/screens/map_view_screen.dart:105`)
- [ ] **offline-4** - Uploads are not idempotent: `.add()` with auto-ID plus mark-after-upload produces duplicate Firestore documents on retry (`lib/services/sync_service.dart:233`)
- [ ] **ml-8** - Analytics ambientCategories list omits 'Other', so 'Other' readings vanish from both Pollution and Ambient filters (`lib/screens/analytics_screen.dart:729`)
- [ ] **analytics-13** - Daily x-axis labels claim clock hours but buckets are rolling 60-minute windows anchored to 'now' (`lib/screens/analytics_screen.dart:239`)
- [ ] **dash-13** - Gauge scale tops out at 100 dB while readings are clamped to 120 dB: needle pegs, digits keep climbing (`lib/screens/dashboard_screen.dart:747`)
- [ ] **boot-4** - Login has no generic catch and its error mapping misses the codes modern Firebase Auth actually returns (`lib/screens/login_screen.dart:61`)
- [ ] **settings-12** - Error handlers in _deleteAccount/_clearHistory pop the Settings route when the loading dialog was never shown (`lib/screens/settings_screen_enhanced.dart:944`)
- [ ] **fb-3** - History load permanently deadlocks when userId is null: _isLoading stuck true blocks all retries (`lib/screens/history_screen.dart:87`)
- [ ] **dash-8** - setState and timer creation after dispose in _startRecording (no mounted check after await) (`lib/screens/dashboard_screen.dart:482`)
- [ ] **map-5** - _showNativeLocationDialog shows no dialog — geolocator throws instead when location services are off (`lib/screens/map_view_screen.dart:330`)
- [ ] **analytics-12** - Negative elapsed time (server timestamp ahead of device clock) produces bucket indices beyond maxX, drawing spots outside the chart (`lib/screens/analytics_screen.dart:206`)
- [ ] **fb-12** - Unsafe casts in marker/heatmap building: one malformed doc silently blanks the entire map (`lib/screens/map_view_screen.dart:176`)
- [ ] **social-18** - SharedAppState.locationDialogShown is set true but almost never reset — location dialog shows at most once per session on error paths (`lib/screens/report_noise_screen.dart:183`)
- [ ] **dash-11** - In-flight classification resurrects _currentClassification after stop; stale label attached to next session's saves (`lib/screens/dashboard_screen.dart:639`)
- [ ] **analytics-2** - Weekly/Monthly buckets use rolling 24h windows but x-axis labels claim calendar days — readings attributed to the wrong weekday (`lib/screens/analytics_screen.dart:210`)
- [ ] **fb-6** - Analytics 'Duration' stat is off by 60x: divides reading count by 12 but readings are saved every 5 seconds (`lib/screens/analytics_screen.dart:163`)
- [ ] **flow2-15** - Mic permission dialog uses BuildContext across an async gap without a mounted check (`lib/screens/dashboard_screen.dart:311`)
- [ ] **dash-2** - Double-start race: _isRecording set only after awaits, leaking a noise subscription and a duplicate save timer (`lib/screens/dashboard_screen.dart:364`)
- [ ] **donate-4** - 'Open in Browser' button does nothing except show a misleading 'Opening in browser...' snackbar (`lib/widgets/buy_me_coffee_widget.dart:106`)
- [ ] **donate-6** - LateInitializationError crash if Reload/Try Again is tapped before the webview controller is created (`lib/widgets/paypal_webview_widget.dart:63`)
- [ ] **analytics-6** - Average dB uses arithmetic mean instead of energy (Leq) averaging — understates true noise exposure (`lib/services/firebase_service.dart:311`)
- [ ] **dash-7** - MIN stat card renders the literal text 'Infinity' until the first reading arrives (`lib/screens/dashboard_screen.dart:1040`)
- [ ] **map-15** - Duplicate current-location MarkerLayer mislabeled as 'Searched location marker' (`lib/screens/map_view_screen.dart:768`)
- [ ] **offline-1** - Queue is permanently unsyncable after app restart: Hive returns Map<dynamic,dynamic>, fromMap cast throws (`lib/services/offline_storage_service.dart:93`)
- [ ] **social-9** - Every load failure is misreported as 'No Internet Connection' (`lib/screens/history_screen.dart:111`)
- [ ] **donate-3** - Any failed non-'paypal.com' subresource replaces a working checkout with a full-screen error - including PayPal's own CDN (`lib/widgets/paypal_webview_widget.dart:134`)
- [ ] **dash-4** - Readings saved with hardcoded Colombo fallback coordinates when location is denied or unavailable (`lib/screens/dashboard_screen.dart:492`)
- [ ] **map-4** - Location permission result ignored; denied/deniedForever fail silently and camera jumps to default location (`lib/screens/map_view_screen.dart:288`)
- [ ] **settings-4** - 'High Noise Alerts' toggle and 'Alert Threshold' slider have no effect — alert logic is hardcoded (`lib/screens/settings_screen_enhanced.dart:180`)
- [ ] **analytics-9** - Trend chart silently drops readings >120 dB or <0 dB that the stat cards still include (`lib/screens/analytics_screen.dart:191`)
- [ ] **ml-5** - Peak normalization amplifies the noise floor to full scale, distorting YAMNet input and making 'Silence' undetectable (`lib/services/sound_classification_service.dart:223`)
- [ ] **dash-5** - Community Feed count query violates the project Firestore index rule (isGreaterThanOrEqualTo, no orderBy) and swallows the resulting error (`lib/screens/dashboard_screen.dart:911`)
- [ ] **ml-11** - Int16-to-float scaling divides by 32767, producing samples below -1.0 (`lib/screens/dashboard_screen.dart:529`)
- [ ] **dash-16** - dispose() races closeRecorder against the still-running async _stopRecording (`lib/screens/dashboard_screen.dart:664`)
- [ ] **dash-9** - setState after dispose in _checkAndRefreshLocation: mounted not re-checked after await (`lib/screens/dashboard_screen.dart:132`)
- [ ] **map-7** - Heatmap projection ignores map rotation — blobs misalign when the user rotates the map (`lib/screens/map_view_screen.dart:1395`)
- [ ] **settings-14** - Change Password maps only legacy 'wrong-password' code; modern Firebase returns 'invalid-credential' so users get a generic error (`lib/screens/settings_screen_enhanced.dart:789`)
- [ ] **ml-2** - Range fallbacks (0-15 Speech, 16-35 Body Sounds, 229-309 Domestic, ...) are dead code due to 'Unknown_Class_' vs 'YAMNet_Class_' prefix mismatch (`lib/services/yamnet_class_mapping.dart:1011`)
- [ ] **fb-18** - Hard (as num) decibelLevel casts in list/grid builders crash the whole view on a single bad doc (`lib/screens/search_list_screen.dart:505`)
- [ ] **map-3** - Debounce guard compares raw input to lowercased query — search never fires for capitalized input (`lib/screens/search_list_screen.dart:292`)
- [ ] **social-3** - Deleting a recording never updates the on-screen list or the 'Showing X of Y' count (`lib/screens/history_screen.dart:721`)
- [ ] **offline-9** - last_sync_time is saved even when zero recordings synced, so 'Last Sync: just now' is shown after total failure (`lib/services/sync_service.dart:191`)
- [ ] **analytics-4** - Manual 'Speech-Pollution' readings appear under the Ambient filter and vanish from the Pollution filter in the category breakdown (`lib/screens/analytics_screen.dart:746`)
- [ ] **settings-21** - Change Password dialog leaks TextEditingControllers (`lib/screens/settings_screen_enhanced.dart:678`)
- [ ] **ml-4** - Threshold logic has zero behavioral effect: below-threshold results are returned identically and persisted to Firestore (`lib/services/sound_classification_service.dart:126`)
- [ ] **offline-15** - SyncStatusIndicator's onTap constructor parameter is silently ignored (`lib/widgets/sync_status_indicator.dart:102`)
- [ ] **fb-14** - Read/write field mismatch: heatmap reads 'soundCategory' but every writer stores 'soundClass' (`lib/models/heatmap_point.dart:45`)
- [ ] **donate-5** - Classification guide contradicts the actual YAMNet mapping for Market, Alarm, Body Sounds, Nature, Other, and Transport (`lib/models/category_guide_data.dart:144`)
- [ ] **social-12** - Compression failure silently returns the original full-size image with no size cap (latent) (`lib/services/image_compression_service.dart:44`)
- [ ] **social-13** - Compression stats divide by zero for images under 1 KB — logs 'Infinity% reduction' or 'NaN' (`lib/services/image_compression_service.dart:34`)
- [ ] **map-8** - HeatmapPainter.shouldRepaint compares only list length — equal-count data changes can render stale (`lib/screens/map_view_screen.dart:1471`)
- [ ] **donate-9** - Donation history entries are corrupted on read: split(':') breaks on ISO-8601 timestamps (`lib/services/donation_service.dart:98`)
- [ ] **map-16** - Nominatim query string is not URL-encoded (`lib/screens/map_view_screen.dart:362`)
- [ ] **social-2** - Hard cast `data['decibelLevel'] as num` crashes list rendering on any doc missing decibelLevel (`lib/screens/history_screen.dart:451`)
- [ ] **ml-3** - Confidence threshold is 0.15, violating the documented project threshold of 0.30 (`lib/services/sound_classification_service.dart:34`)
- [ ] **settings-15** - Notification permission requested only at cold start and init is Android-only — toggle-on can never recover a denial, iOS silently unsupported (`lib/services/notification_service.dart:14`)
- [ ] **dash-10** - Stop is not immediate: _isRecording stays true through async teardown (up to 3s), and a second stop tap re-enters concurrently (`lib/screens/dashboard_screen.dart:544`)
- [ ] **analytics-11** - capturedPeriod race guard fails for A→B→A period toggles — a stale in-flight load can overwrite the newer one (`lib/screens/analytics_screen.dart:157`)
- [ ] **dash-14** - Chart maxY is 100 but data reaches 120 dB; line draws outside the plot with no clipping (`lib/widgets/noise_history_chart.dart:61`)
- [ ] **boot-1** - No error handling around Firebase init or any pre-runApp startup await — failure leaves a permanent blank screen (`lib/main.dart:38`)
- [ ] **map-21** - Saved map position restore races the first FlutterMap layout (`lib/screens/map_view_screen.dart:241`)
- [ ] **offline-10** - One malformed queue entry blocks the entire queue: no per-item error handling around fromMap (`lib/services/offline_storage_service.dart:86`)
- [ ] **donate-7** - Any failed subresource on the Buy Me a Coffee page triggers the full-screen error overlay (`lib/widgets/buy_me_coffee_widget.dart:56`)
- [ ] **offline-8** - Sync loop has no upload timeout and no mid-batch online re-check; with Firestore persistence enabled a dropped connection hangs the sync indefinitely (`lib/services/sync_service.dart:149`)
- [ ] **map-6** - SyncStatusIndicator is painted beneath the map and is never visible (`lib/screens/map_view_screen.dart:611`)
- [ ] **map-24** - Heatmap paints oldest readings on top of newest at the same location (`lib/screens/map_view_screen.dart:1438`)
- [ ] **ml-10** - Stale classification is re-saved to Firestore when subsequent classifications fail or return null (`lib/screens/dashboard_screen.dart:498`)
- [ ] **dash-1** - AVG decibel uses arithmetic mean instead of energy-based (logarithmic) averaging (`lib/screens/dashboard_screen.dart:424`)
- [ ] **social-10** - Location pill spinner sticks on and the refresh button stays disabled — _isGettingLocation is cleared without setState (`lib/screens/report_noise_screen.dart:174`)
