# End-to-End Flow Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **70** (2 Critical, 30 High, 31 Medium, 7 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| flow6-01 | Critical | confirmed | `lib/screens/settings_screen_enhanced.dart:904` | Delete Account anonymizes all readings BEFORE user.delete(), so a requires-recent-login failure permanently orphans the user's history | M |
| flow2-1 | Critical | confirmed | `lib/services/offline_storage_service.dart:93` | Offline queue unreadable after app restart - Hive Map<dynamic,dynamic> cast crashes sync, readings never reach Firestore | S |
| flow2-4 | High | confirmed | `lib/screens/dashboard_screen.dart:492` | Location failure still saves readings with hardcoded Colombo coordinates and status strings as locationName | M |
| flow6-04 | High | confirmed | `lib/screens/dashboard_screen.dart:428` | 'High Noise Alerts' toggle and 'Alert Threshold' slider (50-100 dB) are dead — threshold hardcoded to 70 dB and the toggle is never read | S |
| flow3-8 | High | confirmed | `lib/screens/analytics_screen.dart:721` | Analytics category-filter lists diverge from the written taxonomy: 'Speech-Pollution' shows under Ambient, and 'Other' vanishes under Ambient filter | S |
| flow2-2 | High | confirmed | `lib/services/sync_service.dart:162` | Offline recordings synced under whoever is logged in at sync time (cross-user attribution) | M |
| flow3-5 | High | confirmed | `lib/screens/history_screen.dart:403` | History empty state is a dead end: no scrollable means pull-to-refresh cannot fire, and nothing reloads on tab activation | S |
| flow6-06 | High | confirmed | `lib/screens/edit_profile_screen.dart:115` | New email is written to Firestore immediately, but Auth email only changes after the verification link is clicked — data diverges if the user never verifies | M |
| flow3-4 | High | disputed | `lib/screens/analytics_screen.dart:122` | Analytics mixes a live stream (trend chart) with one-shot stats loaded once at app start - same screen shows contradictory data | M |
| flow2-6 | High | confirmed | `lib/services/sound_classification_service.dart:34` | Classification confidence threshold is 0.15 (spec: 0.30) and is non-gating - low-confidence classifications are persisted as fact | S |
| flow3-7 | High | confirmed | `lib/screens/analytics_screen.dart:163` | 'Duration' stat divides reading count by 12, but readings are saved every 5 seconds - overstates duration ~60x | S |
| settings-9 | High | confirmed | `lib/screens/edit_profile_screen.dart:100` | Email change writes the new, unverified email to users doc and all noise_readings before verification completes | M |
| flow6-03 | High | confirmed | `lib/services/firebase_service.dart:121` | 'Anonymize Location' privacy toggle is a silent no-op — exact GPS coordinates are always uploaded | S |
| flow7-01 | High | confirmed | `lib/widgets/paypal_webview_widget.dart:121` | PayPal success/cancel detection can never fire - donation completion is never observed | M |
| donate-1 | High | confirmed | `lib/widgets/paypal_webview_widget.dart:42` | PayPal success/cancel detection can never fire - completion flow is dead code | M |
| map-2 | High | confirmed | `lib/screens/map_view_screen.dart:603` | Map data can never be refreshed — stale markers/heatmap after a new recording or deletion | M |
| flow2-7 | High | confirmed | `lib/services/sync_service.dart:151` | Sync dead-end: recordings are abandoned forever after 3 failed attempts with no recovery or user surface | M |
| social-4 | High | confirmed | `lib/screens/report_noise_screen.dart:22` | Report can be submitted with hardcoded Colombo fallback coordinates and placeholder location names | M |
| flow4-4 | High | confirmed | `lib/screens/community_feed_screen.dart:63` | Community feed shows every user's automatic 5-second monitoring samples — manual reports are drowned out of the 100-item window | M |
| flow3-1 | High | confirmed | `lib/models/heatmap_point.dart:45` | Reader field 'soundCategory' never matches writer field 'soundClass' - heatmap points always lose classification | S |
| offline-3 | High | confirmed | `lib/services/sync_service.dart:83` | Sync is only triggered by an offline-to-online transition — never at startup, after login, or after a fallback offline save | S |
| flow1-2 | High | confirmed | `lib/screens/splash_screen.dart:36` | Onboarding is never persisted as seen — it replays on every signed-out launch and every logout | S |
| analytics-3 | High | disputed | `lib/screens/analytics_screen.dart:47` | Stats, pie chart, breakdown and readings count are loaded once in initState and never refresh, while the trend chart live-updates — contradictory data on the same screen | M |
| flow5-3 | High | confirmed | `lib/services/sync_service.dart:233` | No duplicate-upload protection: sync uses collection.add() with auto ID and marks synced only after the ack | S |
| dash-6 | High | confirmed | `lib/screens/dashboard_screen.dart:102` | Recording continues invisibly on tab switch and app background; frozen _currentDb is re-saved every 5s as fresh data | M |
| flow5-2 | High | confirmed | `lib/models/offline_recording.dart:5` | Offline recordings sync under whichever user is logged in at sync time — OfflineRecording has no userId field | M |
| social-5 | High | confirmed | `lib/screens/report_noise_screen.dart:235` | 'Noise report submitted successfully!' shows even when nothing was saved — error path is unreachable | S |
| flow1-1 | High | confirmed | `lib/main.dart:38` | Unguarded Firebase.initializeApp dead-ends the app before runApp with no error UI | S |
| flow6-05 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:1027` | Clear History, Delete Account, and profile-email propagation all use a single unchunked WriteBatch — fails outright for users with >500 readings | S |
| flow4-3 | High | confirmed | `lib/services/image_compression_service.dart:12` | 'Report with image' leg of the flow does not exist — ImageCompressionService is unreachable dead code | L |
| flow2-3 | High | confirmed | `lib/services/sync_service.dart:211` | Writer/writer field mismatch: offline-sync path omits userEmail that the online path writes and readers consume | S |
| flow3-3 | High | confirmed | `lib/screens/history_screen.dart:721` | Deleting a recording does not remove it from the History list or update the count | S |
| flow4-7 | Medium | unverified | `lib/screens/community_feed_screen.dart:174` | Offline-synced reports show upload time instead of recording time ('Just now' for a 3-day-old reading) | S |
| flow2-13 | Medium | unverified | `lib/screens/dashboard_screen.dart:372` | Restart race: un-awaited _stopRecording can close the NEW session's audio stream and reset _isRecording mid-recording | M |
| flow5-8 | Medium | unverified | `lib/widgets/sync_status_indicator.dart:212` | 'Sync Now' gives no feedback — snackbar guarded by the popped dialog's dead context, and its message would be wrong anyway | S |
| flow6-07 | Medium | unverified | `lib/screens/edit_profile_screen.dart:135` | Name-only profile save fetches every reading and commits EMPTY batch updates | S |
| flow2-12 | Medium | unverified | `lib/screens/dashboard_screen.dart:515` | Mic-permission-denied record tap fails silently and leaks the noise-meter subscription | S |
| flow7-04 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:153` | Navigation allowlists silently block 3-D Secure and login redirects, freezing checkout mid-payment | M |
| ml-9 | Medium | unverified | `lib/screens/dashboard_screen.dart:592` | Model-load failure silently disables classification forever with no retry, while the audio-capture pipeline keeps running | M |
| flow5-10 | Medium | unverified | `lib/services/sync_service.dart:191` | lastSyncTime saved even when every upload failed — dialog shows 'Last Sync: Just now' after a 0% sync | S |
| flow2-14 | Medium | unverified | `lib/services/firebase_service.dart:161` | Offline save failures are silently discarded - saveOfflineRecording's bool result is ignored | S |
| flow4-5 | Medium | unverified | `lib/services/firebase_service.dart:27` | Submit shows 'submitted successfully' even when the report was silently dropped or only queued | S |
| flow1-8 | Medium | unverified | `lib/main.dart:150` | Auth-gate StreamBuilder is destroyed by the splash pushReplacement — app stops reacting to auth-state changes after first navigation | M |
| flow4-8 | Medium | unverified | `lib/services/sync_service.dart:56` | No sync on app startup — queued offline reports wait for a connectivity transition or a manual tap | S |
| flow2-11 | Medium | unverified | `lib/screens/dashboard_screen.dart:296` | Location error with dialog-flag set leaves 'Fetching location...' spinner forever and disables the refresh tap | S |
| flow6-12 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:90` | 'Decibel Scale' (dBA/dBC) and 'Response Time' (Fast/Slow) toggles are dead settings | M |
| flow3-13 | Medium | unverified | `lib/screens/map_view_screen.dart:42` | Map shows only the 100 most recent readings across ALL users - a user's saved reading can be missing from the map while present in History/Analytics | M |
| flow2-10 | Medium | unverified | `lib/screens/dashboard_screen.dart:346` | '_showNativeLocationDialog' shows no dialog - location-denied path dead-ends and the app-wide flag blocks all future prompts | S |
| flow6-10 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:257` | Five settings rows are silent dead ends: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service have empty onTap handlers | M |
| donate-12 | Medium | unverified | `lib/widgets/buy_me_coffee_widget.dart:71` | Navigation blocklist blocks legitimate checkout redirects (3-D Secure bank pages, Stripe Link) so some payments cannot complete | S |
| flow2-9 | Medium | unverified | `lib/screens/dashboard_screen.dart:909` | Community feed count query violates the project period-query rule (isGreaterThanOrEqualTo, no orderBy) and streams all users' docs unbounded | S |
| flow7-09 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:37` | PAYPAL_CLIENT_ID is actually used as the PayPal account email; following .env.example breaks all donations | S |
| flow6-14 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:214` | 'Share Data with Researchers' toggle is a no-op — every reading is always globally visible | M |
| flow6-13 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:131` | 'Recording Duration' and 'Save Frequency' sliders are dead — save interval hardcoded to 5 s, recording never auto-stops | S |
| flow4-6 | Medium | unverified | `lib/screens/report_noise_screen.dart:224` | Placeholder location strings and default Colombo coordinates are written to Firestore and shown verbatim in the community feed | S |
| flow1-3 | Medium | unverified | `lib/screens/registration_screen.dart:79` | Registration handoff leaves a stale LoginScreen route underneath MainAppShell | S |
| settings-13 | Medium | unverified | `lib/screens/dashboard_screen.dart:684` | Logout is incomplete: SharedAppState never reset, notifications not cancelled, and navigation duplicates the auth-state listener | S |
| social-16 | Medium | unverified | `lib/screens/history_screen.dart:480` | History does not reload after returning from 'Add Manual' — the just-submitted recording is missing | S |
| flow5-9 | Medium | unverified | `lib/services/sync_service.dart:99` | Offline detection is transport-level only; captive-portal wifi hangs sync with _isSyncing stuck true | M |
| flow1-5 | Medium | unverified | `lib/screens/login_screen.dart:61` | Login error mapping is dead code under modern Firebase Auth and non-FirebaseAuthException failures are swallowed silently | S |
| flow6-11 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:189` | 'Daily Reminders' toggle does nothing — no scheduler exists and showDailyReminder is never called | M |
| boot-5 | Medium | unverified | `lib/screens/registration_screen.dart:56` | Partial registration failure strands a signed-in user with no profile doc and 'email-already-in-use' on retry | M |
| donate-13 | Medium | unverified | `lib/services/donation_service.dart:12` | Sandbox mode is the silent default and is currently enabled - release builds would send real users to sandbox.paypal.com | S |
| flow1-13 | Low | unverified | `lib/screens/registration_screen.dart:68` | users/{uid} profile document written at registration is never read anywhere — totalRecordings and preferences are dead, divergent data | S |
| flow6-17 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:229` | Settings has no Sign Out option — logout exists only as an unlabeled icon in the Dashboard app bar | S |
| flow1-9 | Low | unverified | `lib/screens/dashboard_screen.dart:694` | Inconsistent auth-exit destinations: logout replays splash+onboarding, account deletion goes straight to LoginScreen | S |
| flow3-15 | Low | unverified | `lib/screens/history_screen.dart:453` | History list, CSV export, and HeatmapPoint ignore the createdAt fallback convention | S |
| flow6-16 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:37` | Two live Settings instances (shell tab + dashboard push) desync because prefs load only in initState | S |
| flow5-11 | Low | unverified | `lib/services/sync_service.dart:184` | In-loop 5-second retry delay never retries anything — it only stalls the remaining queue | S |
| flow4-12 | Low | unverified | `lib/screens/community_feed_screen.dart:185` | soundClass/soundType/confidence are written by the report screen but never displayed in the community feed | S |

## Detailed Findings

### Critical

#### [flow6-01] Delete Account anonymizes all readings BEFORE user.delete(), so a requires-recent-login failure permanently orphans the user's history

**Severity:** Critical | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:904`

**Verifier verdict (CONFIRMED):** settings_screen_enhanced.dart:_deleteAccount(): lines 887-901 batch-update all noise_readings, rewriting userId to 'deleted_user_${uid.substring(0,8)}' and userEmail to 'Deleted User', and commit BEFORE user.delete() at line 904. No reauthentication precedes delete (contrast the password-change flow, which calls reauthenticateWithCredential at line 772), so requires-recent-login is a realistic failure; the catch at lines 924-937 only shows a snackbar — no rollback of the committed batch. The account remains, but the user's readings no longer match their uid, so any userId-based history query permanently loses them. Defect is real as described.

**Description:**

_deleteAccount (lines 883-904) first batch-rewrites every noise_readings doc, setting userId to 'deleted_user_<uid8>' and userEmail to 'Deleted User' (lines 893-901), and only then calls user.delete() (line 904). Firebase requires a recent sign-in for account deletion; user.delete() throws FirebaseAuthException 'requires-recent-login' whenever the session is older than ~5 minutes, which is the common case. The catch block (lines 924-943) just shows a snackbar — it cannot undo the already-committed batch.

**Failure scenario:**

A user logged in yesterday opens Settings > Delete Account > Delete. The batch commits (all their readings reassigned to 'deleted_user_...'), then user.delete() throws requires-recent-login. They see 'Please log out and log in again before deleting your account', still have their account, but History (query where userId == uid, history_screen.dart:86-96) is now permanently empty and Analytics stats are zeroed. Irreversible data loss with no deletion.

**Recommended fix:**

Re-authenticate first (prompt for password, user.reauthenticateWithCredential) exactly like _showChangePassword does, and only run the anonymization batch after reauth succeeds — or delete the auth user first and run the anonymization from the success path/cloud function.

---

#### [flow2-1] Offline queue unreadable after app restart - Hive Map<dynamic,dynamic> cast crashes sync, readings never reach Firestore

**Severity:** Critical | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/offline_storage_service.dart:93`

**Verifier verdict (CONFIRMED):** Real. Boxes are Box<dynamic> with no adapters (offline_storage_service.dart:35), so after restart Hive rehydrates stored maps as Map<dynamic,dynamic>. getQueuedRecordings passes that raw value to OfflineRecording.fromMap(v) at line 93; fromMap requires Map<String,dynamic> (offline_recording.dart:34), so the implicit cast throws TypeError. The code itself acknowledges this hazard — line 113 comments "Cast Map<dynamic, dynamic> to Map<String, dynamic>" in getPendingSyncRecordings (line 114), but that safe method has no callers. The only sync path, SyncService.syncOfflineRecordings, calls getQueuedRecordings (sync_service.dart:140); the throw aborts every sync attempt before any Firestore write, so restart-persisted readings never sync. Same defect at lines 220 and 229 (`as Map<String, dynamic>` on a Hive Map). Same-session sync works only because Hive returns the cached original object; persistence across restart is exactly where it breaks, as claimed.

**Description:**

OfflineRecording.toMap() (Map<String,dynamic>) is stored in a dynamic Hive box (offline_storage_service.dart:58). Within the same session Hive returns the cached Map<String,dynamic> instance, but after app restart Hive deserializes values from disk as Map<dynamic,dynamic>. getQueuedRecordings() line 93 calls OfflineRecording.fromMap(v) where v is dynamic, causing an implicit downcast to Map<String,dynamic> that throws TypeError at runtime. The exception propagates into SyncService.syncOfflineRecordings() (sync_service.dart:140) where it is swallowed by the catch at sync_service.dart:200-201, so sync silently returns 0 forever. getAllOfflineRecordings() line 220 ('v as Map<String, dynamic>') and getRecording() line 229 have the same broken cast. Note getPendingSyncRecordings() line 114 does it correctly with Map<String,dynamic>.from(value), proving the pattern was known.

**Failure scenario:**

User records readings offline in the field (queued to Hive via firebase_service.dart:137-162), closes the app, later reopens it on WiFi. Connectivity change fires syncOfflineRecordings -> getQueuedRecordings throws '_Map<dynamic, dynamic> is not a subtype of Map<String, dynamic>' -> caught and logged only -> 0 recordings synced, every retry fails the same way. All offline readings are permanently stranded in Hive and never appear in Firestore, history, analytics, or the map.

**Recommended fix:**

In getQueuedRecordings (line 93) map with OfflineRecording.fromMap(Map<String, dynamic>.from(v)); apply the same Map<String,dynamic>.from() conversion in getAllOfflineRecordings (line 220) and getRecording (line 229) instead of direct 'as Map<String, dynamic>' casts.

---

### High

#### [flow2-4] Location failure still saves readings with hardcoded Colombo coordinates and status strings as locationName

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:492`

**Verifier verdict (CONFIRMED):** dashboard_screen.dart:61-63 hardcodes defaults `_latitude = 6.9271; // Colombo default`, `_longitude = 79.8612`, `_locationName = 'Fetching location...'`. Failure paths only change _locationName to status strings ('Location permission denied' line 201, 'Location services disabled' lines 217/299) and never update coordinates. The 5s save timer (lines 487-502) checks only `_currentDb > 0 && _currentDb.isFinite` before calling saveNoiseReading with `_latitude`, `_longitude`, `_locationName` — no location-validity gate. firebase_service.dart:16+ saveNoiseReading performs no coordinate/locationName validation (only auth + connectivity checks). Thus on location failure, readings are saved at Colombo coordinates with status strings as locationName, exactly as claimed.

**Description:**

_latitude/_longitude default to 6.9271/79.8612 (dashboard_screen.dart:62-63). When location permission is denied (:195-208), services are disabled (:211-224), or getCurrentPosition times out (:292-303), only _locationName is changed to a status string ('Location permission denied' / 'Location services disabled' / it can remain 'Fetching location...'). _startRecording and the 5-second _saveTimer (:487-503) never validate location state, so saveNoiseReading is called with the default coordinates and the status string as locationName, which firebase_service.dart:123 persists verbatim.

**Failure scenario:**

User denies location permission (or taps record within the first seconds before the GPS fix at :227 completes) and records for a minute: ~12 documents are written at the Colombo default point with locationName 'Location permission denied' or 'Fetching location...'. The map/heatmap then shows phantom noise hotspots in central Colombo, and history/community feed display the error string as a place name.

**Recommended fix:**

Track a hasLocationFix flag (set only after a successful getCurrentPosition). In the _saveTimer callback, skip the save (or save with latitude/longitude omitted plus locationName 'Unknown Location') when there is no fix, and block _startRecording with a snackbar prompting the user to enable location.

---

#### [flow6-04] 'High Noise Alerts' toggle and 'Alert Threshold' slider (50-100 dB) are dead — threshold hardcoded to 70 dB and the toggle is never read

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:428`

**Verifier verdict (CONFIRMED):** Confirmed. dashboard_screen.dart:428 hardcodes the trigger: `if (_currentDb > 70 && !_hasShownHighNoiseAlert)` then calls NotificationService.showHighNoiseAlert. The settings screen writes prefs 'db_threshold' (settings_screen_enhanced.dart:161, slider 50-100 dB) and 'high_noise_alerts' (line 186), but a repo-wide grep shows those keys are read only by the settings screen itself for display. notification_service.dart:38 checks only 'notifications_enabled' (the master toggle), never 'high_noise_alerts', and no code reads 'db_threshold'. So the 'High Noise Alerts' toggle and 'Alert Threshold' slider have no effect on alert behavior — exactly as claimed.

**Description:**

Settings saves 'high_noise_alerts' (settings_screen_enhanced.dart:180-187) and 'db_threshold' (lines 153-163), but neither key is read anywhere else (grep confirms). The only alert site is dashboard_screen.dart:428 `if (_currentDb > 70 && !_hasShownHighNoiseAlert)` with reset at `< 65` (line 435), and NotificationService.showHighNoiseAlert only checks 'notifications_enabled' (notification_service.dart:38).

**Failure scenario:**

A user sets Alert Threshold to 90 dB and disables High Noise Alerts (leaving general notifications on). They still receive a 'High Noise Alert!' push every time ambient noise crosses 70 dB — the two controls visibly save and restore state but change nothing.

**Recommended fix:**

Load 'high_noise_alerts' and 'db_threshold' in DashboardScreen (initState or before the check) and gate line 428 with `prefsHighNoiseAlerts && _currentDb > dbThreshold` (reset at dbThreshold - 5).

---

#### [flow3-8] Analytics category-filter lists diverge from the written taxonomy: 'Speech-Pollution' shows under Ambient, and 'Other' vanishes under Ambient filter

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:721`

**Verifier verdict (CONFIRMED):** Both halves check out. (1) report_noise_screen.dart:44 writes soundClass 'Speech-Pollution' with type 'Pollution', but analytics_screen.dart:729-740 puts 'Speech' in ambientCategories and matches with substring `category.contains(c)` (line 750), so 'Speech-Pollution'.contains('Speech') is true — it appears under the Ambient filter and, since no pollutionCategories entry (lines 721-728) substring-matches it, it disappears under the Pollution filter. (2) 'Other' is a real written category (yamnet_class_mapping.dart:36; dashboard_screen.dart:498 writes classifier category) and getSoundType maps categoryOther to Ambient (yamnet_class_mapping.dart:993-999), yet 'Other' is in neither list at analytics_screen.dart:721-740, so it vanishes under the Ambient filter (and Pollution). The category breakdown genuinely diverges from the app's taxonomy.

**Description:**

The Pollution/Ambient filter in _buildSoundCategoryBreakdown uses hardcoded lists with substring matching (analytics_screen.dart:721-752, `category.contains(c)`). Two verified divergences from what writers store: (1) report_noise_screen.dart:44 writes soundClass 'Speech-Pollution' with soundType 'Pollution'; 'Speech-Pollution' contains 'Speech' (in ambientCategories, line 732) so it is listed under the Ambient filter, and no pollutionCategories entry matches it so it disappears under the Pollution filter - the exact opposite of its stored soundType, and contradicting the pie chart which counts it via soundType=='Pollution' (lines 143-147). (2) YAMNetClassMapping.getSoundType maps 'Other' to Ambient (yamnet_class_mapping.dart:993-1002) and auto-classification frequently writes soundClass 'Other' (Silence, White noise, Background ambient...), but 'Other' is absent from ambientCategories (729-740), so those readings are counted in the Ambient pie slice yet dropped from the Sound Categories list when the Ambient chip is selected.

**Failure scenario:**

User manually reports a loudspeaker as 'Speech-Pollution'. Pie chart: 1 Pollution reading. User taps the Pollution chip: Sound Categories shows 'No pollution sounds' (or omits it). User taps Ambient: 'Speech-Pollution' is listed there. Separately, a user with 10 'Other' readings sees 'Ambient 10 readings' in the pie but an Ambient category list summing to 0.

**Recommended fix:**

Replace the hardcoded lists/substring matching with the single source of truth: `YAMNetClassMapping.getSoundType(category) == _selectedFilter` (with an explicit special-case for the manual 'Speech-Pollution'/'Speech-Ambient' values, or map those to soundType at read time).

---

