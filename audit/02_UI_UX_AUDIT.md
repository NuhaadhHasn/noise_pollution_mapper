# UI/UX Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **64** (7 High, 26 Medium, 31 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| uiux-3 | High | confirmed | `lib/screens/history_screen.dart:230` | 'Export Data to CSV' exports EVERY user's recordings, including their emails | S |
| uiux-6 | High | confirmed | `lib/screens/search_list_screen.dart:292` | Search-as-you-type never fires when the query contains an uppercase letter | S |
| uiux-5 | High | confirmed | `lib/screens/map_view_screen.dart:603` | Map pull-to-refresh can never trigger — markers/heatmap are stale until app restart | S |
| uiux-7 | High | disputed | `lib/screens/history_screen.dart:451` | List builders crash the whole screen on a doc with missing/null decibelLevel | S |
| uiux-4 | High | confirmed | `lib/screens/map_view_screen.dart:686` | Cluster color is always orange due to broken string interpolation in key lookup | S |
| uiux-2 | High | confirmed | `lib/screens/history_screen.dart:721` | Deleting a recording leaves it visible in the list and has no error handling | S |
| uiux-1 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:131` | Measurement and alert settings have no effect anywhere in the app | M |
| flow1-6 | Medium | unverified | `lib/main.dart:48` | Notification permission dialog is awaited before runApp — first launch shows an OS prompt over a blank screen | S |
| uiux-26 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:927` | Delete-account/clear-history error paths can pop the wrong route | S |
| uiux-21 | Medium | unverified | `lib/screens/history_screen.dart:383` | History pull-to-refresh is dead exactly in the offline and empty states | S |
| uiux-18 | Medium | unverified | `lib/screens/analytics_screen.dart:539` | All/Pollution/Ambient filter silently applies to only 2 of 5 analytics sections | M |
| uiux-14 | Medium | unverified | `lib/screens/analytics_screen.dart:49` | Analytics stat cards/pie chart go permanently stale inside the IndexedStack shell | M |
| uiux-22 | Medium | unverified | `lib/screens/login_screen.dart:63` | Login error handling only maps legacy Firebase error codes — users get generic 'Login failed' | S |
| uiux-23 | Medium | unverified | `lib/screens/dashboard_screen.dart:911` | Community Feed badge query violates the project Firestore index rule and hides loading/error as '0' | S |
| boot-6 | Medium | unverified | `lib/screens/registration_screen.dart:136` | Back navigation stays enabled during registration submit — user can pop mid-flight and end up silently authenticated on the Login screen | S |
| offline-7 | Medium | unverified | `lib/widgets/sync_status_indicator.dart:216` | Manual-sync feedback is wrong and usually never appears: unconditional success snackbar built on the popped dialog's context | S |
| uiux-19 | Medium | unverified | `lib/screens/map_view_screen.dart:933` | Map autocomplete fires an HTTP request on every keystroke with no debounce or stale-response guard | S |
| uiux-24 | Medium | unverified | `lib/screens/search_list_screen.dart:649` | City details bottom sheet: 24px city name in a Row without Flexible — RenderFlex overflow on long names | S |
| flow7-07 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:47` | No back-navigation handling in either webview: system back exits checkout instead of going back a page | S |
| analytics-10 | Medium | unverified | `lib/screens/analytics_screen.dart:367` | No empty or error state for the stats grid — zeros are presented as real measurements and load failures are swallowed | S |
| uiux-11 | Medium | unverified | `lib/widgets/decibel_meter_gauge.dart:20` | Decibel gauge hardcoded to 320px — overflows and clips on narrow phones | S |
| uiux-20 | Medium | unverified | `lib/widgets/buy_me_coffee_widget.dart:106` | 'Open in Browser' button shows 'Opening in browser...' but never opens anything | S |
| social-15 | Medium | unverified | `lib/screens/history_screen.dart:432` | Pull-to-refresh is dead when the list does not fill the screen and on the empty state | S |
| uiux-13 | Medium | unverified | `lib/screens/analytics_screen.dart:172` | Analytics load failure is silent — zeros shown as if they were real data | S |
| settings-8 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:223` | Five settings rows with chevrons do nothing when tapped: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service | M |
| flow3-12 | Medium | unverified | `lib/screens/map_view_screen.dart:611` | SyncStatusIndicator on the map is painted underneath FlutterMap and is never visible | S |
| boot-7 | Medium | unverified | `lib/widgets/main_app_shell.dart:30` | Back button instantly exits the app from any tab — no back-to-home behavior, no confirmation, no-op on iOS | S |
| uiux-8 | Medium | unverified | `lib/screens/search_list_screen.dart:403` | Completely blank screen when a search returns zero results | S |
| uiux-9 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:80` | AppBar back arrows nearly invisible in light mode; per-screen white-icon hacks are inconsistent | S |
| uiux-15 | Medium | unverified | `lib/screens/dashboard_screen.dart:683` | Logout executes instantly with no confirmation | S |
| uiux-25 | Medium | unverified | `lib/screens/history_screen.dart:222` | CSV export has no busy state — long download with only a 1-second snackbar, repeat taps run parallel exports | S |
| uiux-17 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:728` | Change Password dialog has no busy/disabled state during the network call | S |
| uiux-10 | Medium | unverified | `lib/screens/splash_screen.dart:82` | Hardcoded AppTheme.textGray used on light backgrounds — near-invisible text in light mode | S |
| map-14 | Low | unverified | `lib/screens/map_view_screen.dart:812` | Selecting an autocomplete result leaves an empty red label on the searched-location pin | S |
| uiux-35 | Low | unverified | `lib/screens/edit_profile_screen.dart:218` | Saving profile replaces the entire form with a bare spinner | S |
| flow4-13 | Low | unverified | `lib/screens/community_feed_screen.dart:60` | Hardcoded AppTheme colors and manual brightness checks throughout the feed (and spots of the report screen) violate the ThemeHelper convention | M |
| flow7-11 | Low | unverified | `lib/services/donation_service.dart:186` | Success path never returns the user to the app: thank-you dialog Close only dismisses the dialog | S |
| settings-19 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:640` | Theme color picker uses white selection borders/labels tuned for dark mode only | S |
| uiux-31 | Low | unverified | `lib/screens/map_view_screen.dart:768` | Duplicate 'current location' person marker layer rendered whenever a search is active | S |
| map-23 | Low | unverified | `lib/screens/map_view_screen.dart:879` | Hardcoded AppTheme colors with manual isDark branching instead of ThemeHelper (project convention violation) | S |
| offline-14 | Low | unverified | `lib/widgets/sync_status_indicator.dart:83` | Hardcoded Material colors throughout the widget violate the project's ThemeHelper convention | S |
| dash-19 | Low | unverified | `lib/screens/dashboard_screen.dart:875` | Hardcoded AppTheme colors in dashboard UI violate the ThemeHelper convention | S |
| flow1-11 | Low | unverified | `lib/widgets/world_map_background.dart:90` | Hardcoded colors on the launch/auth screens violate the ThemeHelper convention and break light mode on onboarding | M |
| donate-17 | Low | unverified | `lib/widgets/world_map_background.dart:27` | Location pins use absolute pixel positions while continents scale with screen size, so pins drift onto the wrong continents; colors ignore light theme | S |
| uiux-33 | Low | unverified | `lib/widgets/paypal_webview_widget.dart:63` | Reload button crashes with LateInitializationError if tapped before the WebView is created | S |
| uiux-32 | Low | unverified | `lib/screens/map_view_screen.dart:363` | Nominatim query string is interpolated unencoded into the URL | S |
| uiux-34 | Low | unverified | `lib/screens/report_noise_screen.dart:404` | Pale red[300]/green[300] classification colors designed for dark mode used on white surfaces | S |
| boot-12 | Low | unverified | `lib/screens/onboarding_screen.dart:76` | Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention across four boot files | S |
| map-18 | Low | unverified | `lib/screens/search_list_screen.dart:304` | Typing 1-2 characters blanks the Search Cities screen and wastes a fetch | S |
| dash-20 | Low | unverified | `lib/widgets/decibel_meter_gauge.dart:86` | Gauge widget hand-rolls isDark branching with raw AppTheme constants instead of ThemeHelper | S |
| donate-15 | Low | unverified | `lib/services/donation_service.dart:27` | Impact-message math is internally inconsistent (100x jump at the $50 tier) | S |
| offline-13 | Low | unverified | `lib/widgets/sync_status_indicator.dart:149` | Sync status dialog shows frozen data: values captured once at open and never refreshed | S |
| dash-17 | Low | unverified | `lib/screens/dashboard_screen.dart:487` | Zero UI feedback that readings are being auto-saved every 5 seconds, and save failures are fully silent | M |
| settings-22 | Low | unverified | `lib/theme/app_theme.dart:57` | Dark theme AppBar ignores the user's selected theme color while light theme follows it | S |
| dash-22 | Low | unverified | `lib/widgets/noise_history_chart.dart:67` | Curved line interpolation can overshoot, drawing dB levels that were never measured | S |
| donate-16 | Low | unverified | `lib/screens/donation_screen.dart:93` | Donation flow screens hardcode AppTheme/Material colors instead of using ThemeHelper (project convention violation) | M |
| uiux-30 | Low | unverified | `lib/screens/donation_screen.dart:318` | Impact message box hardcodes Colors.green.shade50 — glaring light block in dark mode | S |
| fb-19 | Low | unverified | `lib/services/firebase_service.dart:169` | City statistics are computed from only the newest 100 global readings but presented as totals | M |
| flow1-14 | Low | unverified | `lib/screens/splash_screen.dart:36` | Fixed unskippable 3-second splash delay stacks on top of already-slow pre-runApp init | S |
| uiux-29 | Low | unverified | `lib/widgets/decibel_meter_gauge.dart:96` | Gauge arc and needle hardcode purple — the app's marquee widget ignores the selected theme color | S |
| uiux-38 | Low | unverified | `lib/widgets/noise_history_chart.dart:61` | Live chart maxY is 100 but readings go up to 120 — loud spikes draw outside the card | S |
| social-14 | Low | unverified | `lib/screens/community_feed_screen.dart:87` | Community feed bypasses ThemeHelper entirely — hardcoded AppTheme colors with manual brightness checks throughout | S |
| settings-17 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:391` | Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention | S |
| uiux-28 | Low | unverified | `lib/screens/community_feed_screen.dart:73` | Community feed hardcodes AppTheme.primaryPurple and raw AppTheme colors, ignoring the user's theme color | S |

## Detailed Findings

### High

