# Improvements & Prioritized Roadmap - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **16** (1 Medium, 5 Low, 10 Enhancement).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| critic-07 | Medium | unverified | `.env.example:12` | CONFIDENCE_THRESHOLD, CLASSIFICATION_INTERVAL_SECONDS and HIGH_NOISE_THRESHOLD env vars are documented but never read | S |
| settings-18 | Low | unverified | `lib/theme/app_theme.dart:209` | Dead code cluster: static themes, unused notification methods, never-called reset(), unused animation widgets | S |
| ml-14 | Low | unverified | `lib/services/yamnet_class_mapping.dart:1062` | Stale comment claims indices 137-228 fall through to keyword checks, but they are handled by the first range check | S |
| critic-10 | Low | unverified | `assetsmodels:1` | Leftover empty `assetsmodels/` directory and inconsistent app display names across platforms | S |
| critic-08 | Low | unverified | `README.md:116` | README contradicts the repo: wrong test path, references to nonexistent docs, published test credentials, 'Known Issues: None' | S |
| boot-14 | Low | unverified | `lib/main.dart:183` | Dead Flutter-template counter code (MyHomePage) still shipped in main.dart | S |
| uiux-42 | Enhancement | unverified | `lib/widgets/heatmap_settings_panel.dart:6` | HeatmapSettingsPanel is fully built but dead — wire it up or delete it | M |
| uiux-43 | Enhancement | unverified | `lib/screens/history_screen.dart:285` | CSV export ends with an unactionable file path — offer a share sheet | S |
| donate-18 | Enhancement | unverified | `pubspec.yaml:90` | Dead payment code: flutter_paypal_payment dependency and five DonationService methods are never used | S |
| uiux-40 | Enhancement | unverified | `lib/screens/dashboard_screen.dart:837` | Add haptic feedback to the record start/stop button | S |
| map-25 | Enhancement | unverified | `lib/models/heatmap_point.dart:36` | Recency weight is computed but never used in rendering | S |
| map-26 | Enhancement | unverified | `lib/screens/search_list_screen.dart:137` | City grid is derived from only the 100 most recent global readings | M |
| uiux-39 | Enhancement | unverified | `lib/screens/history_screen.dart:439` | Use the existing (dead) ShimmerLoading widget for skeleton loaders instead of bare spinners | M |
| offline-19 | Enhancement | unverified | `lib/widgets/sync_status_indicator.dart:30` | Replace 2-second polling with event-driven status updates from SyncService | M |
| analytics-15 | Enhancement | unverified | `lib/screens/analytics_screen.dart:539` | Sound-type filter chips (All/Pollution/Ambient) only affect the pie chart and breakdown — not the trend chart or stat cards | M |
| uiux-41 | Enhancement | unverified | `lib/screens/history_screen.dart:414` | Empty states tell users to act but give no button to act with | M |

## Detailed Findings

### Medium

#### [critic-07] CONFIDENCE_THRESHOLD, CLASSIFICATION_INTERVAL_SECONDS and HIGH_NOISE_THRESHOLD env vars are documented but never read

**Severity:** Medium | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `.env.example:12`

**Description:**

.env.example lines 12-16 and README.md lines 85-87 instruct configuring CONFIDENCE_THRESHOLD=0.6, CLASSIFICATION_INTERVAL_SECONDS=5, HIGH_NOISE_THRESHOLD=70 in .env. Grep of lib/ shows no dotenv read of any of these keys: the real values are compile-time constants - confidenceThreshold = 0.15 and classificationIntervalSeconds = 5 in sound_classification_service.dart lines 34/37, and the 70 dB trigger hardcoded at dashboard_screen.dart line 428. The documented 0.6 also contradicts the actual 0.15.

**Failure scenario:**

An operator tuning false-positive classifications edits CONFIDENCE_THRESHOLD in .env to 0.5 and rebuilds; nothing changes because the value is never parsed, and they burn hours debugging a config system that does not exist.

**Recommended fix:**

Either wire the constants to dotenv with fallbacks (e.g. `double.tryParse(dotenv.env['CONFIDENCE_THRESHOLD'] ?? '') ?? 0.15`) in sound_classification_service.dart and notification trigger, or delete the three keys from .env.example and README and document the real hardcoded values.

---

### Low

#### [settings-18] Dead code cluster: static themes, unused notification methods, never-called reset(), unused animation widgets

**Severity:** Low | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/theme/app_theme.dart:209`

**Description:**

Verified by project-wide grep: AppTheme.darkTheme and AppTheme.lightTheme (app_theme.dart lines 209-364, ~155 lines) have zero references since main.dart switched to generateDarkTheme/generateLightTheme; NotificationService.showDailyReminder (notification_service.dart lines 63-85), showExportComplete (88-105) and cancelAll (108-110) have no call sites; SharedAppState.reset() (shared_app_state.dart lines 7-9) is never called despite its doc comment; animations.dart classes ScalePageRoute (line 65), AnimatedCard (line 172), ShimmerLoading (line 238) and PulseAnimation (line 313) are unused (only SlidePageRoute, FadePageRoute, AnimatedButton, FadeInListItem have call sites).

**Failure scenario:**

A developer edits AppTheme.darkTheme to change card styling and sees no effect anywhere, because the app only builds themes via generateDarkTheme — the duplicate definitions invite exactly this wasted work and drift.

**Recommended fix:**

Delete AppTheme.darkTheme/lightTheme and the unused animation classes; either wire up showDailyReminder/cancelAll/reset() per findings settings-5 and settings-13 or remove them.

---

#### [ml-14] Stale comment claims indices 137-228 fall through to keyword checks, but they are handled by the first range check

**Severity:** Low | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/services/yamnet_class_mapping.dart:1062`

**Description:**