#### [flow2-2] Offline recordings synced under whoever is logged in at sync time (cross-user attribution)

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/services/sync_service.dart:162`

**Verifier verdict (CONFIRMED):** Real. OfflineRecording (lib/models/offline_recording.dart:4-31) has no userId field — the original owner's uid is only baked into the id string at queue time (firebase_service.dart:148: id: '${millis}_$userId') and never parsed back. At sync time, sync_service.dart:133 takes `_auth.currentUser` and line 162/212 writes `'userId': user.uid` (the currently logged-in user) for every queued recording. Nothing scopes the Hive queue per user or clears it on sign-out (OfflineStorageService only exposes clearAllRecordings; SyncService never calls it on auth change). So if user A records offline, signs out, and user B signs in when connectivity returns, A's recordings are uploaded attributed to B — exactly the cross-user attribution described.

**Description:**

OfflineRecording has no userId field (only embedded in the id string, firebase_service.dart:148). syncOfflineRecordings() reads _auth.currentUser at sync time (sync_service.dart:133) and passes user.uid to _saveToFirebase (line 162), which writes 'userId': userId (line 212). The uid captured when the reading was recorded (firebase_service.dart:66 passes user.uid into _saveOffline but it is only concatenated into the id string, never stored as a field) is discarded.

**Failure scenario:**

User A records readings offline, logs out. User B logs into the same device and the device comes online. SyncService uploads A's queued readings with userId = B's uid and createdAt = A's recording times. B's history/analytics now contain A's data; A's readings are lost to A. Also a privacy leak of A's location trail into B's account.

**Recommended fix:**

Add a userId field to OfflineRecording (models/offline_recording.dart), populate it in FirebaseService._saveOffline, and in SyncService._saveToFirebase write recording.userId instead of the current user's uid; skip (or partition) queued recordings whose userId does not match the signed-in user.

---

#### [flow3-5] History empty state is a dead end: no scrollable means pull-to-refresh cannot fire, and nothing reloads on tab activation

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/history_screen.dart:403`

**Verifier verdict (CONFIRMED):** Real. history_screen.dart:383-431: RefreshIndicator wraps a Column; the empty state (lines 404-431) is a Center/Column with no scrollable descendant, so no ScrollNotification is ever emitted and pull-to-refresh cannot fire (it works only in the data branch via ListView.builder at line 432). Data loads once in initState (lines 37-41 via _checkConnectivityAndLoad). No didChangeDependencies/didUpdateWidget/VisibilityDetector exists (grep: no matches), and widgets/main_app_shell.dart:39-46 hosts HistoryScreen in an IndexedStack with const children, which keeps state alive and never re-triggers initState on tab switch. So a user who records their first reading and switches to the History tab is stuck on "No recordings yet" with no way to reload — a genuine dead end as described.

**Description:**

History loads once in initState (history_screen.dart:37-40) - at MainAppShell startup, typically before the user has recorded anything. When `_recordings` is empty, the body renders Center>Column ('No recordings yet', lines 403-431) inside RefreshIndicator (383-385) whose child is a plain Column - there is no Scrollable in the tree, so the refresh gesture can never trigger _onRefresh. Tab switches don't re-run initState (IndexedStack, main_app_shell.dart:38), and returning from the 'Add Manual' FAB (lines 478-484, Navigator.push without awaiting/then) also triggers no reload. The same dead end applies to the offline UI (only its Retry button escapes it).

**Failure scenario:**

Fresh user opens the app (History tab initializes empty), records 10 readings on Dashboard, then opens History: 'No recordings yet - Start recording to build your history'. Pulling down does nothing. Adding a manual entry via the FAB and returning still shows the empty state. The data is in Firestore but unreachable in this screen until app restart.

**Recommended fix:**

Wrap the empty state in a ListView/SingleChildScrollView with AlwaysScrollableScrollPhysics so RefreshIndicator works, await the ReportNoiseScreen push and call _loadInitialRecordings() on return, and/or reload when the tab becomes visible.

---

#### [flow6-06] New email is written to Firestore immediately, but Auth email only changes after the verification link is clicked — data diverges if the user never verifies

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/edit_profile_screen.dart:115`

**Verifier verdict (CONFIRMED):** Real as described. Line 100 calls user.verifyBeforeUpdateEmail(newEmail) — the Auth email only changes after the user clicks the verification link. Yet lines 115-119 immediately write 'email': newEmail to users/{uid} in Firestore, and lines 126-139 also batch-update every noise_readings doc's 'userEmail' to newEmail. Nothing is conditional on verification completing, and there is no rollback path. If the user never verifies, Auth keeps the old email while Firestore permanently holds the new one — data divergence exactly as claimed. (edit_profile_screen.dart:100, 115-119, 136)

**Description:**

verifyBeforeUpdateEmail (line 100) merely sends a verification link; FirebaseAuth keeps the old email until the link is clicked. Yet the code immediately writes newEmail into users/{uid} (lines 115-119) and rewrites 'userEmail' on every noise_readings doc (lines 126-139). There is no rollback or verification listener.

**Failure scenario:**

User changes email from a@x.com to b@y.com but never opens the verification link (or it lands in spam). Login still requires a@x.com, but the community feed now shows 'b**@y.com' on all their reports and the users doc claims b@y.com — permanently inconsistent identity data, and support-confusing login failures.

**Recommended fix:**

Do not write the new email to Firestore at edit time. Detect the completed change instead (e.g., on next sign-in / idTokenChanges compare user.email to users/{uid}.email and reconcile), or use updateEmail after explicit re-authentication so the auth change is atomic with the Firestore writes.

---

#### [flow3-4] Analytics mixes a live stream (trend chart) with one-shot stats loaded once at app start - same screen shows contradictory data

**Severity:** High | **Status:** disputed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:122`

**Verifier verdict (PARTIAL):** Core defect real, one wording wrong. The identical query (userId==, timestamp>since, orderBy desc) IS run three times per load: as a live stream for the trend chart (firebase_service.dart:259-265 via analytics_screen.dart:96-97), one-shot in calculateStatsByPeriod (firebase_service.dart:287-292, analytics_screen.dart:122), and one-shot in getUserReadingsByPeriodOnce (firebase_service.dart:271-279, analytics_screen.dart:124) — all aggregated client-side with no .limit() (doc count unbounded within the period, though time-bounded). Mixing live+static is also real: the chart updates on new readings via snapshots() while stats/pie stay stale, so the screen can show inconsistent data. However, "loaded once at app start" is false — _loadStatistics reruns on every period-chip tap (analytics_screen.dart:490-494), so stats refresh on user interaction, just not on new data arrival.

**Description:**

The trend chart subscribes to getUserReadingsByPeriod(...).snapshots() (analytics_screen.dart:96-97 cached into _trendStream, consumed by StreamBuilder at 982) so it updates live on every save/delete. But the stat cards, pie chart, category breakdown, confidence card, and '$totalReadings readings' banner come from one-shot calls (calculateStatsByPeriod + getUserReadingsByPeriodOnce, analytics_screen.dart:122-124) executed only in initState (47-49) and on period-chip taps (489-494). The screen sits in the IndexedStack (main_app_shell.dart:38-46), initState runs once at app startup, and there is no RefreshIndicator on the SingleChildScrollView (line 315). So: recording new readings or deleting one in History updates the chart line but leaves Average/Lowest/Highest/Duration, the pie counts, and the banner count stale.

**Failure scenario:**

User with 0 readings opens the app (analytics loads: all zeros), records 20 readings on Dashboard, then opens Analytics: the Weekly trend chart shows the new data points, but the banner shows no reading count, the pie chart is absent, and Average/Highest read '0 dB' - directly contradicting the chart above them. The numbers only correct themselves if the user toggles the period chip away and back.

**Recommended fix:**