#### [uiux-3] 'Export Data to CSV' exports EVERY user's recordings, including their emails

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:230`

**Verifier verdict (CONFIRMED):** Real. history_screen.dart:230-233 queries the entire `noise_readings` collection with no userId filter and no limit — every user's data. Line 248/262 put `User Email` in the CSV header and write `data['userEmail']` per row (line 273), exposing all users' emails. The CSV is built in a synchronous StringBuffer loop (lines 245-274) on the main isolate (no compute/isolate offload), so for a large collection it blocks the UI thread. Both variant wordings are accurate as stated.

**Description:**

_exportDataToCSV queries `collection('noise_readings').orderBy('timestamp')` with no userId filter (lines 230-233), while the screen is titled 'Your Recordings' and the list itself is user-filtered via getUserReadingsPaginated. The CSV includes unmasked userEmail per row (line 262), which the community feed deliberately masks.

**Failure scenario:**

Any user taps the download icon on History and receives a CSV containing all other users' readings and full email addresses — wrong data for the feature and a privacy leak.

**Recommended fix:**

Add `.where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)` to the export query (single equality + orderBy timestamp desc matches the existing composite index), and drop or mask the userEmail column.

---

#### [uiux-6] Search-as-you-type never fires when the query contains an uppercase letter

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:292`

**Verifier verdict (CONFIRMED):** Verified at lib/screens/search_list_screen.dart:287-296. onChanged sets `_searchQuery = value.toLowerCase()` (line 289), then the 500ms debounce fires only `if (value == _searchQuery)` (line 292) before calling `_searchWithNominatim(value)`. For any input containing an uppercase letter, `value` (raw) can never equal `_searchQuery` (lowercased), so the debounced search never executes — exactly as both variant wordings describe. The only mitigation is `onSubmitted` (line 297-299), which searches on explicit Enter, but that is not search-as-you-type, matching the finding's scope. Also, the results section (line 304) still renders for 3+ char queries, showing stale/empty `_nominatimResults`.

**Description:**

onChanged stores `_searchQuery = value.toLowerCase()` (line 289) but the 500ms debounce guard compares the ORIGINAL value: `if (value == _searchQuery)` (line 292). Any capital letter makes the comparison permanently false, so `_searchWithNominatim` is never called while typing — only via keyboard onSubmitted.

**Failure scenario:**

User types 'Colombo' in Search Cities: the grid hides (query non-empty) but no spinner or results ever appear; it looks like search is broken unless they happen to press the keyboard's submit action.

**Recommended fix:**

Compare like-for-like, e.g. store the raw value (`_searchQuery = value`) and lowercase only where needed, or compare `value.toLowerCase() == _searchQuery`. Better: replace the delay-hack with a proper `Timer` debounce that is cancelled on each keystroke.

---

#### [uiux-5] Map pull-to-refresh can never trigger — markers/heatmap are stale until app restart

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:603`

**Verifier verdict (CONFIRMED):** RefreshIndicator (map_view_screen.dart:603) wraps a Stack containing FlutterMap (608-618) with no Scrollable descendant. RefreshIndicator only fires from ScrollNotifications emitted by a scrollable child; FlutterMap handles drags via its own gesture detectors, so onRefresh (604-606) is unreachable. _loadNoiseMarkers has exactly two call sites: initState (line 101) and _refreshAllData (160), which is only invoked by the dead onRefresh (606). No other trigger exists (no timer, lifecycle observer, or external call — grep across lib/ found none). MapViewScreen lives in an IndexedStack (main_app_shell.dart:38-41), so initState runs once per app launch and tab switches never recreate it. Markers/heatmap therefore stay stale until restart, exactly as claimed.

**Description:**

The RefreshIndicator (line 603) wraps a Stack containing FlutterMap, which is not a Scrollable and consumes all drag gestures itself, so ScrollNotifications never reach the RefreshIndicator and onRefresh is unreachable. `_loadNoiseMarkers()` only runs once in initState (line 101); there is no other refresh affordance on the map.

**Failure scenario:**

User records new readings on the Dashboard, switches to the Map tab (kept alive in IndexedStack): the new markers never appear no matter how they drag; only killing and reopening the app shows them.

**Recommended fix:**

Remove the useless RefreshIndicator and add an explicit refresh FAB (or reload in a `didChangeDependencies`/tab-visible hook, or re-query on a timer). Show a brief 'Updated N readings' snackbar on completion.

---

#### [uiux-7] List builders crash the whole screen on a doc with missing/null decibelLevel

**Severity:** High | **Status:** disputed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:451`

**Verifier verdict (PARTIAL):** The hard cast is real: history_screen.dart:451 `(data['decibelLevel'] as num).toDouble()` throws on null/missing field, and it's inconsistent with the same codebase's defensive handling — same file line 261 uses `?? 0.0`, analytics_screen.dart:190 uses `as num?`, and firebase_service.dart:300 even has a comment "Null-safe: skip docs with missing/null decibelLevel instead of crashing", showing the risk is acknowledged. However, overstated in two ways: (1) all in-app writers always include decibelLevel (firebase_service.dart:120, sync_service.dart:213), so a null requires legacy/externally written docs; (2) an itemBuilder exception yields Flutter's ErrorWidget for the failing item, not a hard crash of the whole screen. Defect exists but severity is exaggerated.

**Description:**

history_screen.dart:451 does `(data['decibelLevel'] as num).toDouble()` — a hard cast that throws if the field is missing or null. The same unsafe pattern exists in search_list_screen.dart:505 and map_view_screen.dart:176-178 (where `data['latitude'] as double` additionally throws if Firestore stored an int). Notably firebase_service.calculateStatsByPeriod was already patched to null-skip this exact field ('Null-safe: skip docs with missing/null decibelLevel instead of crashing'), proving such docs occur in this dataset.

**Failure scenario:**

One legacy/malformed noise_readings doc without decibelLevel lands in the first page: the ListView itemBuilder throws, and the entire History screen renders the red/grey error widget instead of the list.

**Recommended fix:**

Use defensive parsing everywhere readings are rendered: `final db = (data['decibelLevel'] as num?)?.toDouble(); if (db == null) return SizedBox.shrink();` and `(data['latitude'] as num?)?.toDouble()` in the map marker builder.

---

#### [uiux-4] Cluster color is always orange due to broken string interpolation in key lookup

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:686`

**Verifier verdict (CONFIRMED):** Real. Keys are written as '${lat}_$lng' at map_view_screen.dart:200-201. The cluster builder lookup at line 687 uses '$point.latitude_$point.longitude' — Dart interpolates only the identifier `point`, so this evaluates to LatLng.toString() ("LatLng(latitude: x, longitude: y)") + literal ".latitude_" etc., never "lat_lng". startsWith never matches, firstWhere falls to orElse '' (line 689), so every marker defaults to 50.0 (line 693). avgNoise is always exactly 50.0, which fails `avgNoise < 50` (line 704) and satisfies `< 70` (line 706), yielding AppTheme.moderateNoise (orange, line 707) for every cluster. Correct fix would be '${point.latitude}_${point.longitude}'.

**Description:**

Marker noise levels are stored under key '${lat}_$lng' (line 200), but the cluster builder looks them up with `k.startsWith('$point.latitude_$point.longitude')` (lines 685-688). In Dart this interpolates `point.toString()` followed by the literal text '.latitude_' — it never matches, so every marker falls back to 50.0 (line 693) and avgNoise is always exactly 50 → `avgNoise < 50` is false → every cluster renders AppTheme.moderateNoise orange (line 707).

**Failure scenario:**

An area with ten 90 dB readings clusters into an orange (moderate) pin instead of red, misrepresenting dangerous noise levels on the community map.

**Recommended fix:**

Use `'${point.latitude}_${point.longitude}'` (with braces) and an exact map lookup `_markerNoiseLevels[key]` instead of startsWith.

---

#### [uiux-2] Deleting a recording leaves it visible in the list and has no error handling

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:721`

**Verifier verdict (CONFIRMED):** CONFIRMED. The list is local paginated state, not a stream: _recordings is a List<DocumentSnapshot> filled by one-time paginated .get() queries (history_screen.dart:27, 93-105, 136-148). The delete handler (lines 719-731) calls FirebaseFirestore...doc(docId).delete() with no try/catch, then only pops the dialog and shows a "Recording deleted" snackbar — it never removes the doc from _recordings, calls no setState, doesn't decrement _totalCount, and doesn't call _loadInitialRecordings. So the deleted item stays visible and "Showing ${_recordings.length} of $_totalCount" (line 392) is stale until pull-to-refresh. If delete() throws, the unhandled await leaves the dialog open with no error feedback. All variant wordings are accurate.

**Description:**

The delete confirmation deletes the Firestore doc directly (line 721) but never updates the locally paginated `_recordings` list or `_totalCount` — the screen uses manual pagination, not a stream, so nothing rebuilds. Also the `await ...delete()` has no try/catch: if it fails (offline, permission), the exception is swallowed by the zone, the dialog stays open, and no feedback is shown.

**Failure scenario:**

User taps delete > Delete: 'Recording deleted' snackbar shows but the row remains on screen and 'Showing X of Y' is stale until a manual pull-to-refresh; offline, the delete silently fails while the dialog hangs.

**Recommended fix:**

Wrap the delete in try/catch; on success `setState(() { _recordings.removeWhere((d) => d.id == docId); _totalCount--; })`, on failure show an error snackbar. Consider a SnackBar with Undo instead of only a confirm dialog.

---

#### [uiux-1] Measurement and alert settings have no effect anywhere in the app

**Severity:** High | **Status:** confirmed | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:131`

**Verifier verdict (CONFIRMED):** All Measurement-section settings at settings_screen_enhanced.dart:131-163 (recording_duration, save_frequency, db_threshold) plus use_dba/use_fast_response are written to SharedPreferences but never read anywhere except the settings screen itself (grep across lib/ shows the only reads are the screen's own _loadSettings at lines 46-57). The alert threshold is hardcoded: dashboard_screen.dart:428 uses `_currentDb > 70` and never reads db_threshold; the high_noise_alerts toggle (line 186) is also never consulted. Minor nuance: the separate notifications_enabled master switch IS honored (notification_service.dart:38,65), but that is the Notifications master toggle, not the measurement/alert-threshold settings the finding targets. Defect is real as described.

**Description:**

The 'Recording Duration', 'Save Frequency' and 'Alert Threshold' sliders (lines 131-163) and the 'High Noise Alerts' toggle (line 180) write SharedPreferences keys (recording_duration, save_frequency, db_threshold, high_noise_alerts) that no other code reads. DashboardScreen hardcodes the save interval to 5s (dashboard_screen.dart:487), the alert threshold to 70 dB (dashboard_screen.dart:428), and NotificationService only checks 'notifications_enabled'. A grep for 'high_noise_alerts' and 'db_threshold' shows they exist only in the settings screen.

**Failure scenario:**

User raises Alert Threshold to 95 dB and disables High Noise Alerts, then records: they still get a high-noise notification at 70 dB and readings still save every 5 seconds. The settings UI silently lies.

**Recommended fix:**

In DashboardScreen, read save_frequency for the Timer.periodic interval and db_threshold + high_noise_alerts before calling NotificationService.showHighNoiseAlert (or check them inside NotificationService). Remove or hide any setting that will not be wired up (e.g. Recording Duration, Daily Reminders).

---

### Medium

#### [flow1-6] Notification permission dialog is awaited before runApp — first launch shows an OS prompt over a blank screen

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/main.dart:48`