The comment at line 1062 says 'Indices 137-228 (Music), 400-520: fall through to keyword checks below', but the very first range check at line 1053 (`if (classIndex >= 137 && classIndex <= 228) return categoryMusic;`) already returns for 137-228, so only 400-520 actually fall through. Misleading for anyone modifying the fallback ranges (which ml-2's fix will require touching). Also note the Music check being ordered first is redundant — the ranges are mutually exclusive, so ordering carries no meaning here.

**Failure scenario:**

A developer fixing the dead-fallback bug (ml-2) reads the comment, assumes 137-228 is unhandled, and adds a duplicate/conflicting Music range or keyword rule, creating divergent behavior between the two paths.

**Recommended fix:**

Correct the comment to 'Indices 400-520 fall through to keyword checks below' and move the 137-228 Music check into numeric order with the other ranges.

---

#### [critic-10] Leftover empty `assetsmodels/` directory and inconsistent app display names across platforms

**Severity:** Low | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `assetsmodels:1`

**Description:**

The project root contains an empty directory named `assetsmodels` - clearly a mistyped `assets/models` from when the YAMNet model was added (the real assets/models/yamnet.tflite, 4.1 MB, is present and correctly declared). Separately, the Android launcher label is 'Urban Noise Mapper' (android/app/src/main/AndroidManifest.xml line 10) while iOS CFBundleDisplayName/CFBundleName is 'Noise Mapper' (ios/Runner/Info.plist lines 8/16) and the README title is 'Noise Mapper' - three different user-facing names for one product.

**Failure scenario:**

A developer hunting for the model file lands in the empty assetsmodels/ folder and assumes the model is missing; testers filing reports refer to different app names per platform, confusing the academic submission.

**Recommended fix:**

Delete the empty assetsmodels/ directory and align android:label with the chosen product name ('Noise Mapper') in AndroidManifest.xml.

---

#### [critic-08] README contradicts the repo: wrong test path, references to nonexistent docs, published test credentials, 'Known Issues: None'

**Severity:** Low | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `README.md:116`

**Description:**

(1) Line 116 says integration tests run via `flutter test integration_test/` but the files live in test/integration/ - the documented command errors with 'no tests found', while the misplaced tests break plain `flutter test` (see critic-04). (2) Lines 120 and 163-168 reference TESTING_GUIDE.md and BUG_FIXES_SESSION_15.md which do not exist in the repo (only SIMPLE_TESTING_GUIDE.md exists), and CLAUDE.md which is gitignored (line 50 of .gitignore). (3) Lines 217-218 publish a live test account email/password (test@example.com / test123) in a repo whose Firestore rules grant authenticated users community-wide read access. (4) Line 242 'Known Issues: None' is contradicted by the 9-document audit/ folder in the same repo. (5) Line 20 says '10 sound categories' but 4 more were added later per session history.

**Failure scenario:**

A new developer or the academic assessor follows the README: the integration-test command fails, three referenced key documents are missing, and anyone reading the public repo can log into the shared test account and write noise readings under it, polluting community map data.

**Recommended fix:**

Update the testing section to `test/` + `integration_test/` after the move, fix or remove dead document links, delete the credentials (rotate that account's password), refresh category count, and replace 'Known Issues: None' with a pointer to audit/00_MASTER.

---

#### [boot-14] Dead Flutter-template counter code (MyHomePage) still shipped in main.dart

**Severity:** Low | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/main.dart:183`

**Description:**

MyHomePage/_MyHomePageState (lines 183-267) is the unmodified flutter-create counter demo — including template comments and a stray 'testing' string at line 252 — and is referenced nowhere in the app (MyApp's home is the auth StreamBuilder). It is dead weight that pads main.dart to 267 lines and confuses navigation-flow reading during audits.

**Failure scenario:**

A developer greps for the app's home widget, finds MyHomePage in main.dart, and wastes time assuming it is part of the boot flow; the dead code also ships in the binary.

**Recommended fix:**

Delete lines 183-267 of lib/main.dart.

---

### Enhancement

#### [uiux-42] HeatmapSettingsPanel is fully built but dead — wire it up or delete it

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/widgets/heatmap_settings_panel.dart:6`

**Description:**

HeatmapSettingsPanel (285 lines: opacity slider, time-range chips, stats row) is instantiated nowhere — the map uses the minimal HeatmapFab toggle instead, and MapViewScreen's `_heatmapOpacity` is a final 0.7 (map_view_screen.dart:69) with no UI to change it. firebase_service.getNoiseReadingsForHeatmap with time filters (firebase_service.dart:183) is similarly orphaned.

**Failure scenario:**

Heatmap users cannot adjust opacity or restrict to '1 Day' even though the finished controls exist in the codebase; meanwhile the dead widget confuses future maintenance.

**Recommended fix:**

Either show HeatmapSettingsPanel (e.g. as a bottom sheet on long-pressing the HeatmapFab) wiring onOpacityChanged/onTimeRangeChanged into MapViewScreen state, or delete the file and the orphaned service method to reduce noise.

---

#### [uiux-43] CSV export ends with an unactionable file path — offer a share sheet

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/screens/history_screen.dart:285`

**Description:**

The export success dialog prints the app-documents path (history_screen.dart:284-317), e.g. /data/user/0/…/app_flutter/…csv, which is inaccessible to users without a file manager and not reachable at all on scoped-storage Android for other apps.

**Failure scenario:**

User exports their data to share with a researcher, sees a long internal path, and has no way to actually get the file off the device.

**Recommended fix:**

Add share_plus and call `Share.shareXFiles([XFile(file.path)], text: 'Noise data export')` from a 'Share' action in the success dialog (keep 'OK' as dismissal).

---

#### [donate-18] Dead payment code: flutter_paypal_payment dependency and five DonationService methods are never used

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `pubspec.yaml:90`

**Description:**

flutter_paypal_payment: ^1.0.0 (pubspec.yaml line 90) has zero imports anywhere in lib/ (verified by grep) - the PayPal flow was reimplemented with flutter_inappwebview, leaving this package as dead APK weight. In donation_service.dart, secret (line 10), getCurrentMonthDonations (53), getDonationHistory (93), clearDonationHistory (107), and isValidAmount (115) have no call sites; the 'Monthly Expenses' card shows static goals with no actual donation progress even though getCurrentMonthDonations exists to power it.

**Failure scenario:**

Developers maintain and ship code paths that cannot execute; the unused package pulls in its own webview stack, inflating build size and dependency-audit surface, and the impact tracker card implies live tracking that does not exist.

**Recommended fix:**

Remove flutter_paypal_payment from pubspec.yaml; either delete the unused DonationService methods or wire getCurrentMonthDonations into the Monthly Expenses card to show real progress toward the goal (after fixing donate-1/donate-9 so donations are actually recorded).

---

#### [uiux-40] Add haptic feedback to the record start/stop button

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:837`

**Description:**

The main record control is a bare GestureDetector (dashboard_screen.dart:836-869) with only a visual AnimatedContainer change. For a measurement app where users watch the environment (not the screen) while recording, a tactile confirmation of start/stop is a cheap, high-value cue. flutter/services is already imported app-side (main_app_shell.dart:2).

**Failure scenario:**

User taps record while holding the phone up toward a noise source and can't tell if the tap registered without looking down at the button state.

**Recommended fix:**

Call `HapticFeedback.mediumImpact()` in the onTap before _startRecording/_stopRecording (import 'package:flutter/services.dart'). Optionally `selectionClick()` on nav-bar taps in shared_bottom_navbar.dart for consistency.

---

#### [map-25] Recency weight is computed but never used in rendering

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** S

**Location:** `lib/models/heatmap_point.dart:36`

**Description:**

_calculateWeight (lines 62-79) assigns each point a recency weight (also note its doc comment values 0.5/0.25 don't match the returned 0.7/0.5/0.3), but HeatmapLayer passes only (offset, intensity) tuples to the painter (map_view_screen.dart:1399-1408) — weight influences nothing.

**Failure scenario:**

A month-old 95 dB reading renders exactly as prominently as one from five minutes ago, so the heatmap cannot distinguish current noise from historical noise.

**Recommended fix:**

Include point.weight in the tuple and factor it into the painted alpha and/or radius (e.g., alpha *= weight), and align the _calculateWeight doc comment with the actual values.

---

#### [map-26] City grid is derived from only the 100 most recent global readings

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/screens/search_list_screen.dart:137`

**Description:**

The grid streams getNoiseReadings() which is orderBy timestamp desc, limit(100) (firebase_service.dart:165-171), then requires >= 2 readings per city (line 519). As community data grows, the last-100 window covers fewer cities, so previously listed cities silently vanish from 'Search Cities' even though their data still exists.

**Failure scenario:**

The community records 100 new readings in Colombo over a weekend; Kandy (with 30 older readings) disappears entirely from the city grid.

**Recommended fix:**

Maintain a small aggregated 'city_stats' collection updated on write (count/avg/max per city), or raise the limit and paginate; at minimum surface 'showing stats from the latest 100 readings' in the UI. Note: keep any new query shapes within the single (userId ASC, timestamp DESC) composite-index constraint.

---

#### [uiux-39] Use the existing (dead) ShimmerLoading widget for skeleton loaders instead of bare spinners

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/screens/history_screen.dart:439`

**Description:**

animations.dart already ships a full ShimmerLoading widget (animations.dart:238-310) that is referenced nowhere in lib/. History's initial load and pagination show plain CircularProgressIndicators (history_screen.dart:439-446), and Analytics shows a full-screen spinner (analytics_screen.dart:299-314), both causing layout jumps when content arrives.

**Failure scenario:**

User opens History on a slow connection: a lone spinner on empty background for seconds, then 50 cards pop in at once — no sense of the incoming layout.

**Recommended fix:**

Render 5-6 ShimmerLoading placeholders shaped like history cards (height ~96, borderRadius 12) during _isLoading, and shimmer stat-card rectangles on Analytics. The widget already handles dark/light base colors.

---

#### [offline-19] Replace 2-second polling with event-driven status updates from SyncService

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/widgets/sync_status_indicator.dart:30`

**Description:**

The indicator rebuilds via `setState` every 2 seconds forever (lines 30-33), even when nothing changed, and each tick calls `getSyncStatus` → `getPendingCount`, which iterates every key in the Hive box (offline_storage_service.dart:345-350). With two indicator instances mounted (dashboard_screen.dart:680 and map_view_screen.dart:614) that's two full box scans per 2 s for the app's lifetime. Status can also be up to 2 s stale after a sync completes.

**Failure scenario:**

App idles on the dashboard for an hour: ~1,800 needless rebuilds and box scans per indicator, plus a visible up-to-2-second lag between sync completion and the badge clearing.

**Recommended fix:**

Expose a `ValueNotifier<SyncStatus>`/broadcast Stream from SyncService updated at state transitions (online change, sync start/finish, item synced, queue add), and drive the widget with ValueListenableBuilder/StreamBuilder; keep at most a slow fallback poll.

---

#### [analytics-15] Sound-type filter chips (All/Pollution/Ambient) only affect the pie chart and breakdown — not the trend chart or stat cards

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:539`

**Description:**

_selectedFilter (line 30) is consumed only by _buildSoundTypePieChart (lines 582-586) and _buildSoundCategoryBreakdown (lines 718-752). The chips sit at the top of the screen above everything (lines 330-331), implying page-wide scope, but the trend chart, Average/Lowest/Highest/Duration cards, confidence card and banner count ignore them. Additionally, selecting Pollution or Ambient zeroes the other slice so the 'Sound Type Distribution' pie degenerates to a single 100% slice, which conveys no distribution information.

**Failure scenario:**

User taps 'Pollution' expecting to see the average dB and trend of pollution sounds only; the chart and cards don't change, and the pie now shows a single '100%' slice — the user cannot tell whether the filter is broken or intentionally scoped.

**Recommended fix:**

Either scope the filter globally (filter the stream docs by soundType before bucketing and recompute stats from the filtered set), or visually scope the chips by moving them inside the pie/breakdown card and hiding the pie when a single type is selected (show a count summary instead of a 100% slice).

---

#### [uiux-41] Empty states tell users to act but give no button to act with

**Severity:** Enhancement | **Status:** unverified | **Category:** improvement | **Effort:** M

**Location:** `lib/screens/history_screen.dart:414`

**Description:**

History's empty state says 'Start recording to build your history' (history_screen.dart:414-428) and Analytics' trend chart says 'Start recording to see trends' (analytics_screen.dart:1013) — but neither offers a tap target; the user must discover the Dashboard tab themselves. MainAppShell owns tab switching one level up, so a callback or shared notifier can jump to tab 2.

**Failure scenario:**

New user lands on History, reads 'Start recording…', and taps the text expecting it to take them somewhere; nothing happens.

**Recommended fix:**

Add an ElevatedButton.icon('Start Recording', Icons.mic) under the empty-state text that switches the shell to the Dashboard tab (expose an onNavigateToTab callback from MainAppShell through SharedBottomNavBar, or a static ValueNotifier<int> in SharedAppState).

---

## Quick Wins (under 1 hour each)

- [ ] **settings-18** - Dead code cluster: static themes, unused notification methods, never-called reset(), unused animation widgets (`lib/theme/app_theme.dart:209`)
- [ ] **critic-07** - CONFIDENCE_THRESHOLD, CLASSIFICATION_INTERVAL_SECONDS and HIGH_NOISE_THRESHOLD env vars are documented but never read (`.env.example:12`)
- [ ] **uiux-43** - CSV export ends with an unactionable file path — offer a share sheet (`lib/screens/history_screen.dart:285`)
- [ ] **ml-14** - Stale comment claims indices 137-228 fall through to keyword checks, but they are handled by the first range check (`lib/services/yamnet_class_mapping.dart:1062`)
- [ ] **donate-18** - Dead payment code: flutter_paypal_payment dependency and five DonationService methods are never used (`pubspec.yaml:90`)
- [ ] **uiux-40** - Add haptic feedback to the record start/stop button (`lib/screens/dashboard_screen.dart:837`)
- [ ] **map-25** - Recency weight is computed but never used in rendering (`lib/models/heatmap_point.dart:36`)
- [ ] **critic-10** - Leftover empty `assetsmodels/` directory and inconsistent app display names across platforms (`assetsmodels:1`)
- [ ] **critic-08** - README contradicts the repo: wrong test path, references to nonexistent docs, published test credentials, 'Known Issues: None' (`README.md:116`)
- [ ] **boot-14** - Dead Flutter-template counter code (MyHomePage) still shipped in main.dart (`lib/main.dart:183`)

## Prioritized Roadmap (all findings)

### Phase 1 - Stabilize (Critical + High)

- **flow2-4** [High/confirmed/M] Location failure still saves readings with hardcoded Colombo coordinates and status strings as locationName - `lib/screens/dashboard_screen.dart:492`
- **flow6-01** [Critical/confirmed/M] Delete Account anonymizes all readings BEFORE user.delete(), so a requires-recent-login failure permanently orphans the user's history - `lib/screens/settings_screen_enhanced.dart:904`
- **offline-6** [High/confirmed/M] Offline recordings are uploaded under whichever user is logged in at sync time, not the user who recorded them - `lib/services/sync_service.dart:162`
- **ml-1** [High/confirmed/M] Hardcoded indexToClassName table does not match the official YAMNet 521-class map - `lib/services/yamnet_class_mapping.dart:52`
- **flow6-04** [High/confirmed/S] 'High Noise Alerts' toggle and 'Alert Threshold' slider (50-100 dB) are dead — threshold hardcoded to 70 dB and the toggle is never read - `lib/screens/dashboard_screen.dart:428`
- **sec-2** [High/confirmed/M] Full user email plus precise coordinates written to shared noise_readings docs; masking is client-side only and fails for short emails - `lib/services/firebase_service.dart:119`
- **uiux-3** [High/confirmed/S] 'Export Data to CSV' exports EVERY user's recordings, including their emails - `lib/screens/history_screen.dart:230`
- **fb-2** [High/confirmed/S] Offline-synced readings get the sync time, not the recording time, as their 'timestamp' - `lib/services/sync_service.dart:217`
- **map-1** [High/confirmed/S] Cluster color lookup key never matches — all clusters render as 'moderate' orange - `lib/screens/map_view_screen.dart:687`
- **arch-1** [High/disputed/M] Settings are written to SharedPreferences but never consumed by any feature - `lib/screens/settings_screen_enhanced.dart:161`
- **critic-01** [Critical/confirmed/S] Info.plist has no permission usage descriptions - app crashes on iOS - `ios/Runner/Info.plist:4`
- **flow3-8** [High/confirmed/S] Analytics category-filter lists diverge from the written taxonomy: 'Speech-Pollution' shows under Ambient, and 'Other' vanishes under Ambient filter - `lib/screens/analytics_screen.dart:721`
- **offline-4** [High/confirmed/S] Uploads are not idempotent: `.add()` with auto-ID plus mark-after-upload produces duplicate Firestore documents on retry - `lib/services/sync_service.dart:233`
- **fb-1** [High/confirmed/M] saveNoiseReading silently drops readings and swallows all errors; callers show false success - `lib/services/firebase_service.dart:29`
- **fb-5** [High/disputed/S] Community-feed card creates a brand-new Firestore snapshots() stream on every dashboard rebuild - `lib/screens/dashboard_screen.dart:907`
- **flow2-2** [High/confirmed/M] Offline recordings synced under whoever is logged in at sync time (cross-user attribution) - `lib/services/sync_service.dart:162`
- **flow3-5** [High/confirmed/S] History empty state is a dead end: no scrollable means pull-to-refresh cannot fire, and nothing reloads on tab activation - `lib/screens/history_screen.dart:403`
- **flow6-06** [High/confirmed/M] New email is written to Firestore immediately, but Auth email only changes after the verification link is clicked — data diverges if the user never verifies - `lib/screens/edit_profile_screen.dart:115`
- **fb-3** [High/confirmed/S] History load permanently deadlocks when userId is null: _isLoading stuck true blocks all retries - `lib/screens/history_screen.dart:87`
- **a11y-2** [High/confirmed/S] Primary record/stop button is an unlabeled GestureDetector; recording state changes are never announced - `lib/screens/dashboard_screen.dart:836`
- **uiux-6** [High/confirmed/S] Search-as-you-type never fires when the query contains an uppercase letter - `lib/screens/search_list_screen.dart:292`
- **flow3-4** [High/disputed/M] Analytics mixes a live stream (trend chart) with one-shot stats loaded once at app start - same screen shows contradictory data - `lib/screens/analytics_screen.dart:122`
- **fb-4** [High/confirmed/M] CSV export downloads the entire global noise_readings collection including every user's email - `lib/screens/history_screen.dart:231`
- **flow2-6** [High/confirmed/S] Classification confidence threshold is 0.15 (spec: 0.30) and is non-gating - low-confidence classifications are persisted as fact - `lib/services/sound_classification_service.dart:34`
- **analytics-2** [High/confirmed/S] Weekly/Monthly buckets use rolling 24h windows but x-axis labels claim calendar days — readings attributed to the wrong weekday - `lib/screens/analytics_screen.dart:210`
- **fb-6** [High/confirmed/S] Analytics 'Duration' stat is off by 60x: divides reading count by 12 but readings are saved every 5 seconds - `lib/screens/analytics_screen.dart:163`
- **flow2-1** [Critical/confirmed/S] Offline queue unreadable after app restart - Hive Map<dynamic,dynamic> cast crashes sync, readings never reach Firestore - `lib/services/offline_storage_service.dart:93`
- **sec-10** [High/confirmed/S] Info.plist missing NSMicrophoneUsageDescription and NSLocationWhenInUseUsageDescription — iOS build crashes on first recording - `ios/Runner/Info.plist:4`
- **flow3-7** [High/confirmed/S] 'Duration' stat divides reading count by 12, but readings are saved every 5 seconds - overstates duration ~60x - `lib/screens/analytics_screen.dart:163`
- **dash-2** [High/confirmed/S] Double-start race: _isRecording set only after awaits, leaking a noise subscription and a duplicate save timer - `lib/screens/dashboard_screen.dart:364`
- **donate-4** [High/confirmed/S] 'Open in Browser' button does nothing except show a misleading 'Opening in browser...' snackbar - `lib/widgets/buy_me_coffee_widget.dart:106`
- **settings-9** [High/confirmed/M] Email change writes the new, unverified email to users doc and all noise_readings before verification completes - `lib/screens/edit_profile_screen.dart:100`
- **flow6-03** [High/confirmed/S] 'Anonymize Location' privacy toggle is a silent no-op — exact GPS coordinates are always uploaded - `lib/services/firebase_service.dart:121`
- **flow7-01** [High/confirmed/M] PayPal success/cancel detection can never fire - donation completion is never observed - `lib/widgets/paypal_webview_widget.dart:121`
- **donate-6** [High/confirmed/S] LateInitializationError crash if Reload/Try Again is tapped before the webview controller is created - `lib/widgets/paypal_webview_widget.dart:63`
- **donate-1** [High/confirmed/M] PayPal success/cancel detection can never fire - completion flow is dead code - `lib/widgets/paypal_webview_widget.dart:42`
- **offline-1** [Critical/confirmed/S] Queue is permanently unsyncable after app restart: Hive returns Map<dynamic,dynamic>, fromMap cast throws - `lib/services/offline_storage_service.dart:93`
- **map-2** [High/confirmed/M] Map data can never be refreshed — stale markers/heatmap after a new recording or deletion - `lib/screens/map_view_screen.dart:603`
- **flow2-7** [High/confirmed/M] Sync dead-end: recordings are abandoned forever after 3 failed attempts with no recovery or user surface - `lib/services/sync_service.dart:151`
- **donate-3** [High/confirmed/S] Any failed non-'paypal.com' subresource replaces a working checkout with a full-screen error - including PayPal's own CDN - `lib/widgets/paypal_webview_widget.dart:134`
- **social-4** [High/confirmed/M] Report can be submitted with hardcoded Colombo fallback coordinates and placeholder location names - `lib/screens/report_noise_screen.dart:22`
- **dash-4** [High/confirmed/S] Readings saved with hardcoded Colombo fallback coordinates when location is denied or unavailable - `lib/screens/dashboard_screen.dart:492`
- **flow4-4** [High/confirmed/M] Community feed shows every user's automatic 5-second monitoring samples — manual reports are drowned out of the 100-item window - `lib/screens/community_feed_screen.dart:63`
- **arch-4** [High/confirmed/M] Duplicated unchunked Firestore batch logic breaks account deletion/data wipe for users with >500 readings - `lib/screens/settings_screen_enhanced.dart:893`
- **a11y-1** [High/confirmed/S] Bottom navigation is icon-only with no labels, roles, or selected-state semantics - `lib/widgets/shared_bottom_navbar.dart:57`
- **map-4** [High/disputed/S] Location permission result ignored; denied/deniedForever fail silently and camera jumps to default location - `lib/screens/map_view_screen.dart:288`
- **settings-4** [High/confirmed/S] 'High Noise Alerts' toggle and 'Alert Threshold' slider have no effect — alert logic is hardcoded - `lib/screens/settings_screen_enhanced.dart:180`
- **flow3-1** [High/confirmed/S] Reader field 'soundCategory' never matches writer field 'soundClass' - heatmap points always lose classification - `lib/models/heatmap_point.dart:45`
- **uiux-5** [High/confirmed/S] Map pull-to-refresh can never trigger — markers/heatmap are stale until app restart - `lib/screens/map_view_screen.dart:603`
- **perf-2** [High/confirmed/M] setState on every NoiseReading rebuilds the entire dashboard tree multiple times per second - `lib/screens/dashboard_screen.dart:385`
- **uiux-7** [High/disputed/S] List builders crash the whole screen on a doc with missing/null decibelLevel - `lib/screens/history_screen.dart:451`
- **dash-5** [High/disputed/S] Community Feed count query violates the project Firestore index rule (isGreaterThanOrEqualTo, no orderBy) and swallows the resulting error - `lib/screens/dashboard_screen.dart:911`
- **offline-3** [High/confirmed/S] Sync is only triggered by an offline-to-online transition — never at startup, after login, or after a fallback offline save - `lib/services/sync_service.dart:83`
- **settings-3** [High/confirmed/M] 'Anonymize Location' privacy toggle is a complete no-op — precise coordinates always uploaded - `lib/screens/settings_screen_enhanced.dart:205`
- **uiux-4** [High/confirmed/S] Cluster color is always orange due to broken string interpolation in key lookup - `lib/screens/map_view_screen.dart:686`
- **perf-4** [High/disputed/M] Analytics fetches the same unbounded period query three times and aggregates client-side - `lib/screens/analytics_screen.dart:122`
- **flow1-2** [High/confirmed/S] Onboarding is never persisted as seen — it replays on every signed-out launch and every logout - `lib/screens/splash_screen.dart:36`
- **uiux-2** [High/confirmed/S] Deleting a recording leaves it visible in the list and has no error handling - `lib/screens/history_screen.dart:721`
- **arch-3** [High/confirmed/S] Classification threshold is 0.15 (spec says 0.30) and the threshold gates nothing - `lib/services/sound_classification_service.dart:34`
- **ml-2** [High/confirmed/S] Range fallbacks (0-15 Speech, 16-35 Body Sounds, 229-309 Domestic, ...) are dead code due to 'Unknown_Class_' vs 'YAMNet_Class_' prefix mismatch - `lib/services/yamnet_class_mapping.dart:1011`
- **map-3** [High/confirmed/S] Debounce guard compares raw input to lowercased query — search never fires for capitalized input - `lib/screens/search_list_screen.dart:292`
- **settings-6** [High/confirmed/L] All four Measurement settings (dBA/dBC, Response Time, Recording Duration, Save Frequency) are silent no-ops - `lib/screens/settings_screen_enhanced.dart:90`
- **offline-2** [High/confirmed/M] Recordings that fail 3 sync attempts are stranded forever: attempts are never reset and there is no recovery path - `lib/services/sync_service.dart:151`
- **analytics-3** [High/disputed/M] Stats, pie chart, breakdown and readings count are loaded once in initState and never refresh, while the trend chart live-updates — contradictory data on the same screen - `lib/screens/analytics_screen.dart:47`
- **social-3** [High/confirmed/S] Deleting a recording never updates the on-screen list or the 'Showing X of Y' count - `lib/screens/history_screen.dart:721`
- **donate-2** [High/confirmed/S] Substring-based URL allowlist in PayPal webview is trivially bypassable - arbitrary URLs can load - `lib/widgets/paypal_webview_widget.dart:145`
- **analytics-4** [High/confirmed/S] Manual 'Speech-Pollution' readings appear under the Ambient filter and vanish from the Pollution filter in the category breakdown - `lib/screens/analytics_screen.dart:746`
- **ml-4** [High/confirmed/S] Threshold logic has zero behavioral effect: below-threshold results are returned identically and persisted to Firestore - `lib/services/sound_classification_service.dart:126`
- **settings-1** [Critical/confirmed/M] Delete Account anonymizes all readings BEFORE auth deletion, orphaning data when delete fails - `lib/screens/settings_screen_enhanced.dart:887`
- **flow5-3** [High/confirmed/S] No duplicate-upload protection: sync uses collection.add() with auto ID and marks synced only after the ack - `lib/services/sync_service.dart:233`
- **critic-05** [High/confirmed/M] Release builds are signed with the debug keystore - `android/app/build.gradle.kts:46`
- **perf-5** [High/confirmed/M] CSV export downloads the entire noise_readings collection (all users, unbounded) and builds the CSV on the UI thread - `lib/screens/history_screen.dart:230`
- **sec-1** [Critical/disputed/M] No Firestore/Storage security rules in the app repo; deployed rules are unverifiable and likely open - `firebase.json:1`
- **dash-6** [High/confirmed/M] Recording continues invisibly on tab switch and app background; frozen _currentDb is re-saved every 5s as fresh data - `lib/screens/dashboard_screen.dart:102`
- **settings-5** [High/confirmed/M] 'Daily Reminders' toggle does nothing — no scheduling exists and showDailyReminder() is never called - `lib/screens/settings_screen_enhanced.dart:189`
- **arch-2** [High/confirmed/L] Test suite is broken: 53 of 149 tests fail on a clean `flutter test` run - `test/unit/sound_classification_test.dart:71`
- **flow5-2** [High/confirmed/M] Offline recordings sync under whichever user is logged in at sync time — OfflineRecording has no userId field - `lib/models/offline_recording.dart:5`
- **perf-3** [High/confirmed/M] YAMNet TFLite inference runs synchronously on the main isolate every 5 seconds during recording - `lib/services/sound_classification_service.dart:108`
- **critic-02** [Critical/disputed/L] PayPal merchant secret and all API keys shipped inside the APK via bundled .env - `pubspec.yaml:138`
- **donate-5** [High/confirmed/S] Classification guide contradicts the actual YAMNet mapping for Market, Alarm, Body Sounds, Nature, Other, and Transport - `lib/models/category_guide_data.dart:144`
- **social-5** [High/confirmed/S] 'Noise report submitted successfully!' shows even when nothing was saved — error path is unreachable - `lib/screens/report_noise_screen.dart:235`
- **flow1-1** [High/confirmed/S] Unguarded Firebase.initializeApp dead-ends the app before runApp with no error UI - `lib/main.dart:38`
- **flow6-05** [High/confirmed/S] Clear History, Delete Account, and profile-email propagation all use a single unchunked WriteBatch — fails outright for users with >500 readings - `lib/screens/settings_screen_enhanced.dart:1027`
- **sec-3** [Critical/confirmed/S] Account deletion anonymizes all readings BEFORE deleting the auth user — requires-recent-login leaves data destroyed but account alive - `lib/screens/settings_screen_enhanced.dart:901`
- **social-2** [High/disputed/S] Hard cast `data['decibelLevel'] as num` crashes list rendering on any doc missing decibelLevel - `lib/screens/history_screen.dart:451`
- **ml-3** [High/confirmed/S] Confidence threshold is 0.15, violating the documented project threshold of 0.30 - `lib/services/sound_classification_service.dart:34`
- **boot-1** [High/confirmed/S] No error handling around Firebase init or any pre-runApp startup await — failure leaves a permanent blank screen - `lib/main.dart:38`
- **flow4-3** [High/confirmed/L] 'Report with image' leg of the flow does not exist — ImageCompressionService is unreachable dead code - `lib/services/image_compression_service.dart:12`
- **flow2-3** [High/confirmed/S] Writer/writer field mismatch: offline-sync path omits userEmail that the online path writes and readers consume - `lib/services/sync_service.dart:211`
- **dash-1** [High/confirmed/S] AVG decibel uses arithmetic mean instead of energy-based (logarithmic) averaging - `lib/screens/dashboard_screen.dart:424`
- **flow3-3** [High/confirmed/S] Deleting a recording does not remove it from the History list or update the count - `lib/screens/history_screen.dart:721`
- **uiux-1** [High/confirmed/M] Measurement and alert settings have no effect anywhere in the app - `lib/screens/settings_screen_enhanced.dart:131`

### Phase 2 - Harden (Medium)

- **flow4-7** [Medium/unverified/S] Offline-synced reports show upload time instead of recording time ('Just now' for a 3-day-old reading) - `lib/screens/community_feed_screen.dart:174`
- **flow2-13** [Medium/unverified/M] Restart race: un-awaited _stopRecording can close the NEW session's audio stream and reset _isRecording mid-recording - `lib/screens/dashboard_screen.dart:372`
- **flow1-6** [Medium/unverified/S] Notification permission dialog is awaited before runApp — first launch shows an OS prompt over a blank screen - `lib/main.dart:48`
- **uiux-26** [Medium/unverified/S] Delete-account/clear-history error paths can pop the wrong route - `lib/screens/settings_screen_enhanced.dart:927`
- **flow7-02** [Medium/unverified/S] _paymentComplete set outside setState so the 'Payment Complete!' overlay never renders - `lib/widgets/paypal_webview_widget.dart:123`
- **map-12** [Medium/unverified/S] Timestamp read ignores createdAt fallback — violates the project's dual-timestamp convention - `lib/models/heatmap_point.dart:35`
- **donate-11** [Medium/unverified/S] MIXED_CONTENT_ALWAYS_ALLOW enabled on the payment webview - `lib/widgets/paypal_webview_widget.dart:94`
- **analytics-7** [Medium/unverified/S] Every load issues three identical Firestore queries for the same data (stream + two .get()s) - `lib/screens/analytics_screen.dart:96`
- **arch-11** [Medium/unverified/M] Half the unit-test files never import application code — they test reimplemented local helpers and tautologies - `test/unit/decibel_calculation_test.dart:6`
- **a11y-6** [Medium/unverified/M] Heatmap overlay is color-only with no legend and no semantic alternative - `lib/screens/map_view_screen.dart:649`
- **flow5-8** [Medium/unverified/S] 'Sync Now' gives no feedback — snackbar guarded by the popped dialog's dead context, and its message would be wrong anyway - `lib/widgets/sync_status_indicator.dart:212`
- **flow6-07** [Medium/unverified/S] Name-only profile save fetches every reading and commits EMPTY batch updates - `lib/screens/edit_profile_screen.dart:135`
- **uiux-21** [Medium/unverified/S] History pull-to-refresh is dead exactly in the offline and empty states - `lib/screens/history_screen.dart:383`
- **flow2-12** [Medium/unverified/S] Mic-permission-denied record tap fails silently and leaks the noise-meter subscription - `lib/screens/dashboard_screen.dart:515`
- **flow7-04** [Medium/unverified/M] Navigation allowlists silently block 3-D Secure and login redirects, freezing checkout mid-payment - `lib/widgets/paypal_webview_widget.dart:153`
- **uiux-18** [Medium/unverified/M] All/Pollution/Ambient filter silently applies to only 2 of 5 analytics sections - `lib/screens/analytics_screen.dart:539`
- **ml-9** [Medium/unverified/M] Model-load failure silently disables classification forever with no retry, while the audio-capture pipeline keeps running - `lib/screens/dashboard_screen.dart:592`
- **perf-10** [Medium/unverified/S] HeatmapPainter.shouldRepaint compares only point-list length, and each repaint draws up to 100 blurred circles - `lib/screens/map_view_screen.dart:1471`
- **ml-8** [Medium/unverified/S] Analytics ambientCategories list omits 'Other', so 'Other' readings vanish from both Pollution and Ambient filters - `lib/screens/analytics_screen.dart:729`
- **uiux-14** [Medium/unverified/M] Analytics stat cards/pie chart go permanently stale inside the IndexedStack shell - `lib/screens/analytics_screen.dart:49`
- **a11y-17** [Medium/unverified/S] Hardcoded AppTheme.textGray on light backgrounds yields ~1.8:1 contrast - `lib/screens/dashboard_screen.dart:875`
- **a11y-11** [Medium/unverified/S] Custom filter chips (period, sound type, donation amounts) expose no selected state or button role - `lib/screens/analytics_screen.dart:488`
- **uiux-22** [Medium/unverified/S] Login error handling only maps legacy Firebase error codes — users get generic 'Login failed' - `lib/screens/login_screen.dart:63`
- **a11y-4** [Medium/unverified/S] Noise history LineChart has no semantic alternative — invisible to screen readers - `lib/widgets/noise_history_chart.dart:31`
- **dash-13** [Medium/unverified/S] Gauge scale tops out at 100 dB while readings are clamped to 120 dB: needle pegs, digits keep climbing - `lib/screens/dashboard_screen.dart:747`
- **boot-4** [Medium/unverified/S] Login has no generic catch and its error mapping misses the codes modern Firebase Auth actually returns - `lib/screens/login_screen.dart:61`
- **settings-12** [Medium/unverified/S] Error handlers in _deleteAccount/_clearHistory pop the Settings route when the loading dialog was never shown - `lib/screens/settings_screen_enhanced.dart:944`
- **dash-8** [Medium/unverified/S] setState and timer creation after dispose in _startRecording (no mounted check after await) - `lib/screens/dashboard_screen.dart:482`
- **critic-07** [Medium/unverified/S] CONFIDENCE_THRESHOLD, CLASSIFICATION_INTERVAL_SECONDS and HIGH_NOISE_THRESHOLD env vars are documented but never read - `.env.example:12`
- **uiux-23** [Medium/unverified/S] Community Feed badge query violates the project Firestore index rule and hides loading/error as '0' - `lib/screens/dashboard_screen.dart:911`
- **map-5** [Medium/unverified/S] _showNativeLocationDialog shows no dialog — geolocator throws instead when location services are off - `lib/screens/map_view_screen.dart:330`
- **a11y-19** [Medium/unverified/M] Orange #FF9800 used as text on white/light surfaces fails contrast everywhere it appears - `lib/screens/search_list_screen.dart:608`
- **a11y-24** [Medium/unverified/M] Fixed-aspect-ratio GridView stat/city cards overflow at large text scale - `lib/screens/analytics_screen.dart:359`
- **boot-6** [Medium/unverified/S] Back navigation stays enabled during registration submit — user can pop mid-flight and end up silently authenticated on the Login screen - `lib/screens/registration_screen.dart:136`
- **flow5-10** [Medium/unverified/S] lastSyncTime saved even when every upload failed — dialog shows 'Last Sync: Just now' after a 0% sync - `lib/services/sync_service.dart:191`
- **fb-12** [Medium/unverified/S] Unsafe casts in marker/heatmap building: one malformed doc silently blanks the entire map - `lib/screens/map_view_screen.dart:176`
- **flow2-14** [Medium/unverified/S] Offline save failures are silently discarded - saveOfflineRecording's bool result is ignored - `lib/services/firebase_service.dart:161`
- **a11y-18** [Medium/unverified/S] Classification badges use Colors.red[300]/green[300] text — ~2.9:1 / ~1.9:1 in light mode - `lib/screens/history_screen.dart:613`
- **social-18** [Medium/unverified/S] SharedAppState.locationDialogShown is set true but almost never reset — location dialog shows at most once per session on error paths - `lib/screens/report_noise_screen.dart:183`
- **dash-11** [Medium/unverified/S] In-flight classification resurrects _currentClassification after stop; stale label attached to next session's saves - `lib/screens/dashboard_screen.dart:639`
- **arch-8** [Medium/unverified/M] Six screens bypass FirebaseService and query Firestore directly, duplicating existing service methods - `lib/screens/community_feed_screen.dart:62`
- **donate-10** [Medium/unverified/S] PAYPAL_SECRET getter reads from a .env that ships inside the APK; bundled .env also leaks developer PII - `lib/services/donation_service.dart:10`
- **flow4-5** [Medium/unverified/S] Submit shows 'submitted successfully' even when the report was silently dropped or only queued - `lib/services/firebase_service.dart:27`
- **offline-12** [Medium/unverified/M] No Hive corruption recovery: a corrupt box file permanently disables the offline feature and the indicator lies about it - `lib/services/offline_storage_service.dart:35`
- **flow1-8** [Medium/unverified/M] Auth-gate StreamBuilder is destroyed by the splash pushReplacement — app stops reacting to auth-state changes after first navigation - `lib/main.dart:150`
- **offline-7** [Medium/unverified/S] Manual-sync feedback is wrong and usually never appears: unconditional success snackbar built on the popped dialog's context - `lib/widgets/sync_status_indicator.dart:216`
- **arch-5** [Medium/unverified/S] Dashboard today-count query violates the mandated Firestore query pattern (isGreaterThanOrEqualTo, no orderBy) and streams full docs just to count them - `lib/screens/dashboard_screen.dart:911`
- **uiux-19** [Medium/unverified/S] Map autocomplete fires an HTTP request on every keystroke with no debounce or stale-response guard - `lib/screens/map_view_screen.dart:933`
- **flow4-8** [Medium/unverified/S] No sync on app startup — queued offline reports wait for a connectivity transition or a manual tap - `lib/services/sync_service.dart:56`
- **boot-10** [Medium/unverified/S] runApp is blocked on the notification-permission dialog and a duplicate YAMNet model load - `lib/main.dart:48`
- **a11y-15** [Medium/unverified/S] Login fields have no labels — password field's only accessible name is bullet characters - `lib/screens/login_screen.dart:146`
- **flow2-11** [Medium/unverified/S] Location error with dialog-flag set leaves 'Fetching location...' spinner forever and disables the refresh tap - `lib/screens/dashboard_screen.dart:296`
- **uiux-24** [Medium/unverified/S] City details bottom sheet: 24px city name in a Row without Flexible — RenderFlex overflow on long names - `lib/screens/search_list_screen.dart:649`
- **flow7-07** [Medium/unverified/S] No back-navigation handling in either webview: system back exits checkout instead of going back a page - `lib/widgets/paypal_webview_widget.dart:47`
- **analytics-10** [Medium/unverified/S] No empty or error state for the stats grid — zeros are presented as real measurements and load failures are swallowed - `lib/screens/analytics_screen.dart:367`
- **offline-11** [Medium/unverified/M] Connectivity detection equates any network interface (including bluetooth/VPN) with internet reachability - `lib/services/sync_service.dart:104`
- **analytics-6** [Medium/unverified/S] Average dB uses arithmetic mean instead of energy (Leq) averaging — understates true noise exposure - `lib/services/firebase_service.dart:311`
- **dash-7** [Medium/unverified/S] MIN stat card renders the literal text 'Infinity' until the first reading arrives - `lib/screens/dashboard_screen.dart:1040`
- **sec-11** [Medium/unverified/S] Debug-level logging left enabled for production; logs include PII and payment URLs - `lib/utils/app_logger.dart:22`
- **boot-8** [Medium/unverified/M] IndexedStack eagerly builds all five tabs at mount — three hidden tabs fire Firestore loads at startup and never refresh on tab switch - `lib/widgets/main_app_shell.dart:38`
- **social-9** [Medium/unverified/S] Every load failure is misreported as 'No Internet Connection' - `lib/screens/history_screen.dart:111`
- **social-11** [Medium/unverified/S] ImageCompressionService is fully orphaned — no image pick/compress/upload pipeline exists anywhere - `lib/services/image_compression_service.dart:12`
- **a11y-23** [Medium/unverified/S] Two-line AppBar title Columns overflow the fixed 56dp toolbar at large text scale - `lib/screens/history_screen.dart:358`
- **arch-6** [Medium/unverified/S] Firestore write shape duplicated between FirebaseService and SyncService and has already diverged: offline-synced readings lack userEmail - `lib/services/sync_service.dart:211`
- **a11y-5** [Medium/unverified/M] Analytics trend LineChart and pie chart expose no data to assistive technology - `lib/screens/analytics_screen.dart:1039`
- **a11y-9** [Medium/unverified/S] Multiple IconButtons across screens have no tooltip/label — including the destructive per-item delete - `lib/screens/history_screen.dart:644`
- **a11y-10** [Medium/unverified/S] Search-history icon in map search bar is a bare 24px GestureDetector - `lib/screens/map_view_screen.dart:937`
- **a11y-16** [Medium/unverified/S] AnimatedButton (login/registration submit) is a GestureDetector with no button role or disabled state - `lib/utils/animations.dart:150`
- **uiux-11** [Medium/unverified/S] Decibel gauge hardcoded to 320px — overflows and clips on narrow phones - `lib/widgets/decibel_meter_gauge.dart:20`
- **arch-9** [Medium/unverified/M] Inconsistent state management: unused provider dependency, global ValueNotifiers in main.dart imported back by screens (circular), mixed singleton/non-singleton services - `lib/main.dart:18`
- **a11y-21** [Medium/unverified/S] Guide tile YAMNet info text rendered in raw category color — yellow on near-white is ~1.1:1 - `lib/widgets/classification_guide_widget.dart:142`
- **uiux-20** [Medium/unverified/S] 'Open in Browser' button shows 'Opening in browser...' but never opens anything - `lib/widgets/buy_me_coffee_widget.dart:106`
- **boot-9** [Medium/unverified/M] Microphone keeps recording on a hidden tab with no indicator — tab switch never notifies Dashboard - `lib/widgets/main_app_shell.dart:48`
- **social-15** [Medium/unverified/S] Pull-to-refresh is dead when the list does not fill the screen and on the empty state - `lib/screens/history_screen.dart:432`
- **flow6-12** [Medium/unverified/M] 'Decibel Scale' (dBA/dBC) and 'Response Time' (Fast/Slow) toggles are dead settings - `lib/screens/settings_screen_enhanced.dart:90`
- **arch-12** [Medium/unverified/M] Highest-value pure logic (YAMNet mapping fallbacks, audio preprocessing, analytics bucket math) has no tests and is mostly private/untestable - `lib/services/yamnet_class_mapping.dart:1052`
- **analytics-9** [Medium/unverified/S] Trend chart silently drops readings >120 dB or <0 dB that the stat cards still include - `lib/screens/analytics_screen.dart:191`
- **arch-7** [Medium/unverified/M] No typed NoiseReading model: six screens parse raw doc maps with inconsistent null-safety and inconsistent timestamp/createdAt fallback - `lib/screens/map_view_screen.dart:178`
- **settings-11** [Medium/unverified/S] Account deletion never deletes the users/{uid} profile document — PII retained after deletion - `lib/screens/settings_screen_enhanced.dart:883`
- **uiux-13** [Medium/unverified/S] Analytics load failure is silent — zeros shown as if they were real data - `lib/screens/analytics_screen.dart:172`
- **ml-5** [Medium/unverified/S] Peak normalization amplifies the noise floor to full scale, distorting YAMNet input and making 'Silence' undetectable - `lib/services/sound_classification_service.dart:223`
- **flow3-13** [Medium/unverified/M] Map shows only the 100 most recent readings across ALL users - a user's saved reading can be missing from the map while present in History/Analytics - `lib/screens/map_view_screen.dart:42`
- **boot-3** [Medium/unverified/M] Auth-state routing is destroyed after splash navigates — authStateChanges only routes at cold start - `lib/main.dart:150`
- **flow2-10** [Medium/unverified/S] '_showNativeLocationDialog' shows no dialog - location-denied path dead-ends and the app-wide flag blocks all future prompts - `lib/screens/dashboard_screen.dart:346`
- **flow6-10** [Medium/unverified/M] Five settings rows are silent dead ends: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service have empty onTap handlers - `lib/screens/settings_screen_enhanced.dart:257`
- **dash-16** [Medium/unverified/S] dispose() races closeRecorder against the still-running async _stopRecording - `lib/screens/dashboard_screen.dart:664`
- **donate-12** [Medium/unverified/S] Navigation blocklist blocks legitimate checkout redirects (3-D Secure bank pages, Stripe Link) so some payments cannot complete - `lib/widgets/buy_me_coffee_widget.dart:71`
- **dash-9** [Medium/unverified/S] setState after dispose in _checkAndRefreshLocation: mounted not re-checked after await - `lib/screens/dashboard_screen.dart:132`
- **map-7** [Medium/unverified/S] Heatmap projection ignores map rotation — blobs misalign when the user rotates the map - `lib/screens/map_view_screen.dart:1395`
- **settings-14** [Medium/unverified/S] Change Password maps only legacy 'wrong-password' code; modern Firebase returns 'invalid-credential' so users get a generic error - `lib/screens/settings_screen_enhanced.dart:789`
- **map-17** [Medium/unverified/S] Map autocomplete fires a Nominatim request on every keystroke with no debounce and no out-of-order guard - `lib/screens/map_view_screen.dart:932`
- **settings-8** [Medium/unverified/M] Five settings rows with chevrons do nothing when tapped: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service - `lib/screens/settings_screen_enhanced.dart:223`
- **sec-13** [Medium/unverified/M] Unverified new email is written to the users doc and broadcast into all noise_readings before ownership verification - `lib/screens/edit_profile_screen.dart:115`
- **flow3-12** [Medium/unverified/S] SyncStatusIndicator on the map is painted underneath FlutterMap and is never visible - `lib/screens/map_view_screen.dart:611`
- **a11y-12** [Medium/unverified/S] dBA/dBC and Fast/Slow segmented toggles are ~36dp tall unlabeled GestureDetectors - `lib/screens/settings_screen_enhanced.dart:409`
- **flow2-9** [Medium/unverified/S] Community feed count query violates the project period-query rule (isGreaterThanOrEqualTo, no orderBy) and streams all users' docs unbounded - `lib/screens/dashboard_screen.dart:909`
- **arch-10** [Medium/unverified/L] God files: 5 files over 1,100 lines; dashboard State class mixes audio capture, DSP, persistence timers, notifications and UI - `lib/screens/dashboard_screen.dart:1174`
- **offline-9** [Medium/unverified/S] last_sync_time is saved even when zero recordings synced, so 'Last Sync: just now' is shown after total failure - `lib/services/sync_service.dart:191`
- **boot-7** [Medium/unverified/S] Back button instantly exits the app from any tab — no back-to-home behavior, no confirmation, no-op on iOS - `lib/widgets/main_app_shell.dart:30`
- **a11y-3** [Medium/unverified/S] Decibel gauge (CustomPaint) has no semantic representation of the reading - `lib/widgets/decibel_meter_gauge.dart:19`
- **flow7-09** [Medium/unverified/S] PAYPAL_CLIENT_ID is actually used as the PayPal account email; following .env.example breaks all donations - `lib/widgets/paypal_webview_widget.dart:37`
- **fb-14** [Medium/unverified/S] Read/write field mismatch: heatmap reads 'soundCategory' but every writer stores 'soundClass' - `lib/models/heatmap_point.dart:45`
- **fb-8** [Medium/unverified/S] Search screen creates a new getNoiseReadings() stream on every rebuild - `lib/screens/search_list_screen.dart:137`
- **ml-7** [Medium/unverified/S] YAMNet model is loaded twice at cold start, both times before runApp - `lib/main.dart:66`
- **uiux-8** [Medium/unverified/S] Completely blank screen when a search returns zero results - `lib/screens/search_list_screen.dart:403`
- **a11y-7** [Medium/unverified/S] Sync status indicator tap target is roughly 34x26dp and lacks a button role - `lib/widgets/sync_status_indicator.dart:101`
- **uiux-9** [Medium/unverified/S] AppBar back arrows nearly invisible in light mode; per-screen white-icon hacks are inconsistent - `lib/screens/settings_screen_enhanced.dart:80`
- **flow6-14** [Medium/unverified/M] 'Share Data with Researchers' toggle is a no-op — every reading is always globally visible - `lib/screens/settings_screen_enhanced.dart:214`
- **flow6-13** [Medium/unverified/S] 'Recording Duration' and 'Save Frequency' sliders are dead — save interval hardcoded to 5 s, recording never auto-stops - `lib/screens/settings_screen_enhanced.dart:131`
- **flow4-6** [Medium/unverified/S] Placeholder location strings and default Colombo coordinates are written to Firestore and shown verbatim in the community feed - `lib/screens/report_noise_screen.dart:224`
- **fb-11** [Medium/unverified/M] Connectivity check trusts interface state: connected-without-internet hangs the online save path indefinitely - `lib/services/firebase_service.dart:43`
- **flow1-3** [Medium/unverified/S] Registration handoff leaves a stale LoginScreen route underneath MainAppShell - `lib/screens/registration_screen.dart:79`
- **settings-13** [Medium/unverified/S] Logout is incomplete: SharedAppState never reset, notifications not cancelled, and navigation duplicates the auth-state listener - `lib/screens/dashboard_screen.dart:684`
- **perf-11** [Medium/unverified/S] FadeInListItem delay scales with absolute list index, hiding deep rows for seconds and allocating a controller per row - `lib/screens/history_screen.dart:458`
- **map-13** [Medium/unverified/M] Every bare map tap recreates the whole cluster layer via key bump - `lib/screens/map_view_screen.dart:625`
- **analytics-8** [Medium/unverified/M] Unbounded period queries with full client-side re-aggregation on every rebuild - `lib/screens/analytics_screen.dart:1021`
- **map-8** [Medium/unverified/S] HeatmapPainter.shouldRepaint compares only list length — equal-count data changes can render stale - `lib/screens/map_view_screen.dart:1471`
- **donate-9** [Medium/unverified/S] Donation history entries are corrupted on read: split(':') breaks on ISO-8601 timestamps - `lib/services/donation_service.dart:98`
- **map-16** [Medium/unverified/S] Nominatim query string is not URL-encoded - `lib/screens/map_view_screen.dart:362`
- **social-16** [Medium/unverified/S] History does not reload after returning from 'Add Manual' — the just-submitted recording is missing - `lib/screens/history_screen.dart:480`
- **flow5-9** [Medium/unverified/M] Offline detection is transport-level only; captive-portal wifi hangs sync with _isSyncing stuck true - `lib/services/sync_service.dart:99`
- **settings-7** [Medium/unverified/M] 'Share Data with Researchers' consent toggle is never consulted — data shared regardless - `lib/screens/settings_screen_enhanced.dart:214`
- **settings-15** [Medium/unverified/S] Notification permission requested only at cold start and init is Android-only — toggle-on can never recover a denial, iOS silently unsupported - `lib/services/notification_service.dart:14`
- **dash-10** [Medium/unverified/S] Stop is not immediate: _isRecording stays true through async teardown (up to 3s), and a second stop tap re-enters concurrently - `lib/screens/dashboard_screen.dart:544`
- **dash-14** [Medium/unverified/S] Chart maxY is 100 but data reaches 120 dB; line draws outside the plot with no clipping - `lib/widgets/noise_history_chart.dart:61`
- **uiux-15** [Medium/unverified/S] Logout executes instantly with no confirmation - `lib/screens/dashboard_screen.dart:683`
- **sec-7** [Medium/unverified/M] Donation 'success' is detected by URL substring with no server verification — spoofable and effectively dead code - `lib/widgets/paypal_webview_widget.dart:121`
- **donate-8** [Medium/unverified/S] Substring-based navigation allowlist in BMC webview is bypassable (same flaw as PayPal webview) - `lib/widgets/buy_me_coffee_widget.dart:64`
- **offline-10** [Medium/unverified/S] One malformed queue entry blocks the entire queue: no per-item error handling around fromMap - `lib/services/offline_storage_service.dart:86`
- **uiux-25** [Medium/unverified/S] CSV export has no busy state — long download with only a 1-second snackbar, repeat taps run parallel exports - `lib/screens/history_screen.dart:222`
- **a11y-13** [Medium/unverified/S] Settings switches are not semantically associated with their text labels - `lib/screens/settings_screen_enhanced.dart:454`
- **donate-7** [Medium/unverified/S] Any failed subresource on the Buy Me a Coffee page triggers the full-screen error overlay - `lib/widgets/buy_me_coffee_widget.dart:56`
- **perf-7** [Medium/unverified/S] Cluster builder does an O(n) string scan per marker per cluster with a key that can never match - `lib/screens/map_view_screen.dart:686`
- **flow1-5** [Medium/unverified/S] Login error mapping is dead code under modern Firebase Auth and non-FirebaseAuthException failures are swallowed silently - `lib/screens/login_screen.dart:61`
- **offline-8** [Medium/unverified/S] Sync loop has no upload timeout and no mid-batch online re-check; with Firestore persistence enabled a dropped connection hangs the sync indefinitely - `lib/services/sync_service.dart:149`
- **flow6-11** [Medium/unverified/M] 'Daily Reminders' toggle does nothing — no scheduler exists and showDailyReminder is never called - `lib/screens/settings_screen_enhanced.dart:189`
- **social-8** [Medium/unverified/S] Email masking is skipped entirely for local parts of 3 characters or fewer — full email of other users displayed - `lib/screens/community_feed_screen.dart:216`
- **uiux-17** [Medium/unverified/S] Change Password dialog has no busy/disabled state during the network call - `lib/screens/settings_screen_enhanced.dart:728`
- **map-6** [Medium/unverified/S] SyncStatusIndicator is painted beneath the map and is never visible - `lib/screens/map_view_screen.dart:611`
- **arch-14** [Medium/unverified/S] Eight declared dependencies are never imported anywhere in lib/ or test/ - `pubspec.yaml:54`
- **uiux-10** [Medium/unverified/S] Hardcoded AppTheme.textGray used on light backgrounds — near-invisible text in light mode - `lib/screens/splash_screen.dart:82`
- **boot-5** [Medium/unverified/M] Partial registration failure strands a signed-in user with no profile doc and 'email-already-in-use' on retry - `lib/screens/registration_screen.dart:56`
- **donate-13** [Medium/unverified/S] Sandbox mode is the silent default and is currently enabled - release builds would send real users to sandbox.paypal.com - `lib/services/donation_service.dart:12`
- **arch-13** [Medium/unverified/S] Logging inconsistency: 7 files with error paths log nothing while the rest of the app uses AppLogger - `lib/screens/settings_screen_enhanced.dart:944`
- **fb-10** [Medium/unverified/M] Period queries (getUserReadingsByPeriod/Once, calculateStatsByPeriod) have no limit - `lib/services/firebase_service.dart:263`
- **social-10** [Medium/unverified/S] Location pill spinner sticks on and the refresh button stays disabled — _isGettingLocation is cleared without setState - `lib/screens/report_noise_screen.dart:174`

### Phase 3 - Polish (Low + Enhancement)

- **sec-17** [Low/unverified/S] Login error handling enables account enumeration - `lib/screens/login_screen.dart:65`
- **flow1-13** [Low/unverified/S] users/{uid} profile document written at registration is never read anywhere — totalRecordings and preferences are dead, divergent data - `lib/screens/registration_screen.dart:68`
- **arch-17** [Low/unverified/S] dB-to-color/label banding duplicated in 7 places - `lib/widgets/decibel_meter_gauge.dart:177`
- **a11y-26** [Low/unverified/S] Location pill and community feed card are tappable GestureDetectors with no button role or action hint - `lib/screens/dashboard_screen.dart:752`
- **map-14** [Low/unverified/S] Selecting an autocomplete result leaves an empty red label on the searched-location pin - `lib/screens/map_view_screen.dart:812`
- **uiux-35** [Low/unverified/S] Saving profile replaces the entire form with a bare spinner - `lib/screens/edit_profile_screen.dart:218`
- **boot-11** [Low/unverified/S] Email validation is nearly a no-op on both auth forms - `lib/screens/login_screen.dart:159`
- **offline-16** [Low/unverified/S] Queue key collisions silently overwrite recordings: ID is millisecond timestamp + userId - `lib/services/offline_storage_service.dart:58`
- **uiux-42** [Enhancement/unverified/M] HeatmapSettingsPanel is fully built but dead — wire it up or delete it - `lib/widgets/heatmap_settings_panel.dart:6`
- **flow4-13** [Low/unverified/M] Hardcoded AppTheme colors and manual brightness checks throughout the feed (and spots of the report screen) violate the ThemeHelper convention - `lib/screens/community_feed_screen.dart:60`
- **map-20** [Low/unverified/S] MapController is never disposed - `lib/screens/map_view_screen.dart:105`
- **analytics-13** [Low/unverified/S] Daily x-axis labels claim clock hours but buckets are rolling 60-minute windows anchored to 'now' - `lib/screens/analytics_screen.dart:239`
- **a11y-14** [Low/unverified/S] Sliders announce percentages instead of their real units (seconds / dB) - `lib/screens/settings_screen_enhanced.dart:495`
- **arch-16** [Low/unverified/S] Dead FirebaseService methods, one of which fetches the entire collection and ignores all its parameters - `lib/services/firebase_service.dart:243`
- **settings-18** [Low/unverified/S] Dead code cluster: static themes, unused notification methods, never-called reset(), unused animation widgets - `lib/theme/app_theme.dart:209`
- **flow7-11** [Low/unverified/S] Success path never returns the user to the app: thank-you dialog Close only dismisses the dialog - `lib/services/donation_service.dart:186`
- **analytics-12** [Low/unverified/S] Negative elapsed time (server timestamp ahead of device clock) produces bucket indices beyond maxX, drawing spots outside the chart - `lib/screens/analytics_screen.dart:206`
- **flow7-12** [Low/unverified/M] Two different webview plugins power the two donation webviews - `lib/widgets/buy_me_coffee_widget.dart:2`
- **uiux-43** [Enhancement/unverified/S] CSV export ends with an unactionable file path — offer a share sheet - `lib/screens/history_screen.dart:285`
- **settings-19** [Low/unverified/S] Theme color picker uses white selection borders/labels tuned for dark mode only - `lib/screens/settings_screen_enhanced.dart:640`
- **uiux-31** [Low/unverified/S] Duplicate 'current location' person marker layer rendered whenever a search is active - `lib/screens/map_view_screen.dart:768`
- **ml-14** [Low/unverified/S] Stale comment claims indices 137-228 fall through to keyword checks, but they are handled by the first range check - `lib/services/yamnet_class_mapping.dart:1062`
- **fb-15** [Low/unverified/S] Dead FirebaseService methods with latent hazards: full-collection scan, ignored parameters, crash-prone cast - `lib/services/firebase_service.dart:250`
- **flow2-15** [Low/unverified/S] Mic permission dialog uses BuildContext across an async gap without a mounted check - `lib/screens/dashboard_screen.dart:311`
- **perf-12** [Low/unverified/S] Sync indicator polls every 2 seconds with unconditional setState and full Hive box iteration - `lib/widgets/sync_status_indicator.dart:30`
- **map-23** [Low/unverified/S] Hardcoded AppTheme colors with manual isDark branching instead of ThemeHelper (project convention violation) - `lib/screens/map_view_screen.dart:879`
- **offline-14** [Low/unverified/S] Hardcoded Material colors throughout the widget violate the project's ThemeHelper convention - `lib/widgets/sync_status_indicator.dart:83`
- **a11y-8** [Low/unverified/S] Heatmap FAB and map location FAB have no tooltip; heatmap toggle state not exposed - `lib/widgets/heatmap_fab.dart:21`
- **flow6-17** [Low/unverified/S] Settings has no Sign Out option — logout exists only as an unlabeled icon in the Dashboard app bar - `lib/screens/settings_screen_enhanced.dart:229`
- **sec-16** [Low/unverified/S] Weak auth input validation: 6-char password minimum, naive email check, raw exception text shown to users - `lib/screens/registration_screen.dart:323`
- **map-15** [Low/unverified/S] Duplicate current-location MarkerLayer mislabeled as 'Searched location marker' - `lib/screens/map_view_screen.dart:768`
- **offline-18** [Low/unverified/S] 5-second delay after each failed item blocks the rest of the batch without actually retrying anything - `lib/services/sync_service.dart:184`
- **dash-19** [Low/unverified/S] Hardcoded AppTheme colors in dashboard UI violate the ThemeHelper convention - `lib/screens/dashboard_screen.dart:875`
- **flow1-9** [Low/unverified/S] Inconsistent auth-exit destinations: logout replays splash+onboarding, account deletion goes straight to LoginScreen - `lib/screens/dashboard_screen.dart:694`
- **flow1-11** [Low/unverified/M] Hardcoded colors on the launch/auth screens violate the ThemeHelper convention and break light mode on onboarding - `lib/widgets/world_map_background.dart:90`
- **donate-17** [Low/unverified/S] Location pins use absolute pixel positions while continents scale with screen size, so pins drift onto the wrong continents; colors ignore light theme - `lib/widgets/world_map_background.dart:27`
- **donate-18** [Enhancement/unverified/S] Dead payment code: flutter_paypal_payment dependency and five DonationService methods are never used - `pubspec.yaml:90`
- **map-22** [Low/unverified/M] HeatmapSettingsPanel and the entire heatmap filter/statistics API are dead code - `lib/widgets/heatmap_settings_panel.dart:6`
- **uiux-33** [Low/unverified/S] Reload button crashes with LateInitializationError if tapped before the WebView is created - `lib/widgets/paypal_webview_widget.dart:63`
- **uiux-40** [Enhancement/unverified/S] Add haptic feedback to the record start/stop button - `lib/screens/dashboard_screen.dart:837`
- **map-25** [Enhancement/unverified/S] Recency weight is computed but never used in rendering - `lib/models/heatmap_point.dart:36`
- **flow7-13** [Low/unverified/M] Recorded donation amount is the app-side amount, never verified against the actual transaction - `lib/widgets/paypal_webview_widget.dart:287`
- **critic-10** [Low/unverified/S] Leftover empty `assetsmodels/` directory and inconsistent app display names across platforms - `assetsmodels:1`
- **flow3-15** [Low/unverified/S] History list, CSV export, and HeatmapPoint ignore the createdAt fallback convention - `lib/screens/history_screen.dart:453`
- **uiux-32** [Low/unverified/S] Nominatim query string is interpolated unencoded into the URL - `lib/screens/map_view_screen.dart:363`
- **uiux-34** [Low/unverified/S] Pale red[300]/green[300] classification colors designed for dark mode used on white surfaces - `lib/screens/report_noise_screen.dart:404`
- **boot-12** [Low/unverified/S] Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention across four boot files - `lib/screens/onboarding_screen.dart:76`
- **flow5-12** [Low/unverified/S] Dead storage API for a nonexistent BackgroundSyncService, including duplicated markAsSynced with divergent schema - `lib/services/offline_storage_service.dart:103`
- **a11y-25** [Enhancement/unverified/M] Animations ignore the system reduce-motion / disable-animations setting - `lib/utils/animations.dart:313`
- **map-18** [Low/unverified/S] Typing 1-2 characters blanks the Search Cities screen and wastes a fetch - `lib/screens/search_list_screen.dart:304`
- **flow6-16** [Low/unverified/S] Two live Settings instances (shell tab + dashboard push) desync because prefs load only in initState - `lib/screens/settings_screen_enhanced.dart:37`
- **dash-18** [Low/unverified/S] Both gauge painters return shouldRepaint => true, forcing full repaints on every frame of every rebuild - `lib/widgets/decibel_meter_gauge.dart:188`
- **arch-20** [Low/unverified/S] Startup loads the YAMNet TFLite model twice before the first frame - `lib/main.dart:66`
- **critic-08** [Low/unverified/S] README contradicts the repo: wrong test path, references to nonexistent docs, published test credentials, 'Known Issues: None' - `README.md:116`
- **dash-20** [Low/unverified/S] Gauge widget hand-rolls isDark branching with raw AppTheme constants instead of ThemeHelper - `lib/widgets/decibel_meter_gauge.dart:86`
- **a11y-20** [Low/unverified/S] Edit-profile hint text at 30% alpha is ~1.5:1 contrast in both themes - `lib/screens/edit_profile_screen.dart:264`
- **ml-11** [Low/unverified/S] Int16-to-float scaling divides by 32767, producing samples below -1.0 - `lib/screens/dashboard_screen.dart:529`
- **donate-15** [Low/unverified/S] Impact-message math is internally inconsistent (100x jump at the $50 tier) - `lib/services/donation_service.dart:27`
- **offline-13** [Low/unverified/S] Sync status dialog shows frozen data: values captured once at open and never refreshed - `lib/widgets/sync_status_indicator.dart:149`
- **dash-17** [Low/unverified/M] Zero UI feedback that readings are being auto-saved every 5 seconds, and save failures are fully silent - `lib/screens/dashboard_screen.dart:487`
- **ml-12** [Low/unverified/M] Latent resampler defects: no anti-aliasing filter and output can be shorter than the computed length - `lib/services/sound_classification_service.dart:192`
- **sec-14** [Low/unverified/S] User search text interpolated unencoded into Nominatim URLs — query-string parameter injection - `lib/screens/map_view_screen.dart:363`
- **map-26** [Enhancement/unverified/M] City grid is derived from only the 100 most recent global readings - `lib/screens/search_list_screen.dart:137`
- **fb-18** [Low/unverified/S] Hard (as num) decibelLevel casts in list/grid builders crash the whole view on a single bad doc - `lib/screens/search_list_screen.dart:505`
- **settings-21** [Low/unverified/S] Change Password dialog leaks TextEditingControllers - `lib/screens/settings_screen_enhanced.dart:678`
- **settings-22** [Low/unverified/S] Dark theme AppBar ignores the user's selected theme color while light theme follows it - `lib/theme/app_theme.dart:57`
- **offline-15** [Low/unverified/S] SyncStatusIndicator's onTap constructor parameter is silently ignored - `lib/widgets/sync_status_indicator.dart:102`
- **dash-22** [Low/unverified/S] Curved line interpolation can overshoot, drawing dB levels that were never measured - `lib/widgets/noise_history_chart.dart:67`
- **uiux-39** [Enhancement/unverified/M] Use the existing (dead) ShimmerLoading widget for skeleton loaders instead of bare spinners - `lib/screens/history_screen.dart:439`
- **a11y-22** [Low/unverified/S] Inactive nav icons at 50% white on primary color are ~2.2:1 in light mode - `lib/widgets/shared_bottom_navbar.dart:66`
- **donate-16** [Low/unverified/M] Donation flow screens hardcode AppTheme/Material colors instead of using ThemeHelper (project convention violation) - `lib/screens/donation_screen.dart:93`
- **uiux-30** [Low/unverified/S] Impact message box hardcodes Colors.green.shade50 — glaring light block in dark mode - `lib/screens/donation_screen.dart:318`
- **arch-18** [Low/unverified/S] AppLogger level hardcoded to Level.debug with a TODO — verbose logs ship in release builds - `lib/utils/app_logger.dart:22`
- **fb-19** [Low/unverified/M] City statistics are computed from only the newest 100 global readings but presented as totals - `lib/services/firebase_service.dart:169`
- **flow1-14** [Low/unverified/S] Fixed unskippable 3-second splash delay stacks on top of already-slow pre-runApp init - `lib/screens/splash_screen.dart:36`
- **social-12** [Low/unverified/S] Compression failure silently returns the original full-size image with no size cap (latent) - `lib/services/image_compression_service.dart:44`
- **social-13** [Low/unverified/S] Compression stats divide by zero for images under 1 KB — logs 'Infinity% reduction' or 'NaN' - `lib/services/image_compression_service.dart:34`
- **perf-13** [Low/unverified/S] Dead service methods with unbounded full-collection queries are cost traps - `lib/services/firebase_service.dart:243`
- **map-19** [Low/unverified/S] Map position written to SharedPreferences on every gesture frame - `lib/screens/map_view_screen.dart:631`
- **offline-19** [Enhancement/unverified/M] Replace 2-second polling with event-driven status updates from SyncService - `lib/widgets/sync_status_indicator.dart:30`
- **analytics-15** [Enhancement/unverified/M] Sound-type filter chips (All/Pollution/Ambient) only affect the pie chart and breakdown — not the trend chart or stat cards - `lib/screens/analytics_screen.dart:539`
- **analytics-11** [Low/unverified/S] capturedPeriod race guard fails for A→B→A period toggles — a stale in-flight load can overwrite the newer one - `lib/screens/analytics_screen.dart:157`
- **ml-13** [Low/unverified/S] Interpreter is never closed: dispose() and reset() have zero call sites - `lib/services/sound_classification_service.dart:260`
- **offline-17** [Low/unverified/M] Duplicate, drifting storage APIs (two markAsSynced, two attempt-updaters, two pending counters) with inconsistent persistence formats - `lib/services/offline_storage_service.dart:123`
- **flow5-11** [Low/unverified/S] In-loop 5-second retry delay never retries anything — it only stalls the remaining queue - `lib/services/sync_service.dart:184`
- **map-21** [Low/unverified/S] Saved map position restore races the first FlutterMap layout - `lib/screens/map_view_screen.dart:241`
- **uiux-29** [Low/unverified/S] Gauge arc and needle hardcode purple — the app's marquee widget ignores the selected theme color - `lib/widgets/decibel_meter_gauge.dart:96`
- **boot-14** [Low/unverified/S] Dead Flutter-template counter code (MyHomePage) still shipped in main.dart - `lib/main.dart:183`
- **uiux-38** [Low/unverified/S] Live chart maxY is 100 but readings go up to 120 — loud spikes draw outside the card - `lib/widgets/noise_history_chart.dart:61`
- **social-14** [Low/unverified/S] Community feed bypasses ThemeHelper entirely — hardcoded AppTheme colors with manual brightness checks throughout - `lib/screens/community_feed_screen.dart:87`
- **boot-15** [Low/unverified/S] Firebase API keys committed without evidence of key restrictions or App Check — abuse surface for Auth endpoints - `lib/firebase_options.dart:50`
- **arch-19** [Low/unverified/S] Dependency hygiene: latlong2 pinned to 'any' and build tool flutter_launcher_icons in runtime dependencies - `pubspec.yaml:106`
- **settings-17** [Low/unverified/S] Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention - `lib/screens/settings_screen_enhanced.dart:391`
- **map-24** [Low/unverified/S] Heatmap paints oldest readings on top of newest at the same location - `lib/screens/map_view_screen.dart:1438`
- **ml-10** [Low/unverified/S] Stale classification is re-saved to Firestore when subsequent classifications fail or return null - `lib/screens/dashboard_screen.dart:498`
- **arch-15** [Low/unverified/S] Dead files: image_compression_service.dart (99 lines), heatmap_settings_panel.dart (285 lines), and the template MyHomePage in main.dart - `lib/services/image_compression_service.dart:1`
- **uiux-41** [Enhancement/unverified/M] Empty states tell users to act but give no button to act with - `lib/screens/history_screen.dart:414`
- **uiux-28** [Low/unverified/S] Community feed hardcodes AppTheme.primaryPurple and raw AppTheme colors, ignoring the user's theme color - `lib/screens/community_feed_screen.dart:73`
- **flow4-12** [Low/unverified/S] soundClass/soundType/confidence are written by the report screen but never displayed in the community feed - `lib/screens/community_feed_screen.dart:185`