Either derive the stats/pie/breakdown from the same StreamBuilder snapshot the chart uses (compute them in _buildTimeAggregatedSpots' caller), or re-run _loadStatistics() when the tab becomes visible and add a RefreshIndicator around the SingleChildScrollView.

---

#### [flow2-6] Classification confidence threshold is 0.15 (spec: 0.30) and is non-gating - low-confidence classifications are persisted as fact

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sound_classification_service.dart:34`

**Verifier verdict (CONFIRMED):** All claims verified in code. (1) Threshold is 0.15: sound_classification_service.dart:34, with a comment "Lowered to 15%" (lines 28-33), while project memory/session history documents threshold 0.30. (2) Non-gating: the below-threshold branch (lines 126-138) builds and returns a ClassificationResult with the identical five fields as the passing path (lines 146-152) — it only changes a debug log. (3) Persisted as fact: dashboard_screen.dart:641 stores the result unconditionally, and lines 498-500 write soundClass/soundType/confidence to the reading without any confidence check; meetsThreshold (service line 300) is never referenced by any consumer (grep shows only its definition), and confidenceThreshold's only other use is a startup log (main.dart:119). Minor note: README/PRODUCTION_CHECKLIST mention CONFIDENCE_THRESHOLD=0.6, so "0.30" is the memory-documented spec, not the only documented value — but neither 0.30 nor 0.6 matches 0.15, and the gating claim holds regardless.

**Description:**

confidenceThreshold is declared 0.15 at sound_classification_service.dart:34, violating the project constraint that the threshold is 0.30. Worse, the threshold gates nothing: the below-threshold branch (:126-138) returns a fully mapped ClassificationResult identical in shape to the above-threshold branch (:146-152). The dashboard stores whatever comes back (:639-641) and the _saveTimer writes _currentClassification.category/soundType/confidence to Firestore unconditionally (dashboard_screen.dart:498-500); the meetsThreshold getter (:300) is never consulted anywhere on the save path.

**Failure scenario:**

YAMNet's top score for ambient mush is 4% 'Siren' -> mapped to category 'Traffic', soundType 'Pollution' -> displayed on the classification card and saved to Firestore as soundClass 'Traffic' with confidence 0.04. Analytics and map filters then report noise pollution events that are statistically noise, directly contradicting the documented 0.30 threshold.

**Recommended fix:**

Set confidenceThreshold = 0.30 and make the below-threshold branch return null (or a result the caller checks via meetsThreshold before assigning _currentClassification / passing soundClass to saveNoiseReading).

---

#### [flow3-7] 'Duration' stat divides reading count by 12, but readings are saved every 5 seconds - overstates duration ~60x

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:163`

**Verifier verdict (CONFIRMED):** analytics_screen.dart:163 computes `_totalHours = (stats['count'] ?? 0) / 12`, displayed as 'Duration' in hours at line 373. stats['count'] is the number of readings with decibelLevel (firebase_service.dart:314). Readings are written by a Timer.periodic every 5 seconds (dashboard_screen.dart:487, comment "Start periodic Firebase saves (every 5 seconds)"), i.e., 720 readings/hour. Dividing by 12 assumes 12 readings/hour (a 5-minute interval); the correct divisor is 720. Duration is therefore overstated by exactly 60x, as claimed.

**Description:**

analytics_screen.dart:163 computes `_totalHours = (stats['count'] ?? 0) / 12`, i.e., it assumes 12 readings per hour (one per 5 minutes). The actual writer saves one reading every 5 seconds while recording (dashboard_screen.dart:487 `Timer.periodic(const Duration(seconds: 5) ...)` -> saveNoiseReading at 492), which is 720 readings per hour. The Duration card (line 372-373) therefore shows ~60x the true recording time. Manual entries (report_noise_screen.dart:224) also each add '5 minutes'.

**Failure scenario:**

User records continuously for 1 hour (about 720 docs saved). Analytics 'Duration' card shows '60 h' for the Daily period - a physically impossible number for a 24-hour window, displayed as fact.

**Recommended fix:**

Divide by 720 (5-second cadence) or, better, compute duration from timestamps (e.g., count distinct 5-second/1-minute buckets) so manual entries don't inflate it.

---

#### [settings-9] Email change writes the new, unverified email to users doc and all noise_readings before verification completes

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/edit_profile_screen.dart:100`

**Verifier verdict (CONFIRMED):** Real as described. edit_profile_screen.dart:100 calls user.verifyBeforeUpdateEmail(newEmail), which only sends a verification link — the auth email does not change until the user clicks it. Yet lines 115-119 immediately write 'email': newEmail to users/{uid} via merge set, and lines 126-140 batch-update every noise_readings doc's userEmail to newEmail. Nothing awaits or checks verification (line 123's user.reload() doesn't gate anything, and there is no listener/cleanup on failure). If the user never verifies, Firestore permanently holds an unverified/possibly attacker-controlled email diverging from the actual auth email.

**Description:**

verifyBeforeUpdateEmail (line 100) only SENDS a verification link — FirebaseAuth keeps the old email until the user clicks it. But the code immediately overwrites users/{uid}.email (lines 115-119) and every noise_readings.userEmail (lines 126-139) with the new address. If the user never verifies (or typo'd the address), Firestore permanently disagrees with Auth: login still uses the old email while History (history_screen.dart line 262) and the community feed (community_feed_screen.dart lines 211-216, which masks and displays userEmail) show an address that was never confirmed and may belong to someone else.

**Failure scenario:**

User mistypes 'jhon@gmial.com' as their new email and saves. Verification email goes to a dead address and is never clicked; auth email stays old, yet all their readings and profile doc now display the typo'd email, and re-running Edit Profile shows the old email again (loaded from auth), making the state unrecoverable from the UI.

**Recommended fix:**

Do not write newEmail to Firestore at request time. After verifyBeforeUpdateEmail, listen for the change (e.g. on next login / userChanges() where user.email == newEmail) and only then sync users doc and readings; show 'pending verification' state in the meantime.

---

#### [flow6-03] 'Anonymize Location' privacy toggle is a silent no-op — exact GPS coordinates are always uploaded

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/firebase_service.dart:121`

**Verifier verdict (CONFIRMED):** All variants check out. firebase_service.dart:119 writes `'userEmail': _auth.currentUser?.email` (full email) plus raw `'latitude'/'longitude'` (121-122) to the shared `noise_readings` collection; the offline queue also stores raw coords (150-151). Email masking exists only client-side at display time (community_feed_screen.dart:210-216) and its `emailParts[0].length > 3` guard means local parts of 3 or fewer chars are shown unmasked; the raw email remains readable in Firestore regardless. The 'Anonymize Location' toggle only persists prefs key 'anonymize_location' (settings_screen_enhanced.dart:54, 211); project-wide grep shows no other code reads it — the upload path never consults it, so exact GPS coordinates are always uploaded. Silent no-op confirmed.

**Description:**

Settings writes prefs key 'anonymize_location' (settings_screen_enhanced.dart:205-212), but a project-wide grep shows the key is read only by the settings screen itself (line 54). FirebaseService._saveToFirebase always writes raw 'latitude'/'longitude' (firebase_service.dart:121-122), and the offline path stores raw coords too (lines 150-151). These readings are publicly listed in the community feed (community_feed_screen.dart:62-67).

**Failure scenario:**

A privacy-conscious user enables 'Anonymize Location' and records at home. Their exact home coordinates are still saved to the shared noise_readings collection and rendered on the public map/heatmap and community feed — the privacy promise in the UI is false.

**Recommended fix:**

In FirebaseService.saveNoiseReading, read prefs 'anonymize_location'; when true, round lat/lng to ~2-3 decimals (or add random jitter within ~300 m) before both the online write and the offline queue entry.

---

#### [flow7-01] PayPal success/cancel detection can never fire - donation completion is never observed

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/widgets/paypal_webview_widget.dart:121`

**Verifier verdict (CONFIRMED):** The donation URL (paypal_webview_widget.dart:41-43) is a legacy `cmd=_donations` link with NO `return`, `cancel_return`, or `rm` parameters, so PayPal never redirects to any URL containing `payment=success`, `payment=completed`, or `payment=cancel(led)` — the strings checked in onLoadStop (lines 121-128). PayPal's actual post-donation flow stays on paypal.com confirmation pages whose URLs don't contain these merchant-invented query params. Additionally, shouldOverrideUrlLoading (lines 141-154) cancels any non-PayPal navigation, so even a configured external return URL would be blocked. Consequently `_onPaymentSuccess`/`_onPaymentCancelled` (lines 285-301), including DonationService.recordDonation, are dead code paths and donation completion is never observed. Finding is accurate as stated.

**Description:**

The donation URL built at lines 41-43 is a classic webscr 'cmd=_donations' link with only business, item_name, amount and currency_code params. It sets no 'return', 'cancel_return' or 'rm' parameters, so PayPal never redirects the webview to any URL containing 'payment=success', 'payment=completed' or 'payment=cancel'. The checks in onLoadStop (lines 121-128) and therefore _onPaymentSuccess (line 285) and _onPaymentCancelled (line 296) are unreachable dead code: the donation is never recorded via DonationService.recordDonation, the thank-you dialog never shows, and the cancellation snackbar never shows.

**Failure scenario:**

User taps 'Donate with PayPal', completes the donation on paypal.com, and lands on PayPal's own receipt page. The app never detects success, records nothing locally, shows no confirmation, and the user is stranded inside the webview with only the AppBar X to escape. Cancelling on PayPal likewise produces no feedback.

**Recommended fix:**

Append '&return=<marker-url>?payment=success&cancel_return=<marker-url>?payment=cancelled&rm=0' to the URL (marker can be any URL you intercept, e.g. https://noisemapper.app/donate) and intercept those marker URLs in shouldOverrideUrlLoading to call _onPaymentSuccess/_onPaymentCancelled and CANCEL the navigation. Longer term, migrate to the PayPal Orders API / SDK for verifiable results.

---

#### [donate-1] PayPal success/cancel detection can never fire - completion flow is dead code

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/widgets/paypal_webview_widget.dart:42`

**Verifier verdict (CONFIRMED):** The donation URL (paypal_webview_widget.dart:41-43) is a classic `cmd=_donations` link with NO `return` or `cancel_return` parameters, so PayPal never redirects to any URL containing `payment=success`/`payment=completed`/`payment=cancel`/`payment=cancelled` — the substrings checked in onLoadStop (lines 121-127). DonationService (donation_service.dart:9-12) supplies only clientId/sandbox flag; no return URLs anywhere. Even if return URLs existed, shouldOverrideUrlLoading (lines 141-153) cancels any navigation not containing paypal.com/paypalobjects.com/braintreegateway.com, so a custom-scheme or app return URL would never reach onLoadStop. Therefore _onPaymentSuccess (line 285) and _onPaymentCancelled (line 296), plus the "Payment Complete!" overlay (line 195), are unreachable dead code, exactly as claimed.

**Description:**

The donation URL built at lines 41-43 (webscr?cmd=_donations&business=...&amount=...&currency_code=...) contains no 'return', 'cancel_return', or 'rm' parameters. PayPal's legacy donations flow only redirects to merchant-supplied return URLs; it never produces a URL containing 'payment=success', 'payment=completed', 'payment=cancel', or 'payment=cancelled', which is what onLoadStop checks at lines 121-128. Therefore _onPaymentSuccess (line 285) and _onPaymentCancelled (line 296) are unreachable: DonationService.recordDonation is never called (confirmed it is the only call site in the codebase), the thank-you dialog never shows, and the cancellation snackbar never shows.

**Failure scenario:**

User selects $10, completes a real PayPal payment inside the webview. PayPal shows its own confirmation page; the app never records the donation, never shows 'Thank You', and the 'Payment Complete!' overlay never appears. If the user cancels, no 'Donation cancelled' message appears either. The user must manually tap the close X with no in-app acknowledgment of what happened.

**Recommended fix:**

Append URL-encoded return parameters to the donation URL, e.g. '&return=https://<yourdomain>/donate?payment=success&cancel_return=https://<yourdomain>/donate?payment=cancel&rm=1', then in onLoadStop match on your exact return host+path (not substrings). Alternatively migrate to the PayPal Orders API / an SDK with proper callbacks.

---

#### [map-2] Map data can never be refreshed — stale markers/heatmap after a new recording or deletion

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/map_view_screen.dart:603`

**Verifier verdict (CONFIRMED):** The defect is real. Evidence from C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper: (1) Map data is loaded exactly once — `_loadNoiseMarkers()` (lib/screens/map_view_screen.dart:123) is called only from `initState` (line 101) and from `_refreshAllData` (line 159-161), which is reachable only via `RefreshIndicator.onRefresh` (lines 603-607). It uses the one-shot `getNoiseReadingsOnce()` Future (lib/services/firebase_service.dart:174), not a snapshot stream, so there are no live updates by design. (2) The screen never re-initializes: `MapViewScreen(isInAppShell: true)` is a permanent child of the `IndexedStack` in lib/widgets/main_app_shell.dart:38-46, so `initState` runs once per app session and there is no tab-visibility or navigation-return hook that reloads data. (3) The sole refresh mechanism is dead UI: `RefreshIndicator` fires only on ScrollNotifications from a descendant Scrollable at depth 0, but its child is a `Stack` whose interactive surface is `FlutterMap` (flutter_map ^7.0.2), which handles vertical drags with its own gesture recognizers to pan the map and contains no Scrollable. Pulling down on the map therefore pans the map and never triggers `onRefresh`. There is no other refresh affordance (no refresh FAB; the FABs at lines 1049-1067 only toggle heatmap and re-center location; no delete flow exists in this screen). Net effect: after a new recording (made on the Dashboard tab) or a deletion (made in History), the map's `_cachedMarkers` and `_heatmapPoints` remain whatever was fetched at app startup until the app is restarted — exactly as the finding states. Minor caveat that does not change the verdict: the search-autocomplete dropdown (`ListView.builder`, line 987, shown only when `_searchResults.isNotEmpty` with maxHeight 250) is a depth-0 Scrollable inside the RefreshIndicator, so overscrolling an overflowing results list could accidentally fire `onRefresh`; this is an obscure, unintended path (requires an active search with enough results to overflow 250px), not a functioning refresh mechanism, and a full app restart also reloads — neither constitutes "refreshing" in any practical sense.

**Description:**

Markers and heatmap points are loaded exactly once in initState (lines 100-101) via a one-shot get(). MapViewScreen lives permanently in the shell IndexedStack (widgets/main_app_shell.dart:38-46), so initState never re-runs on tab switches, and nothing (GlobalKey/callback/stream) notifies it of writes. The only intended refresh path, RefreshIndicator (lines 603-607), requires ScrollNotifications from a scrollable descendant — its child is a Stack containing FlutterMap, which produces none, so onRefresh is physically unreachable. History screen deletes docs directly (screens/history_screen.dart:721).

**Failure scenario:**

User records a new reading on Dashboard, switches to the Map tab: the new marker is absent. User deletes a reading in History: its marker stays on the map. There is no gesture or button in the UI that reloads the data; only a full app restart updates the map.

**Recommended fix:**

Trigger _loadNoiseMarkers() when the tab becomes active (pass an onTabSelected callback or GlobalKey<_MapViewScreenState> from MainAppShell, or use a shared ChangeNotifier/stream bumped by FirebaseService.save/delete). Remove the dead RefreshIndicator or add a working manual refresh button.

---

#### [flow2-7] Sync dead-end: recordings are abandoned forever after 3 failed attempts with no recovery or user surface

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/services/sync_service.dart:151`

**Verifier verdict (CONFIRMED):** Real. sync_service.dart:151 skips any recording with syncAttempts >= 3 with `continue`, and this same gate applies to manual sync (triggerManualSync:237 just calls syncOfflineRecordings). Grep for `syncAttempts` shows attempts are only ever incremented (sync_service.dart:171-176, offline_storage_service.dart:146-167, 258-282) — no code path resets them to 0 for an existing record. deleteRecording/clearAllRecordings (offline_storage_service.dart:285, 326) have zero callers in lib/. Stranded records stay counted in pendingCount (getPendingCount counts all !isSynced), so the sync indicator shows a pending count that can never drain, with no failure state, retry, or purge exposed to the user. Minor nuance: items are indirectly visible via the perpetual pending count, but there is no recovery path — the finding stands.

**Description:**

syncOfflineRecordings skips any recording with syncAttempts >= maxSyncAttempts (3) permanently (sync_service.dart:151-156). Attempts increment on any exception (:169-176), including transient ones (server hiccup, auth token refresh, brief captive-portal 'online' state per _isConnectedToInternet which only checks interface presence, :99-109). Skipped recordings are never synced, never deleted (clearSyncedRecordings only removes isSynced==true, offline_storage_service.dart:299-323), and still count as pending (getPendingCount, :340-358), so the sync indicator shows a pending count that can never drain.

**Failure scenario:**

Device connects to hotel WiFi with a captive portal: connectivity says online, three Firestore writes fail/time out 5s apart, syncAttempts hits 3. When real internet returns, those readings are silently skipped on every future sync - permanent data loss with a perpetual stale 'pending' badge in SyncStatusIndicator.

**Recommended fix:**

Reset syncAttempts on connectivity restoration (or use exponential backoff instead of a hard cap), and surface max-attempt recordings to the user with a manual 'retry failed' action in the sync status UI.

---

#### [social-4] Report can be submitted with hardcoded Colombo fallback coordinates and placeholder location names

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/report_noise_screen.dart:22`

**Verifier verdict (CONFIRMED):** Real. lib/screens/report_noise_screen.dart:22-24 initializes _latitude=6.9271, _longitude=79.8612 (Colombo) and _locationName='Unknown Location'. If GPS fails, all failure paths (lines 138-144 services disabled, 166-172 exception) return without updating coordinates, leaving _locationName as 'Fetching location...' or 'Location services disabled'. The submit button (line 456) is gated only on _isSubmitting, and _submitReport (lines 208-232) writes _latitude/_longitude/_locationName straight to Firebase via saveNoiseReading with no location-validity check. So a report with hardcoded Colombo coordinates and a placeholder name can be submitted exactly as claimed.

**Description:**

_latitude/_longitude default to 6.9271/79.8612 (lines 22-23) and _locationName to 'Unknown Location' (line 24). _submitReport (line 208) performs zero validation before writing to Firestore (lines 224-232). If GPS fails, permission is denied (lines 131-134 never check the result of requestPermission — denied/deniedForever falls through to getCurrentPosition which throws), or the user submits before the fetch finishes, the reading is saved at the hardcoded default coordinates with locationName 'Fetching location...', 'Location services disabled', or 'Unknown Location' — these placeholder strings are persisted verbatim and shown to everyone in the community feed and map.

**Failure scenario:**

User denies location permission, sets the slider to 90 dB and taps Submit within 2 seconds of the screen opening. A 90 dB 'reading' is written at central Colombo with locationName 'Fetching location...' and appears on the shared heatmap/community feed as real data.

**Recommended fix:**

In _submitReport, block submission (with an explanatory snackbar) while _isGettingLocation is true or while _locationName is one of the placeholder states ('Fetching location...', 'Location services disabled', 'Unknown Location'), and handle LocationPermission.denied/deniedForever explicitly after requestPermission instead of letting getCurrentPosition throw.

---

#### [flow4-4] Community feed shows every user's automatic 5-second monitoring samples — manual reports are drowned out of the 100-item window

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/community_feed_screen.dart:63`

**Verifier verdict (CONFIRMED):** community_feed_screen.dart:63-67 streams the latest 100 docs from noise_readings with no filter. Both writers use the same path: dashboard_screen.dart:487-503 runs Timer.periodic(5s) calling saveNoiseReading during monitoring, and report_noise_screen.dart:224 calls the same saveNoiseReading for manual reports. The written schema (firebase_service.dart:117-133) contains no field distinguishing manual reports from automatic samples, so no filter is even possible. One user monitoring ~8.5 minutes generates 100+ docs (12/min), completely filling the feed window and pushing out manual reports. Finding is real as described.

**Description:**

The feed query (community_feed_screen.dart:62-67) is collection('noise_readings').orderBy('timestamp', descending: true).limit(100) with no filter of any kind. The same collection receives an automatic write every 5 seconds per recording user from the dashboard live monitor (dashboard_screen.dart:487-503, Timer.periodic 5s calling saveNoiseReading). Neither writer (firebase_service.dart:117-133, sync_service.dart:211-220) writes any 'source'/'isManual' discriminator field, so the feed cannot distinguish a deliberate community report from a background sample. 100 items = ~8.3 minutes of a single user recording. The dashboard entry-card badge (dashboard_screen.dart:917, 997) has the same problem: it counts all of today's auto-samples as 'reports'.

**Failure scenario:**

User A records live audio on the dashboard for 10 minutes (120 auto-docs). User B submitted a manual report 15 minutes ago. User B opens Community Feed: all 100 cards are User A's near-identical 5-second samples ('See what others are reporting'); User B's actual report is pushed past the limit(100) cutoff and is unreachable — the feed has no pagination.

**Recommended fix:**

Write a discriminator (e.g. 'source': 'manual' | 'auto') in both writers, then filter the feed. Note: where('source', isEqualTo: 'manual') + orderBy('timestamp' desc) needs a NEW composite index (source ASC, timestamp DESC) — the project's only index is (userId ASC, timestamp DESC) — so plan the index deployment, or alternatively write manual reports to a separate 'community_reports' collection.

---

#### [flow3-1] Reader field 'soundCategory' never matches writer field 'soundClass' - heatmap points always lose classification

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/models/heatmap_point.dart:45`

**Verifier verdict (CONFIRMED):** heatmap_point.dart:45 reads `data['soundCategory'] as String?`, but every writer stores the classification under 'soundClass': firebase_service.dart:129 (`if (soundClass != null) data['soundClass'] = soundClass`) and sync_service.dart:224 (`data['soundClass'] = recording.soundClass`); sound_classification_service.dart:305 also emits 'soundClass'. Grep of the whole repo shows no code ever writes a 'soundCategory' key, so HeatmapPoint.soundCategory is always null, and heatmap_service.dart:96 (`point.soundCategory == category`) filters to an empty list for any concrete category. Defect is real exactly as described.

**Description:**

HeatmapPoint.fromFirestore reads `data['soundCategory'] as String?` (heatmap_point.dart:45). Both writers persist the classification under the key `soundClass` (firebase_service.dart:129 `data['soundClass'] = soundClass`; sync_service.dart:224 `data['soundClass'] = recording.soundClass`). Character-by-character: writer `soundClass` vs reader `soundCategory` - no match. Every HeatmapPoint built on the live map path (map_view_screen.dart:135 -> heatmap_service.dart:14) gets soundCategory == null, so HeatmapService.filterBySoundCategory (heatmap_service.dart:95-97, `point.soundCategory == category`) can never return a non-empty list for any real category.

**Failure scenario:**

A reading is saved with soundClass 'Traffic'. The map screen converts it to a HeatmapPoint; soundCategory is null. Any current or future call to HeatmapService.filterBySoundCategory(points, category: 'Traffic') returns an empty list, silently blanking the heatmap for every category filter, even though the data exists in Firestore.

**Recommended fix:**

In heatmap_point.dart:45 change to `soundCategory: data['soundClass'] as String?` (or rename the model field to soundClass for consistency with the rest of the app).

---

#### [offline-3] Sync is only triggered by an offline-to-online transition — never at startup, after login, or after a fallback offline save

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:83`

**Verifier verdict (CONFIRMED):** Automatic sync fires only in _onConnectivityChanged under `if (!wasOnline && _isOnline)` (sync_service.dart:83-88). initialize() (called once at startup, main.dart:51) sets _isOnline but never calls syncOfflineRecordings — so if the app starts already online with queued recordings, no transition ever occurs and they sit unsynced. Grep over lib/ shows the only other call site is the user-pressed "Sync Now" button (sync_status_indicator.dart:214), which is manual, not automatic. No FirebaseAuth authStateChanges listener triggers sync (syncOfflineRecordings bails at line 134 if user is null, and nothing retries after login), and nothing invokes sync after an offline fallback save. All three claimed gaps (startup, post-login, post-fallback-save) are real.

**Description:**

The only automatic trigger is `!wasOnline && _isOnline` in `_onConnectivityChanged` (lines 83-90). `initialize()` (called from main.dart:51) sets `_isOnline` but never starts a sync even when pending recordings exist. FirebaseService's error-fallback path (firebase_service.dart:70-90) queues a recording while the device is *online* — no transition will ever occur, so it sits until the network flaps or the user finds the manual Sync Now button. Similarly, if sync is skipped because `_auth.currentUser == null` (line 134), nothing re-triggers after login.

**Failure scenario:**

User records offline, force-quits the app, relaunches at home on wifi. The app starts already-online, so no offline→online transition ever fires; the recordings remain queued indefinitely with the badge stuck showing a pending count until the user manually opens the sync dialog and taps Sync Now (or toggles airplane mode).

**Recommended fix:**

At the end of `initialize()`, if `_isOnline && _storage.getPendingCount() > 0`, call `syncOfflineRecordings()`. Also trigger a sync after any offline save while online (expose a `notifyQueued()` hook FirebaseService calls), and listen to `FirebaseAuth.authStateChanges()` to sync once a user logs in.

---

#### [flow1-2] Onboarding is never persisted as seen — it replays on every signed-out launch and every logout

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/splash_screen.dart:36`

**Verifier verdict (CONFIRMED):** splash_screen.dart:36-42 unconditionally pushes OnboardingScreen after a 3s timer — no persisted flag is checked. A project-wide grep for onboarding/hasSeenOnboarding shows no SharedPreferences (or any) write/read of a "seen" flag; onboarding_screen.dart:37-41 just pushes LoginScreen without persisting anything. main.dart:150-162 routes every signed-out state (initial launch and post-logout, since authStateChanges emits null on signOut) to SplashScreen, so onboarding replays on every signed-out launch and every logout, exactly as claimed.

**Description:**

splash_screen.dart:36-42 unconditionally pushes OnboardingScreen after a 3s timer. A project-wide grep for any onboarding/first-launch SharedPreferences key returns nothing — no 'onboarding_seen' flag is ever written or read, even though shared_preferences is a dependency (pubspec.yaml:71) and main.dart already uses it for theme prefs (lines 55-63). The expected behavior is onboarding shown exactly once. Additionally dashboard logout (dashboard_screen.dart:694-699) routes to SplashScreen, so every logout replays splash + onboarding too.

**Failure scenario:**

A returning user who is signed out (or who taps logout) opens the app: they wait through the 3s splash and must dismiss the 'Protect your hearing' onboarding card again — on the 2nd, 3rd, and every subsequent launch, not just the first.

**Recommended fix:**

In OnboardingScreen's 'Get started' handler set prefs.setBool('onboarding_seen', true); in SplashScreen's timer read the flag and pushReplacement to LoginScreen directly when it is true (and have logout route to LoginScreen, not SplashScreen).

---

#### [analytics-3] Stats, pie chart, breakdown and readings count are loaded once in initState and never refresh, while the trend chart live-updates — contradictory data on the same screen

**Severity:** High | **Status:** disputed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:47`

**Verifier verdict (PARTIAL):** The core defect is real: stats/pie/breakdown come from one-shot fetches (analytics_screen.dart:122-124 → calculateStatsByPeriod + getUserReadingsByPeriodOnce, which uses .get(), firebase_service.dart:278), while the trend chart uses a live StreamBuilder on .snapshots() (analytics_screen.dart:982-983, firebase_service.dart:265). New readings update the trend chart but not the stats — inconsistent data on one screen. However, "loaded once in initState and never refresh" is overstated: _loadStatistics() also reruns on every period-chip tap (analytics_screen.dart:494), refreshing all one-shot data. So it refreshes on user interaction, just not live.

**Description:**

_loadStatistics() is called only from initState (line 49) and from period-chip taps (line 494). MainAppShell keeps AnalyticsScreen permanently alive in an IndexedStack (main_app_shell.dart:38-46), so switching tabs never re-runs initState. The stat cards, banner readings count, pie chart, category breakdown, and confidence card are built from one-shot .get() calls (lines 122-124), whereas the trend chart subscribes to a live snapshots() stream (firebase_service.dart:259-265). The 'since' anchor (line 94) also freezes at load time, so after the app is open long enough the 'Last 24 Hours' window silently drifts.

**Failure scenario:**

User opens the app (Analytics loads with 100 readings), records for 10 minutes on the Dashboard tab (~120 new readings), then switches to the Analytics tab. The trend chart includes the new readings (live stream), but the banner still says '100 readings' and Average/Lowest/Highest, pie chart and category breakdown all show launch-time values. Nothing on screen offers a way to refresh.

**Recommended fix:**

Re-run _loadStatistics when the tab becomes visible (pass the shell's current index / a ValueNotifier into AnalyticsScreen, or use a VisibilityDetector), and/or wrap the body in a RefreshIndicator. Alternatively derive stats, pie counts and breakdown from the same stream snapshot inside the StreamBuilder so everything updates together and the .get() calls disappear.

---

#### [flow5-3] No duplicate-upload protection: sync uses collection.add() with auto ID and marks synced only after the ack

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:233`

**Verifier verdict (CONFIRMED):** lib/services/sync_service.dart:233 uses `_firestore.collection('noise_readings').add(data)` — auto-generated doc ID, and `recording.id` is never written to the document (data map at lines 211-231 contains no client ID/idempotency key). markAsSynced runs only after the add resolves (lines 162-165). So: (1) if the write commits server-side but the ack is lost (network drop/timeout), the catch at 169 increments attempts and the record is re-uploaded on retry as a new doc; (2) if the app dies between add success and markAsSynced, same duplicate on next sync. No deterministic doc ID (e.g. doc(recording.id).set) or server-side dedup exists, so duplicates are undetectable/uncleanable. The `_isSyncing` flag only guards concurrent runs, not re-upload. Finding is accurate as stated.

**Description:**

SyncService._saveToFirebase uploads via `_firestore.collection('noise_readings').add(data)` (line 233) — a new auto-generated document ID on every attempt — and markAsSynced runs only after the await returns (line 165). Firestore offline persistence is enabled globally (main.dart:41-44), so a write started during flaky connectivity is durably queued inside the Firestore SDK cache; if the app process is killed before the future resolves, the SDK will deliver that write on next launch, while the Hive record is still isSynced=false and gets uploaded again by the next sync. The same double-write happens if the app crashes in the window between the server commit and markAsSynced.

**Failure scenario:**

Sync starts as the phone briefly regains signal; add() for recording X is committed to Firestore's local write queue, then the user swipes the app away. On next launch Firestore's SDK flushes the queued write (doc 1); the record is still pending in Hive, so the next sync add()s it again (doc 2). The reading now appears twice in History, doubles its weight in analytics averages, and shows two markers on the map.

**Recommended fix:**

Make the upload idempotent with a deterministic document ID: `_firestore.collection('noise_readings').doc(recording.id).set(data)`. Retries then overwrite the same document instead of creating duplicates. (recording.id = '${ms}_$uid' is already unique per reading.)

---

#### [dash-6] Recording continues invisibly on tab switch and app background; frozen _currentDb is re-saved every 5s as fresh data

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:102`

**Verifier verdict (CONFIRMED):** All three components verified in code. (1) Tab switch: lib/widgets/main_app_shell.dart:38-54 hosts DashboardScreen in an IndexedStack and tab taps only change the index, so the screen stays mounted, dispose() never runs, and the timer guards at lib/screens/dashboard_screen.dart:489 and :511 ("if (!_isRecording || !mounted) return;") both pass — noise stream, audio recorder, save timer, and classification timer all keep running with no indicator on other tabs. (2) Background: didChangeAppLifecycleState (dashboard_screen.dart:102-114) handles only AppLifecycleState.resumed (location refresh); there is no paused/inactive branch anywhere, so nothing stops recording on background, and no foreground service exists in the project. (3) Frozen re-save: the save timer (lines 487-503) writes _currentDb to Firestore every 5s with only a ">0 && isFinite" guard and no reading-freshness check. When Android 9+ silences mic input for the backgrounded app, near-zero readings hit the "rawDb < 10" filter at line 398 and are discarded, so _currentDb freezes at its last foreground value while the still-running Timer.periodic saves that stale value (plus stale lat/lng/locationName) as fresh data via firebaseService.saveNoiseReading, which writes unconditionally. Minor nuance only: on a pure foreground tab switch the mic stays live so _currentDb keeps updating (recording is still invisible, but not frozen); the frozen-value re-save materializes in the backgrounded case and in the stream-error case (onError at line 441 deliberately does not cancel). This matches the finding as described.

**Description:**

DashboardScreen lives at index 2 of MainAppShell's IndexedStack (lib/widgets/main_app_shell.dart lines 38-46), so switching tabs never disposes it and nothing observes tab visibility — the noise subscription, mic, and both timers keep running with no on-screen indication. `didChangeAppLifecycleState` (lines 102-114) handles only `resumed` (location refresh); on `paused` nothing stops recording. On Android 9+ a backgrounded app without a foreground service receives silence from the mic, so `rawDb` drops below 10 and is filtered (line 398), leaving `_currentDb` frozen at its last valid value — while the save timer (lines 487-503) keeps passing its `_currentDb > 0` check and writes that identical stale reading every 5 seconds for as long as the process runs.

**Failure scenario:**

User starts recording at 78 dB, taps the Map tab and then backgrounds the app for 10 minutes. The mic goes silent, _currentDb freezes at 78, and ~120 identical 78 dB readings are written to Firestore, fabricating a sustained high-noise event on the community map; battery drains and the mic stays held with zero UI indication.

**Recommended fix:**

Stop (or pause) recording in `didChangeAppLifecycleState` on `AppLifecycleState.paused`/`inactive`, or add a timestamp guard so the save timer skips saving when no new reading has arrived since the last save (track `_lastReadingAt`). For tab switches, either surface a persistent recording indicator in the shell or have MainAppShell notify tabs of visibility so Dashboard can auto-stop.

---

#### [flow5-2] Offline recordings sync under whichever user is logged in at sync time — OfflineRecording has no userId field

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/models/offline_recording.dart:5`

**Verifier verdict (CONFIRMED):** OfflineRecording (lib/models/offline_recording.dart:4-16) has no userId field — not in the constructor, toMap, or fromMap. The queue is a single shared Hive box 'recordings_queue' (offline_storage_service.dart:13,35), not user-scoped. At sync time, sync_service.dart:133 takes _auth.currentUser and line 162/210-212 writes 'userId': user.uid for every queued recording. So recordings queued by user A and synced after user B logs in are attributed to B. firebase_service.dart:148 embeds the original uid only in the id string ('${millis}_$userId'), but it is never parsed back during sync. Defect is real as described.

**Description:**

OfflineRecording (offline_recording.dart:5-16) stores id, dB, location, timestamp, classification — but no userId. FirebaseService._saveOffline (firebase_service.dart:148) only embeds the recorder's uid inside the id string ('${ms}_$userId'), which is never parsed back. When SyncService.syncOfflineRecordings runs, it stamps every queued recording with the CURRENT FirebaseAuth user's uid (sync_service.dart:133, 162, 212: 'userId': userId from user.uid). Additionally, if no user is logged in when connectivity returns, sync aborts (sync_service.dart:134-137) and the queue simply waits for the next user.

**Failure scenario:**

User A records offline readings, logs out. User B logs in on the same device; the phone regains connectivity (or B taps Sync Now). A's readings — including A's precise GPS locations and timestamps — are uploaded with userId=B. They appear in B's History and Analytics (getUserReadings filters userId), pollute B's stats, and A's location trail is disclosed to B: wrong data attribution plus a privacy leak.

**Recommended fix:**

Add a `userId` field to OfflineRecording (model, toMap, fromMap, copyWith), set it in FirebaseService._saveOffline from user.uid, and in SyncService._saveToFirebase write recording.userId instead of the current user's uid. In the sync loop, skip (or defer) recordings whose userId != _auth.currentUser.uid. Handle legacy queued maps missing userId by falling back to parsing the id suffix.

---

#### [social-5] 'Noise report submitted successfully!' shows even when nothing was saved — error path is unreachable

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/report_noise_screen.dart:235`

**Verifier verdict (CONFIRMED):** FirebaseService.saveNoiseReading (lib/services/firebase_service.dart:16-92) can never throw: the entire body is wrapped in try/catch that only logs (line 70-91), the fallback offline save's own failure is swallowed at line 88-90, and a null user silently returns at line 27-30 with nothing saved. Therefore the await at report_noise_screen.dart:224 always completes normally, the catch at line 245 is unreachable, and the 'Noise report submitted successfully!' snackbar (line 235-240) plus Navigator.pop fire even when the user is logged out or both online and offline saves failed. Defect is real exactly as described.

**Description:**

_submitReport's catch block (lines 245-253) can never fire for save failures because FirebaseService.saveNoiseReading swallows everything: it silently returns when currentUser is null (firebase_service.dart lines 27-30), and its outer catch (lines 70-91) absorbs both the online failure and a failed offline fallback without rethrowing. The screen then unconditionally shows the green success snackbar and pops (lines 234-244).

**Failure scenario:**

The user's auth session expires while the Report screen is open (or Firestore write fails AND the Hive offline queue write also fails, e.g. storage full). saveNoiseReading returns normally having saved nothing; the user sees 'submitted successfully!' and the screen closes. The reading is silently lost.

**Recommended fix:**

Make saveNoiseReading return a result (e.g. enum saved/queued/failed) or rethrow when both persistence paths fail / no user is present, and have _submitReport branch the snackbar on that result ('Submitted', 'Saved offline — will sync', or the error path).

---

#### [flow1-1] Unguarded Firebase.initializeApp dead-ends the app before runApp with no error UI

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/main.dart:38`

**Verifier verdict (CONFIRMED):** lib/main.dart:26-72 confirms the defect. Line 38 `await Firebase.initializeApp(...)` has no try/catch, and neither do the subsequent pre-runApp awaits: Firestore settings (41-44), NotificationService.initialize/requestPermission (47-48), SyncService().initialize() (51), SharedPreferences.getInstance() (55). runApp is only reached at line 71; any throw in those awaits propagates out of main(), leaving the engine attached with no widget tree — a permanent blank screen with no error UI. Only dotenv (30-36) and the TFLite/sound-classification steps (75-127) are wrapped in try/catch, so the "any pre-runApp startup await" wording is accurate for the Firebase/notification/sync/prefs chain. There is no runZonedGuarded, PlatformDispatcher.onError, or fallback error app anywhere in main.dart.

**Description:**

main() awaits Firebase.initializeApp at line 38 with no try/catch, and everything after it (Firestore settings line 41, NotificationService line 47-48, SyncService line 51, runApp line 71) is unreachable if it throws. firebase_options.dart:28-45 explicitly throws UnsupportedError for macOS/Windows/Linux, and on Android/iOS any init failure (corrupt google-services config, plugin registration failure) is an uncaught exception in main(). dotenv at lines 30-36 IS guarded, showing the pattern was known but not applied to the one call that can actually kill startup.

**Failure scenario:**

User launches the app on a device where Firebase initialization throws (e.g. desktop platform target, or broken Google Play Services / misconfigured firebase_options). The exception escapes main(), runApp is never called, and the user stares at the frozen native splash screen forever with no message and no retry.

**Recommended fix:**

Wrap Firebase.initializeApp (and the dependent init block) in try/catch; on failure call runApp with a minimal error screen offering a retry button, and gate Firestore/notification/sync init behind the success flag.

---

#### [flow6-05] Clear History, Delete Account, and profile-email propagation all use a single unchunked WriteBatch — fails outright for users with >500 readings

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:1027`

**Verifier verdict (CONFIRMED):** All three flows use one unchunked WriteBatch over an unbounded query of the user's noise_readings, exceeding Firestore's 500-op batch limit for heavy users. Clear History: settings_screen_enhanced.dart:1021-1031 (query all, one batch.delete loop, single commit). Delete Account anonymization: settings_screen_enhanced.dart:887-901 (one batch.update loop, single commit). Email propagation: edit_profile_screen.dart:127-139 (one batch.update loop, single commit) — note this third case lives in edit_profile_screen.dart, not settings_screen_enhanced.dart, but the defect is identical. No chunking anywhere; commit() throws with >500 docs, so each operation fails outright for such users.

**Description:**

Firestore batches are limited to 500 operations. _clearHistory (lines 1021-1031), _deleteAccount (lines 887-901), and edit_profile_screen.dart:127-139 each put ALL of the user's noise_readings docs into one batch and commit once. The dashboard auto-saves a reading every 5 seconds while recording (dashboard_screen.dart:487), so 500 docs is only ~42 minutes of total recording time — the failure case is the normal case.

**Failure scenario:**

A user with 1,200 readings taps Settings > Clear History > Clear. batch.commit() throws (batch exceeds 500 writes), the generic catch shows 'Failed to clear history', and nothing is deleted. The same user can never delete their account through the app either.

**Recommended fix:**

Chunk the docs into batches of <=450 and commit sequentially (for (chunk in docs.slices(450)) { batch...commit(); }) in all three places; extract a shared helper.

---

#### [flow4-3] 'Report with image' leg of the flow does not exist — ImageCompressionService is unreachable dead code

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** L

**Location:** `lib/services/image_compression_service.dart:12`

**Verifier verdict (CONFIRMED):** ImageCompressionService is defined at lib/services/image_compression_service.dart:12 but a project-wide grep for "ImageCompressionService|image_compression_service" finds zero matches in lib/ other than the definition itself (all other hits are audit docs and graphify cache). A grep of lib/ for image_picker, ImagePicker, firebase_storage, and imageUrl returns no matches, so no image pick/compress/upload pipeline or "report with image" leg exists anywhere in app code. The service is never imported or instantiated — unreachable dead code, exactly as the finding states.

**Description:**

ImageCompressionService has zero call sites: grep across lib/ finds no import of image_compression_service.dart anywhere. report_noise_screen.dart contains no image picker UI (only dB slider, sound-class dropdown, location pill); firebase_service.dart:_saveToFirebase (117-133) writes no image/imageUrl field; community_feed_screen.dart renders no image. Meanwhile pubspec.yaml declares image_picker ^1.1.2 (line 65), firebase_storage ^12.3.8 (line 34) and flutter_image_compress ^2.1.0 (line 101), none of which are imported anywhere in lib/ except the dead service (verified by grep for 'package:image_picker' and 'package:firebase_storage' — no matches). The service itself also has latent defects should it ever be wired up: compressWithList's minWidth/minHeight params (lines 26-27) are minimums, not the maximums the constants claim (_maxWidth/_maxHeight), and line 34 divides by originalSize which is 0 for images under 1KB (produces '-Infinity%' in logs). Its failure paths (return original bytes at line 44, return null at line 80) are handled but have no consumer.

**Failure scenario:**

A user wants to attach a photo of the construction site to their noise report. There is no attach button on the report screen; the report is saved without any image field; the community feed can never display one. The entire compression service, plus three pubspec dependencies, ship in the binary without ever executing.

**Recommended fix:**

Either implement the leg: add an image_picker button to report_noise_screen, run the file through ImageCompressionService.compressImageFile (falling back to the original path on null), upload to Firebase Storage, write 'imageUrl' into the noise_readings doc in firebase_service._saveToFirebase, and render it in community_feed_screen's card; or delete image_compression_service.dart and remove image_picker/firebase_storage/flutter_image_compress from pubspec.yaml.

---

#### [flow2-3] Writer/writer field mismatch: offline-sync path omits userEmail that the online path writes and readers consume

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:211`

**Verifier verdict (CONFIRMED):** Both variants hold. (1) sync_service.dart:217 writes 'timestamp': FieldValue.serverTimestamp() and puts the actual recording time only in 'createdAt' (line 218: recording.timestamp). Readers sort and display by 'timestamp' (history_screen.dart:232 orderBy('timestamp'), :253/:453 display it), so offline-synced readings show the sync time, not the recording time. (2) The online writer firebase_service.dart:119 includes 'userEmail': _auth.currentUser?.email, while the offline-sync writer's data map (sync_service.dart:211-220) omits userEmail entirely. Readers consume it: community_feed_screen.dart:171 (falls back to 'Anonymous') and history_screen.dart:262 ('N/A'). No crash due to fallbacks, but offline-synced readings render as Anonymous/N/A — a real writer/writer field mismatch as described.

**Description:**

Online write (firebase_service.dart:119) includes 'userEmail': _auth.currentUser?.email. The offline-sync write (sync_service.dart:211-231) builds the document without userEmail at all. Readers consume this field: community_feed_screen.dart:171 (report['userEmail'] ?? 'Anonymous') and history_screen.dart:262 CSV export (data['userEmail'] ?? 'N/A'). So documents produced by the same user flow have two different shapes depending on connectivity at save time.

**Failure scenario:**

User records readings while offline; they sync later. In the Community Feed those readings display as 'Anonymous' while the user's online readings show their name; the CSV export shows 'N/A' in the User Email column for the same person's data. Inconsistent identity data for identical user actions.

**Recommended fix:**

In SyncService._saveToFirebase add 'userEmail': _auth.currentUser?.email (or better, persist the email in OfflineRecording at record time alongside userId per flow2-2) so both writers produce identical document shapes.

---

#### [flow3-3] Deleting a recording does not remove it from the History list or update the count

**Severity:** High | **Status:** confirmed | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/history_screen.dart:721`

**Verifier verdict (CONFIRMED):** CONFIRMED. The list is local paginated state, not a stream: _recordings is a List<DocumentSnapshot> filled by one-time paginated .get() queries (history_screen.dart:27, 93-105, 136-148). The delete handler (lines 719-731) calls FirebaseFirestore...doc(docId).delete() with no try/catch, then only pops the dialog and shows a "Recording deleted" snackbar — it never removes the doc from _recordings, calls no setState, doesn't decrement _totalCount, and doesn't call _loadInitialRecordings. So the deleted item stays visible and "Showing ${_recordings.length} of $_totalCount" (line 392) is stale until pull-to-refresh. If delete() throws, the unhandled await leaves the dialog open with no error feedback. All variant wordings are accurate.

**Description:**

_showDeleteConfirmation's Delete button (history_screen.dart:720-731) awaits `FirebaseFirestore.instance.collection('noise_readings').doc(docId).delete()`, pops the dialog, and shows a snackbar - but never removes the doc from the local `_recordings` list (line 27), never decrements `_totalCount` (line 31), and never calls setState/_loadInitialRecordings. The list was loaded via one-shot paginated .get() (lines 93-96), so nothing observes the server-side delete.

**Failure scenario:**

User taps delete on a recording and confirms. Snackbar says 'Recording deleted', but the row remains fully visible in the list and 'Showing 50 of 120 recordings' still shows the old count. Tapping delete on the same row again attempts to delete an already-deleted doc. Only a manual pull-to-refresh fixes the display.

**Recommended fix:**

After the successful delete, call setState(() { _recordings.removeWhere((d) => d.id == docId); _totalCount -= 1; }); (and guard against negative counts). Optionally route the delete through FirebaseService instead of a raw Firestore call.

---

### Medium

#### [flow4-7] Offline-synced reports show upload time instead of recording time ('Just now' for a 3-day-old reading)

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/community_feed_screen.dart:174`

**Description:**

The reader prefers 'timestamp' and only falls back to 'createdAt' when timestamp is null (community_feed_screen.dart:174-183). For offline-synced docs, SyncService._saveToFirebase writes timestamp = FieldValue.serverTimestamp() at SYNC time and createdAt = recording.timestamp, the true recording time (sync_service.dart:217-218). After sync, timestamp is non-null, so _getTimeAgo (line 208) renders the upload time, and orderBy('timestamp') sorts the old reading to the top of the feed. The dual-timestamp convention is handled for the null case, but the semantic mismatch between the two writers makes the displayed age wrong for every offline report.

**Failure scenario:**

User records 92 dB construction noise on Friday with no signal. Monday morning the queue syncs. The community feed shows the report at the very top labeled 'Just now', misleading everyone about when the noise actually occurred.

**Recommended fix:**

In SyncService._saveToFirebase write 'timestamp': Timestamp.fromDate(recording.timestamp) (keeping createdAt as-is), or have the feed card display createdAt when it differs materially from timestamp.

---

#### [flow2-13] Restart race: un-awaited _stopRecording can close the NEW session's audio stream and reset _isRecording mid-recording

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:372`

**Description:**

When _startRecording finds the recorder already running (:370-375) it fires _stopRecording() WITHOUT awaiting (it is async void) and waits only 200ms. _stopRecording's stopRecorder await can take up to 3s (timeout at :553-559). Meanwhile the new session creates a new _audioStreamController (:456), starts the recorder (:472), and sets _isRecording=true (:482). When the stale _stopRecording invocation resumes, it closes _audioStreamController (:569) - which now references the NEW controller - nulls it (:573), clears _audioBuffer (:575), and setState(_isRecording = false) (:578-584).

**Failure scenario:**

Recorder is left running from a stop that previously timed out; user taps record. 1-3 seconds into the new session the UI flips back to 'Tap to measure', the save timer's '!_isRecording' guard (:489) stops all Firestore saves, and classification stops receiving audio - while flutter_sound is still actually recording the mic.

**Recommended fix:**

Make _stopRecording return Future<void> and await it in _startRecording (replacing the 200ms delay); additionally capture the controller in a local variable inside _stopRecording so a stale invocation cannot close a newer session's controller.

---

#### [flow5-8] 'Sync Now' gives no feedback — snackbar guarded by the popped dialog's dead context, and its message would be wrong anyway

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:212`

**Description:**

The Sync Now button's onPressed (sync_status_indicator.dart:212-217) captures the showDialog builder's context (shadowing the State's), calls Navigator.pop(context), awaits triggerManualSync(), then checks `context.mounted` — but the dialog element is unmounted after the pop, so the check is false and _showSyncResultSnackbar never runs. The user gets zero feedback. Even if it did run, _showSyncResultSnackbar (lines 263-278) unconditionally reports 'Synced $initialCount recording(s) successfully!' using the pre-sync pendingCount and a green background, while the actual return value of triggerManualSync (which is 0 on total failure, sync_service.dart:237-243) is discarded.

**Failure scenario:**

User taps Sync Now with 5 pending on a dead connection. The dialog closes and nothing else happens — no snackbar, badge still shows 5. If the context bug were fixed alone, they would instead see 'Synced 5 recording(s) successfully!' in green despite 0 uploads — both variants misrepresent the sync outcome.

**Recommended fix:**

Capture `final synced = await _syncService.triggerManualSync();` inside the button, use the State's `mounted` and `this.context` (or a pre-captured ScaffoldMessengerState) instead of the dialog context, and show 'Synced X of Y' with error styling when synced < pendingCount or 0.

---

#### [flow6-07] Name-only profile save fetches every reading and commits EMPTY batch updates

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/edit_profile_screen.dart:135`

**Description:**

The block at lines 126-141 runs when `emailChanged || nameChanged`, but the update map is `{ if (emailChanged) 'userEmail': newEmail }` — an empty map when only the name changed. So a rename fetches the user's entire noise_readings collection (line 127-130) and issues one empty update per doc. Firestore SDKs reject empty update payloads ('Invalid data. Data must not be empty' on Android), which lands in the generic catch at line 193 and shows 'Error updating profile' even though the display name WAS already saved (lines 86-95) — and at best it is a full-collection read plus N pointless writes.

**Failure scenario:**

User with 300 readings edits only their display name and taps Save Changes. The app reads 300 docs, the batch commit rejects the empty updates, and the user sees a red 'Error updating profile: ...' snackbar despite the rename having succeeded — they retry repeatedly, burning quota each time.

**Recommended fix:**

Guard the block with `if (emailChanged)` instead of `if (emailChanged || nameChanged)` (line 126), or include a real field (e.g. 'userDisplayName': newName) in the update map if name propagation to readings is intended.

---

#### [flow2-12] Mic-permission-denied record tap fails silently and leaks the noise-meter subscription

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:515`

**Description:**

_startRecording (dashboard_screen.dart:361-518) never checks Permission.microphone.status. If permission was denied (dialog at :156 dismissed), the NoiseMeter stream (:381) delivers errors to onError which only logs (:441-444), and _audioRecorder.startRecorder (:472) throws, jumping to the catch (:515-517) which only logs. Consequences: _isRecording is never set true so the button visually does nothing; no snackbar/dialog tells the user why; and _noiseSubscription created at :381 is never cancelled on this error path (only _stopRecording cancels it, which the user cannot trigger because _isRecording is false), leaking the subscription on every tap.

**Failure scenario:**

User denied mic permission at first launch, later taps the record button repeatedly: nothing visible happens, no explanation is shown, and each tap leaks another active noise-meter stream subscription with its platform channel.

**Recommended fix:**

At the top of _startRecording, check 'if (!await Permission.microphone.isGranted)' and show _showPermissionDeniedDialog; in the catch block cancel _noiseSubscription (and cancel the audio stream controller) and show a SnackBar with the failure reason.

---

#### [flow7-04] Navigation allowlists silently block 3-D Secure and login redirects, freezing checkout mid-payment

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/widgets/paypal_webview_widget.dart:153`

**Description:**

shouldOverrideUrlLoading (lines 141-154) CANCELs every navigation whose URL does not contain 'paypal.com', 'paypalobjects.com' or 'braintreegateway.com'. Guest card payments frequently require a 3-D Secure challenge hosted on the card issuer's or ACS provider's domain (e.g. cardinalcommerce.com, bank domains) - those redirects are cancelled with only a log line, no user feedback. The Buy Me a Coffee widget has the same problem (buy_me_coffee_widget.dart lines 62-72): only buymeacoffee.com/stripe.com/paypal.com pass, so social login (accounts.google.com) and issuer 3DS pages are blocked.

**Failure scenario:**

A donor without a PayPal account pays by card; their bank triggers a 3DS challenge redirect to a non-PayPal domain. The navigation is silently cancelled, the page appears frozen on the card form, and the payment can never complete - a hard dead end with no error shown.

**Recommended fix:**

Instead of cancelling unknown domains outright, open unknown https URLs in the external browser via url_launcher (already in pubspec.yaml line 93), or extend the allowlist with known payment-authentication domains. At minimum, show a snackbar when a navigation is blocked instead of failing silently.

---

#### [ml-9] Model-load failure silently disables classification forever with no retry, while the audio-capture pipeline keeps running

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:592`

**Description:**

SoundClassificationService.initialize() is called exactly once, in main.dart:109; on failure it logs and returns false (sound_classification_service.dart:65-69) and is never retried anywhere. _performSoundClassification then returns silently on every tick because !isInitialized (dashboard_screen.dart:592-594). Meanwhile _startRecording still creates the stream controller, starts the PCM16 recorder at 16kHz, and runs per-buffer int16 conversion plus 2-second ring-buffer trimming (dashboard_screen.dart:452-480, 520-541) — pure CPU/battery waste feeding a classifier that will never run. The user gets no indication: readings are saved with soundClass/soundType/confidence all null (lines 498-500) and the UI simply never shows a classification.

**Failure scenario:**

A transient asset/IO error (or OOM on a low-end device) makes Interpreter.fromAsset throw during app launch. For the entire app session, every recording runs the full microphone-stream pipeline, no classification ever appears, and all Firestore readings lack sound categories — with nothing telling the user or retrying the 1-time init.

**Recommended fix:**

In _startRecording (or _performSoundClassification's !isInitialized branch), call `await _classificationService.initialize()` as a retry before giving up; skip starting the audio recorder/stream when the service is unavailable; and surface a small 'classification unavailable' status on the dashboard when initialize() has failed.

---

#### [flow5-10] lastSyncTime saved even when every upload failed — dialog shows 'Last Sync: Just now' after a 0% sync

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:191`

**Description:**

saveLastSyncTime(DateTime.now()) runs unconditionally after the sync loop (sync_service.dart:191), regardless of whether syncedCount is 0 (all attempts failed or all items were skipped for exceeding max attempts). The sync dialog then renders this via _syncStatus['lastSyncTime'] as 'Last Sync: Just now' (sync_status_indicator.dart:194-201), implying a successful sync while the pending count above it says otherwise.

**Failure scenario:**

All 4 queued recordings fail with network errors; syncedCount is 0. The user opens the sync dialog and sees 'Pending Uploads: 4 recording(s)' directly above 'Last Sync: Just now' — contradictory status that hides the fact that no data has ever reached the server.

**Recommended fix:**

Only call _storage.saveLastSyncTime(...) when syncedCount > 0; store a separate 'last_attempt_time' if attempt telemetry is wanted, and label the dialog rows 'Last successful sync' / 'Last attempt' accordingly.

---

#### [flow2-14] Offline save failures are silently discarded - saveOfflineRecording's bool result is ignored

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/firebase_service.dart:161`

**Description:**

OfflineStorageService.saveOfflineRecording returns false when Hive is uninitialized (offline_storage_service.dart:52-55, e.g. Hive.initFlutter failed at startup) or when the put throws (:73-76). FirebaseService._saveOffline (firebase_service.dart:161) awaits it but ignores the return value, and saveNoiseReading's fallback path (:73-90) likewise treats it as success. The dashboard save timer is fire-and-forget, so the reading vanishes with only a log line; the entire save path has no user-visible failure signal.

**Failure scenario:**

Hive initialization failed at app start (corrupt box / storage full). User records offline for 10 minutes; all ~120 readings are dropped one by one. The UI shows 'Recording...' the whole time and the user believes the session was captured.

**Recommended fix:**

Propagate the bool up (make _saveOffline and saveNoiseReading return success), and in the dashboard save-timer show a one-time SnackBar / switch the SyncStatusIndicator to an error state when a save returns false.

---

#### [flow4-5] Submit shows 'submitted successfully' even when the report was silently dropped or only queued

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/firebase_service.dart:27`

**Description:**

saveNoiseReading returns normally (no throw, no return value) when _auth.currentUser is null (firebase_service.dart:27-30) — the reading is dropped entirely. It also swallows every online-save exception via the catch at lines 70-91 (falls back to the offline queue) and even swallows the case where the fallback offline save fails too (lines 88-90). Because the method can never throw, _submitReport's catch block in report_noise_screen.dart:245-253 is dead code and the success snackbar + pop at report_noise_screen.dart:234-243 run unconditionally.

**Failure scenario:**

User's auth token is revoked mid-session (currentUser becomes null before authStateChanges rebuilds the tree), or Hive is uninitialized and both the Firestore write and the offline fallback throw. User taps Submit: green 'Noise report submitted successfully!' appears and the screen pops. Nothing was saved anywhere; the report never appears in the feed or history.

**Recommended fix:**

Make saveNoiseReading return a result (e.g. enum saved/queued/failed) or rethrow when user==null and when the offline fallback also fails; in report_noise_screen show 'queued for sync' vs 'submitted' vs the error snackbar accordingly.

---

#### [flow1-8] Auth-gate StreamBuilder is destroyed by the splash pushReplacement — app stops reacting to auth-state changes after first navigation

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/main.dart:150`

**Description:**

The authStateChanges StreamBuilder lives only inside the MaterialApp home route (main.dart:150-174). When SplashScreen calls Navigator.pushReplacement (splash_screen.dart:38-40), the home route — and the auth gate with it — is disposed. From then on all auth routing is manual (login_screen.dart:57, registration_screen.dart:79, dashboard_screen.dart:694). Consequence: mid-session sign-outs that are NOT user-initiated (token revoked, password changed on another device, account disabled by admin) fire authStateChanges but nothing listens, so the user remains on the authenticated MainAppShell while every Firestore call starts failing with permission-denied. The gate only works for the cold-start-while-signed-in case (line 161), where hot restart correctly resolves the persisted session to MainAppShell.

**Failure scenario:**

User is on the Dashboard after logging in via the login screen (home route long since replaced). Their password is reset from another device and Firebase invalidates the session: no navigation occurs, the shell stays visible, and every read/write silently errors — a signed-out user stuck inside the signed-in UI until they manually kill the app.

**Recommended fix:**

Make the auth gate persistent: keep the StreamBuilder as the permanent root (never pushReplacement over it — have Splash/Onboarding/Login be widgets swapped inside it or pushed with the gate as base), or add a global authStateChanges listener that pushAndRemoveUntil to LoginScreen when user becomes null unexpectedly.

---

#### [flow4-8] No sync on app startup — queued offline reports wait for a connectivity transition or a manual tap

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:56`

**Description:**

SyncService.initialize() (main.dart:51 at startup) checks connectivity and sets _isOnline (sync_service.dart:49-56) but never calls syncOfflineRecordings(). Sync only fires in _onConnectivityChanged when the state transitions offline->online (lines 83-89), or when the user taps the SyncStatusIndicator's manual button (widgets/sync_status_indicator.dart:214 — only rendered on dashboard_screen.dart:680 and map_view_screen.dart:614). If the app launches already online with a non-empty queue from a previous session, nothing triggers.

**Failure scenario:**

User submits a report offline, kills the app, reopens it at home on Wi-Fi. Connectivity never 'changes' during the session, the user never notices the sync indicator, and the report sits in Hive indefinitely — invisible to the community feed even though the device has been online for hours.

**Recommended fix:**

At the end of initialize(), if _isOnline && _storage.getPendingCount() > 0, call syncOfflineRecordings() (fire-and-forget).

---

#### [flow2-11] Location error with dialog-flag set leaves 'Fetching location...' spinner forever and disables the refresh tap

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:296`

**Description:**

In _getCurrentLocation's catch (dashboard_screen.dart:292-303), the setState that clears _isLocationLoading runs only 'if (mounted && !SharedAppState.locationDialogShown)'. If the dialog flag is already true (set earlier by this or any other screen) and getCurrentPosition throws (e.g. the 15s TimeoutException at :232-237 with GPS enabled but no fix), _isLocationLoading stays true and _locationName stays 'Fetching location...' permanently. The location pill's onTap is 'null' while loading (:753), so the user cannot manually refresh. The resume-path recovery (_checkAndRefreshLocation :117-137) only fires for the exact string 'Location services disabled', which never matches here.

**Failure scenario:**

User previously triggered the location dialog path (flag=true), then stands in a GPS-shadowed area: fix times out, spinner spins forever, refresh is untappable. If they record, every document is saved with locationName 'Fetching location...' and default coordinates.

**Recommended fix:**

In the catch block, always reset _isLocationLoading=false and set a tappable error label (e.g. 'Location unavailable - tap to retry') regardless of SharedAppState.locationDialogShown; only the dialog invocation should be gated by the flag.

---

#### [flow6-12] 'Decibel Scale' (dBA/dBC) and 'Response Time' (Fast/Slow) toggles are dead settings

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:90`

**Description:**

'use_dba' (lines 90-93) and 'use_fast_response' (lines 94-103) are written to SharedPreferences but never read outside settings_screen_enhanced.dart (grep-verified). The dashboard measurement path uses noise_meter's default weighting with a fixed -10 dB calibration offset (dashboard_screen.dart:393-394) and has no response-time concept anywhere.

**Failure scenario:**

An acoustics-minded user switches to dBC expecting low-frequency-inclusive readings; the meter, saved readings, gauge, and all analytics remain identical. The toggle state persists across restarts, reinforcing the illusion it works.

**Recommended fix:**

Either implement frequency weighting/response smoothing in the dashboard audio pipeline reading these prefs, or delete both rows until the measurement engine supports them.

---

#### [flow3-13] Map shows only the 100 most recent readings across ALL users - a user's saved reading can be missing from the map while present in History/Analytics

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/map_view_screen.dart:42`

**Description:**

getNoiseReadingsOnce is global (no userId filter, firebase_service.dart:174-180) and capped by _kMapReadingLimit = 100 (map_view_screen.dart:42, used at 131-133). The dashboard writer produces one document every 5 seconds per recording user (dashboard_screen.dart:487-503), so 100 documents is under 9 minutes of one user recording. Any moderately active community evicts a given user's reading from the map window within minutes, while History (paginated, per-user, unbounded) and Analytics (per-user, 7/30-day windows) still show it - the three surfaces permanently disagree about which readings exist.

**Failure scenario:**

User records at 9:00. Two other users record continuously from 9:05-9:15 (240 docs). At 9:16 the first user opens the Map (or restarts the app so the map reloads): their 9:00 reading is gone from markers and heatmap, yet History and Analytics both show it. There is no UI hint that the map is truncated to the last 100 community readings.

**Recommended fix:**

Query by visible map bounds (geo-bounded query or GeoFirestore) or raise the limit with clustering already in place; at minimum overlay a 'showing latest 100 readings' label so truncation is visible, and consider aggregating the 5-second writer into per-session summary docs.

---

#### [flow2-10] '_showNativeLocationDialog' shows no dialog - location-denied path dead-ends and the app-wide flag blocks all future prompts

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:346`

**Description:**

_showNativeLocationDialog (dashboard_screen.dart:332-358) just calls Geolocator.getCurrentPosition (:346). geolocator on Android does not display a settings-resolution dialog: with services disabled it throws LocationServiceDisabledException immediately, and with permission deniedForever it throws PermissionDeniedException - both land in the catch (:354-357) which logs 'User declined'. Before that, SharedAppState.locationDialogShown is set true (:336), which permanently suppresses this path on every screen (guard at :333) and also suppresses the error-state reset in _getCurrentLocation's catch (:296). The getCurrentPosition call also has no timeout, so in the case where services ARE enabled it silently performs a second full GPS fix.

**Failure scenario:**

User has location services off, opens the dashboard: label says 'Location services disabled', no dialog ever appears, locationDialogShown becomes true so tapping other screens never prompts either. User records anyway -> Colombo-default readings saved (see flow2-4). The only escape is the label tap that resets the flag (:760), which nothing tells the user about.

**Recommended fix:**

Replace with a real in-app AlertDialog offering Geolocator.openLocationSettings() (services off) or Geolocator.openAppSettings() (deniedForever), and reset SharedAppState.locationDialogShown when the dialog is dismissed so future sessions can re-prompt.

---

#### [flow6-10] Five settings rows are silent dead ends: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service have empty onTap handlers

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:257`

**Description:**

Privacy Policy (line 223), Export All Data (line 257), Rate Us (line 303), Contact Support (lines 304-308), and Terms of Service (lines 309-313) all pass `() {}` while rendering a chevron affordance — tapping does literally nothing, with no 'coming soon' feedback. Notably a working CSV export already exists in the History screen (history_screen.dart:244-281), and NotificationService.showExportComplete (notification_service.dart:88-105) is never called by anything, so 'Export All Data' could be wired trivially.

**Failure scenario:**

A user preparing a GDPR-style data request taps Settings > Data Management > Export All Data repeatedly; nothing happens and no message explains why. Same for users looking for the privacy policy referenced by the Privacy & Security section.

**Recommended fix:**

Wire Export All Data to the existing CSV export routine; open url_launcher links for Privacy Policy/Terms/Rate Us/Contact Support; until implemented, remove the rows or show a 'coming soon' snackbar like login_screen.dart:240 does for Forgot Password.

---

#### [donate-12] Navigation blocklist blocks legitimate checkout redirects (3-D Secure bank pages, Stripe Link) so some payments cannot complete

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/widgets/buy_me_coffee_widget.dart:71`

**Description:**

onNavigationRequest returns NavigationDecision.prevent for every URL not containing 'buymeacoffee.com', 'stripe.com', or 'paypal.com' (lines 62-72). Buy Me a Coffee card payments run on Stripe, and cards enrolled in 3-D Secure redirect to the issuing bank's ACS domain (e.g., acs.<bank>.com); Stripe Link uses link.com. Those main-frame redirects are prevented, leaving the checkout frozen mid-payment with only a 'Blocked navigation' log entry (line 70).

**Failure scenario:**

A user in a 3DS-mandated region (EU SCA) enters card details on the BMC checkout and taps Pay. The bank-challenge redirect to the issuer's domain is silently blocked; the page never advances, the payment neither completes nor errors, and the user gives up.

**Recommended fix:**

Allow all https main-frame navigations during checkout (keeping only a scheme check and blocking non-http(s) intents), or drop the in-app webview for BMC and open the URL externally via url_launcher where the browser handles 3DS natively.

---

#### [flow2-9] Community feed count query violates the project period-query rule (isGreaterThanOrEqualTo, no orderBy) and streams all users' docs unbounded

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:909`

**Description:**

The dashboard's community card StreamBuilder (dashboard_screen.dart:906-914) queries collection('noise_readings').where('timestamp', isGreaterThanOrEqualTo: todayStart).where('timestamp', isLessThan: todayEnd).snapshots(). The project constraint mandates isGreaterThan + orderBy('timestamp', descending: true) for period queries. This one has neither. It currently survives only because it lacks a userId equality filter (single-field auto-index), but it contradicts the documented convention, and it has no limit(): it subscribes to every user's full documents for the day just to render a count.

**Failure scenario:**

On a busy day with 50 active users each saving a doc every 5 seconds, the dashboard downloads and re-receives thousands of full documents per snapshot tick just to display an integer badge - growing Firestore read costs and jank; and any future addition of an equality filter to this query will throw FAILED_PRECONDITION per the index rule.

**Recommended fix:**

Rewrite per convention: .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart.subtract(const Duration(milliseconds: 1)))).orderBy('timestamp', descending: true), and use the aggregate count() API (FirebaseFirestore count query) instead of snapshots() of full docs.

---

#### [flow7-09] PAYPAL_CLIENT_ID is actually used as the PayPal account email; following .env.example breaks all donations

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:37`

**Description:**

Line 37 reads 'final paypalEmail = DonationService.clientId;' and injects it into the webscr URL's business= parameter (lines 42-43), which must be a PayPal email or merchant ID. The env var is named PAYPAL_CLIENT_ID (donation_service.dart line 9) and .env.example line 19 instructs 'PAYPAL_CLIENT_ID=your_paypal_sandbox_client_id' - i.e. a REST API client ID. The current .env happens to contain a sandbox email so it works locally, but any developer configuring per the example/naming puts a REST client ID into business= and PayPal rejects the recipient. The value is also interpolated into the URL without Uri.encodeQueryComponent.

**Failure scenario:**

A new developer (or a production deploy) sets PAYPAL_CLIENT_ID to the actual REST client ID as the variable name and .env.example dictate. The configuration guard in donation_screen.dart lines 44-45 passes (no 'your_paypal' substring), the webview opens, and PayPal shows 'This recipient cannot receive payments' for every donation attempt.

**Recommended fix:**

Rename the config to PAYPAL_BUSINESS_EMAIL (getter businessEmail in DonationService), update .env and .env.example accordingly, encode it with Uri.encodeQueryComponent when building the URL, and update the placeholder guard in donation_screen.dart to match the new placeholder.

---

#### [flow6-14] 'Share Data with Researchers' toggle is a no-op — every reading is always globally visible

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:214`

**Description:**

'share_data_with_researchers' (lines 214-222) is never read outside the settings screen. All saved readings go to the shared noise_readings collection with no sharing flag (firebase_service.dart:117-133), and the community feed streams the collection unfiltered (community_feed_screen.dart:62-67), as do the map/heatmap queries (firebase_service.dart:165-201).

**Failure scenario:**

A user disables 'Share Data with Researchers' believing their recordings become private; every subsequent reading still appears in the public community feed and heatmap with their masked email attached.

**Recommended fix:**

Write a 'shared': bool field on each reading from the pref and filter community/heatmap queries on it (note: a new composite index would be needed, conflicting with the single-index constraint — so alternatively remove the toggle until backend support exists).

---

#### [flow6-13] 'Recording Duration' and 'Save Frequency' sliders are dead — save interval hardcoded to 5 s, recording never auto-stops

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:131`

**Description:**

'recording_duration' (lines 131-141) and 'save_frequency' (lines 142-152) are never read outside the settings screen. The dashboard save timer is `Timer.periodic(const Duration(seconds: 5))` (dashboard_screen.dart:487) and recording continues until manually stopped — there is no duration limit anywhere.

**Failure scenario:**

A user on a limited Firestore quota sets Save Frequency to 30 s to reduce writes; the app keeps writing a reading every 5 seconds (720 docs/hour). Another sets Recording Duration to 10 s expecting auto-stop; recording runs until they stop it.

**Recommended fix:**

Read both prefs in _startRecording: use save_frequency for the Timer.periodic interval and start a one-shot Timer(recording_duration) that calls _stopRecording (or remove the sliders).

---

#### [flow4-6] Placeholder location strings and default Colombo coordinates are written to Firestore and shown verbatim in the community feed

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/report_noise_screen.dart:224`

**Description:**

_locationName is initialized to 'Unknown Location' (line 24) and is set to UI status strings 'Fetching location...' (line 126) and 'Location services disabled' (line 96). _latitude/_longitude default to hardcoded 6.9271/79.8612 (lines 22-23) and are only replaced if GPS succeeds. _submitReport (lines 224-232) passes _locationName and the coords to saveNoiseReading with no validation, and the writer stores them as-is (firebase_service.dart:121-123). The feed reader (community_feed_screen.dart:169-170) displays locationName verbatim, so other users see a card titled 'Fetching location...' or 'Location services disabled', and the map/heatmap gets fabricated Colombo coordinates.

**Failure scenario:**

User opens the report screen with location services off (_locationName = 'Location services disabled', coords = Colombo default), sets 85 dB and taps Submit. A document with locationName 'Location services disabled' at 6.9271,79.8612 is created; every community feed user sees a card located at 'Location services disabled', and the reading pollutes the shared map at a place the user never was.

**Recommended fix:**

In _submitReport, block submission (or confirm with the user) while _locationName is one of the status strings / location fetch has not succeeded; write locationName: null (writer already falls back to 'Unknown Location') and never persist the hardcoded default coordinates — require a real fix or an explicit user-chosen location.

---

#### [flow1-3] Registration handoff leaves a stale LoginScreen route underneath MainAppShell

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/registration_screen.dart:79`

**Description:**

LoginScreen opens RegistrationScreen with Navigator.push (login_screen.dart:284-287), so the stack is [Login, Registration]. On success, registration_screen.dart:79-81 calls pushReplacement(MainAppShell), which replaces only the Registration route, producing [LoginScreen, MainAppShell]. The login path by contrast ends with a clean [MainAppShell] stack (login_screen.dart:57-59). The stale authenticated-underneath-login stack is only masked because MainAppShell's PopScope(canPop:false) calls SystemNavigator.pop() (main_app_shell.dart:30-36); the Login state, controllers, and form stay mounted in memory for the whole session, and any future code path that pops the shell would reveal a login form while the user is still authenticated.

**Failure scenario:**

User registers a new account. The app shows the Dashboard, but Navigator's stack still contains the fully-built LoginScreen beneath it; a maintainer later replacing PopScope behavior (or any programmatic pop of the shell route) drops an authenticated user onto a stale login form.

**Recommended fix:**

In _register use Navigator.pushAndRemoveUntil(FadePageRoute(page: const MainAppShell(initialIndex: 2)), (route) => false) instead of pushReplacement, matching a clean single-route stack.

---

#### [settings-13] Logout is incomplete: SharedAppState never reset, notifications not cancelled, and navigation duplicates the auth-state listener

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:684`

**Description:**

The logout handler (dashboard_screen.dart lines 684-700) only calls signOut() and pushAndRemoveUntil(SplashScreen). (1) SharedAppState.reset() (lib/utils/shared_app_state.dart lines 7-9, commented 'call when app restarts') has ZERO call sites project-wide, so locationDialogShown stays true across users in one app session; the conditional resets (dashboard_screen.dart line 127, report_noise_screen.dart line 90) only fire when location services get re-enabled. (2) NotificationService.cancelAll (notification_service.dart lines 108-110) is never called, so a high-noise notification posted by user A survives logout. (3) main.dart lines 150-163 already swaps home to SplashScreen on auth change, so the manual pushAndRemoveUntil stacks a second SplashScreen route on top of the swapped home — two competing navigation mechanisms.

**Failure scenario:**

User A dismisses the location-services dialog (flag = true), logs out; user B logs in on the same device with location still off. B never sees the location dialog, so recordings silently use the fallback location until the app is fully restarted.

**Recommended fix:**

In the logout handler call SharedAppState.reset() and NotificationService.cancelAll() before signOut(), and drop the manual pushAndRemoveUntil — let the authStateChanges StreamBuilder in main.dart own post-logout navigation.

---

#### [social-16] History does not reload after returning from 'Add Manual' — the just-submitted recording is missing

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/history_screen.dart:480`

**Description:**

The FAB (lines 478-484) fires Navigator.push without awaiting the route or refreshing on return. ReportNoiseScreen pops back after a successful submit (report_noise_screen.dart line 243), landing the user on a stale History list where their brand-new recording and the 'Showing X of Y' count are absent until a manual pull-to-refresh — which is itself broken for short lists (social-15).

**Failure scenario:**

User taps 'Add Manual', submits an 85 dB report, sees 'submitted successfully!', returns to History — the report is not in the list. Combined with social-15 (few items = no pull-to-refresh), there is no way to see it without leaving the tab.

**Recommended fix:**

Await the push and reload: `await Navigator.push(...); if (mounted) _loadInitialRecordings();` (optionally have ReportNoiseScreen pop with a `true` result and only reload then).

---

#### [flow5-9] Offline detection is transport-level only; captive-portal wifi hangs sync with _isSyncing stuck true

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/services/sync_service.dart:99`

**Description:**

_isConnectedToInternet (sync_service.dart:99-109, duplicated at firebase_service.dart:95-104) returns true for ANY ConnectivityResult other than none — including bluetooth, vpn, and wifi with no actual internet (captive portal). connectivity_plus only reports the transport. Under captive-portal wifi: (a) FirebaseService.saveNoiseReading takes the online branch, so new readings go into Firestore's invisible local write queue instead of the Hive queue — the pending badge shows 0 while data is unsent; (b) syncOfflineRecordings sets _isSyncing=true (line 129) then blocks forever on `await _firestore...add(data)` (line 233), which the Firestore SDK never times out; the finally at line 202 never runs, the indicator spins 'Syncing...' indefinitely, and every subsequent auto/manual sync exits at the 'Sync already in progress' guard (lines 119-122) until real internet returns or the app restarts.

**Failure scenario:**

User connects to airport wifi (portal not accepted), the offline→online transition fires, sync starts and hangs on the first add(). For the rest of the session the indicator shows a perpetual spinner, Sync Now does nothing ('already in progress'), and new recordings bypass the visible queue entirely.

**Recommended fix:**

Wrap each upload in a timeout: `await _firestore.collection('noise_readings').doc(recording.id).set(data).timeout(const Duration(seconds: 30))` and treat TimeoutException as a failed attempt (increments syncAttempts, releases _isSyncing via finally). Optionally add a cheap reachability probe (e.g., a HEAD request) before declaring _isOnline true.

---

#### [flow1-5] Login error mapping is dead code under modern Firebase Auth and non-FirebaseAuthException failures are swallowed silently

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/login_screen.dart:61`

**Description:**

Lines 65-71 map only 'user-not-found', 'wrong-password', 'invalid-email'. Firebase Auth with email-enumeration protection (default since late 2023; firebase_auth ^5.x per pubspec.yaml:33) returns 'invalid-credential' for both bad-email and bad-password, so users effectively always get the generic 'Login failed'. 'network-request-failed', 'too-many-requests' and 'user-disabled' are also unmapped. Worse, there is no generic catch clause: a non-FirebaseAuthException (platform channel error, unexpected TypeError) propagates out of the async handler — the finally block (lines 81-87) resets the spinner, so the user sees the button return to normal with zero feedback.

**Failure scenario:**

User types a wrong password: instead of 'Wrong password' they get the unhelpful 'Login failed'. User attempts login with airplane mode mid-toggle causing a platform exception: the spinner stops and nothing at all is shown — the login appears to have been ignored.

**Recommended fix:**

Add 'invalid-credential' (and INVALID_LOGIN_CREDENTIALS), 'network-request-failed', 'too-many-requests', 'user-disabled' cases, plus a trailing catch (e) block that shows a generic SnackBar, mirroring registration_screen.dart:111-119.

---

#### [flow6-11] 'Daily Reminders' toggle does nothing — no scheduler exists and showDailyReminder is never called

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:189`

**Description:**

The toggle saves prefs 'daily_reminders' (lines 189-197), but grep shows the key is read only by the settings screen itself. NotificationService.showDailyReminder (notification_service.dart:63-85) is defined but has zero call sites, and the app never uses zonedSchedule/periodicallyShow, so no daily notification can ever fire.

**Failure scenario:**

A user enables Daily Reminders expecting a daily 'Record Today' nudge. No notification ever arrives, on any day, regardless of the toggle.

**Recommended fix:**

On toggle-on, schedule a repeating notification via flutter_local_notifications zonedSchedule (with timezone setup) that invokes the existing reminder content; on toggle-off, cancel it (id 1). Or remove the toggle.

---

#### [boot-5] Partial registration failure strands a signed-in user with no profile doc and 'email-already-in-use' on retry

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** M

**Location:** `lib/screens/registration_screen.dart:56`

**Description:**

_register (lines 44-75) performs four sequential awaits: createUserWithEmailAndPassword, updateDisplayName, reload, then the Firestore users/{uid} set. If any step after account creation throws (Firestore rules denial, connection drop mid-flow, plugin error), execution jumps to the catch blocks (90-119) which just show a snackbar and leave the user on the registration screen — but the Firebase Auth account now exists AND the user is silently signed in (createUserWithEmailAndPassword signs in). Tapping 'Create Account' again fails with 'An account already exists with this email' (line 95-96) for their own half-created account, and the users/{uid} profile document is never written, so profile-reading screens hit a missing doc. There is no rollback (credential.user.delete()) and no forward-recovery (navigate to shell anyway since auth succeeded).

**Failure scenario:**

User submits the form; the auth account is created but the network drops before the Firestore set completes. They see 'Error: ...', stay on the registration form, retry, and get 'An account already exists with this email' — they are locked out of registering yet don't know they can just log in; even after logging in their users/{uid} doc doesn't exist.

**Recommended fix:**

After createUserWithEmailAndPassword succeeds, treat the profile steps as best-effort: wrap updateDisplayName/reload/Firestore set in their own try/catch, log the failure, and still navigate to MainAppShell(initialIndex: 2) since authentication succeeded (write the users doc lazily on next app start if missing). Alternatively, on profile-write failure call credential.user!.delete() to roll back so retry works cleanly.

---

#### [donate-13] Sandbox mode is the silent default and is currently enabled - release builds would send real users to sandbox.paypal.com

**Severity:** Medium | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/donation_service.dart:12`

**Description:**

isSandboxMode defaults to 'true' whenever PAYPAL_SANDBOX_MODE is unset (line 11-12), and the shipped .env currently sets PAYPAL_SANDBOX_MODE=true with a sandbox business account (sb-...@business.example.com), with the production config commented out (.env lines 22-28). Nothing ties the mode to the build type, so a release build with this .env (which is bundled as an asset) opens https://www.sandbox.paypal.com where real users cannot pay - sandbox requires sandbox test accounts. The only hint is small grey 'Sandbox Mode (Test)' text under the loading spinner (paypal_webview_widget.dart line 182), which disappears once loading finishes.

**Failure scenario:**

The app is released with the current .env. A supporter taps Donate, gets the sandbox PayPal login, their real PayPal credentials do not work, and every donation attempt fails - silently costing all donation revenue until someone notices.

**Recommended fix:**

Gate the mode on build type: isSandboxMode => kReleaseMode ? false : <env flag>, or assert/log an error at startup when kReleaseMode && isSandboxMode. At minimum flip the .env before release and make the sandbox banner persistent rather than loading-only.

---

### Low

#### [flow1-13] users/{uid} profile document written at registration is never read anywhere — totalRecordings and preferences are dead, divergent data

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/registration_screen.dart:68`

**Description:**

Registration writes displayName, email, photoURL, createdAt (server), createdAtClient, totalRecordings: 0, and a preferences map (darkMode/notifications/language) at lines 60-74. A project-wide grep shows the only other touches of collection('users') are two merge-writes in edit_profile_screen.dart:90 and :115 — there is no .get()/.snapshots() reader of the users collection in the entire lib/. The dashboard greeting reads FirebaseAuth displayName instead (dashboard_screen.dart:726). totalRecordings is never incremented by any recording write, and the Firestore preferences duplicate (and immediately diverge from) the real settings stored in SharedPreferences ('dark_mode', 'notifications_enabled').

**Failure scenario:**

User registers with darkMode:true written to Firestore, then switches to light mode in Settings (SharedPreferences only): the Firestore profile forever claims darkMode:true and totalRecordings:0 no matter how many recordings they make — any future feature or admin tooling reading it displays wrong data.

**Recommended fix:**

Either remove the never-read fields (totalRecordings, preferences) from the registration write, or make them live: increment totalRecordings on each noise_readings write and sync preference changes from the settings screen.

---

#### [flow6-17] Settings has no Sign Out option — logout exists only as an unlabeled icon in the Dashboard app bar

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:229`

**Description:**

The Account section (lines 229-250) offers Edit Profile, Change Password, and Delete Account, but no Sign Out. The only logout control is the Icons.logout IconButton in the Dashboard app bar (dashboard_screen.dart:682-703). The 'Settings > profile > logout' flow therefore dead-ends: a user in Settings cannot log out without knowing to return to the Dashboard tab.

**Failure scenario:**

A user on the Settings tab wants to switch accounts; finding no Sign Out, the most prominent destructive escape hatch visible is 'Delete Account' — a dangerous near-miss (especially given flow6-01).

**Recommended fix:**

Add a 'Sign Out' _buildNavigationItem to the Account section that signs out and navigates to LoginScreen (sharing one logout helper with the Dashboard for consistent cleanup and destination).

---

#### [flow1-9] Inconsistent auth-exit destinations: logout replays splash+onboarding, account deletion goes straight to LoginScreen

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:694`

**Description:**

Dashboard logout (dashboard_screen.dart:689-699) does signOut then pushAndRemoveUntil(SplashScreen), forcing the 3s splash plus onboarding card before login. Account deletion in settings (settings_screen_enhanced.dart:912-915) pushAndRemoveUntil(LoginScreen) directly. Two different exits from the same authenticated state land on different screens. For cold-start users the root auth StreamBuilder (main.dart:150) additionally swaps home to a second SplashScreen the moment signOut() completes (disposing the dashboard State so the mounted check at line 693 fails), meaning which SplashScreen instance the user actually sees depends on how they authenticated — the manual push and the reactive swap are racing.

**Failure scenario:**

User A logs out: 3s splash, then onboarding, then login (4+ taps/seconds to get back to the login form). User B deletes their account: immediately on the login screen. Same app, two unexplained different flows.

**Recommended fix:**

Route logout directly to LoginScreen (pushAndRemoveUntil), matching the deletion path, and let the splash/onboarding pair be first-launch-only (see flow1-2).

---

#### [flow3-15] History list, CSV export, and HeatmapPoint ignore the createdAt fallback convention

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/history_screen.dart:453`

**Description:**

Project convention: docs carry both timestamp (serverTimestamp) and createdAt (client DateTime) and readers must handle both. Only the analytics trend chart complies (analytics_screen.dart:196-201 falls back to createdAt). Violations: history list row reads only `data['timestamp']` and hides the date line entirely when null (history_screen.dart:453, 564); CSV export prints 'N/A' (history_screen.dart:253-256); HeatmapPoint substitutes DateTime.now() instead of createdAt (heatmap_point.dart:35), which corrupts its recency weight for docs whose serverTimestamp is unresolved (cached/pending-write snapshots).

**Failure scenario:**

Device is on flaky connectivity; a paginated history read is served from Firestore's cache while a just-written doc's serverTimestamp is still pending. That row renders with no date at all in History and exports as 'N/A' in the CSV, even though createdAt is present in the document.

**Recommended fix:**

At each site, resolve time as `(data['timestamp'] as Timestamp?)?.toDate() ?? (data['createdAt'] as Timestamp?)?.toDate()` before formatting/weighting.

---

#### [flow6-16] Two live Settings instances (shell tab + dashboard push) desync because prefs load only in initState

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:37`

**Description:**

SettingsScreenEnhanced exists permanently as IndexedStack tab 4 (main_app_shell.dart:45) AND the Dashboard app bar pushes a second instance (dashboard_screen.dart:705-716). _loadSettings runs only in initState (settings lines 37-40), so state changed in one instance is never reflected in the other; the IndexedStack instance lives for the whole session.

**Failure scenario:**

User opens Settings via the Dashboard gear, switches Dark Mode off (app goes light), pops back, then opens the Settings tab: the Dark Mode switch there still shows ON. Toggling it 'off' again is a no-op write of false, and toggling it on-off produces confusing double transitions.

**Recommended fix:**

Route the Dashboard gear to the shell's Settings tab instead of pushing a duplicate (matching the isInAppShell contract), or re-run _loadSettings when the screen becomes visible (RouteAware/didChangeDependencies + a shared ValueNotifier).

---

#### [flow5-11] In-loop 5-second retry delay never retries anything — it only stalls the remaining queue

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/services/sync_service.dart:184`

**Description:**

After a failed upload, the loop does `await Future.delayed(syncRetryDelay)` when newAttempts < maxSyncAttempts (sync_service.dart:184-186), but the for-loop then moves to the NEXT recording; the failed one is not re-attempted in this run (it only gets another chance on a future connectivity transition or manual sync). The delay therefore adds up to 5s per failed item of dead time during which _isSyncing is true and the UI spinner runs, without any retry benefit.

**Failure scenario:**

10 queued recordings all fail against a briefly-down backend: the sync run takes 50+ seconds of idle waiting with the 'Syncing...' spinner shown, then finishes having uploaded nothing and having retried nothing.

**Recommended fix:**

Remove the Future.delayed, or implement a real per-item retry (inner loop up to maxSyncAttempts with backoff) so the delay actually precedes a re-attempt of the same recording.

---

#### [flow4-12] soundClass/soundType/confidence are written by the report screen but never displayed in the community feed

**Severity:** Low | **Status:** unverified | **Category:** e2e-flow | **Effort:** S

**Location:** `lib/screens/community_feed_screen.dart:185`

**Description:**

The report screen makes sound classification a prominent (optional) input (report_noise_screen.dart:341-448) and writes soundClass, soundType and confidence=1.0 (lines 229-231; firebase_service.dart:129-131). The feed reader (community_feed_screen.dart:167-189) reads only decibelLevel, locationName, userEmail and timestamp — the classification the reporter chose is invisible to the community, unlike HistoryScreen which does read and show it (history_screen.dart:454-456).

**Failure scenario:**

User carefully selects 'Construction / Pollution' when reporting. Other users open the feed and see only '85 dB — High' with no indication of the noise source, losing the flow's key categorization data.

**Recommended fix:**

Read soundClass/soundType in the itemBuilder and render a small category chip on _buildReportCard (mirroring the Pollution/Ambient badge styling already used in the report screen's dropdown).

---

## Quick Wins (under 1 hour each)

- [ ] **flow4-7** - Offline-synced reports show upload time instead of recording time ('Just now' for a 3-day-old reading) (`lib/screens/community_feed_screen.dart:174`)
- [ ] **flow1-13** - users/{uid} profile document written at registration is never read anywhere — totalRecordings and preferences are dead, divergent data (`lib/screens/registration_screen.dart:68`)
- [ ] **flow6-04** - 'High Noise Alerts' toggle and 'Alert Threshold' slider (50-100 dB) are dead — threshold hardcoded to 70 dB and the toggle is never read (`lib/screens/dashboard_screen.dart:428`)
- [ ] **flow5-8** - 'Sync Now' gives no feedback — snackbar guarded by the popped dialog's dead context, and its message would be wrong anyway (`lib/widgets/sync_status_indicator.dart:212`)
- [ ] **flow6-07** - Name-only profile save fetches every reading and commits EMPTY batch updates (`lib/screens/edit_profile_screen.dart:135`)
- [ ] **flow2-12** - Mic-permission-denied record tap fails silently and leaks the noise-meter subscription (`lib/screens/dashboard_screen.dart:515`)
- [ ] **flow3-8** - Analytics category-filter lists diverge from the written taxonomy: 'Speech-Pollution' shows under Ambient, and 'Other' vanishes under Ambient filter (`lib/screens/analytics_screen.dart:721`)
- [ ] **flow3-5** - History empty state is a dead end: no scrollable means pull-to-refresh cannot fire, and nothing reloads on tab activation (`lib/screens/history_screen.dart:403`)
- [ ] **flow2-6** - Classification confidence threshold is 0.15 (spec: 0.30) and is non-gating - low-confidence classifications are persisted as fact (`lib/services/sound_classification_service.dart:34`)
- [ ] **flow5-10** - lastSyncTime saved even when every upload failed — dialog shows 'Last Sync: Just now' after a 0% sync (`lib/services/sync_service.dart:191`)
- [ ] **flow2-14** - Offline save failures are silently discarded - saveOfflineRecording's bool result is ignored (`lib/services/firebase_service.dart:161`)
- [ ] **flow4-5** - Submit shows 'submitted successfully' even when the report was silently dropped or only queued (`lib/services/firebase_service.dart:27`)
- [ ] **flow2-1** - Offline queue unreadable after app restart - Hive Map<dynamic,dynamic> cast crashes sync, readings never reach Firestore (`lib/services/offline_storage_service.dart:93`)
- [ ] **flow3-7** - 'Duration' stat divides reading count by 12, but readings are saved every 5 seconds - overstates duration ~60x (`lib/screens/analytics_screen.dart:163`)
- [ ] **flow4-8** - No sync on app startup — queued offline reports wait for a connectivity transition or a manual tap (`lib/services/sync_service.dart:56`)
- [ ] **flow6-17** - Settings has no Sign Out option — logout exists only as an unlabeled icon in the Dashboard app bar (`lib/screens/settings_screen_enhanced.dart:229`)
- [ ] **flow6-03** - 'Anonymize Location' privacy toggle is a silent no-op — exact GPS coordinates are always uploaded (`lib/services/firebase_service.dart:121`)
- [ ] **flow2-11** - Location error with dialog-flag set leaves 'Fetching location...' spinner forever and disables the refresh tap (`lib/screens/dashboard_screen.dart:296`)
- [ ] **flow1-9** - Inconsistent auth-exit destinations: logout replays splash+onboarding, account deletion goes straight to LoginScreen (`lib/screens/dashboard_screen.dart:694`)
- [ ] **flow3-1** - Reader field 'soundCategory' never matches writer field 'soundClass' - heatmap points always lose classification (`lib/models/heatmap_point.dart:45`)
- [ ] **flow3-15** - History list, CSV export, and HeatmapPoint ignore the createdAt fallback convention (`lib/screens/history_screen.dart:453`)
- [ ] **offline-3** - Sync is only triggered by an offline-to-online transition — never at startup, after login, or after a fallback offline save (`lib/services/sync_service.dart:83`)
- [ ] **flow6-16** - Two live Settings instances (shell tab + dashboard push) desync because prefs load only in initState (`lib/screens/settings_screen_enhanced.dart:37`)
- [ ] **flow2-10** - '_showNativeLocationDialog' shows no dialog - location-denied path dead-ends and the app-wide flag blocks all future prompts (`lib/screens/dashboard_screen.dart:346`)
- [ ] **flow1-2** - Onboarding is never persisted as seen — it replays on every signed-out launch and every logout (`lib/screens/splash_screen.dart:36`)
- [ ] **donate-12** - Navigation blocklist blocks legitimate checkout redirects (3-D Secure bank pages, Stripe Link) so some payments cannot complete (`lib/widgets/buy_me_coffee_widget.dart:71`)
- [ ] **flow2-9** - Community feed count query violates the project period-query rule (isGreaterThanOrEqualTo, no orderBy) and streams all users' docs unbounded (`lib/screens/dashboard_screen.dart:909`)
- [ ] **flow5-3** - No duplicate-upload protection: sync uses collection.add() with auto ID and marks synced only after the ack (`lib/services/sync_service.dart:233`)
- [ ] **flow7-09** - PAYPAL_CLIENT_ID is actually used as the PayPal account email; following .env.example breaks all donations (`lib/widgets/paypal_webview_widget.dart:37`)
- [ ] **flow6-13** - 'Recording Duration' and 'Save Frequency' sliders are dead — save interval hardcoded to 5 s, recording never auto-stops (`lib/screens/settings_screen_enhanced.dart:131`)
- [ ] **flow4-6** - Placeholder location strings and default Colombo coordinates are written to Firestore and shown verbatim in the community feed (`lib/screens/report_noise_screen.dart:224`)
- [ ] **flow1-3** - Registration handoff leaves a stale LoginScreen route underneath MainAppShell (`lib/screens/registration_screen.dart:79`)
- [ ] **settings-13** - Logout is incomplete: SharedAppState never reset, notifications not cancelled, and navigation duplicates the auth-state listener (`lib/screens/dashboard_screen.dart:684`)
- [ ] **social-5** - 'Noise report submitted successfully!' shows even when nothing was saved — error path is unreachable (`lib/screens/report_noise_screen.dart:235`)
- [ ] **flow1-1** - Unguarded Firebase.initializeApp dead-ends the app before runApp with no error UI (`lib/main.dart:38`)
- [ ] **flow6-05** - Clear History, Delete Account, and profile-email propagation all use a single unchunked WriteBatch — fails outright for users with >500 readings (`lib/screens/settings_screen_enhanced.dart:1027`)
- [ ] **social-16** - History does not reload after returning from 'Add Manual' — the just-submitted recording is missing (`lib/screens/history_screen.dart:480`)
- [ ] **flow5-11** - In-loop 5-second retry delay never retries anything — it only stalls the remaining queue (`lib/services/sync_service.dart:184`)
- [ ] **flow1-5** - Login error mapping is dead code under modern Firebase Auth and non-FirebaseAuthException failures are swallowed silently (`lib/screens/login_screen.dart:61`)
- [ ] **flow2-3** - Writer/writer field mismatch: offline-sync path omits userEmail that the online path writes and readers consume (`lib/services/sync_service.dart:211`)
- [ ] **donate-13** - Sandbox mode is the silent default and is currently enabled - release builds would send real users to sandbox.paypal.com (`lib/services/donation_service.dart:12`)
- [ ] **flow3-3** - Deleting a recording does not remove it from the History list or update the count (`lib/screens/history_screen.dart:721`)
- [ ] **flow4-12** - soundClass/soundType/confidence are written by the report screen but never displayed in the community feed (`lib/screens/community_feed_screen.dart:185`)

## Flow Traces

### Flow 1: First launch & auth

END-TO-END TRACE: "First launch & auth" (main.dart -> splash -> onboarding -> login/registration -> MainAppShell(initialIndex 2)). All file paths relative to noise_pollution_mapper/.

1. lib/main.dart:26-27 -> main() starts; WidgetsFlutterBinding.ensureInitialized().
2. lib/main.dart:30-36 -> dotenv.load('.env') inside try/catch (guarded; .env exists at project root and is a declared asset at pubspec.yaml:138) — failure tolerated with a warning.
3. lib/main.dart:38 -> await Firebase.initializeApp(DefaultFirebaseOptions.currentPlatform) — UNGUARDED. lib/firebase_options.dart:28-45 throws UnsupportedError for macOS/Windows/Linux; any throw here means runApp is never reached: permanent native splash, no error UI (finding flow1-1).
4. lib/main.dart:41-44 -> Firestore offline persistence enabled with unlimited cache.
5. lib/main.dart:47 -> NotificationService.initialize() (lib/services/notification_service.dart:11-19; Android-only InitializationSettings).
6. lib/main.dart:48 -> await NotificationService.requestPermission() (notification_service.dart:22-32) — on Android 13+ this pops the OS notification dialog BEFORE any Flutter frame and blocks startup until answered (finding flow1-6).
7. lib/main.dart:51 -> SyncService().initialize() (lib/services/sync_service.dart:31-70): Hive init via OfflineStorageService.initialize (lib/services/offline_storage_service.dart:22-48), connectivity check + listener. All failure paths return false and are logged — startup continues gracefully (no finding).
8. lib/main.dart:55-63 -> SharedPreferences loaded: 'dark_mode' (default true -> ThemeMode.dark) and 'theme_color' into global ValueNotifiers. NOTE: no onboarding flag is read here or anywhere (finding flow1-2).
9. lib/main.dart:66 -> _testModelLoading() (lines 75-99): loads assets/models/yamnet.tflite (exists on disk, asset dir declared pubspec.yaml:137), prints shapes, closes interpreter — throwaway load (finding flow1-7). Failure is caught; classification disabled gracefully.
10. lib/main.dart:69 -> _initializeSoundClassification() (lines 102-127) -> SoundClassificationService.initialize (lib/services/sound_classification_service.dart:48-70) loads the SAME model a second time (line 56). confidenceThreshold const = 0.15 at line 34, violating the mandated 0.30 (finding flow1-12).
11. lib/main.dart:71 -> runApp(MyApp) — first Flutter frame only now possible.
12. lib/main.dart:134-148 -> MyApp: MaterialApp built from themeNotifier/themeColorNotifier (dark theme default on first launch).
13. lib/main.dart:150-152 -> home: StreamBuilder over FirebaseAuth.instance.authStateChanges() — the auth gate.
14. lib/main.dart:164-172 -> while connectionState != active: full-screen spinner Scaffold (uses hardcoded AppTheme.darkBackground/lightBackground rather than ThemeHelper — part of finding flow1-11).
15. lib/main.dart:154-158 -> stream active + user == null (true first launch) -> SplashScreen.
16. lib/main.dart:159-161 -> stream active + user != null -> MainAppShell() (default initialIndex 2 per main_app_shell.dart:13). AUTH PERSISTENCE / HOT RESTART: verified OK — hot restart re-runs main(), Firebase resolves the persisted session, authStateChanges emits the user, and routing lands on MainAppShell(Dashboard) without touching splash/onboarding/login. The gate, however, only lives in the home route (finding flow1-8).
17. lib/screens/splash_screen.dart:23-33 -> 1.5s fade-in animation of logo/title.
18. lib/screens/splash_screen.dart:36-42 -> Timer(3s) -> Navigator.pushReplacement(OnboardingScreen). This REPLACES the home route, destroying the auth-gate StreamBuilder for the rest of the session (finding flow1-8), is unconditional (no onboarding-seen check — finding flow1-2), and is an unskippable fixed delay (finding flow1-14). BACK BUTTON on splash: root route, system back exits app (acceptable).
19. lib/screens/onboarding_screen.dart:12-63 -> single static page: WorldMapBackground (lib/widgets/world_map_background.dart:86-205 — hardcoded 0xFF3D3554 painter + AppTheme.lightPurple pins at fixed pixel offsets; finding flow1-11) + info card (lines 69-131, direct AppTheme card/text colors).
20. lib/screens/onboarding_screen.dart:37-41 -> 'Get started' -> pushReplacement(LoginScreen). Stack: [Login]. BACK BUTTON on onboarding: root route -> back exits app (acceptable, though the user cannot revisit onboarding by design... and yet it replays every launch — flow1-2).
21. lib/screens/login_screen.dart:38-53 -> _handleLogin: form validation (email must contain '@' line 159; password >= 6 chars line 198) then FirebaseAuth.signInWithEmailAndPassword.
22. lib/screens/login_screen.dart:56-60 -> success (mounted-guarded) -> pushReplacement(MaterialPageRoute(MainAppShell(initialIndex: 2))). Stack: [MainAppShell] — clean.
23. lib/screens/login_screen.dart:61-87 -> FirebaseAuthException mapped only for user-not-found / wrong-password / invalid-email — dead branches under modern 'invalid-credential' enumeration protection; no generic catch, so non-FirebaseAuthException failures are silent (finding flow1-5). finally resets spinner (mounted-guarded, correct).
24. lib/screens/login_screen.dart:237-245 -> 'Forgot Password?' is a stub SnackBar ('coming soon') — dead-end acknowledged in-code; not reported as a separate finding since it is an explicit TODO, but note the auth flow has NO password recovery path.
25. lib/screens/login_screen.dart:282-288 -> 'Sign Up' -> Navigator.push(FadePageRoute(RegistrationScreen)). Stack: [Login, Registration].
26. lib/screens/registration_screen.dart:136-139 (AppBar back arrow -> Navigator.pop) and :442-443 ('Log In' -> Navigator.pop) -> BACK BEHAVIOR on registration verified correct: both return to LoginScreen; system back also pops to Login.
27. lib/screens/registration_screen.dart:46-53 -> createUserWithEmailAndPassword -> updateDisplayName -> reload. User is now signed in (authStateChanges fires, but the gate is already destroyed — no double navigation, by luck of flow1-8).
28. lib/screens/registration_screen.dart:56-74 -> users/{uid} .set: displayName, email, photoURL:null, createdAt (serverTimestamp), createdAtClient (client DateTime), updatedAt/updatedAtClient, totalRecordings:0, preferences{notifications,darkMode,language}. Grep confirms NO reader of collection('users') exists anywhere in lib/ (only merge-writes in edit_profile_screen.dart:90,115) — no reader/writer field mismatch possible today, but the data is dead/divergent (finding flow1-13). Failure of this write after auth success strands a signed-in user (finding flow1-4).
29. lib/screens/registration_screen.dart:78-88 -> REGISTRATION->SHELL HANDOFF: pushReplacement(FadePageRoute(MainAppShell(initialIndex: 2))) replaces only the Registration route -> stack [LoginScreen, MainAppShell] with a stale login screen retained beneath the shell (finding flow1-3). Welcome SnackBar via root ScaffoldMessenger displays correctly on the new screen. displayName was set+reloaded BEFORE navigation, so the Dashboard greeting (dashboard_screen.dart:726: currentUser.displayName ?? email prefix) shows the right name immediately — handoff data verified consistent.
30. lib/widgets/main_app_shell.dart:22-26 -> _currentIndex = widget.initialIndex (2 = Dashboard).
31. lib/widgets/main_app_shell.dart:38-46 -> IndexedStack eagerly builds all 5 tabs: Map=0, Analytics=1, Dashboard=2, History=3, Settings=4 — matches the documented tab contract exactly; every screen receives isInAppShell: true per convention (verified).
32. lib/widgets/main_app_shell.dart:30-36 -> BACK BUTTON in shell: PopScope(canPop:false) -> SystemNavigator.pop() exits the app from ANY tab (and masks the stale Login route from flow1-3); no-op on iOS (finding flow1-10).
33. lib/widgets/shared_bottom_navbar.dart:38-42 -> nav buttons wired to indices 0,1,(2 home),3,4 — consistent with the IndexedStack order (verified, no mismatch).
34. lib/screens/dashboard_screen.dart:91-99 -> arrival screen initState: audio recorder init, permission requests, immediate location fetch. Flow complete.
35. RETURN PATH (logout): lib/screens/dashboard_screen.dart:689-699 -> signOut() then pushAndRemoveUntil(SplashScreen) -> replays 3s splash + onboarding before login on EVERY logout; settings account-deletion (settings_screen_enhanced.dart:912-915) instead goes straight to LoginScreen — inconsistent exits, plus a benign race with the root StreamBuilder for cold-start users (finding flow1-9; the mounted guard at dashboard_screen.dart:693 correctly prevents a double push when the StreamBuilder disposes the shell first).

SCOPE NOTES: dashboard_screen.dart:906-914 contains a noise_readings query using isGreaterThanOrEqualTo WITHOUT a userId filter or orderBy (community feed count). Because it filters only the single 'timestamp' field it is served by Firestore's automatic single-field index and does NOT hit the (userId ASC, timestamp DESC) composite-index FAILED_PRECONDITION rule — verified not a violation of the stated constraint as written, and deep dashboard data auditing belongs to the dashboard-flow auditor, so it is not reported here. Files fully read on the path: main.dart, firebase_options.dart, splash_screen.dart, onboarding_screen.dart, login_screen.dart, registration_screen.dart, main_app_shell.dart, shared_bottom_navbar.dart, world_map_background.dart, animations.dart, theme_helper.dart, notification_service.dart, sync_service.dart (init path), offline_storage_service.dart (init path), sound_classification_service.dart (init path), dashboard_screen.dart (arrival + logout sections), pubspec.yaml.

### Flow 2: Record & save reading

E2E TRACE: "Record & save reading" (all paths verified by reading the code; paths relative to project root noise_pollution_mapper/)

ENTRY AND SETUP
1. lib/widgets/main_app_shell.dart (Dashboard = IndexedStack tab 2) -> lib/screens/dashboard_screen.dart:29 -> DashboardScreen(isInAppShell) constructed; state kept alive across tab switches.
2. dashboard_screen.dart:91-99 -> initState: registers WidgetsBindingObserver, fires _initializeAudioRecorder() (un-awaited), _requestPermissions(), _getCurrentLocation().
3. dashboard_screen.dart:140-148 -> _initializeAudioRecorder: FlutterSoundRecorder().openRecorder(); failure only logged.
4. dashboard_screen.dart:151-158 -> _requestPermissions: Permission.microphone.request(); denied -> _showPermissionDeniedDialog (:310-329, offers openAppSettings; no mounted check - flow2-15). Granted -> waits for user tap (no auto-start).
5. dashboard_screen.dart:161-308 -> _getCurrentLocation: concurrency guard (:163-166) + 30s debounce (:169-176); Geolocator.checkPermission/requestPermission (:190-193); denied/deniedForever -> label 'Location permission denied' + _showNativeLocationDialog, return (:195-208); isLocationServiceEnabled false -> label 'Location services disabled' + dialog, return (:211-224); getCurrentPosition high accuracy, 10s LocationSettings timeLimit + 15s outer .timeout (:227-237); success -> _latitude/_longitude set (:239-244); placemarkFromCoordinates 10s timeout (:250-259); name = locality ?? subAdministrativeArea ?? administrativeArea ?? coords (:263-273); empty/failed geocoding -> 'GPS: lat, lng' label (:274-291); any throw -> catch (:292-303) resets UI ONLY if !SharedAppState.locationDialogShown (flow2-11). NOTE defaults _latitude=6.9271/_longitude=79.8612 Colombo (:62-63) are never invalidated (flow2-4).
6. dashboard_screen.dart:332-358 -> _showNativeLocationDialog: sets SharedAppState.locationDialogShown=true (lib/utils/shared_app_state.dart:4) then just calls Geolocator.getCurrentPosition (:346) - no actual dialog on Android; throws straight to catch (flow2-10).

START RECORDING
7. dashboard_screen.dart:837 -> record button GestureDetector onTap -> _startRecording (or _stopRecording when active).
8. dashboard_screen.dart:363-375 -> guards: _isRecording re-entry check; if recorder already running, _stopRecording() fired UN-awaited + 200ms delay (race, flow2-13). No mic-permission re-check (flow2-12).
9. dashboard_screen.dart:380-449 -> NoiseMeter().noise.listen: per NoiseReading -> rawDb = meanDecibel - 10.0 calibration (:393-394); rawDb <10 or >130 discarded (:398-401); _currentDb = clamp(0,120) (:403); _dbHistory (last 100), min/max/avg updated (:406-425); >70 dB -> NotificationService.showHighNoiseAlert once per session (:428-437); onError only logs, cancelOnError false (:441-448).
10. dashboard_screen.dart:452-480 -> audio capture: StreamController<Uint8List> (:456), FlutterSoundRecorder.startRecorder(toStream, Codec.pcm16, 16000 Hz, mono) (:472-477); _processAudioData (:521-541) converts PCM16 LE to [-1,1] doubles (divisor 32767), buffer capped at 2s (32000 samples).
11. dashboard_screen.dart:482-484 -> setState _isRecording = true (only reached if startRecorder didn't throw; any throw lands in catch :515-517 which ONLY logs - flow2-12).
12. dashboard_screen.dart:487-503 -> _saveTimer = Timer.periodic(5s): guard '!_isRecording || !mounted' (:489); 'if (_currentDb > 0 && _currentDb.isFinite)' (:491) -> FirebaseService.saveNoiseReading(decibelLevel: _currentDb, latitude: _latitude, longitude: _longitude, locationName: _locationName, soundClass/soundType/confidence from _currentClassification) (:492-501). Location validity never checked (flow2-4); classification confidence never checked (flow2-6); fire-and-forget, failures invisible (flow2-14).
13. dashboard_screen.dart:507-514 -> _classificationTimer = Timer.periodic(5s) -> _performSoundClassification.

CLASSIFICATION (YAMNet)
14. dashboard_screen.dart:591-607 -> _performSoundClassification: skips if _isClassifying / service not initialized (initialized once in lib/main.dart:69,102-127) / disposed; requires >=50% of 15600 samples, pads with zeros otherwise.
15. dashboard_screen.dart:617-637 -> slices most recent 15600 samples -> SoundClassificationService.classifySound(samples, 16000).
16. lib/services/sound_classification_service.dart:98-108 -> _preprocessAudio (resample if needed via linear interpolation :192-219, peak-normalize :223-242, pad/trim to 15600) -> interpreter.run([1,15600] -> [1,521]).
17. sound_classification_service.dart:111-123 -> argmax + confidence; yamnetClassName from YAMNetClassMapping.indexToClassName (lib/services/yamnet_class_mapping.dart:52-484).
18. sound_classification_service.dart:126-152 -> confidenceThreshold = 0.15 declared at :34 (SPEC SAYS 0.30 - flow2-6); BOTH the below-threshold branch (:131-137) and above-threshold branch (:146-152) return a full ClassificationResult, so the threshold gates nothing. Category via getCategoryFromClassName (yamnet_class_mapping.dart:1007-1043: exact match -> partial match -> _categorizeByKeywords). Range fallbacks at :1052-1062 MATCH spec: 0-15 Speech, 16-35 Body Sounds, 229-309 Domestic (also 36-136 Nature, 137-228 Music, 310-373 Traffic, 374-387 Sports, 388-393 Construction, 394-399 Industrial). soundType via getSoundType (:976-1004): Traffic/Tuk-tuk/Construction/Industrial/Transport/Alarm = 'Pollution', rest 'Ambient'.
19. dashboard_screen.dart:639-646 -> result stored in _currentClassification (drives the classification card :1057-1173 and the next save tick). NOTE: yamnetClass and yamnetClassIndex from ClassificationResult are NEVER persisted (toMap at sound_classification_service.dart:303-312 is dead code on this path).

SAVE
20. lib/services/firebase_service.dart:16-92 -> saveNoiseReading: currentUser null -> silent return (:26-30); connectivity_plus checkConnectivity (:33-41, interface-only check - captive portals count as online); online -> _saveToFirebase (:43-55); offline -> _saveOffline (:56-68); any throw -> fallback _saveOffline (:70-91).
21. firebase_service.dart:117-133 -> ONLINE WRITE: _firestore.collection('noise_readings').add(...).

COMPLETE FIRESTORE FIELD ENUMERATION (collection 'noise_readings')
Online writer (firebase_service.dart:117-133):
- userId: String (uid)
- userEmail: String? (may be literal null)
- decibelLevel: double
- latitude: double
- longitude: double
- locationName: String (never null; '?? Unknown Location'; CAN be status strings like 'Fetching location...' / 'Location permission denied' - flow2-4)
- timestamp: FieldValue.serverTimestamp() -> Timestamp
- createdAt: DateTime.now() -> Timestamp
- deviceInfo: String, constant 'Mobile Device'
- soundClass: String (OPTIONAL - one of 17 categories: Traffic, Tuk-tuk, Construction, Industrial, Speech, Music, Religious, Market, Nature, Other, Domestic, Alarm, Body Sounds, Transport, Sports, Weather, Office)
- soundType: String (OPTIONAL - 'Pollution' | 'Ambient')
- confidence: double (OPTIONAL, 0.0-1.0)
Offline-sync writer (sync_service.dart:210-234): IDENTICAL except (a) NO userEmail field (flow2-3), (b) userId = uid of user logged in AT SYNC TIME (flow2-2), (c) timestamp = serverTimestamp at SYNC time while createdAt = original recording DateTime (flow2-8).
Hive offline queue record (models/offline_recording.dart:52-67): id ('<epochMs>_<uid>'), decibelLevel, latitude, longitude, locationName?, timestamp (DateTime), soundClass?, soundType?, confidence?, syncAttempts, syncError?, isSynced (+ syncedAt/lastSyncAttempt ISO strings added by offline_storage_service.dart:133,157). No userId field.

OFFLINE PATH
22. firebase_service.dart:137-162 -> _saveOffline builds OfflineRecording -> OfflineStorageService.saveOfflineRecording -> Hive box 'recordings_queue'.put(id, toMap()) (offline_storage_service.dart:58); bool result ignored by caller (flow2-14).
23. lib/services/sync_service.dart:59-96 -> connectivity restored -> _onConnectivityChanged -> syncOfflineRecordings (:113): getQueuedRecordings (offline_storage_service.dart:80-100 - CRASHES post-restart on Map cast, flow2-1); per recording: skip forever if syncAttempts>=3 (:151-156, flow2-7); _saveToFirebase (:210-234); markAsSynced (:165); clearSyncedRecordings (:196-199).

STOP / BACKGROUND / DISPOSE
24. dashboard_screen.dart:544-585 -> _stopRecording: cancels noise+audio subscriptions and both timers (:545-548); stopRecorder with 3s timeout (:551-565); closes _audioStreamController (:567-573); clears buffer; setState _isRecording=false, _currentClassification=null (:578-584).
25. dashboard_screen.dart:102-114 -> lifecycle: ONLY AppLifecycleState.resumed handled (location re-check via _checkAndRefreshLocation :117-137). NOTHING on paused -> recording, classification, and 5s Firestore saves continue while backgrounded; android/app/src/main/AndroidManifest.xml:4-7 has no foreground service (flow2-5).
26. dashboard_screen.dart:659-667 -> dispose: _isDisposed=true; _stopRecording() un-awaited then immediate _audioRecorder?.closeRecorder() (race, flow2-16). Dashboard is disposed only on logout (pushAndRemoveUntil :694-699), not on tab switch (IndexedStack).

READER CROSS-CHECKS (field-name consistency for docs this flow writes)
- community_feed_screen.dart:168-177 reads decibelLevel/locationName/userEmail/timestamp with createdAt fallback - handles both per convention; userEmail missing on synced docs -> 'Anonymous' (flow2-3).
- history_screen.dart:451-456 (list) and :253-268 (CSV) read decibelLevel/locationName/timestamp/soundClass/soundType/confidence/userEmail/deviceInfo - names match writer; timestamp-only (no createdAt fallback) but null-safe.
- analytics_screen.dart:135-137,190-201 reads soundClass/soundType/confidence/decibelLevel, timestamp with createdAt fallback - matches writer.
- map_view_screen.dart:176-190 and models/heatmap_point.dart:26-35 read latitude/longitude/decibelLevel/soundClass/soundType/confidence - names match; all values this flow writes are doubles so the hard 'as double' casts hold for flow-written docs.
- Period queries on the save data (firebase_service.dart:259-292) correctly use isGreaterThan + orderBy timestamp descending per the composite-index rule; the ONE violation found is the dashboard community-feed count query (dashboard_screen.dart:909-913, isGreaterThanOrEqualTo + no orderBy - flow2-9).

Constraint checks: YAMNet range fallbacks match spec (yamnet_class_mapping.dart:1052-1062). Dual timestamp+createdAt written by both writers. Classification threshold VIOLATES spec (0.15 at sound_classification_service.dart:34, and non-gating) - flow2-6.

### Flow 3: View data everywhere

E2E TRACE: "View data everywhere" - saved reading -> map markers/heatmap, history list, analytics stats/charts (Daily/Weekly/Monthly), plus delete propagation. All paths relative to noise_pollution_mapper/.

WRITE PATH
1. lib/screens/dashboard_screen.dart:487-503 -> while recording, a Timer.periodic fires every 5 SECONDS and calls FirebaseService.saveNoiseReading(decibelLevel: _currentDb, latitude, longitude, locationName, soundClass: _currentClassification?.category, soundType, confidence).
2. lib/screens/report_noise_screen.dart:224-232 -> manual entry calls the same saveNoiseReading; soundClass comes from a hardcoded option list (lines 37-55) that includes 'Speech-Pollution'/'Speech-Ambient' - values that exist nowhere in YAMNetClassMapping (finding flow3-8).
3. lib/services/firebase_service.dart:16-92 -> connectivity check branches: online -> _saveToFirebase; offline (or failure fallback) -> _saveOffline into Hive.
4. lib/services/firebase_service.dart:117-133 -> ONLINE writer fields (authoritative schema): userId, userEmail, decibelLevel, latitude, longitude, locationName, timestamp=FieldValue.serverTimestamp(), createdAt=DateTime.now(), deviceInfo, and conditionally soundClass, soundType, confidence. Collection: noise_readings.
5. lib/services/sync_service.dart:210-233 -> OFFLINE-QUEUE writer replays the same fields EXCEPT userEmail is omitted (finding flow3-14); createdAt is the original client capture time - dual-timestamp convention honored by both writers.

SHELL CONTEXT
6. lib/widgets/main_app_shell.dart:38-46 -> IndexedStack builds all five tabs once at startup (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4; matches convention). Every screen's initState runs exactly once; tab switches never re-trigger loads. This is the staleness root shared by findings flow3-2/3-4/3-5.

MAP PATH
7. lib/screens/map_view_screen.dart:101 -> initState calls _loadNoiseMarkers() once.
8. lib/screens/map_view_screen.dart:131-135 + lib/services/firebase_service.dart:174-180 -> one-shot getNoiseReadingsOnce(limit: 100): GLOBAL query (no userId), orderBy timestamp desc, limit 100 - index-safe (single-field), but truncates to the community's last 100 docs (finding flow3-13).
9. lib/screens/map_view_screen.dart:174-190 -> marker reader fields vs writer, character-by-character: latitude OK, longitude OK, decibelLevel OK, locationName OK, soundClass OK, soundType OK, confidence OK. Casts are brittle (`as double`, non-null `as num`) inside one try/catch - one bad doc blanks the whole map (finding flow3-10).
10. lib/screens/map_view_screen.dart:135 -> the SAME snapshot feeds HeatmapService.convertToHeatmapPoints (good: markers and heatmap can't disagree) -> lib/services/heatmap_service.dart:9-27 -> HeatmapPoint.fromFirestore.
11. lib/models/heatmap_point.dart:26-45 -> reads decibelLevel/latitude/longitude/timestamp OK, but reads 'soundCategory' while writers write 'soundClass' - FIELD-NAME MISMATCH, classification always null on heatmap points (finding flow3-1); no createdAt fallback (finding flow3-15).
12. lib/screens/map_view_screen.dart:648-652 -> HeatmapLayer renders intensity = dB/120 blobs; 655-741 -> MarkerClusterLayerWidget renders markers; cluster color lookup at 685-688 uses malformed interpolation '$point.latitude_$point.longitude' vs stored key '${lat}_$lng' (line 200) -> clusters always orange (finding flow3-6).
13. lib/screens/map_view_screen.dart:603-608 -> RefreshIndicator wraps a Stack/FlutterMap with NO scrollable descendant -> onRefresh unreachable; grep confirms _loadNoiseMarkers/_refreshAllData have no other callers -> map data FROZEN from app start; new saves and history deletes never propagate to markers or heatmap (finding flow3-2).

HISTORY PATH
14. lib/screens/history_screen.dart:37-40 -> initState -> _checkConnectivityAndLoad -> _loadInitialRecordings (one-shot, page size 50).
15. lib/screens/history_screen.dart:90-96 + lib/services/firebase_service.dart:214-240 -> count() + getUserReadingsPaginated: where userId == + orderBy timestamp desc -> matches the only composite index (userId ASC, timestamp DESC). Compliant.
16. lib/screens/history_screen.dart:449-456 -> list reader fields vs writer: decibelLevel OK (num cast), locationName OK, timestamp OK (Timestamp?), soundClass OK, soundType OK, confidence OK (num?). No createdAt fallback (finding flow3-15). Infinite scroll at 118-167; pull-to-refresh works only when the ListView exists - empty state is unrefreshable (finding flow3-5); any load error is shown as offline (flow3-11); null-uid early return wedges the spinner (flow3-16).
17. lib/screens/history_screen.dart:704-737 -> DELETE: raw Firestore doc(docId).delete(). Local list/count not updated (finding flow3-3). Propagation verdict: History's own list - NO (until manual refresh); Map - NEVER (frozen one-shot cache, flow3-2); Analytics stats/pie/banner - NO (one-shot, flow3-4); Analytics trend chart - YES (live snapshots stream). No shared-state/notifier mechanism exists (lib/utils/shared_app_state.dart holds only a location-dialog flag).
18. lib/screens/history_screen.dart:219-329 -> CSV export queries the ENTIRE collection with no userId filter and emits userEmail per row under a 'Your Recordings' screen (finding flow3-9).

ANALYTICS PATH (Daily/Weekly/Monthly)
19. lib/screens/analytics_screen.dart:47-50 -> initState -> _loadStatistics() once; period start at 54-65 (Daily=now-24h, Weekly=now-7d, Monthly=now-30d).
20. lib/screens/analytics_screen.dart:96-97 + lib/services/firebase_service.dart:259-266 -> trend stream: where userId == AND timestamp isGreaterThan Timestamp(since) + orderBy timestamp desc + snapshots() -> COMPLIANT with the composite-index rule (isGreaterThan, not >=, with orderBy desc).
21. lib/screens/analytics_screen.dart:122-124 + lib/services/firebase_service.dart:271-279, 283-317 -> one-shot getUserReadingsByPeriodOnce and calculateStatsByPeriod use the identical compliant query shape. All three period queries verified index-safe.
22. lib/screens/analytics_screen.dart:132-153 -> classification reader fields vs writer: soundClass OK, soundType OK ('Pollution'/'Ambient' string compare matches YAMNetClassMapping.typePollution/typeAmbient constants), confidence OK (num?).
23. lib/screens/analytics_screen.dart:184-226 -> chart aggregation reads decibelLevel (null-safe) and timestamp WITH createdAt fallback (196-201) - the only reader implementing the dual-timestamp convention.
24. lib/screens/analytics_screen.dart:159-171 -> stats applied; Duration = count/12 is wrong by ~60x for the 5-second writer cadence (finding flow3-7). Stream(chart) vs one-shot(everything else) on one screen -> contradictory data after saves/deletes (finding flow3-4).
25. lib/screens/analytics_screen.dart:489-494 -> period chips re-run _loadStatistics (the ONLY refresh trigger); 539-545 -> sound-type chips only re-filter pie/breakdown via hardcoded category lists at 721-752 that diverge from getSoundType (findings flow3-8, flow3-17).

CONSTRAINT COMPLIANCE CHECKED: all userId+timestamp period queries use isGreaterThan + orderBy timestamp desc (compliant); both writers emit timestamp+createdAt (compliant); readers' createdAt handling is inconsistent (flow3-15); isInAppShell flag respected by all three screens; note dashboard_screen.dart:906-914 uses isGreaterThanOrEqualTo but on a timestamp-only (no userId) query that needs no composite index, and it is outside this flow's scope so it was not reported.

FLEET/SCOPE NOTE: sound_classification_service.dart:34 sets confidenceThreshold = 0.15, which contradicts the stated 0.30 constraint - observed while confirming writer values but NOT reported as a finding since classification/recording is outside this auditor's view-data scope; flagging here for the recording-flow auditor.

### Flow 4: Community feed & reporting

END-TO-END TRACE: Community feed & reporting (report_noise_screen submit -> community_feed_screen display). All paths relative to project root C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper.

ENTRY
1. lib/widgets/main_app_shell.dart:38-46 -> shell IndexedStack: Map=0, Analytics=1, Dashboard=2, History=3, Settings=4; HistoryScreen(isInAppShell: true) at index 3.
2. lib/screens/history_screen.dart:478-483 -> FAB 'Add Manual' pushes ReportNoiseScreen via MaterialPageRoute; no await/.then, so History will not refresh on return (finding flow4-11). This is the ONLY push site of ReportNoiseScreen in the app.
3. lib/screens/report_noise_screen.dart:21-24 -> state defaults: _manualDb=50.0, _latitude=6.9271, _longitude=79.8612 (hardcoded Colombo), _locationName='Unknown Location'.
4. report_noise_screen.dart:58-62 -> initState adds lifecycle observer and calls _getCurrentLocation(); lines 122-165 set _locationName to 'Fetching location...' (126) during fetch, or leave 'Location services disabled' (96) / defaults on failure (finding flow4-6).
5. report_noise_screen.dart:313-325 dB slider (0-120); 380-444 optional soundClass dropdown (17 options with Pollution/Ambient tags). NO image picker exists on this screen; ImageCompressionService (lib/services/image_compression_service.dart) has zero call sites in lib/ and image_picker/firebase_storage are declared in pubspec.yaml (lines 65/34) but never imported — the 'with image' leg of the flow is a dead end (finding flow4-3).

SUBMIT (WRITE)
6. report_noise_screen.dart:456 -> Submit tap -> _submitReport() (line 208); button disabled while _isSubmitting (double-submit protected).
7. report_noise_screen.dart:216-221 -> resolves soundType ('Pollution'/'Ambient') from _soundClassOptions for the selected class.
8. report_noise_screen.dart:224-232 -> await FirebaseService.saveNoiseReading(decibelLevel=_manualDb, latitude/_longitude, locationName=_locationName VERBATIM (including placeholder strings), soundClass, soundType, confidence=1.0 when a class is selected).
9. lib/services/firebase_service.dart:26-30 -> if FirebaseAuth.currentUser == null: logs a warning and returns NORMALLY — the report is silently dropped and the caller cannot tell (finding flow4-5).
10. firebase_service.dart:33-41 -> connectivity_plus check; check failure => treated as offline.
11. ONLINE: firebase_service.dart:117-133 -> _firestore.collection('noise_readings').add({userId, userEmail (nullable), decibelLevel, latitude, longitude, locationName ?? 'Unknown Location', timestamp: FieldValue.serverTimestamp(), createdAt: DateTime.now(), deviceInfo: 'Mobile Device'} + optional soundClass/soundType/confidence). Dual timestamp+createdAt convention followed by this writer.
12. OFFLINE (or online save threw): firebase_service.dart:137-162 -> builds OfflineRecording (timestamp=DateTime.now()) -> lib/services/offline_storage_service.dart:58 Hive put into 'recordings_queue'. The catch at firebase_service.dart:70-91 swallows ALL online-save errors (falls back to the offline queue) and even swallows fallback failure — saveNoiseReading can never throw, so report_noise_screen's error snackbar (245-253) is dead code.
13. report_noise_screen.dart:234-243 -> success snackbar 'Noise report submitted successfully!' shows unconditionally, then Navigator.pop(context) returns to HistoryScreen inside the shell (comment at line 242 claims 'Go back to Dashboard' — wrong; the push site is the History FAB). History list (one-shot paginated fetch, history_screen.dart:78-115) is NOT refreshed, so the new report is missing until pull-to-refresh (flow4-11).

OFFLINE SYNC LEG (queued reports -> Firestore)
14. lib/main.dart:51 -> SyncService().initialize() at startup; sync_service.dart:47-65 records _isOnline but NEVER triggers an initial sync of pending recordings (finding flow4-8).
15. lib/services/sync_service.dart:73-89 -> only an offline->online connectivity TRANSITION triggers syncOfflineRecordings(); manual trigger exists only via SyncStatusIndicator (lib/widgets/sync_status_indicator.dart:214, rendered on dashboard_screen.dart:680 and map_view_screen.dart:614).
16. sync_service.dart:140 -> _storage.getQueuedRecordings(); offline_storage_service.dart:86-94 maps raw Hive values straight into OfflineRecording.fromMap(v) (fromMap requires Map<String,dynamic>, lib/models/offline_recording.dart:34). After an app restart Hive returns Map<dynamic,dynamic>, the implicit downcast throws TypeError, which is caught by the blanket catch at sync_service.dart:200 -> the WHOLE sync aborts before the loop, syncAttempts never increments, and it fails identically forever (finding flow4-1, Critical). Note offline_storage_service.dart:114 shows the correct Map<String,dynamic>.from() pattern in a dead method.
17. sync_service.dart:210-233 -> per-recording write: {userId, decibelLevel, latitude, longitude, locationName ?? 'Unknown Location', timestamp: FieldValue.serverTimestamp() (SYNC time), createdAt: recording.timestamp (true recording time), deviceInfo} + optional classification. userEmail is OMITTED, unlike the online writer (finding flow4-2). timestamp semantics differ from createdAt (finding flow4-7). Successful docs are marked synced (165) and cleaned up (196-199); after 3 failed attempts a recording is skipped forever (151-156).

READ (COMMUNITY FEED DISPLAY)
18. lib/screens/dashboard_screen.dart:900-914 -> Community Feed entry card streams collection('noise_readings').where('timestamp', isGreaterThanOrEqualTo: todayStart).where('timestamp', isLessThan: todayEnd).snapshots() — no orderBy, no limit — solely for the count badge at 917/997; violates the project's isGreaterThan+orderBy rule and is an unbounded live read (finding flow4-9; works only because it's a single-field range on the automatic index).
19. dashboard_screen.dart:919-924 -> tap pushes CommunityFeedScreen via FadePageRoute (lib/utils/animations.dart:48-62), full-screen above the shell.
20. lib/screens/community_feed_screen.dart:62-67 -> StreamBuilder: collection('noise_readings').orderBy('timestamp', descending: true).limit(100).snapshots(). No userId filter — ALL users' documents are shown (this answers 'whose posts': everyone's, including the current user's own), and crucially INCLUDING the automatic 5-second monitoring saves from dashboard_screen.dart:487-503; no field distinguishes manual reports from auto samples, so the 100-item feed is dominated by auto samples (finding flow4-4). Query needs no composite index (single-field orderBy) — OK.
21. community_feed_screen.dart:70-76 loading spinner; 79-108 generic error state (no retry, error not surfaced — finding flow4-14); 111-152 empty state.
22. community_feed_screen.dart:167-183 -> field-by-field read: decibelLevel = (report['decibelLevel'] ?? 0.0).toDouble() [matches writer field name/type], locationName ?? 'Unknown Location' [matches], userEmail ?? 'Anonymous' [matches online writer; offline-sync writer omits it -> 'Anonymous', flow4-2], timestamp read as Timestamp? — NULL HANDLING: when timestamp is null (pending serverTimestamp in a latency-compensated snapshot, or a doc missing it), falls back to createdAt handling both Timestamp and DateTime (175-183). This is correct: a just-submitted report appears immediately with its createdAt-based age, then flips to server time on ack. Core field names match the online writer 1:1 — no read/write name mismatches on the primary path.
23. community_feed_screen.dart:200-208 -> card: noise color/label via db thresholds (18-29, hardcoded AppTheme noise colors — flow4-13), timeAgo = _getTimeAgo(timestamp) (32-48) or 'Unknown time' when both timestamp and createdAt are absent — graceful, no crash.
24. community_feed_screen.dart:211-218 -> email privacy mask only applies when local part length > 3; short local parts render in full (finding flow4-10).
25. community_feed_screen.dart:220-389 -> renders dB circle, location, level badge, masked user, timeAgo. soundClass/soundType/confidence written at submit are never displayed (finding flow4-12); no image is rendered (none exists in the data — flow4-3).

NAV BACK TO SHELL
26. community_feed_screen.dart:56-58 -> AppBar back arrow Navigator.pop -> returns to Dashboard (shell tab 2). report_noise_screen.dart:269-271 back arrow pops to History (shell tab 3). main_app_shell.dart:30-36 PopScope(canPop:false -> SystemNavigator.pop) applies only to the shell's own route, so pushed screens pop back into the IndexedStack normally — navigation returns cleanly to the shell in both cases; no dead-end.

SUMMARY OF VERIFIED BREAK POINTS: (1) offline queue permanently unsyncable after restart (Hive map cast, Critical); (2) offline-synced reports lose userEmail -> 'Anonymous'; (3) image leg of the flow entirely absent / ImageCompressionService dead code; (4) feed and count badge flooded by auto 5-sec samples with no discriminator field; (5) success snackbar on silent drop; (6) placeholder location strings + default Colombo coords persisted and displayed; (7) offline reports display sync time not recording time; (8) no startup sync; (9) unbounded count stream violating the project's period-query rule; (10) email-mask bypass; (11) stale History after pop-back; plus lower-severity display/theming/error-state gaps. Timestamp null handling in the feed reader itself is CORRECT (timestamp -> createdAt fallback handling both Timestamp and DateTime).

### Flow 5: Offline record & sync

END-TO-END TRACE: "Offline record & sync" (all paths relative to project root C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper)

1. lib/main.dart:41-44 -> Firestore offline persistence enabled globally (persistenceEnabled: true, unlimited cache) — a second, invisible write queue that coexists with the Hive queue.
2. lib/main.dart:51 -> SyncService().initialize() at cold start (before login).
3. lib/services/sync_service.dart:41 -> storage.initialize() -> lib/services/offline_storage_service.dart:32-36 -> Hive.initFlutter(); opens boxes 'recordings_queue' and 'sync_status'. Queue persistence across restart: the Hive box files DO persist — but see flow5-1: values read back from disk are Map<dynamic,dynamic> and crash the sync-side reader.
4. lib/services/sync_service.dart:49-56 -> initial offline detection: Connectivity().checkConnectivity(); _isConnectedToInternet (lines 99-109) treats ANY result != ConnectivityResult.none (wifi/mobile/bluetooth/vpn) as online — transport-level only, no internet validation (flow5-9). On exception, assumes offline (lines 51-54).
5. lib/services/sync_service.dart:59-61 -> subscribes to Connectivity().onConnectivityChanged -> _onConnectivityChanged. This is the ONLY automatic sync trigger in the app (flow5-4); no background sync exists (BackgroundSyncService referenced in comments is absent from the codebase).
6. lib/screens/dashboard_screen.dart:487-503 -> while recording, Timer.periodic(5s) fire-and-forgets FirebaseService.saveNoiseReading(currentDb, lat, lng, locationName, classification fields). Manual path: lib/screens/report_noise_screen.dart:224-232 awaits the same call.
7. lib/services/firebase_service.dart:26-30 -> aborts silently if no FirebaseAuth user.
8. lib/services/firebase_service.dart:33-41 -> per-save offline detection (same transport-only check, duplicated at lines 95-104).
9. ONLINE branch: lib/services/firebase_service.dart:43-55 -> _saveToFirebase (lines 107-134) writes doc to 'noise_readings' with userId, userEmail, timestamp=FieldValue.serverTimestamp(), createdAt=DateTime.now(), deviceInfo, optional soundClass/soundType/confidence via .add().
10. OFFLINE branch: lib/services/firebase_service.dart:56-68 -> _saveOffline (lines 137-162) builds OfflineRecording(id='${millisecondsSinceEpoch}_$userId', timestamp=DateTime.now(), isSynced=false, syncAttempts=0) — NOTE: model has no userId field (lib/models/offline_recording.dart:5-16; flow5-2).
11. lib/services/offline_storage_service.dart:51-77 -> saveOfflineRecording: box.put(recording.id, recording.toMap()) into 'recordings_queue'; logs pending/total counts.
12. FALLBACK: lib/services/firebase_service.dart:70-91 -> any exception in the online branch re-saves the reading into the Hive queue (_saveOffline) — these entries never auto-sync because no connectivity transition occurs (flow5-4).
13. RECONNECT: lib/services/sync_service.dart:73-90 -> _onConnectivityChanged recomputes _isOnline; only on false->true transition AND getPendingCount()>0 calls syncOfflineRecordings(). No trigger at startup-already-online, on login, or periodically (flow5-4).
14. lib/services/sync_service.dart:113-129 -> guards: _isInitialized, !_isSyncing (single-flight; but can stick true forever under captive portal, flow5-9), _isOnline; sets _isSyncing=true.
15. lib/services/sync_service.dart:133-137 -> requires _auth.currentUser; else returns 0 (queue waits for ANY next user — flow5-2 cross-user attribution).
16. lib/services/sync_service.dart:140 -> _storage.getQueuedRecordings() -> lib/services/offline_storage_service.dart:86-94 -> filters isSynced==false, then OfflineRecording.fromMap(v) with implicit cast to Map<String,dynamic> — WORKS same-session (Hive returns the original object), THROWS TypeError on disk-loaded Map<dynamic,dynamic> after restart; swallowed at sync_service.dart:200-201 -> sync permanently returns 0 post-restart (flow5-1, Critical).
17. lib/services/sync_service.dart:149-156 -> loop over queue; records with syncAttempts >= 3 are skipped forever via continue; attempts never reset (flow5-5).
18. lib/services/sync_service.dart:162 -> _saveToFirebase(recording, user.uid) (lines 210-233): writes userId=CURRENT uid (not recorder's, flow5-2); timestamp=FieldValue.serverTimestamp() = SYNC time; createdAt=recording.timestamp = capture time (readers display `timestamp`, so shown time is wrong — flow5-6); NO userEmail (readers show 'Anonymous'/'N/A' — flow5-7); upload via .add() auto-ID with no idempotency; marks synced only after ack -> duplicate on crash/kill between commit and mark, amplified by Firestore local persistence (flow5-3).
19. lib/services/sync_service.dart:165 -> _storage.markAsSynced(recording.id) -> lib/services/offline_storage_service.dart:235-255 sets isSynced=true; syncedCount++ (incremented even if markAsSynced returned false).
20. FAILURE path: lib/services/sync_service.dart:169-187 -> updateSyncStatus(attempts+1, error) (offline_storage_service.dart:258-282), then Future.delayed(5s) which does NOT retry the item in this run — pure stall (flow5-11).
21. lib/services/sync_service.dart:191 -> saveLastSyncTime(DateTime.now()) UNCONDITIONALLY, even when syncedCount==0 (flow5-10) -> offline_storage_service.dart:380-382 puts into 'sync_status' box.
22. lib/services/sync_service.dart:196-199 -> clearSyncedRecordings() (offline_storage_service.dart:299-323) deletes isSynced==true entries, keeping the box bounded.
23. UI: lib/widgets/sync_status_indicator.dart:30-33 -> Timer.periodic(2s) polls SyncService.getSyncStatus() (sync_service.dart:246-263: isOnline/isSyncing/pendingCount via full-box scan at offline_storage_service.dart:340-358/lastSyncTime). Two instances alive simultaneously in the IndexedStack: dashboard_screen.dart:680 (app bar) and map_view_screen.dart:611-614 (Positioned overlay) (flow5-14).
24. lib/widgets/sync_status_indicator.dart:66-97 -> renders states: syncing=spinner; offline=cloud_off orange (+queued count); online+pending=cloud_upload orange + count badge; all synced=cloud_done green. Hardcoded Colors.* throughout (flow5-13).
25. lib/widgets/sync_status_indicator.dart:148-224 -> tap opens status dialog (connection / pending / sync state / last sync). 'Sync Now' (lines 210-221) -> Navigator.pop(dialog context) -> await triggerManualSync() (sync_service.dart:237-243) -> `context.mounted` check on the popped dialog context is always false, so the result snackbar (lines 263-278, which would report the PRE-sync count as success regardless of outcome) never shows (flow5-8).
26. READ-BACK of synced data: history_screen.dart:453/253 and community_feed_screen.dart:171-183 read the Firestore docs — display `timestamp` (sync time) and `userEmail` (absent on synced-offline docs), producing the wrong-time/'Anonymous' inconsistencies of flow5-6/flow5-7. Period analytics (firebase_service.dart:259-292) correctly use isGreaterThan + orderBy timestamp descending (composite-index constraint respected — no violation found on this path).

SUMMARY OF FLOW BREAKS: the queue survives restart on disk but is unreadable by the sync path after restart (flow5-1, Critical, silent permanent data loss); attribution is to the syncing user not the recorder (flow5-2); duplicate-upload protection is absent (flow5-3); auto-sync fires only on a connectivity transition (flow5-4); items strand permanently after 3 failures (flow5-5); synced readings show sync time and no email to all readers (flow5-6/7); manual-sync feedback is dead/wrong (flow5-8); offline detection is transport-only and can wedge _isSyncing (flow5-9); lastSyncTime lies on total failure (flow5-10). Dependency versions on the path: hive 2.2.3, hive_flutter 1.1.0, connectivity_plus ^6.1.0, cloud_firestore ^5.5.0 (pubspec.yaml:35,96-98).

### Flow 6: Settings, profile, logout

END-TO-END TRACE: Settings -> Profile -> Logout (all paths relative to project root C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper)

PREMISE CORRECTION: the theme toggle does NOT go through lib/utils/shared_app_state.dart. That file (lines 1-10) contains only a static `locationDialogShown` flag for location dialogs (used by dashboard/report screens); its reset() is never called. Theme state lives in two global ValueNotifiers in lib/main.dart:18-24 (themeNotifier, themeColorNotifier).

A. SETTINGS ENTRY + THEME TOGGLE
1. lib/widgets/main_app_shell.dart:45 -> SettingsScreenEnhanced(isInAppShell: true) lives permanently as IndexedStack tab index 4 (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4). A SECOND instance can be pushed from the Dashboard app bar (lib/screens/dashboard_screen.dart:705-716) with isInAppShell=false (back arrow shown per lines 77-82 of settings screen). Two live instances -> stale-state desync (flow6-16).
2. lib/screens/settings_screen_enhanced.dart:37-40 -> initState calls _loadSettings once per instance lifetime.
3. settings_screen_enhanced.dart:42-60 -> loads 12 SharedPreferences keys (use_dba, use_fast_response, notifications_enabled, high_noise_alerts, daily_reminders, share_data_with_researchers, dark_mode, anonymize_location, recording_duration, save_frequency, db_threshold).
4. settings_screen_enhanced.dart:104-118 -> Dark Mode switch: setState, _saveSetting('dark_mode', val) (fire-and-forget prefs write, lines 62-68), then themeNotifier.value = dark/light + green snackbar.
5. lib/main.dart:134-148 -> ValueListenableBuilder<ThemeMode> on themeNotifier rebuilds MaterialApp with themeMode; nested ValueListenableBuilder<Color> regenerates light/dark themes from themeColorNotifier via AppTheme.generateLightTheme/generateDarkTheme (lib/theme/app_theme.dart:41,125). Theme applies app-wide instantly. WORKS.
6. Persistence across restart: lib/main.dart:55-57 reads prefs 'dark_mode' (default true) before runApp; main.dart:60-63 reads 'theme_color' int -> Color. Both restore correctly. THEME PERSISTENCE VERIFIED WORKING.
7. Theme color picker: settings_screen_enhanced.dart:576-603 dialog over AppTheme.themeColors (app_theme.dart:29); _buildColorOption onTap (605-631) sets themeColorNotifier, saves prefs.setInt('theme_color', color.toARGB32()), pops dialog, snackbar. WORKS.
8. Other toggles (settings 90-222) all persist to prefs, but grep across lib/ shows ONLY 'notifications_enabled' is consumed elsewhere (lib/services/notification_service.dart:38,65). Dead keys: use_dba, use_fast_response, high_noise_alerts, daily_reminders, share_data_with_researchers, anonymize_location, recording_duration, save_frequency, db_threshold (findings flow6-03/04/11/12/13/14). The high-noise alert is hardcoded >70 dB / reset <65 at dashboard_screen.dart:428-437; save cadence hardcoded 5 s at dashboard_screen.dart:487.
9. Dead menu rows with empty onTap: settings 223 (Privacy Policy), 257 (Export All Data), 303 (Rate Us), 304-308 (Contact Support), 309-313 (Terms of Service) (flow6-10).

B. EDIT PROFILE SAVE + PROPAGATION
10. settings_screen_enhanced.dart:231-238 -> Navigator.push(EditProfileScreen).
11. lib/screens/edit_profile_screen.dart:23-26,35-43 -> initState loads name/email from FirebaseAuth.currentUser (displayName/email), not from Firestore users doc.
12. edit_profile_screen.dart:45-63 -> _updateProfile validates form (email validator only checks contains '@' and '.').
13. edit_profile_screen.dart:66-83 -> diff detection; 'No changes made' early-out.
14. Name change: edit_profile_screen.dart:86-95 -> user.updateDisplayName(newName) + users/{uid} merge-set {displayName, email, updatedAt(+Client)}. NOTE: collection('users') is write-only app-wide (writes at edit_profile 90/115 and registration_screen.dart:58; zero reads) (flow6-08).
15. Email change: edit_profile_screen.dart:99-120 -> verifyBeforeUpdateEmail(newEmail) (sends link; Auth email unchanged until verified) then IMMEDIATELY writes newEmail into users/{uid} -> premature/possibly-permanent divergence (flow6-06).
16. edit_profile_screen.dart:123 -> user.reload().
17. edit_profile_screen.dart:126-141 -> if (emailChanged || nameChanged): fetch ALL noise_readings where userId==uid (equality-only query, no composite index needed - OK per index constraint) and batch.update each with { if (emailChanged) 'userEmail': newEmail } -> EMPTY map on name-only saves (flow6-07); single unchunked batch breaks at >500 docs (flow6-05).
18. edit_profile_screen.dart:143-165 -> success snackbar; pops back to Settings (2 s delayed pop if email changed).
19. Propagation reality: community feed shows masked userEmail from each reading (lib/screens/community_feed_screen.dart:171, 211-218; 'Deleted User'/'Anonymous' special-cased); History list/CSV shows userEmail (lib/screens/history_screen.dart:262); dashboard greeting reads FirebaseAuth displayName at build (dashboard_screen.dart:726) but DashboardScreen is a const IndexedStack child (main_app_shell.dart:40-46) so tab switches never rebuild it -> greeting can stay stale until dashboard setState. Net: display-name changes propagate NOWHERE visible (flow6-08); email changes propagate to feed/history only via step 17 and only pre-verification (flow6-06).

C. LOGOUT -> AUTH STATE -> LANDING
20. dashboard_screen.dart:682-689 -> app-bar logout IconButton: captures Navigator, awaits FirebaseAuth.instance.signOut(). (Settings screen itself has NO sign-out entry - flow6-17.)
21. main.dart:150-163 -> authStateChanges StreamBuilder is the auth gate at MaterialApp.home; on sign-out it would swap home to SplashScreen, BUT...
22. dashboard_screen.dart:693-699 -> navigator.pushAndRemoveUntil(SplashScreen, (r)=>false) removes ALL routes including the home route hosting the auth-gate StreamBuilder; end state is a bare SplashScreen route (single instance regardless of event ordering; the auth gate is gone until a full restart - re-login relies on LoginScreen's manual navigation, which exists at login_screen.dart:56-60).
23. Widget cleanup on route removal: MainAppShell + all 5 tabs dispose. Dashboard dispose (dashboard_screen.dart:660-667) cancels noise subscription, audio stream, save/classification timers, closes recorder (_stopRecording, 544-569). History dispose (history_screen.dart:71-75) releases scroll controller. StreamBuilder Firestore listeners (analytics getUserReadings, community feed if open) are cancelled with their elements. Screen-level stream cleanup on logout: OK.
24. NOT cleaned on logout: SyncService singleton - connectivity subscription and Hive offline queue stay live; SyncService.dispose (lib/services/sync_service.dart:285-290) has zero call sites; queued recordings carry no userId (lib/models/offline_recording.dart:4-31) and are stamped with _auth.currentUser.uid at sync time (sync_service.dart:133,162,210-233) -> cross-user misattribution after account switch (flow6-02, flow6-15). NotificationService.cancelAll (notification_service.dart:108-110) also never called. SharedPreferences (theme, toggles) and Firestore offline cache persist across users by design.
25. Landing sequence: splash_screen.dart:36-42 -> unconditional 3 s Timer -> pushReplacement OnboardingScreen; onboarding_screen.dart:37-41 -> 'Get started' -> pushReplacement LoginScreen; login_screen.dart:50-59 -> signInWithEmailAndPassword -> pushReplacement MainAppShell(initialIndex: 2). Every logout (and every logged-out cold start) replays splash + onboarding (flow6-09).
26. Alternate exit - Delete Account: settings_screen_enhanced.dart:828-861 confirm dialog -> _deleteAccount (864-959): batch-anonymize ALL readings (887-901: userEmail='Deleted User', userId='deleted_user_<uid8>') THEN user.delete() (904) -> requires-recent-login failure orphans history irreversibly (flow6-01); success path pops loading and pushAndRemoveUntil LoginScreen (912-915) - a different landing than logout's SplashScreen; snackbar (918-923) still displays via the root ScaffoldMessenger.

Constraint checks: all traced Firestore queries comply with the single composite index (equality-only where userId==uid for the batches; getUserReadingsByPeriod uses isGreaterThan + orderBy timestamp desc per firebase_service.dart:259-266). Traced UI code uses ThemeHelper + withValues throughout the settings/profile path. Tab indices match the documented MainAppShell contract.

### Flow 7: Donation

END-TO-END TRACE: Donation flow (all paths verified reachable; all four files read in full).

ENTRY / REACHABILITY
1. lib/widgets/main_app_shell.dart:45 -> SettingsScreenEnhanced(isInAppShell: true) is mounted at IndexedStack index 4 (Settings tab), making the flow entry reachable from the main shell. A second path exists via lib/screens/dashboard_screen.dart:711 (pushes SettingsScreenEnhanced).
2. lib/screens/settings_screen_enhanced.dart:272-282 -> "Support This Project" item; onTap at :276 does Navigator.push(MaterialPageRoute(builder: (_) => const DonationScreen())). DonationScreen is reachable. PayPalWebViewWidget and BuyMeACoffeeWidget are each reachable from DonationScreen (steps 8 and 16 below) - no unreachable widgets on this path.

DONATION SCREEN
3. lib/screens/donation_screen.dart:26 -> initState pre-selects the first preset amount ("5.0" from DonationService.presetAmounts, donation_service.dart:19).
4. donation_screen.dart:209-240 -> preset chips $5/$10/$20 set _selectedAmount and clear _isCustomAmount; :249-288 "Custom" toggle; :292-309 custom TextField parses input with double.tryParse into _customAmountValue (invalid text -> null).
5. donation_screen.dart:347-354 -> "Donate with PayPal" button computes amount (custom ?? 0, or tryParse(selected) ?? 0) and calls _processPayPalDonation.
6. donation_screen.dart:37-41 -> DonationService.getValidationError (donation_service.dart:120-128) rejects <$1 / >$1000 with an error snackbar (donation_service.dart:196-216) and aborts.
7. donation_screen.dart:44-52 -> config guard: clientId empty or contains 'your_paypal' -> error snackbar, abort. Current .env:27 has PAYPAL_CLIENT_ID=sb-...@business.example.com (an email, not a client ID - see flow7-09), so guard passes.
8. donation_screen.dart:55-63 -> Navigator.push -> PayPalWebViewWidget(amount, currency: 'USD').

PAYPAL WEBVIEW PATH
9. lib/widgets/paypal_webview_widget.dart:37-43 -> builds classic webscr URL: https://www.{sandbox.}paypal.com/cgi-bin/webscr?cmd=_donations&business=<clientId>&item_name=Donation+to+Noise+Pollution+Mapper&amount=X.XX&currency_code=USD. Host chosen by DonationService.isSandboxMode (donation_service.dart:11-12, defaults to sandbox=true when env missing). No return/cancel_return/rm params; business value not query-encoded (flow7-01, flow7-09).
10. paypal_webview_widget.dart:79-99 -> InAppWebView loads the URL; controller captured in onWebViewCreated (:96-99). AppBar refresh (:60-71) touches late-final _controller and can crash before creation (flow7-03).
11. paypal_webview_widget.dart:100-106 -> onLoadStart sets _isLoading; loading overlay (:162-192) shows sandbox/live indicator.
12. paypal_webview_widget.dart:107-128 -> onLoadStop clears loading, then checks URL for 'payment=success'/'payment=completed' -> _onPaymentSuccess, 'payment=cancel(led)' -> _onPaymentCancelled. DEAD CODE: those query strings can never appear because step 9 sets no return URLs (flow7-01). _paymentComplete assigned outside setState at :123 (flow7-02).
13. paypal_webview_widget.dart:141-154 -> shouldOverrideUrlLoading ALLOWs URLs containing 'paypal.com'/'paypalobjects.com'/'braintreegateway.com' (substring match - spoofable, flow7-05) and CANCELs everything else silently (blocks 3DS/issuer redirects, flow7-04).
14. paypal_webview_widget.dart:130-140 -> onReceivedError suppresses errors for URLs containing 'paypal.com' and never checks isForMainFrame -> in-app error UI (:222-278) is unreachable for real main-frame failures yet triggerable by harmless subresource failures (flow7-14).
15. paypal_webview_widget.dart:285-301 -> (if it ever fired) _onPaymentSuccess -> DonationService.recordDonation (donation_service.dart:67-90, SharedPreferences only; history entry format '${iso8601}:$amount' at :86 clashes with the split(':') parser in getDonationHistory :97-103, flow7-08) then showThankYouDialog (donation_service.dart:131-193) whose Close pops only the dialog (flow7-11). _onPaymentCancelled -> orange snackbar (donation_service.dart:219-234). Only exit from the screen: AppBar X (:54-58) -> Navigator.pop. No PopScope/back-history handling (flow7-07).

BUY ME A COFFEE PATH
16. donation_screen.dart:66-85 -> _openBuyMeACoffee: guard rejects empty/'yourusername' URL; .env:34 has https://www.buymeacoffee.com/nuhaadh so guard passes; Navigator.push -> BuyMeACoffeeWidget(url).
17. lib/widgets/buy_me_coffee_widget.dart:28-76 -> initState builds webview_flutter WebViewController (different plugin than PayPal's flutter_inappwebview, flow7-12), sets NavigationDelegate, loadRequest(widget.url).
18. buy_me_coffee_widget.dart:62-72 -> onNavigationRequest: substring allowlist buymeacoffee.com/stripe.com/paypal.com, prevents everything else (blocks social login and 3DS, flow7-04; spoofable, flow7-05).
19. buy_me_coffee_widget.dart:36-60 -> progress/loading/error states wired via onProgress/onPageStarted/onPageFinished/onWebResourceError; error UI (:157-212) with working Try Again (:189-195; controller is non-late-safe here because it is created in initState).
20. buy_me_coffee_widget.dart:104-117 -> AppBar 'Open in Browser' action: logs + snackbar 'Opening in browser...' but never launches anything (url_launcher already in pubspec.yaml:93) - stub with false feedback (flow7-06).
21. Exit: implicit AppBar back arrow pops the route; no PopScope/canGoBack handling for system back (flow7-07). No success/completion detection exists at all on the BMC path (donation there is never recorded - consistent with the widget being a plain browser, but note the asymmetry with the PayPal path's recordDonation intent).

SUPPORTING FACTS VERIFIED: pubspec.yaml:76 flutter_dotenv, :91 webview_flutter, :92 flutter_inappwebview, :93 url_launcher, :138 '.env' bundled as asset; lib/main.dart:31 dotenv.load('.env'); .env.example:19-21 instructs putting a REST client ID and PAYPAL_SECRET into the bundled .env (flow7-09, flow7-10). Dead code confirmed by grep: DonationService.getCurrentMonthDonations, getDonationHistory, clearDonationHistory, isValidAmount, and the 'secret' getter have zero callers.

BOTTOM LINE: every screen/widget on the path is reachable and the UI renders, but the PayPal leg is fire-and-forget in practice - success/cancel handling, donation recording, and the thank-you/cancellation UX are all dead code because the donation URL carries no return parameters (flow7-01), and both webviews are navigation sandboxes with silent blocking, no back handling, and a fake open-in-browser escape hatch.