**Description:**

main.dart:47-48 awaits NotificationService.initialize() and requestPermission() before runApp(line 71). notification_service.dart:22-32 calls requestNotificationsPermission(), which on Android 13+ pops the system POST_NOTIFICATIONS dialog. Because no Flutter frame has rendered yet, the very first thing a new user sees is a notification permission prompt floating over the frozen native splash, with no app context explaining why — and startup is blocked until they answer.

**Failure scenario:**

Brand-new user installs and opens the app on Android 13+: before any splash/onboarding UI appears, an 'Allow Noise Mapper to send you notifications?' dialog appears over a blank screen; the app does not paint its first frame until they respond.

**Recommended fix:**

Keep initialize() in main but move requestPermission() to after first frame (e.g. in SplashScreen/Dashboard initState via addPostFrameCallback), ideally just-in-time before the first feature that needs notifications.

---

#### [uiux-26] Delete-account/clear-history error paths can pop the wrong route

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:927`

**Description:**

In _deleteAccount, `throw Exception('No user logged in')` (line 868) occurs BEFORE the loading dialog is shown, yet both catch blocks unconditionally `Navigator.pop(context)` (lines 927, 946) to 'close the loading dialog' — popping the Settings screen itself in that path. _clearHistory has the identical pattern (lines 1000-1003 vs 1049-1064). Also, `user.delete()` failing with requires-recent-login leaves the batch of anonymized readings already committed even though the account remains.

**Failure scenario:**

Auth session expires, user taps Delete Account > Delete: the exception fires before showDialog, the catch pops the Settings route, and the user is mysteriously thrown back to the previous screen with an error snackbar on the wrong page.

**Recommended fix:**

Track dialog visibility with a bool (set true right after showDialog) and only pop when it is showing; or move the user-null check before showDialog and return early with a snackbar.

---

#### [uiux-21] History pull-to-refresh is dead exactly in the offline and empty states

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:383`

**Description:**

RefreshIndicator (line 383) wraps a Column whose scrollable (the ListView) only exists in the has-data branch. The offline UI (line 402) and empty state (line 404) are plain Centers — non-scrollable — so the pull gesture does nothing in the two states where refreshing matters most. (The offline state has a Retry button; the empty state has no refresh path at all.)

**Failure scenario:**

User opens History while briefly offline, reconnects, and pulls down on the 'No Internet Connection' or 'No recordings yet' view: nothing happens; the empty state persists until they leave and re-enter the tab.

**Recommended fix:**

Render the offline/empty states inside a `ListView`/`SingleChildScrollView` with `AlwaysScrollableScrollPhysics` (e.g. LayoutBuilder + ConstrainedBox to center content) so RefreshIndicator works in every state.

---

#### [uiux-18] All/Pollution/Ambient filter silently applies to only 2 of 5 analytics sections

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:539`

**Description:**

The sound-type chips (lines 527-574) filter only the pie chart (lines 582-586) and the category breakdown (lines 716-753). The context banner's reading count, the confidence card, the trend chart and the Average/Lowest/Highest/Duration stat grid all ignore the filter with no visual indication of scope.

**Failure scenario:**

User taps 'Pollution': the pie collapses to 100% pollution but 'Average 62 dB' and the trend line still include ambient readings — the user reasonably but wrongly concludes pollution averages 62 dB.

**Recommended fix:**

Either apply the filter to the stats/trend computations (filter docs by soundType before aggregating) or visually scope it: move the chips directly above the two sections they affect and title them 'Distribution filter'.

---

#### [uiux-14] Analytics stat cards/pie chart go permanently stale inside the IndexedStack shell

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:49`

**Description:**

AnalyticsScreen lives in MainAppShell's IndexedStack (tab 1) so it is built once; _loadStatistics runs only in initState (line 49) and when a period chip is tapped. The trend chart updates via its stream, but the stats grid, pie chart, category breakdown, confidence card and '$totalReadings readings' badge are one-shot .get() results. There is also no pull-to-refresh on the scroll view.

**Failure scenario:**

User records 20 new readings on Dashboard, taps the Analytics tab: the trend line shows the new data but 'readings' count, Average/Highest cards and the pie chart still show pre-recording values until they toggle Daily/Weekly back and forth.

**Recommended fix:**

Wrap the SingleChildScrollView in a RefreshIndicator calling _loadStatistics, and/or reload when the tab becomes visible (pass a callback/notifier from MainAppShell's onTap, or use a VisibilityDetector).

---

#### [uiux-22] Login error handling only maps legacy Firebase error codes — users get generic 'Login failed'

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/login_screen.dart:63`

**Description:**

The FirebaseAuthException handler (lines 61-71) maps only 'user-not-found', 'wrong-password' and 'invalid-email'. With email-enumeration protection (default on current Firebase projects), failed sign-ins return 'invalid-credential'/'INVALID_LOGIN_CREDENTIALS', and network failures return 'network-request-failed' — all of which fall through to the bare 'Login failed'. There is also no fallback to e.message.

**Failure scenario:**

User mistypes their password: instead of 'Wrong password' they see 'Login failed' with no hint whether the account exists, the password is wrong, or the network is down.

**Recommended fix:**

Add cases for 'invalid-credential' ('Incorrect email or password'), 'network-request-failed' ('Check your internet connection'), 'too-many-requests', and default to `e.message ?? 'Login failed'` like registration_screen already does (registration_screen.dart:100).

---

#### [uiux-23] Community Feed badge query violates the project Firestore index rule and hides loading/error as '0'

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:911`

**Description:**

The badge StreamBuilder queries noise_readings with `isGreaterThanOrEqualTo` + `isLessThan` on timestamp and no orderBy (lines 906-914), contrary to the documented project rule that period queries must use isGreaterThan + orderBy timestamp descending. Additionally the builder ignores snapshot.hasError and connectionState: `snapshot.hasData ? docs.length : 0` (line 917) renders '0' both while loading and on failure. The count also tallies every auto-saved 5-second reading app-wide, not 'reports'.

**Failure scenario:**

Firestore returns an error (or the stream is still connecting): the badge confidently shows '0' next to 'See what others are reporting', telling the user the community is empty when it is not.

**Recommended fix:**

Use `.where('timestamp', isGreaterThan: ...)` per the project convention, and in the builder render a small placeholder ('—' or a 12px spinner) while waiting and hide the badge on error instead of showing 0.

---

#### [boot-6] Back navigation stays enabled during registration submit — user can pop mid-flight and end up silently authenticated on the Login screen

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/registration_screen.dart:136`

**Description:**

While _isLoading is true the submit button is disabled (line 386), but the AppBar back IconButton (lines 136-139) and the system back gesture still work — there is no PopScope and the leading button's onPressed is unconditional. If the user pops during the in-flight _register, the async chain continues: the account is created and the user is signed in, but the `if (mounted)` guard (line 78) skips navigation to MainAppShell, leaving them on LoginScreen while FirebaseAuth.currentUser is already set. Because the root auth StreamBuilder was destroyed earlier (see boot-3), nothing redirects them.

**Failure scenario:**

User taps 'Create Account' on a slow connection, gets impatient after 4 seconds and taps the back arrow. They land on Login, but the registration completed in the background: they are actually signed in. Killing and relaunching the app then drops them straight into the Dashboard, which looks like a security surprise; or they attempt to register again and hit 'email-already-in-use'.

**Recommended fix:**

Disable the back arrow while submitting (`onPressed: _isLoading ? null : () => Navigator.pop(context)`) and wrap the Scaffold in `PopScope(canPop: !_isLoading)`. Apply the same guard to the 'Log In' TextButton at line 443.

---

#### [offline-7] Manual-sync feedback is wrong and usually never appears: unconditional success snackbar built on the popped dialog's context

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:216`

**Description:**

The Sync Now handler (lines 212-217) pops the dialog, awaits `triggerManualSync()`, discards its return value (the actual synced count), then calls `_showSyncResultSnackbar(context, pendingCount)` with the *pre-sync* pending count and the message 'Synced N recording(s) successfully!' (line 270) regardless of outcome — including when triggerManualSync returned 0 because the device went offline, another sync was in progress (sync_service.dart:119-122), or every upload failed. Additionally, `context` here is the dialog builder's context, which was popped at line 213; by the time a multi-second sync finishes, `context.mounted` (line 215) is false, so in practice the snackbar silently never shows and the user gets zero feedback.

**Failure scenario:**

User taps Sync Now with 5 pending recordings; all 5 uploads fail because the wifi is a captive portal. Either the user sees nothing at all (dialog context unmounted), or — if sync returns fast enough — sees 'Synced 5 recording(s) successfully!' while all 5 remain queued.

**Recommended fix:**

Capture `final synced = await _syncService.triggerManualSync();`, use the State's own `mounted` and `this.context` (not the dialog's) for the snackbar, and branch the message: success with the real count, or an error style ('Sync failed — N still pending') when synced < pendingCount.

---

#### [uiux-19] Map autocomplete fires an HTTP request on every keystroke with no debounce or stale-response guard

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:933`

**Description:**

onChanged calls _autocompleteSearch directly (lines 932-934), which awaits _searchNominatim and unconditionally setState's the results (lines 503-515). There is no debounce timer and no request sequencing, so a slow response for an earlier prefix can arrive after and overwrite the results for the full query. It also fires ~1 request per keystroke at Nominatim, whose usage policy is max 1 req/s (risking 429/blocks for all users of the shared User-Agent).

**Failure scenario:**

User types 'Kandy' quickly: 5 requests fire; the response for 'Kan' arrives last and replaces the correct 'Kandy' dropdown with broader stale results. Under rate limiting, search intermittently returns nothing.

**Recommended fix:**

Debounce with a cancellable Timer (400-500ms) and track a request generation counter: only apply results whose generation matches the latest. (SearchListScreen needs the same once its debounce comparison bug uiux-6 is fixed.)

---

#### [uiux-24] City details bottom sheet: 24px city name in a Row without Flexible — RenderFlex overflow on long names

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:649`

**Description:**

_showCityDetails builds `Row(children: [Icon, SizedBox(8), Text(city, fontSize: 24, bold)])` (lines 642-657) with no Expanded/Flexible and no overflow handling. Geocoded Sri Lankan locality names and the normalized coordinate strings ('6.9271, 79.8612') easily exceed the remaining width at 24px bold.

**Failure scenario:**

User taps the 'Sri Jayawardenepura Kotte' city card: the bottom sheet renders with the yellow/black RenderFlex overflow stripes on the right edge of the title row.

**Recommended fix:**

Wrap the Text in `Expanded` with `maxLines: 1, overflow: TextOverflow.ellipsis` (the grid card at line 595 already does this correctly).

---

#### [flow7-07] No back-navigation handling in either webview: system back exits checkout instead of going back a page

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:47`

**Description:**

Neither PayPalWebViewWidget (Scaffold at line 47) nor BuyMeACoffeeWidget (Scaffold at buy_me_coffee_widget.dart line 83) wraps its Scaffold in PopScope/WillPopScope or consults controller.canGoBack()/goBack(). Android hardware/gesture back always pops the entire Flutter route, discarding the in-progress payment session with no confirmation. There is also no way to step back one page within the multi-step PayPal or BMC checkout.

**Failure scenario:**

A donor is three pages deep in PayPal checkout, mis-taps, and presses system back intending to return to the previous checkout step. The entire webview route is popped and the payment session is lost; they must restart from the donation screen.

**Recommended fix:**

Wrap each Scaffold in PopScope(canPop: false, onPopInvokedWithResult: ...) that checks await _controller.canGoBack(): if true call goBack(), otherwise Navigator.pop(context). Both flutter_inappwebview and webview_flutter controllers expose canGoBack/goBack.

---

#### [analytics-10] No empty or error state for the stats grid — zeros are presented as real measurements and load failures are swallowed

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:367`

**Description:**

When the period has no readings, or when _loadStatistics throws (catch at lines 172-175 only logs and clears _isLoading), the stats grid (lines 359-375) still renders 'Average 0 dB / Lowest 0 dB / Highest 0 dB / Duration 0 h' as if they were measured values. The trend chart has proper empty ('No data for …', line 1010-1019) and error (line 1000-1008) states, but the stat cards, banner and pie/breakdown sections have none — the cards look identical whether the query failed, the user has no data, or the environment genuinely measured 0 dB.

**Failure scenario:**

A user switches to Monthly while offline: calculateStatsByPeriod throws, the catch logs it silently, and the screen shows a chart populated from Firestore's local cache next to stat cards all reading 0 — contradictory data with no error message or retry affordance.

**Recommended fix:**

Track a _statsError flag in the catch and render an inline error card with a Retry button; when _totalCount == 0 (and no error), replace the grid values with an em dash or a 'No readings in this period' placeholder instead of '0 dB'.

---

#### [uiux-11] Decibel gauge hardcoded to 320px — overflows and clips on narrow phones

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:20`

**Description:**

DecibelMeterGauge is a fixed `SizedBox(width: 320, height: 320)` (lines 19-21). Dashboard places it inside a SingleChildScrollView with `EdgeInsets.all(24)` (dashboard_screen.dart:721), leaving only 312dp on a common 360dp-wide phone and 272dp on a 320dp device. The gauge (whose painter draws tick numbers at radius+25, out to the widget edge) overflows the Column's cross-axis and gets its side labels ('0', '100') clipped.

**Failure scenario:**

On a 320-360dp wide device (e.g. small Android in split-screen), the dashboard gauge sticks out of the padded column; the left/right tick numbers are cut off or paint over other content.

**Recommended fix:**

Wrap the gauge in a LayoutBuilder or FittedBox: `SizedBox(width: min(320, constraints.maxWidth), ...)` keeping the painter size-relative (it already scales from `size.width`).

---

#### [uiux-20] 'Open in Browser' button shows 'Opening in browser...' but never opens anything

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/buy_me_coffee_widget.dart:106`

**Description:**

The AppBar action (lines 104-117) only logs and shows a snackbar saying 'Opening in browser...'; the code comment admits url_launcher was never added. The user receives explicit success-style feedback for an action that does not happen.

**Failure scenario:**

The in-app webview fails to render Buy Me a Coffee's payment flow; the user taps 'Open in Browser' as the escape hatch, sees 'Opening in browser...', and waits for a browser that never comes — a donation dead end.

**Recommended fix:**

Add url_launcher and call `launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication)`; show the error snackbar only if launching fails. Until then, remove the button.

---

#### [social-15] Pull-to-refresh is dead when the list does not fill the screen and on the empty state

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:432`

**Description:**

RefreshIndicator wraps a Column (line 385). The inner ListView.builder (line 432) uses default physics, so when the user has fewer items than one screenful the list is not scrollable and no overscroll notification ever reaches the RefreshIndicator — the refresh gesture does nothing. The empty state (lines 404-431) and offline state (Center/Column) are not scrollable at all, so a user on the 'No recordings yet' screen has no way to refresh (the FAB adds a record, and there is no retry button on the empty state).

**Failure scenario:**

User with 3 recordings (or zero) opens History, records a new reading elsewhere, comes back and pulls down to refresh — nothing happens; the screen looks frozen and the new reading never appears without restarting.

**Recommended fix:**

Give the ListView `physics: const AlwaysScrollableScrollPhysics()`, and render the empty/offline states inside a scrollable (e.g. ListView/SingleChildScrollView with AlwaysScrollableScrollPhysics) so RefreshIndicator works everywhere.

---

#### [uiux-13] Analytics load failure is silent — zeros shown as if they were real data

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:172`

**Description:**

_loadStatistics' catch block (lines 172-175) only logs and clears _isLoading. Because the same method zeroes all stats before the query (lines 102-115), a failed fetch leaves the screen showing 'Average 0 dB / Highest 0 dB / 0 readings' with no error banner and no retry affordance.

**Failure scenario:**

Device is offline (or Firestore errors) when the user opens Analytics: they see 0 dB everywhere and '0 readings', which reads as 'I have no data' rather than 'loading failed'.

**Recommended fix:**

Add an `_loadError` flag set in the catch; render an inline error card with a Retry button (calling _loadStatistics) instead of the stats grid when set.

---

#### [settings-8] Five settings rows with chevrons do nothing when tapped: Privacy Policy, Export All Data, Rate Us, Contact Support, Terms of Service

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:223`

**Description:**

onTap is an empty closure for Privacy Policy (line 223), Export All Data (line 257), Rate Us (line 303), Contact Support (lines 304-308) and Terms of Service (lines 309-313). Each renders as a full InkWell row with a chevron_right affordance implying navigation. Export All Data is doubly misleading: NotificationService.showExportComplete (notification_service.dart lines 88-105) exists for an export feature that was never built. Privacy Policy / Terms being dead also matters for store-review compliance.

**Failure scenario:**

User taps 'Export All Data' to back up recordings before clearing history. Nothing happens — no feedback, no export — and they may proceed to Clear History believing a backup exists.

**Recommended fix:**

Implement each (url_launcher for policy/terms/store/mailto, CSV export via csv + share_plus for Export All Data) or remove/disable the rows with a 'Coming soon' label so no dead affordances remain.

---

#### [flow3-12] SyncStatusIndicator on the map is painted underneath FlutterMap and is never visible

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:611`

**Description:**

In the body Stack, the Positioned SyncStatusIndicator is the FIRST child (map_view_screen.dart:610-615) and FlutterMap is the second (line 618). Stack paints later children on top, and FlutterMap fills the stack with opaque tiles, so the indicator - the map screen's only cue that offline readings are still pending upload (i.e., why a saved reading isn't visible yet) - is completely occluded. Compare dashboard_screen.dart:680 where the same widget is placed in the AppBar and is visible.

**Failure scenario:**

User records offline; readings are queued in Hive. They open the Map expecting to see them and see nothing; the pending-sync badge that would explain this is hidden behind the map tiles, so the app looks like it lost the data.

**Recommended fix:**

Move the Positioned SyncStatusIndicator after the FlutterMap child in the Stack (e.g., just before the search-bar SafeArea) so it paints on top.

---

#### [boot-7] Back button instantly exits the app from any tab — no back-to-home behavior, no confirmation, no-op on iOS

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/main_app_shell.dart:30`

**Description:**

PopScope(canPop: false) with onPopInvokedWithResult calling SystemNavigator.pop() (lines 30-36) means a single Android back press anywhere in the shell terminates the app immediately, even from Map/Analytics/History/Settings where users expect back to return to the Dashboard (home tab, index 2). There is also no double-press-to-exit confirmation, so an accidental back press kills a recording session (Dashboard's _isRecording state dies with the process). On iOS, SystemNavigator.pop() is documented to do nothing, and canPop:false also disables Android 14+ predictive-back animation.

**Failure scenario:**

User is mid-noise-measurement on Dashboard, switches to the Map tab to look around, and presses back expecting to return to Dashboard: the app fully exits, killing the in-progress recording without any confirmation.

**Recommended fix:**

In onPopInvokedWithResult: if _currentIndex != 2, setState(() => _currentIndex = 2) and return; only when already on index 2 either SystemNavigator.pop() or show a 'Press back again to exit' snackbar with a 2-second window before exiting.

---

#### [uiux-8] Completely blank screen when a search returns zero results

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:403`

**Description:**

With a query of 3+ chars, the city grid is hidden (`_searchQuery.isEmpty` check, line 134) and `_buildGlobalSearchSection` returns `SizedBox.shrink()` when `_nominatimResults` is empty and there is no error (line 403). There is no 'no results' state.

**Failure scenario:**

User searches 'asdfgh': the spinner disappears and the body under the search bar is entirely empty — no message, no way to tell whether search finished or failed.

**Recommended fix:**

Add an explicit empty state ('No locations found for "query" — try a different term') with an icon, returned when `!_isSearching && _searchError == null && _nominatimResults.isEmpty`.

---

#### [uiux-9] AppBar back arrows nearly invisible in light mode; per-screen white-icon hacks are inconsistent

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:80`

**Description:**

AppTheme's appBarTheme (app_theme.dart:141-150) sets a primary-colored light-mode AppBar with white titleTextStyle but no foregroundColor/iconTheme. With Material 3 defaults (useMaterial3 not disabled in main.dart), AppBar icons fall back to colorScheme.onSurface — near-black on the purple bar. Screens that noticed this hardcode `iconTheme: IconThemeData(color: AppTheme.textWhite)` individually (history_screen.dart:366, dashboard_screen.dart:676, report_noise_screen.dart:273, community_feed_screen.dart:60, search_list_screen.dart:111, edit_profile_screen.dart:216) while settings (line 80) and analytics (analytics_screen.dart:294) do not.

**Failure scenario:**

In light mode, push Settings from the Dashboard gear icon: the back arrow is dark-on-purple and barely visible; meanwhile History's arrow is white — visibly inconsistent chrome across screens.

**Recommended fix:**

Set `foregroundColor: Colors.white` (and/or iconTheme/actionsIconTheme) once in both generateLightTheme and generateDarkTheme appBarTheme in app_theme.dart, then delete all per-screen iconTheme overrides.

---

#### [uiux-15] Logout executes instantly with no confirmation

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:683`

**Description:**

The AppBar logout IconButton (lines 682-703) calls FirebaseAuth.signOut() and clears the whole navigation stack on a single tap. It sits directly next to the settings gear, and there is no confirm dialog and no feedback while sign-out runs. If a recording is active it is dropped without warning.

**Failure scenario:**

User reaches for the settings gear and fat-fingers the logout icon mid-recording: they are dumped to the splash screen, the in-progress measurement session is lost, and they must log in again.

**Recommended fix:**

Show an AlertDialog ('Log out? Any active recording will stop.') with Cancel/Log out actions before calling signOut(), matching the confirmation pattern already used for Delete Recording and Clear History.

---

#### [uiux-25] CSV export has no busy state — long download with only a 1-second snackbar, repeat taps run parallel exports

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/history_screen.dart:222`

**Description:**

_exportDataToCSV shows a 1s 'Preparing export...' snackbar (lines 222-227) then awaits a full-collection .get() that can take many seconds on large datasets; the AppBar download icon (line 377) stays enabled the whole time, so repeated taps start concurrent exports writing duplicate files.

**Failure scenario:**

On a slow connection the snackbar disappears after 1 second with nothing else on screen; the user taps export three more times and eventually gets four dialogs and four CSV files.

**Recommended fix:**

Add an _isExporting flag: disable the IconButton (or swap it for a 18px spinner) while exporting, and show the success dialog or error snackbar on completion.

---

#### [uiux-17] Change Password dialog has no busy/disabled state during the network call

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:728`

**Description:**

The 'Change' TextButton (line 728) runs reauthenticateWithCredential + updatePassword with no spinner, no disabling of the button, and the dialog remains fully interactive. Double-taps fire concurrent auth requests; the user gets zero feedback for the several seconds the operation takes and may dismiss the dialog mid-flight.

**Failure scenario:**

On a slow connection the user taps 'Change', sees nothing happen, taps twice more — three reauth attempts fire; a wrong current password can then surface multiple 'incorrect password' snackbars (and repeated failures can trigger Firebase's too-many-requests lockout).

**Recommended fix:**

Convert the dialog content to a StatefulBuilder with an _isSubmitting flag: disable both buttons and show a small CircularProgressIndicator on the Change button while awaiting, re-enable on failure.

---

#### [uiux-10] Hardcoded AppTheme.textGray used on light backgrounds — near-invisible text in light mode

**Severity:** Medium | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/splash_screen.dart:82`

**Description:**

AppTheme.textGray (#B8B5C8) is the dark-theme secondary color, but it is hardcoded in light-mode-reachable places: splash subtitle (splash_screen.dart:82) on the #F5F5F5 light scaffold; 'Tap to measure' label (dashboard_screen.dart:875); and the map marker bottom sheet coordinates/level/confidence texts plus Divider (map_view_screen.dart:1183, 1197, 1201, 1267) which sit on a white card in light mode. All violate the ThemeHelper-only convention.

**Failure scenario:**

User enables light mode: the splash tagline 'Visualize your sound environment' and the map detail sheet's '6.9271, 79.8612' / 'Moderate Noise' captions render light-gray-on-white at roughly 1.3:1 contrast — effectively unreadable.

**Recommended fix:**

Replace each with ThemeHelper.getSecondaryTextColor(context) (and ThemeHelper.getDividerColor for the Divider). These are non-const-compatible one-line changes.

---

### Low

#### [map-14] Selecting an autocomplete result leaves an empty red label on the searched-location pin

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:812`

**Description:**

The searched-location marker label renders widget.searchedLocationName ?? _mapSearchController.text (line 812). The dropdown onTap handler clears the controller (line 1026) while setting _searchedLocation, and widget.searchedLocationName is null in the shell flow — so the red badge above the pin renders with an empty string.

**Failure scenario:**

User types 'kandy', taps a dropdown result: the map moves correctly but the pin shows an empty red rectangle where the place name should be.

**Recommended fix:**

Store the picked name in a state field (e.g., _searchedLocationName) set both in the dropdown onTap and navigateToLocation, and use it for the label instead of the text controller.

---

#### [uiux-35] Saving profile replaces the entire form with a bare spinner

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/edit_profile_screen.dart:218`

**Description:**

`body: _isLoading ? Center(spinner) : SingleChildScrollView(form)` (lines 218-224) blanks the whole screen during _updateProfile, discarding visual context; the Save button's own inline spinner (lines 395-403) is therefore never visible. If the update fails, the form pops back with the keyboard dismissed.

**Failure scenario:**

User taps Save Changes on a slow network: the whole form vanishes into a blank screen with a spinner for several seconds, then snaps back on error — feels like a crash/reload rather than a save.

**Recommended fix:**

Keep the form visible: rely on the existing in-button spinner, set `enabled: !_isLoading` on the TextFormFields, and drop the body-level swap.

---

#### [flow4-13] Hardcoded AppTheme colors and manual brightness checks throughout the feed (and spots of the report screen) violate the ThemeHelper convention

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/community_feed_screen.dart:60`

**Description:**

Project convention: all UI colors via ThemeHelper.getX(context), never hardcoded AppTheme colors. community_feed_screen.dart uses AppTheme.textWhite (line 60), AppTheme.primaryPurple for the loader (73) and RefreshIndicator (158), AppTheme.lowNoise/moderateNoise/highNoise (19-21), and repeated Theme.of(context).brightness == Brightness.dark ? AppTheme.textGray : AppTheme.textLightGray blocks (87-101, 119-147, 223-227, 285-289, 296-300, 337-341, 348-352, 363-367, 373-377). report_noise_screen.dart also uses AppTheme.textWhite (273) and hardcoded Colors.red[300]/Colors.green[300] in the dropdown (404, 416-433). withValues(alpha:) is used correctly (no withOpacity), but with a user-selectable theme color (main.dart:137-142 generates themes from themeColorNotifier) the purple accents on this screen will not follow the chosen theme color.

**Failure scenario:**

User picks a teal theme color in settings. Dashboard and report screen accents turn teal (they use ThemeHelper.getPrimaryColor), but the Community Feed keeps purple spinner/refresh/location icons and its grays don't route through ThemeHelper — visibly inconsistent theming on adjacent screens of the same flow.

**Recommended fix:**

Replace AppTheme.* references and brightness ternaries with the ThemeHelper getters (getTextColor, getSecondaryTextColor, getCardColor, getPrimaryColor) used elsewhere in the app; keep noise-level semantic colors if ThemeHelper exposes them, otherwise add a helper.

---

#### [flow7-11] Success path never returns the user to the app: thank-you dialog Close only dismisses the dialog

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/services/donation_service.dart:186`

**Description:**

showThankYouDialog's Close button (lines 185-188) pops only the dialog route, leaving the user on the PayPalWebViewWidget with the (would-be) 'Payment Complete!' overlay, which has no continue/done button (paypal_webview_widget.dart lines 195-219). The only way back to DonationScreen is the AppBar X. Nothing on DonationScreen updates either, since no result is passed back.

**Failure scenario:**

(After flow7-01/02 are fixed) donor completes payment, taps Close on the thank-you dialog, and is left on a dead overlay screen with no obvious next step.

**Recommended fix:**

In _onPaymentSuccess, after the dialog future completes (await showDialog...), call Navigator.pop(context, true) to close the webview and let DonationScreen react to the result (e.g. show the impact tracker updated). Alternatively add a 'Done' button to the success overlay that pops the route.

---

#### [settings-19] Theme color picker uses white selection borders/labels tuned for dark mode only

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:640`

**Description:**

_buildColorOption draws circle borders in Colors.white / white 30% (lines 640-645) and the selected glow assumes a dark backdrop. In light mode the dialog background is white (AppTheme.lightCardBackground, line 584-585), so the unselected border is invisible and the selected 3px white ring is nearly indistinguishable — only the check icon differentiates selection.

**Failure scenario:**

Light-mode user opens Theme Colors: color swatches float with no visible ring, and the current selection is hard to identify at a glance.

**Recommended fix:**

Derive border color from brightness (e.g. isDark ? Colors.white : Colors.black54) and use ThemeHelper.getTextColor for the ring/labels.

---

#### [uiux-31] Duplicate 'current location' person marker layer rendered whenever a search is active

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:768`

**Description:**

Lines 767-789 are a copy-paste of the current-location MarkerLayer (744-765) but gated on `_searchedLocation != null` and pointing at `_currentLocation` — not the searched point (the real searched marker follows at 791-832). It re-draws the person pin, bypassing the `!_isLoadingLocation` guard.

**Failure scenario:**

User searches a location before their GPS fix resolves: the person marker appears at the default Colombo coordinates (drawn by the duplicate layer) even though location is still loading, misrepresenting where they are.

**Recommended fix:**

Delete the duplicated MarkerLayer at lines 767-789.

---

#### [map-23] Hardcoded AppTheme colors with manual isDark branching instead of ThemeHelper (project convention violation)

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:879`

**Description:**

Project convention: all UI colors via ThemeHelper.getX(context). map_view_screen.dart repeatedly branches manually: isDark ? AppTheme.textGray : AppTheme.textLightGray (lines 879-881, 898-900, 914-917, 961-963), isDark ? getCardColor : AppTheme.lightCardBackground (lines 861-863, 974-976), AppTheme.darkPurple (line 591), AppTheme.textDark (line 891), AppTheme.textGray in the details sheet (lines 1183, 1197, 1267). search_list_screen.dart:111/115 hardcodes AppTheme.textWhite; heatmap_fab.dart:25 mixes ThemeHelper with a raw Colors.white surface.

**Failure scenario:**

A theme palette adjustment made through ThemeHelper does not propagate to the map search bar, dropdown, marker detail sheet, or Search Cities app bar, leaving mismatched colors between screens.

**Recommended fix:**

Replace the manual isDark ternaries with the corresponding ThemeHelper getters (getSecondaryTextColor, getCardColor, getTextColor, etc.), and route the status-bar/app-bar colors through ThemeHelper too.

---

#### [offline-14] Hardcoded Material colors throughout the widget violate the project's ThemeHelper convention

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:83`

**Description:**

The project convention is all UI colors via ThemeHelper.getX(context). This widget hardcodes `Colors.orange` (lines 83, 90, 161, 176, 184), `Colors.green` (95, 161, 176, 185, 273), `Colors.blue` (192, 200), `Colors.grey` (192), and `Colors.white` (268). These won't adapt to the app's theme-color setting (main.dart loads a user-selected theme color) or dark mode adjustments handled by ThemeHelper. (`withValues(alpha:)` is correctly used at line 109.)

**Failure scenario:**

User switches to the app's dark theme or a custom theme color; the indicator and dialog keep stock orange/green/blue that clash with the themed AppBar and reduce contrast in dark mode.

**Recommended fix:**

Replace with ThemeHelper getters (e.g. ThemeHelper.getWarningColor/getSuccessColor/getInfoColor or the project's equivalents) taking `context`, mirroring the rest of the app's screens.

---

#### [dash-19] Hardcoded AppTheme colors in dashboard UI violate the ThemeHelper convention

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:875`

**Description:**

Line 875 uses `AppTheme.textGray` for the 'Tap to measure' status text and lines 1163-1167 use `const AppTheme.primaryPurple` for the classifying spinner, both bypassing the project rule that all UI colors go through ThemeHelper.getX(context). Lines 676-677 similarly hardcode `AppTheme.textWhite` for AppBar icon themes. In light theme, textGray (a dark-theme gray) renders low-contrast against the light background for the primary status label under the record button.

**Failure scenario:**

User switches to light theme: the 'Tap to measure' label under the main record button is washed-out gray-on-light and barely legible, unlike every ThemeHelper-driven label around it.

**Recommended fix:**

Replace line 875 with `ThemeHelper.getSecondaryTextColor(context)` (keep the red recording state), line 1166 with `ThemeHelper.getPrimaryColor(context)`, and the AppBar icon colors with the theme-appropriate helper.

---

#### [flow1-11] Hardcoded colors on the launch/auth screens violate the ThemeHelper convention and break light mode on onboarding

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/widgets/world_map_background.dart:90`

**Description:**

Multiple flow-path files bypass ThemeHelper: world_map_background.dart:90 paints the map with a raw const Color(0xFF3D3554) and lines 71/75 use AppTheme.lightPurple for pins — in light theme the onboarding shows dark-purple continent blobs designed for the dark background, and pin positions are absolute pixels (lines 27-61) that misplace on small/large screens. splash_screen.dart:110 uses AppTheme.lightPurple and line 82 AppTheme.textGray directly; main.dart:166-168 uses AppTheme.darkBackground/lightBackground; shared_bottom_navbar.dart:25 uses AppTheme.darkPurple, so a user who picked a custom theme color still gets a purple navbar in dark mode. Project convention: all UI colors via ThemeHelper.getX(context).

**Failure scenario:**

User in light mode reaches onboarding: the world map renders as murky dark-purple shapes clashing with the light card; user who set a teal theme color sees purple splash bars and a purple bottom navbar in dark mode.

**Recommended fix:**

Replace the raw hex and AppTheme constants on these five files with ThemeHelper.getPrimaryColor/getBackgroundColor/getSecondaryTextColor equivalents (theme_helper.dart already exposes them), and derive pin positions from size fractions inside the painter.

---

#### [donate-17] Location pins use absolute pixel positions while continents scale with screen size, so pins drift onto the wrong continents; colors ignore light theme

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/world_map_background.dart:27`

**Description:**

The continent shapes are painted proportionally (w*0.15..., h*0.25... etc., lines 115-201) but the six pins use fixed pixel offsets (top:300/left:200 for 'Colombo', top:180/left:80 for 'North America', etc., lines 26-61). On a 360px-wide phone left:200 is ~55% width (over Asia), but on a 800px tablet it is 25% width (over the Americas). Additionally the painter hardcodes Color(0xFF3D3554) (line 90) and pins use AppTheme.lightPurple (lines 74-75) rather than theme-aware colors, so on the light theme (OnboardingScreen uses scaffoldBackgroundColor) the dark-purple map blobs clash with the light background. Widget is live: used by OnboardingScreen (onboarding_screen.dart line 17), reached from splash_screen.dart line 39 - not dead code.

**Failure scenario:**

User opens the app on a tablet or large/foldable phone: the 'Sri Lanka' pin floats over the mid-Atlantic and the 'Australia' pin sits in open ocean; on light theme the map renders as dark blobs inconsistent with the light onboarding card.

**Recommended fix:**

Position pins as fractions of MediaQuery size matching the painter's coordinate system (e.g., left: w*0.62, top: h*0.38 for Colombo) via LayoutBuilder, and derive map/pin colors from ThemeHelper/Theme brightness.

---

#### [uiux-33] Reload button crashes with LateInitializationError if tapped before the WebView is created

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:63`

**Description:**

`late final InAppWebViewController _controller` (line 25) is assigned only in onWebViewCreated (line 97). The AppBar refresh action (line 63) and the error-state 'Try Again' button (line 255) call `_controller.reload()`; tapped during the creation window (slow devices/first paint) this throws LateInitializationError.

**Failure scenario:**

PayPal page stalls on a slow device; the user immediately taps the refresh icon in the AppBar before the WebView finishes initializing — the app throws instead of reloading.

**Recommended fix:**

Make it nullable (`InAppWebViewController? _controller`) and call `_controller?.reload()`, or disable the refresh action until onWebViewCreated fires.

---

#### [uiux-32] Nominatim query string is interpolated unencoded into the URL

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:363`

**Description:**

`Uri.parse('...search?format=json&q=$query&limit=50...')` (map_view_screen.dart:362-364 and identically search_list_screen.dart:55-57) puts raw user input in the query string. Characters like '&', '#', '+' or '=' corrupt the parameter list (e.g. everything after '&' is parsed as separate params).

**Failure scenario:**

User searches 'M&S Colombo' or 'C# academy': the request becomes q=M with stray params, returning wrong or empty results with no indication why.

**Recommended fix:**

Build the URL with `Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'json', 'q': query, 'limit': '50', ...})` which encodes parameters correctly.

---

#### [uiux-34] Pale red[300]/green[300] classification colors designed for dark mode used on white surfaces

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/report_noise_screen.dart:404`

**Description:**

The sound-class dropdown items use Colors.red[300]/green[300] icons and badge text (report_noise_screen.dart:404, 429) on a dropdown whose background is getCardColor — white in light mode. History's classification badges do the same (history_screen.dart:607-630, red[300]/green[300]/red[200]/green[200] on a white card).

**Failure scenario:**

Light-mode user opens the classification dropdown or scans history badges: pastel pink/mint text on white sits well below readable contrast, making Pollution/Ambient labels hard to distinguish.

**Recommended fix:**

Pick shades per brightness: `isDark ? Colors.red[300] : Colors.red[700]` (and green equivalents), or use AppTheme.highNoise/lowNoise which already work on both surfaces.

---

#### [boot-12] Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention across four boot files

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/onboarding_screen.dart:76`

**Description:**

Project convention: all UI colors via ThemeHelper.getX(context), never hardcoded AppTheme constants. Violations verified: onboarding_screen.dart lines 76 (AppTheme.cardBackground/lightCardBackground), 111 (AppTheme.textWhite/textDark), 123 (AppTheme.textGray/textLightGray); splash_screen.dart lines 82 (AppTheme.textGray) and 110 (AppTheme.lightPurple — this sound bar also ignores the user's selected theme color while its two siblings at 108/112 correctly use ThemeHelper.getPrimaryColor); shared_bottom_navbar.dart lines 25 (AppTheme.darkPurple) and 69 (AppTheme.textGray); main.dart lines 166-168 (AppTheme.darkBackground/lightBackground in the auth-loading scaffold). Practical effect: users who pick a non-purple theme color still see purple remnants (splash middle bar, dark-mode nav bar background), and manual isDark branching duplicates what ThemeHelper centralizes.

**Failure scenario:**

User sets the theme color to teal in Settings: the dark-mode bottom nav bar stays purple (AppTheme.darkPurple) and the splash screen's center sound bar stays light purple, visibly clashing with the teal primary used by the adjacent elements.

**Recommended fix:**

Replace each AppTheme constant with the equivalent ThemeHelper getter (getCardColor, getTextColor, getSecondaryTextColor, getPrimaryColor, getBackgroundColor) at the cited lines; for the nav bar dark background add/use a ThemeHelper surface getter derived from the current primary color.

---

#### [map-18] Typing 1-2 characters blanks the Search Cities screen and wastes a fetch

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/search_list_screen.dart:304`

**Description:**

The city grid is hidden as soon as _searchQuery.isNotEmpty (line 134), but results render only when length >= 3 (line 304), while _searchWithNominatim fetches at >= 2 chars (line 37). With 1-2 chars the screen below the search bar is empty, and the 2-char network request's results are never displayed.

**Failure scenario:**

User types 'ka': the city grid disappears, a Nominatim request fires, and nothing at all is shown until the third character.

**Recommended fix:**

Align the thresholds: keep the grid visible until length >= 3 (or show results from >= 2), and gate the fetch at the same length as the display.

---

#### [dash-20] Gauge widget hand-rolls isDark branching with raw AppTheme constants instead of ThemeHelper

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:86`

**Description:**

The gauge bypasses the ThemeHelper convention throughout: background ring `isDark ? AppTheme.cardBackground : AppTheme.lightCardBackground` (line 86), sweep gradient hardcodes AppTheme.primaryPurple/lightPurple (lines 96-97), tick and label colors branch manually on isDark (lines 142, 160), the digital readout does the same (lines 39, 51), and the needle is fixed AppTheme.primaryPurple (lines 208, 221). Any future change to ThemeHelper's palette (or a new theme) silently desynchronizes this widget from the rest of the app.

**Failure scenario:**

The team adjusts the app's primary color via ThemeHelper: every screen updates except the Dashboard's centerpiece gauge, whose arc and needle stay the old purple.

**Recommended fix:**

Thread the needed colors in from the widget level using ThemeHelper.getCardColor/getPrimaryColor/getTextColor/getSecondaryTextColor(context) and pass them into the painters as constructor fields (painters can't access context), removing the isDark ternaries.

---

#### [donate-15] Impact-message math is internally inconsistent (100x jump at the $50 tier)

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/services/donation_service.dart:27`

**Description:**

getImpactMessage (lines 25-36) computes '(amount/0.77)*100' users for >=50 but '(amount/0.77)*10' for >=20 and a fixed '100+' for >=10. So $49 shows '636+ users', $50 shows '6493+ users' (a 100x discontinuity for one extra dollar), and $20 shows '259+ users' while $19 shows '100+'. The same string is echoed on the donation screen preview (donation_screen.dart line 581) and in the thank-you dialog (line 173).

**Failure scenario:**

User toggles between the $20 preset and a $50 custom amount and sees the claimed impact leap from 259 users to 6,493 users, making the numbers obviously fabricated and undermining trust in the donation pitch.

**Recommended fix:**

Use one continuous formula across all tiers (e.g., users = (amount / costPerUser).round() with a single costPerUser constant) and vary only the emoji/wording per tier.

---

#### [offline-13] Sync status dialog shows frozen data: values captured once at open and never refreshed

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:149`

**Description:**

`_showSyncStatusDialog` reads isOnline/isSyncing/pendingCount/lastSyncTime into locals (lines 149-152) and the dialog builder closes over them. The dialog is a separate route, so the parent's 2-second timer setState does not rebuild it. A dialog left open shows 'Syncing…' after the sync finished, a stale pending count, and a Sync Now button whose visibility condition (line 210) was evaluated at open time.

**Failure scenario:**

User opens the dialog while a sync is running and watches it; the sync completes and clears the queue, but the dialog continues to show 'Syncing…' with '5 recording(s)' pending until dismissed and reopened.

**Recommended fix:**

Wrap the dialog content in a StatefulBuilder (or a small StatefulWidget) with its own periodic refresh reading `_syncService.getSyncStatus()`, or drive it from a ValueListenable/stream exposed by SyncService.

---

#### [dash-17] Zero UI feedback that readings are being auto-saved every 5 seconds, and save failures are fully silent

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/dashboard_screen.dart:487`

**Description:**

Saving happens invisibly via `_saveTimer` (lines 487-503); `saveNoiseReading` is fire-and-forget and (verified in lib/services/firebase_service.dart lines 16-92) swallows every error internally, including the case where even the offline Hive fallback fails (logged only, line 88-90). Nothing on the Dashboard indicates a save occurred, is pending, or failed — the SyncStatusIndicator in the AppBar shows connectivity/queue state but not per-session save outcomes. A user who expects 'stop' to save their session gets no confirmation either way.

**Failure scenario:**

User records a 3-minute session while Hive storage is failing (e.g. disk full): every save and every fallback silently fails, the user sees 'Recording...' throughout, stops, and only discovers in History that the entire session was lost.

**Recommended fix:**

Surface save state on the Dashboard: have saveNoiseReading return an enum (savedOnline/queuedOffline/failed), track the last result in state, and render a small status line under the record button (e.g. 'Last saved 5s ago' / 'Queued offline' / 'Save failed'); show a SnackBar on the first failure of a session.

---

#### [settings-22] Dark theme AppBar ignores the user's selected theme color while light theme follows it

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/theme/app_theme.dart:57`

**Description:**

generateDarkTheme pins appBarTheme.backgroundColor to the purple constant darkPurple (lines 57-58) regardless of the primaryColor passed in, whereas generateLightTheme uses primaryColor (lines 141-142). Picking Green/Teal/Red in the Theme Colors dialog therefore recolors app bars in light mode but leaves them purple-tinted in dark mode — inconsistent propagation of the theme color feature between modes.

**Failure scenario:**

User selects the Green theme in dark mode: buttons, sliders and accents turn green but every AppBar stays the old purple (#2D2640), making the color choice look half-applied.

**Recommended fix:**

In generateDarkTheme derive the app bar color from the chosen color (e.g. Color.lerp(primaryColor, Colors.black, 0.6)) or use the shared dark surface color intentionally for both modes.

---

#### [dash-22] Curved line interpolation can overshoot, drawing dB levels that were never measured

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/noise_history_chart.dart:67`

**Description:**

`isCurved: true` (line 67) without `preventCurveOverShooting: true` lets fl_chart's cubic smoothing overshoot between adjacent points with large deltas — common in noise data (quiet-to-loud transients). The rendered curve then dips below or spikes above the actual readings, e.g. showing an apparent ~95 dB peak between two 85 dB samples, in a chart whose whole purpose is showing measured levels.

**Failure scenario:**

Readings jump 45 → 88 → 50 dB: the smoothed curve overshoots above 88 and undershoots below 45 between samples, visually exaggerating both the peak and the trough the user believes they measured.

**Recommended fix:**

Add `preventCurveOverShooting: true` (optionally `curveSmoothness: 0.2`) to the LineChartBarData at line 65.

---

#### [donate-16] Donation flow screens hardcode AppTheme/Material colors instead of using ThemeHelper (project convention violation)

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/screens/donation_screen.dart:93`

**Description:**

Project convention: all UI colors via ThemeHelper.getX(context), never hardcoded AppTheme colors in UI. Violations: donation_screen.dart uses AppTheme.darkPurple (lines 93, 96), AppTheme.cardBackground (184, 223, 259, 400, 499), Colors.grey.shade50 (93), Colors.blue.shade600 for the donate button (362), fixed light-green info box colors (318-331) that render as a light box in dark mode; paypal_webview_widget.dart uses AppTheme.darkPurple/cardBackground (48, 51, 78, 164, 197, 224, 307); buy_me_coffee_widget.dart likewise (84, 87, 124, 131, 159, 223). Also 'Alternative donation method' uses Colors.grey.shade600 (539) which is low-contrast on the dark card background.

**Failure scenario:**

A future theme change (or the existing dark theme) is updated via ThemeHelper; these screens keep their hardcoded purples/greys and drift visually - e.g., in dark mode the impact box stays light green with dark text and the subtitle text at line 539 is barely readable on AppTheme.cardBackground.

**Recommended fix:**

Replace AppTheme.* and raw Colors.* usages with ThemeHelper.getBackgroundColor/getCardColor/getTextColor/getSecondaryTextColor/getPrimaryColor(context) across the three files, keeping only semantic accents (success green / PayPal blue) as named theme-aware constants.

---

#### [uiux-30] Impact message box hardcodes Colors.green.shade50 — glaring light block in dark mode

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/donation_screen.dart:318`

**Description:**

The impact preview container uses `color: Colors.green.shade50` with green.shade200 border and green.shade800 text (lines 315-338) regardless of brightness. In dark mode it is a bright pastel panel inside the dark card. Similar dark-mode blind spots: 'Alternative donation method' subtitle Colors.grey.shade600 (line 539) and the security note grey.shade500 (lines 379-386) sit on dark surfaces at low contrast.

**Failure scenario:**

Dark-mode user opens Support This Project: a stark white-green box glows inside the dark card, and the 'Alternative donation method' caption is dim grey-on-dark.

**Recommended fix:**

Gate on isDark (already computed at line 89): e.g. `isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50` for the fill and lighter green/grey text shades in dark mode.

---

#### [fb-19] City statistics are computed from only the newest 100 global readings but presented as totals

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** M

**Location:** `lib/services/firebase_service.dart:169`

**Description:**

getNoiseReadings() hard-caps at .limit(100) (line 169). search_list_screen builds its entire 'Search Cities' grid from this stream (line 137): per-city averages, max, and the '$count readings' label (line 616) are therefore computed over whichever cities happen to appear in the 100 most recent readings collection-wide, and cities need >=2 readings within that window to appear at all (line 519). The UI presents these as authoritative city stats.

**Failure scenario:**

A city with 500 historical readings but none in the latest 100 disappears from the grid entirely; another city shows '3 readings' when it actually has 200, and its displayed average reflects only the 3 newest — users see misleading community statistics.

**Recommended fix:**

Either label the screen explicitly ('based on the latest 100 readings'), or compute city aggregates from a purpose-built query/aggregation (e.g. a Cloud Function-maintained per-city summary doc, or a larger bounded window with server-side aggregation) rather than the map's marker feed.

---

#### [flow1-14] Fixed unskippable 3-second splash delay stacks on top of already-slow pre-runApp init

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/splash_screen.dart:36`

**Description:**

splash_screen.dart:36 hardcodes Timer(Duration(seconds: 3)) before navigating. The user has already waited through the blocking main() sequence (Firebase, notifications+permission dialog, Hive/SyncService, double TFLite model load — main.dart:38-69) plus the auth-stream loading spinner (main.dart:164-172); the splash then adds another guaranteed 3 seconds doing nothing, and tapping the screen does not skip it. The fade animation itself completes at 1.5s (line 24).

**Failure scenario:**

Signed-out user on a slow device: several seconds of native splash, a moment of spinner, then three more mandatory seconds of the static logo before the onboarding card finally appears — every launch (see flow1-2).

**Recommended fix:**

Reduce the timer to ~1.5s to match the fade animation and wrap the body in a GestureDetector that cancels the timer and navigates immediately on tap.

---

#### [uiux-29] Gauge arc and needle hardcode purple — the app's marquee widget ignores the selected theme color

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:96`

**Description:**

The progress arc SweepGradient uses AppTheme.primaryPurple/lightPurple (lines 96-97) and the needle + hub are AppTheme.primaryPurple (lines 208, 221); the dashboard classification spinner also hardcodes AppTheme.primaryPurple (dashboard_screen.dart:1166). None react to themeColorNotifier.

**Failure scenario:**

User selects the Teal theme: buttons, chips and charts all turn teal, but the central dashboard gauge stays purple, making the theme feature look broken on the app's main screen.

**Recommended fix:**

Pass `ThemeHelper.getPrimaryColor(context)` into DecibelGaugePainter/NeedlePainter as a constructor param (isDark is already passed the same way).

---

#### [uiux-38] Live chart maxY is 100 but readings go up to 120 — loud spikes draw outside the card

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/widgets/noise_history_chart.dart:61`

**Description:**

LineChartData sets `maxY: 100` (line 61) while DashboardScreen clamps readings to 0-120 (dashboard_screen.dart:403). fl_chart does not clip by default, so spots above 100 render beyond the chart bounds, painting over the card's padding/rounded corner.

**Failure scenario:**

User measures a 110 dB traffic horn: the line spikes out of the top of the 'noise history' card, visually glitching over the container edge instead of peaking at the top.

**Recommended fix:**

Set maxY to 120 to match the clamp range (or compute `max(100, data.max + 10)`), and/or enable `clipData: FlClipData.all()`.

---

#### [social-14] Community feed bypasses ThemeHelper entirely — hardcoded AppTheme colors with manual brightness checks throughout

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/community_feed_screen.dart:87`

**Description:**

Violation of the project convention 'all UI colors via ThemeHelper.getX(context), never hardcoded AppTheme colors in UI'. The whole screen hand-rolls `Theme.of(context).brightness == Brightness.dark ? AppTheme.textGray : AppTheme.textLightGray` (lines 87-92, 97-101, 119-123, 129-133, 141-145, 285-289, 296-300, 337-341, 348-352, 363-367, 373-377), hardcodes AppTheme.primaryPurple (lines 73, 158, 288) and AppTheme.cardBackground/lightCardBackground (lines 223-227). history_screen.dart also hardcodes AppTheme.textWhite in the AppBar (lines 366-367), as does report_noise_screen.dart line 273.

**Failure scenario:**

A theme palette change made in ThemeHelper (the sanctioned single source) does not propagate to the community feed; the screen drifts visually from the rest of the app, exactly what the convention exists to prevent.

**Recommended fix:**

Replace each brightness ternary with the corresponding ThemeHelper getter (getSecondaryTextColor, getTextColor, getCardColor, getPrimaryColor) as done in history_screen's body and report_noise_screen.

---

#### [settings-17] Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:391`

**Description:**

Direct AppTheme constants appear in UI code, against the project rule that all UI colors go through ThemeHelper.getX(context): settings_screen_enhanced.dart line 391 (AppTheme.darkPurple toggle track), line 425 (AppTheme.textGray), line 502 (AppTheme.darkPurple slider inactive), lines 583-591 and 664-666 (theme-picker dialog backgrounds/text), and edit_profile_screen.dart line 216 (iconTheme AppTheme.textWhite). The theme-picker dialog also snapshots isDark before showDialog (line 578), so it won't restyle if dark mode changes underneath it.

**Failure scenario:**

A future theme adjustment (e.g. new dark card color in ThemeHelper) leaves these controls rendering the old purple-family constants, producing mixed styling within the same screen.

**Recommended fix:**

Replace each with the equivalent ThemeHelper getter (getCardColor, getSecondaryTextColor, getTextColor) or add a dedicated helper for the toggle-track color; use dialogContext-based theming inside the dialog builder.

---

#### [uiux-28] Community feed hardcodes AppTheme.primaryPurple and raw AppTheme colors, ignoring the user's theme color

**Severity:** Low | **Status:** unverified | **Category:** ui-ux | **Effort:** S

**Location:** `lib/screens/community_feed_screen.dart:73`

**Description:**

The loading spinner (line 73) and RefreshIndicator (line 158) use `AppTheme.primaryPurple` directly, and the whole file uses `Theme.of(context).brightness == dark ? AppTheme.x : AppTheme.y` ternaries (lines 87-101, 119-147, 223-227, 285-300, 337-379) instead of ThemeHelper getters — violating the project's ThemeHelper-only convention.

**Failure scenario:**

User picks the Green theme in Settings > Theme Colors: every screen accents green except the Community Feed, whose spinner and pull-to-refresh stay purple.

**Recommended fix:**

Replace AppTheme.primaryPurple with ThemeHelper.getPrimaryColor(context) and the brightness ternaries with ThemeHelper.getTextColor/getSecondaryTextColor/getCardColor.

---

## Quick Wins (under 1 hour each)

- [ ] **flow1-6** - Notification permission dialog is awaited before runApp — first launch shows an OS prompt over a blank screen (`lib/main.dart:48`)
- [ ] **uiux-26** - Delete-account/clear-history error paths can pop the wrong route (`lib/screens/settings_screen_enhanced.dart:927`)
- [ ] **map-14** - Selecting an autocomplete result leaves an empty red label on the searched-location pin (`lib/screens/map_view_screen.dart:812`)
- [ ] **uiux-3** - 'Export Data to CSV' exports EVERY user's recordings, including their emails (`lib/screens/history_screen.dart:230`)
- [ ] **uiux-35** - Saving profile replaces the entire form with a bare spinner (`lib/screens/edit_profile_screen.dart:218`)
- [ ] **uiux-21** - History pull-to-refresh is dead exactly in the offline and empty states (`lib/screens/history_screen.dart:383`)
- [ ] **uiux-22** - Login error handling only maps legacy Firebase error codes — users get generic 'Login failed' (`lib/screens/login_screen.dart:63`)
- [ ] **uiux-23** - Community Feed badge query violates the project Firestore index rule and hides loading/error as '0' (`lib/screens/dashboard_screen.dart:911`)
- [ ] **uiux-6** - Search-as-you-type never fires when the query contains an uppercase letter (`lib/screens/search_list_screen.dart:292`)
- [ ] **flow7-11** - Success path never returns the user to the app: thank-you dialog Close only dismisses the dialog (`lib/services/donation_service.dart:186`)
- [ ] **boot-6** - Back navigation stays enabled during registration submit — user can pop mid-flight and end up silently authenticated on the Login screen (`lib/screens/registration_screen.dart:136`)
- [ ] **settings-19** - Theme color picker uses white selection borders/labels tuned for dark mode only (`lib/screens/settings_screen_enhanced.dart:640`)
- [ ] **uiux-31** - Duplicate 'current location' person marker layer rendered whenever a search is active (`lib/screens/map_view_screen.dart:768`)
- [ ] **offline-7** - Manual-sync feedback is wrong and usually never appears: unconditional success snackbar built on the popped dialog's context (`lib/widgets/sync_status_indicator.dart:216`)
- [ ] **uiux-19** - Map autocomplete fires an HTTP request on every keystroke with no debounce or stale-response guard (`lib/screens/map_view_screen.dart:933`)
- [ ] **map-23** - Hardcoded AppTheme colors with manual isDark branching instead of ThemeHelper (project convention violation) (`lib/screens/map_view_screen.dart:879`)
- [ ] **offline-14** - Hardcoded Material colors throughout the widget violate the project's ThemeHelper convention (`lib/widgets/sync_status_indicator.dart:83`)
- [ ] **uiux-24** - City details bottom sheet: 24px city name in a Row without Flexible — RenderFlex overflow on long names (`lib/screens/search_list_screen.dart:649`)
- [ ] **flow7-07** - No back-navigation handling in either webview: system back exits checkout instead of going back a page (`lib/widgets/paypal_webview_widget.dart:47`)
- [ ] **analytics-10** - No empty or error state for the stats grid — zeros are presented as real measurements and load failures are swallowed (`lib/screens/analytics_screen.dart:367`)
- [ ] **dash-19** - Hardcoded AppTheme colors in dashboard UI violate the ThemeHelper convention (`lib/screens/dashboard_screen.dart:875`)
- [ ] **donate-17** - Location pins use absolute pixel positions while continents scale with screen size, so pins drift onto the wrong continents; colors ignore light theme (`lib/widgets/world_map_background.dart:27`)
- [ ] **uiux-33** - Reload button crashes with LateInitializationError if tapped before the WebView is created (`lib/widgets/paypal_webview_widget.dart:63`)
- [ ] **uiux-11** - Decibel gauge hardcoded to 320px — overflows and clips on narrow phones (`lib/widgets/decibel_meter_gauge.dart:20`)
- [ ] **uiux-20** - 'Open in Browser' button shows 'Opening in browser...' but never opens anything (`lib/widgets/buy_me_coffee_widget.dart:106`)
- [ ] **uiux-5** - Map pull-to-refresh can never trigger — markers/heatmap are stale until app restart (`lib/screens/map_view_screen.dart:603`)
- [ ] **social-15** - Pull-to-refresh is dead when the list does not fill the screen and on the empty state (`lib/screens/history_screen.dart:432`)
- [ ] **uiux-32** - Nominatim query string is interpolated unencoded into the URL (`lib/screens/map_view_screen.dart:363`)
- [ ] **uiux-34** - Pale red[300]/green[300] classification colors designed for dark mode used on white surfaces (`lib/screens/report_noise_screen.dart:404`)
- [ ] **uiux-7** - List builders crash the whole screen on a doc with missing/null decibelLevel (`lib/screens/history_screen.dart:451`)
- [ ] **boot-12** - Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention across four boot files (`lib/screens/onboarding_screen.dart:76`)
- [ ] **uiux-13** - Analytics load failure is silent — zeros shown as if they were real data (`lib/screens/analytics_screen.dart:172`)
- [ ] **map-18** - Typing 1-2 characters blanks the Search Cities screen and wastes a fetch (`lib/screens/search_list_screen.dart:304`)
- [ ] **dash-20** - Gauge widget hand-rolls isDark branching with raw AppTheme constants instead of ThemeHelper (`lib/widgets/decibel_meter_gauge.dart:86`)
- [ ] **uiux-4** - Cluster color is always orange due to broken string interpolation in key lookup (`lib/screens/map_view_screen.dart:686`)
- [ ] **donate-15** - Impact-message math is internally inconsistent (100x jump at the $50 tier) (`lib/services/donation_service.dart:27`)
- [ ] **uiux-2** - Deleting a recording leaves it visible in the list and has no error handling (`lib/screens/history_screen.dart:721`)
- [ ] **offline-13** - Sync status dialog shows frozen data: values captured once at open and never refreshed (`lib/widgets/sync_status_indicator.dart:149`)
- [ ] **flow3-12** - SyncStatusIndicator on the map is painted underneath FlutterMap and is never visible (`lib/screens/map_view_screen.dart:611`)
- [ ] **settings-22** - Dark theme AppBar ignores the user's selected theme color while light theme follows it (`lib/theme/app_theme.dart:57`)
- [ ] **boot-7** - Back button instantly exits the app from any tab — no back-to-home behavior, no confirmation, no-op on iOS (`lib/widgets/main_app_shell.dart:30`)
- [ ] **dash-22** - Curved line interpolation can overshoot, drawing dB levels that were never measured (`lib/widgets/noise_history_chart.dart:67`)
- [ ] **uiux-8** - Completely blank screen when a search returns zero results (`lib/screens/search_list_screen.dart:403`)
- [ ] **uiux-9** - AppBar back arrows nearly invisible in light mode; per-screen white-icon hacks are inconsistent (`lib/screens/settings_screen_enhanced.dart:80`)
- [ ] **uiux-30** - Impact message box hardcodes Colors.green.shade50 — glaring light block in dark mode (`lib/screens/donation_screen.dart:318`)
- [ ] **flow1-14** - Fixed unskippable 3-second splash delay stacks on top of already-slow pre-runApp init (`lib/screens/splash_screen.dart:36`)
- [ ] **uiux-15** - Logout executes instantly with no confirmation (`lib/screens/dashboard_screen.dart:683`)
- [ ] **uiux-29** - Gauge arc and needle hardcode purple — the app's marquee widget ignores the selected theme color (`lib/widgets/decibel_meter_gauge.dart:96`)
- [ ] **uiux-25** - CSV export has no busy state — long download with only a 1-second snackbar, repeat taps run parallel exports (`lib/screens/history_screen.dart:222`)
- [ ] **uiux-38** - Live chart maxY is 100 but readings go up to 120 — loud spikes draw outside the card (`lib/widgets/noise_history_chart.dart:61`)
- [ ] **social-14** - Community feed bypasses ThemeHelper entirely — hardcoded AppTheme colors with manual brightness checks throughout (`lib/screens/community_feed_screen.dart:87`)
- [ ] **uiux-17** - Change Password dialog has no busy/disabled state during the network call (`lib/screens/settings_screen_enhanced.dart:728`)
- [ ] **uiux-10** - Hardcoded AppTheme.textGray used on light backgrounds — near-invisible text in light mode (`lib/screens/splash_screen.dart:82`)
- [ ] **settings-17** - Hardcoded AppTheme colors in UI violate the ThemeHelper-only convention (`lib/screens/settings_screen_enhanced.dart:391`)
- [ ] **uiux-28** - Community feed hardcodes AppTheme.primaryPurple and raw AppTheme colors, ignoring the user's theme color (`lib/screens/community_feed_screen.dart:73`)
