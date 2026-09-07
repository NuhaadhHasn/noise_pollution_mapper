# Accessibility Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **26** (2 High, 18 Medium, 5 Low, 1 Enhancement).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| a11y-2 | High | confirmed | `lib/screens/dashboard_screen.dart:836` | Primary record/stop button is an unlabeled GestureDetector; recording state changes are never announced | S |
| a11y-1 | High | confirmed | `lib/widgets/shared_bottom_navbar.dart:57` | Bottom navigation is icon-only with no labels, roles, or selected-state semantics | S |
| a11y-6 | Medium | unverified | `lib/screens/map_view_screen.dart:649` | Heatmap overlay is color-only with no legend and no semantic alternative | M |
| a11y-17 | Medium | unverified | `lib/screens/dashboard_screen.dart:875` | Hardcoded AppTheme.textGray on light backgrounds yields ~1.8:1 contrast | S |
| a11y-11 | Medium | unverified | `lib/screens/analytics_screen.dart:488` | Custom filter chips (period, sound type, donation amounts) expose no selected state or button role | S |
| a11y-4 | Medium | unverified | `lib/widgets/noise_history_chart.dart:31` | Noise history LineChart has no semantic alternative — invisible to screen readers | S |
| a11y-19 | Medium | unverified | `lib/screens/search_list_screen.dart:608` | Orange #FF9800 used as text on white/light surfaces fails contrast everywhere it appears | M |
| a11y-24 | Medium | unverified | `lib/screens/analytics_screen.dart:359` | Fixed-aspect-ratio GridView stat/city cards overflow at large text scale | M |
| a11y-18 | Medium | unverified | `lib/screens/history_screen.dart:613` | Classification badges use Colors.red[300]/green[300] text — ~2.9:1 / ~1.9:1 in light mode | S |
| a11y-15 | Medium | unverified | `lib/screens/login_screen.dart:146` | Login fields have no labels — password field's only accessible name is bullet characters | S |
| a11y-23 | Medium | unverified | `lib/screens/history_screen.dart:358` | Two-line AppBar title Columns overflow the fixed 56dp toolbar at large text scale | S |
| a11y-5 | Medium | unverified | `lib/screens/analytics_screen.dart:1039` | Analytics trend LineChart and pie chart expose no data to assistive technology | M |
| a11y-9 | Medium | unverified | `lib/screens/history_screen.dart:644` | Multiple IconButtons across screens have no tooltip/label — including the destructive per-item delete | S |
| a11y-10 | Medium | unverified | `lib/screens/map_view_screen.dart:937` | Search-history icon in map search bar is a bare 24px GestureDetector | S |
| a11y-16 | Medium | unverified | `lib/utils/animations.dart:150` | AnimatedButton (login/registration submit) is a GestureDetector with no button role or disabled state | S |
| a11y-21 | Medium | unverified | `lib/widgets/classification_guide_widget.dart:142` | Guide tile YAMNet info text rendered in raw category color — yellow on near-white is ~1.1:1 | S |
| a11y-12 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:409` | dBA/dBC and Fast/Slow segmented toggles are ~36dp tall unlabeled GestureDetectors | S |
| a11y-3 | Medium | unverified | `lib/widgets/decibel_meter_gauge.dart:19` | Decibel gauge (CustomPaint) has no semantic representation of the reading | S |
| a11y-7 | Medium | unverified | `lib/widgets/sync_status_indicator.dart:101` | Sync status indicator tap target is roughly 34x26dp and lacks a button role | S |
| a11y-13 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:454` | Settings switches are not semantically associated with their text labels | S |
| a11y-26 | Low | unverified | `lib/screens/dashboard_screen.dart:752` | Location pill and community feed card are tappable GestureDetectors with no button role or action hint | S |
| a11y-14 | Low | unverified | `lib/screens/settings_screen_enhanced.dart:495` | Sliders announce percentages instead of their real units (seconds / dB) | S |
| a11y-8 | Low | unverified | `lib/widgets/heatmap_fab.dart:21` | Heatmap FAB and map location FAB have no tooltip; heatmap toggle state not exposed | S |
| a11y-20 | Low | unverified | `lib/screens/edit_profile_screen.dart:264` | Edit-profile hint text at 30% alpha is ~1.5:1 contrast in both themes | S |
| a11y-22 | Low | unverified | `lib/widgets/shared_bottom_navbar.dart:66` | Inactive nav icons at 50% white on primary color are ~2.2:1 in light mode | S |
| a11y-25 | Enhancement | unverified | `lib/utils/animations.dart:313` | Animations ignore the system reduce-motion / disable-animations setting | M |

## Detailed Findings

### High

#### [a11y-2] Primary record/stop button is an unlabeled GestureDetector; recording state changes are never announced

**Severity:** High | **Status:** confirmed | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:836`

**Verifier verdict (CONFIRMED):** lib/screens/dashboard_screen.dart:836-869 — the primary record/stop control is a bare GestureDetector wrapping an AnimatedContainer with an Icon whose semanticLabel is unset. No Semantics wrapper, Tooltip, button role, or label anywhere; grep for Semantics|SemanticsService|announce|semanticLabel across the file returns zero matches. State changes are conveyed only visually (color/icon at 844-864 and the plain Text "Recording..."/"Tap to measure" at 872-878, which is not a liveRegion), so screen readers get neither a labeled/actionable button nor any announcement when recording starts or stops. Finding is accurate as stated.

**Description:**

The app's core action — start/stop noise measurement — is a GestureDetector (line 836) around an AnimatedContainer with an Icon (mic/stop) that has no semanticLabel, no button role, and no state description. The only state feedback is the visual 'Recording...' text below (line 872) and the icon swap. No SemanticsService.announce or live region exists, so a screen-reader user gets no confirmation that recording started or stopped.

**Failure scenario:**

A blind user focuses the round button: it is announced as 'unlabeled, double tap to activate'. After activating it, nothing is announced; they cannot tell whether the microphone is now recording (a privacy-sensitive state) without visually inspecting the screen.

**Recommended fix:**

Wrap the GestureDetector in Semantics(button: true, label: _isRecording ? 'Stop noise measurement' : 'Start noise measurement') and call SemanticsService.announce('Recording started'/'Recording stopped', TextDirection.ltr) in _startRecording/_stopRecording. Alternatively use an IconButton/FloatingActionButton with tooltip.

---

#### [a11y-1] Bottom navigation is icon-only with no labels, roles, or selected-state semantics

**Severity:** High | **Status:** confirmed | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/shared_bottom_navbar.dart:57`

**Verifier verdict (CONFIRMED):** lib/widgets/shared_bottom_navbar.dart is exactly as described. Nav items are bare InkWell-wrapped Icons (lines 57-74) and a GestureDetector home button (lines 82-119). There are no text labels, no Icon semanticLabel, no Tooltip, and no Semantics widgets anywhere in the file; selected state is conveyed only visually via color/border/shadow (lines 66-70, 93-100). It does not use Material BottomNavigationBar/NavigationBar, which would supply button roles, labels, and "selected" semantics automatically. Screen readers get five unlabeled tappable icons with no role or selection info. Finding is accurate.

**Description:**

All five primary nav destinations are bare InkWell/GestureDetector wrappers around unlabeled Icon widgets (_buildNavButton line 57-75, _buildHomeButton GestureDetector line 82-121). Icons have no semanticLabel, there are no Tooltips, no Semantics(button:true, selected:...) wrappers, and the home button (GestureDetector) does not even get default ink feedback. A grep confirms zero Semantics usage anywhere in lib/. TalkBack/VoiceOver users hear only 'unlabeled, double tap to activate' five times with no way to know which tab is which or which is active. This is the sole navigation for the whole app (MainAppShell IndexedStack tabs Map=0 Analytics=1 Dashboard=2 History=3 Settings=4).

**Failure scenario:**

A TalkBack user opens the app and swipes across the bottom bar: every destination is announced as an unlabeled button with no selected state, so they cannot reach Analytics, History, or Settings except by guessing; the entire app is effectively unnavigable with a screen reader.

**Recommended fix:**

Wrap each item in Semantics(button: true, selected: isActive, label: 'Map'/'Analytics'/'Home'/'History'/'Settings') or add Tooltip + Icon(semanticLabel:). Better: replace the custom Row with Material's NavigationBar/BottomNavigationBar, which provides labels, roles, selected state, and 'tab X of 5' announcements for free.

---

### Medium

#### [a11y-6] Heatmap overlay is color-only with no legend and no semantic alternative

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** M

**Location:** `lib/screens/map_view_screen.dart:649`

**Description:**

HeatmapLayer (line 649, painter lines 1423-1473) encodes noise intensity purely as a green→yellow→orange→red blur ramp painted on canvas — no legend appears anywhere on the map screen, no Semantics node describes the overlay, and the green/red pairing is indistinguishable for deuteranopia users. Notably, HeatmapSettingsPanel (lib/widgets/heatmap_settings_panel.dart) contains stats and controls that would help, but a grep shows it is never instantiated anywhere — the map only mounts the bare HeatmapFab toggle.

**Failure scenario:**

A color-blind user enables the heatmap via the FAB: red 'very loud' and green 'quiet' blobs look nearly identical to them, and no text/legend exists to disambiguate; a screen-reader user activating the toggle gets no feedback that anything changed at all.

**Recommended fix:**

Add a small on-map legend (color swatch + dB range text) when _showHeatmap is true, announce toggle changes ('Heatmap shown, 100 points, average 63 dB') via SemanticsService, and consider mounting the existing HeatmapSettingsPanel which already surfaces avg/max/min as text.

---

#### [a11y-17] Hardcoded AppTheme.textGray on light backgrounds yields ~1.8:1 contrast

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:875`

**Description:**

AppTheme.textGray (#B8B5C8) is a dark-theme color, but several places use it unconditionally: the 'Tap to measure' status under the record button (dashboard_screen.dart:875), the splash subtitle (splash_screen.dart:82), and the marker detail bottom sheet's coordinates, noise-level text, and confidence (map_view_screen.dart:1183, 1197, 1267 on a white card in light mode). #B8B5C8 on #F5F5F5/#FFFFFF is ~1.8:1, far below the 4.5:1 WCAG AA minimum. This also violates the project's ThemeHelper-only color convention.

**Failure scenario:**

A user switches to light mode in Settings, returns to the Dashboard, and the 'Tap to measure' instruction is a pale lavender-gray on near-white — effectively invisible to low-vision users and hard to read for everyone outdoors; the same happens for the noise-level description in the map marker sheet.

**Recommended fix:**

Replace each hardcoded AppTheme.textGray with ThemeHelper.getSecondaryTextColor(context) (which resolves to #6B6B6B ≈ 4.9:1 in light mode), per the existing project convention.

---

#### [a11y-11] Custom filter chips (period, sound type, donation amounts) expose no selected state or button role

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/analytics_screen.dart:488`

**Description:**

Analytics period chips (_buildPeriodChip, GestureDetector line 488) and sound-type chips (_buildFilterChip, line 541) are hand-rolled Containers whose selection is conveyed only by color/border. Donation preset-amount and Custom chips (donation_screen.dart lines 213-239 and 249-285) follow the same pattern. None expose Semantics(selected:) or a button role, unlike HeatmapSettingsPanel which correctly uses ChoiceChip (heatmap_settings_panel.dart:241).

**Failure scenario:**

A TalkBack user on Analytics wants monthly stats: the Daily/Weekly/Monthly row announces three plain text labels with no 'selected' state and no button hint, so they cannot tell Weekly is active or that the labels are tappable; the same failure lets a donor unknowingly submit the default $ amount on the donation screen.

**Recommended fix:**

Replace the GestureDetector containers with ChoiceChip (as already done in heatmap_settings_panel.dart) or wrap in Semantics(button: true, selected: isSelected, label: label).

---

#### [a11y-4] Noise history LineChart has no semantic alternative — invisible to screen readers

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/noise_history_chart.dart:31`

**Description:**

The fl_chart LineChart (line 31) hides grid, titles, and border (lines 51-57) and has no Semantics wrapper, so it produces no accessibility nodes at all. Tooltips are touch-hover-only (lines 87-102), which is unusable with TalkBack's explore-by-touch. The real-time dB history is therefore available exclusively to sighted users.

**Failure scenario:**

A screen-reader user records for two minutes on the Dashboard and swipes into the history card: nothing is announced for the chart region (only the empty-state text exists when there is no data), so they get zero access to the trend data the chart conveys.

**Recommended fix:**

Wrap the LineChart in Semantics(label: 'Noise history chart', value: 'Last ${dataToShow.length} readings, min ${min} dB, max ${max} dB, latest ${last} dB'), computed from dbHistory, so AT users get a textual summary of the same data.

---

#### [a11y-19] Orange #FF9800 used as text on white/light surfaces fails contrast everywhere it appears

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** M

**Location:** `lib/screens/search_list_screen.dart:608`

**Description:**

AppTheme.moderateNoise (#FF9800) is ~2.1:1 against white. Verified text usages on light surfaces: city-card average '${avgDb} dB' at 24px bold (search_list_screen.dart:607-614), 'Moderate Noise' label at 12px (history_screen.dart:573-579), 'Moderate' badge at 12px (community_feed_screen.dart:320-327), and the pending-count '$pendingCount' at 12px bold in SyncStatusIndicator (sync_status_indicator.dart:130-139), which in light mode sits on a 10%-orange pill over the primary-purple app bar at ~1.8:1. Even as large text (3:1 requirement) the 24px value fails; the 12px instances fail 4.5:1 badly.

**Failure scenario:**

A user in light mode opens Search Cities to compare noise levels: for every moderately-noisy city (50-70 dB — the most common bucket) the big dB number is washed-out orange on white and cannot be read in sunlight; on the Dashboard the orange pending-upload count in the app bar is similarly illegible.

**Recommended fix:**

Introduce a text-safe moderate color for light mode (e.g. #B26A00 / Colors.orange[900], ~4.6:1 on white) selected via ThemeHelper/brightness, keeping #FF9800 only for large fills like markers and gauge arcs where it is paired with white text.

---

#### [a11y-24] Fixed-aspect-ratio GridView stat/city cards overflow at large text scale

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:359`

**Description:**

Analytics' stats grid uses childAspectRatio: 1.3 (lines 359-375) with cells containing 32px value + 14px label plus 40px padding — content height is within ~10dp of the cell height at scale 1.0, so any textScaleFactor ≥ ~1.2 overflows (_buildStatCard, lines 1127-1157, has no FittedBox or Flexible). Search list's city grid (search_list_screen.dart:205-213, childAspectRatio 1.2) is worse: icon 32 + three text lines already ≈ 136dp of the ~148dp cell, overflowing around 1.15x scale.

**Failure scenario:**

A user with system font at 130% opens Analytics: all four stat cards ('Average', 'Lowest', 'Highest', 'Duration') show 'BOTTOM OVERFLOWED BY nn PIXELS' stripes (release mode: clipped numbers), and the Search Cities grid clips the readings count off every card.

**Recommended fix:**

Compute the aspect ratio from text scale (childAspectRatio: 1.3 / MediaQuery.textScalerOf(context).scale(1.0)), or wrap card contents in FittedBox/Flexible, or switch to a SliverGrid with mainAxisExtent derived from scaled text heights.

---

#### [a11y-18] Classification badges use Colors.red[300]/green[300] text — ~2.9:1 / ~1.9:1 in light mode

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/history_screen.dart:613`

**Description:**

History item badges render soundClass text and icon in Colors.red[300] (#E57373) or Colors.green[300] (#81C784) at 11px, with confidence in red[200]/green[200] at 10px (lines 603-631), on a 20%-alpha tint over the card. On white light-mode cards this is ~2.9:1 (red300) and ~1.9:1 (green300), both failing the 4.5:1 requirement for small text. The same [300] shades are used in report_noise_screen.dart's dropdown items (lines 404 and 429). These are dark-mode-tuned shades hardcoded for both themes, violating the ThemeHelper convention.

**Failure scenario:**

In light mode a user scans their History to find which recordings were classified as Traffic vs Nature: the pale green 'Nature 82%' badge text nearly vanishes into the white card, and the 10px confidence figure is unreadable without zooming.

**Recommended fix:**

Pick shades per brightness, e.g. isDark ? Colors.red[300] : Colors.red[700] (and green[300]/green[800]), or route through ThemeHelper helpers; bump the 10px confidence text to at least 12px.

---

#### [a11y-15] Login fields have no labels — password field's only accessible name is bullet characters

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/login_screen.dart:146`

**Description:**

The email field uses hintText 'email@example.com' (line 146) and the password field hintText '••••••••' (line 174) with no labelText. Hints are the only accessible name and disappear once text is entered; for the password field, TalkBack reads the bullet glyphs (or nothing useful). Registration and edit-profile screens correctly use labelText, making this an inconsistency confined to the login form.

**Failure scenario:**

A screen-reader user on the login form focuses the second field and hears '•,•,•,•... edit box' — no indication it is the password; after typing in both fields neither field announces any name at all, so reviewing entries before submitting is guesswork.

**Recommended fix:**

Add labelText: 'Email' and labelText: 'Password' to the two InputDecorations (matching registration_screen.dart), and replace the bullet hint with a real hint or remove it.

---

#### [a11y-23] Two-line AppBar title Columns overflow the fixed 56dp toolbar at large text scale

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/history_screen.dart:358`

**Description:**

History stacks 'History' (20px) + 'Your Recordings' (16px) in a Column as the AppBar title (lines 358-363); Analytics does the same with 20px + 13px (analytics_screen.dart:282-289). At the default text scale the combined line height (~46dp) barely fits kToolbarHeight (56dp); at Android font size Large (1.3x) it exceeds it, producing clipped text / RenderFlex overflow stripes since AppBar does not scale its height with textScaleFactor.

**Failure scenario:**

A user sets system font size to 'Largest' (1.5x-2x) for readability and opens History: the subtitle 'Your Recordings' is clipped in half or replaced by the yellow/black overflow bars in debug, and both title lines may be cut off in the fixed-height toolbar.

**Recommended fix:**

Use AppBar(title: Text('History'), bottom: PreferredSize(...)) for the subtitle, or set the subtitle with maxLines:1 + FittedBox, or raise toolbarHeight based on MediaQuery.textScalerOf(context).

---

#### [a11y-5] Analytics trend LineChart and pie chart expose no data to assistive technology

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** M

**Location:** `lib/screens/analytics_screen.dart:1039`

**Description:**

The trend LineChart (line 1039) has no Semantics wrapper; its only textual encodings are 10px axis labels (line 262-271) and touch tooltips, neither reachable via screen reader. The PieChart (line 619) is likewise unlabeled, though it at least has an adjacent visible legend (lines 657-664) — but the legend is not programmatically associated with the chart. The stats grid partially compensates, yet the per-bucket trend data has no non-visual alternative.

**Failure scenario:**

A low-vision user relying on TalkBack opens Analytics to check whether last week's noise was rising: swiping through the 'Noise Trend — Last 7 Days' card announces only the title; the entire trend line (the answer to their question) is silent.

**Recommended fix:**

Wrap the LineChart in Semantics summarizing the aggregated spots (e.g. 'Daily averages: Mon 62 dB, Tue 58 dB, ... peak 74 dB on Friday') built from the same _buildTimeAggregatedSpots output, and give the PieChart a Semantics label repeating the pollution/ambient percentages.

---

#### [a11y-9] Multiple IconButtons across screens have no tooltip/label — including the destructive per-item delete

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/history_screen.dart:644`

**Description:**

Unlabeled IconButtons verified: history delete button (history_screen.dart:644-649, destructive, one per recording), dashboard settings action (dashboard_screen.dart:705-716 — its sibling logout does have a tooltip at line 702), login password-visibility toggle (login_screen.dart:176-186), registration visibility toggles (registration_screen.dart:289-299 and 341-351), map search clear (map_view_screen.dart:912-926), and search-list clear (search_list_screen.dart:264-278). None have tooltip: or Icon semanticLabel, so all announce as 'unlabeled button'.

**Failure scenario:**

A screen-reader user reviewing their history swipes to the control after each recording's details and hears 'unlabeled button'; activating it out of curiosity opens a delete confirmation for data they did not intend to remove — and the visibility toggles on auth screens give no clue they show/hide the password.

**Recommended fix:**

Add tooltip: 'Delete recording', 'Settings', 'Show password'/'Hide password' (state-dependent), and 'Clear search' respectively. For the password toggles, the label should flip with _isPasswordVisible so the current state is conveyed.

---

#### [a11y-10] Search-history icon in map search bar is a bare 24px GestureDetector

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:937`

**Description:**

The Icons.history glyph that opens SearchListScreen is a GestureDetector directly wrapping a default-size (24px) Icon (lines 937-965) with no padding, no minimum touch target, no label, and no button role. Effective hit area is ~24x24dp, half the 48dp minimum, and it sits flush against the TextField edge.

**Failure scenario:**

A user tries to open the city search list by tapping the small clock icon at the right edge of the map search bar; taps land in the adjacent TextField instead, opening the keyboard — screen-reader users additionally hear only 'unlabeled' for the control.

**Recommended fix:**

Replace with IconButton(icon: Icon(Icons.history), tooltip: 'Search history and city list', onPressed: ...), which supplies the 48dp constraint, ripple, and label in one change.

---

#### [a11y-16] AnimatedButton (login/registration submit) is a GestureDetector with no button role or disabled state

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/utils/animations.dart:150`

**Description:**

AnimatedButton renders a GestureDetector + Container (lines 150-167) with no Semantics. It is the submit control on login_screen.dart:210 and registration_screen.dart:385. When _isLoading is true, onPressed is null but nothing conveys the disabled state to AT, and when enabled there is no 'button' role. AnimatedCard (line 217) has the same gap for its tappable use.

**Failure scenario:**

A screen-reader user completes the login form and reaches 'Log in': it is announced as plain text, not a button; while sign-in is in flight the control announces identically even though taps are ignored, so the user re-taps and assumes the app is broken.

**Recommended fix:**

Inside AnimatedButton.build, wrap the GestureDetector in Semantics(button: true, enabled: widget.onPressed != null) — one change fixes every call site; longer-term prefer ElevatedButton with a ScaleTransition wrapper.

---

#### [a11y-21] Guide tile YAMNet info text rendered in raw category color — yellow on near-white is ~1.1:1

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/classification_guide_widget.dart:142`

**Description:**

The yamnetInfo Text (lines 142-149) and its info icon (line 135-139) use Color(categoryData.color) directly at 12px on a background of the same color at alpha 0.05 over grey.shade100 (light mode). For the Religious category the color is 0xFFFFEB3B (verified in yamnet_class_mapping.dart:1511-1512) — pure yellow on near-white is ~1.1:1, i.e. invisible; light green (Nature), orange (Tuk-tuk), and similar bright category colors also fail 4.5:1.

**Failure scenario:**

In light mode a user opens the Sound Classification Guide and expands the 'Religious' category: the 'Mapped from ... YAMNet classes' explainer strip appears completely blank because yellow 12px text sits on a 5%-yellow-tinted white background.

**Recommended fix:**

Render yamnetInfo in ThemeHelper.getTextColor/getSecondaryTextColor and keep the category color only for the border/background tint; alternatively use Color.lerp(categoryColor, Colors.black, isDark ? 0 : 0.45) to darken bright hues for light mode.

---

#### [a11y-12] dBA/dBC and Fast/Slow segmented toggles are ~36dp tall unlabeled GestureDetectors

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:409`

**Description:**

_buildToggleButton (lines 407-433) is a GestureDetector with EdgeInsets.symmetric(horizontal: 16, vertical: 8) around 13px text — roughly 60x36dp, under the 48dp minimum height — and carries no button role, no selected state, and no group association with its 'Decibel Scale'/'Response Time' row label. Selection is color-only (primary fill vs transparent).

**Failure scenario:**

A screen-reader user in Settings hears 'dBA' and 'dBC' as two adjacent plain texts with no indication they are toggle options or which is active; a motor-impaired user aiming for the 36dp-tall 'Slow' segment hits the row padding and nothing happens.

**Recommended fix:**

Use SegmentedButton<bool> (Material 3) which provides roles, selection semantics, and minimum sizes, or add Semantics(button: true, selected: isSelected, label: '$text ${title} option') plus ConstrainedBox(minHeight: 48).

---

#### [a11y-3] Decibel gauge (CustomPaint) has no semantic representation of the reading

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/decibel_meter_gauge.dart:19`

**Description:**

DecibelMeterGauge renders the arc, ticks, and needle via two CustomPaint layers with no Semantics. The center value is two unrelated Text nodes ('72' and 'dB', lines 36-56) with no context label, so assistive tech reads a bare number floating in the dashboard with no indication it is the current noise level, and gauge context (0-100 scale, safe/moderate/dangerous zones) is completely invisible to AT.

**Failure scenario:**

A VoiceOver user on the Dashboard swipes through elements and hears '72' then 'dB' between the MIN/AVG/MAX row and the location pill; they cannot tell this is the live current noise level or how it relates to the 0-100 gauge scale.

**Recommended fix:**

Wrap the SizedBox in Semantics(label: 'Current noise level', value: '${currentDb.toStringAsFixed(0)} decibels out of ${maxDb.toStringAsFixed(0)}', liveRegion: false) and ExcludeSemantics the inner duplicated Text/CustomPaint children (or use MergeSemantics).

---

#### [a11y-7] Sync status indicator tap target is roughly 34x26dp and lacks a button role

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/sync_status_indicator.dart:101`

**Description:**

The tappable area is a GestureDetector around a Container with EdgeInsets.symmetric(horizontal: 8, vertical: 4) holding an 18px icon (lines 101-130) — about 34x26dp, far below the 48x48dp minimum. It opens the sync-status dialog on tap, but the Tooltip only provides a label; there is no button role and no minimum-size constraint. It appears in the Dashboard app bar and floats over the map (map_view_screen.dart line 611-615).

**Failure scenario:**

A user with motor impairment (or anyone on a bumpy bus) tries to tap the tiny cloud icon to trigger a manual sync of queued offline recordings; they repeatedly miss the ~34x26dp target, and the pending recordings stay unsynced.

**Recommended fix:**

Replace the GestureDetector with an IconButton (default 48dp constraint) or wrap in ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48)) plus Semantics(button: true), keeping the existing tooltipText as the label.

---

#### [a11y-13] Settings switches are not semantically associated with their text labels

**Severity:** Medium | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:454`

**Description:**

_buildSwitchSetting (lines 436-462) lays out Icon + Text + Switch as separate Row children. The Switch (line 454) therefore creates its own semantics node with no label — screen readers announce just 'switch, on' — while the label text is a separate, non-interactive node. Only the small Switch thumb (not the whole row) is tappable. Contrast with heatmap_settings_panel.dart:128 which correctly uses SwitchListTile.

**Failure scenario:**

A TalkBack user swipes through Settings and hears 'Anonymize Location' ... 'switch, off' ... 'Share Data with Researchers' ... 'switch, on' as four separate stops; with eight switches on screen it is easy to toggle 'Share Data with Researchers' while believing they toggled the privacy switch above it.

**Recommended fix:**

Replace the Row with SwitchListTile(title: Text(title), secondary: Icon(icon), value: value, onChanged: onChanged) or wrap the Row in MergeSemantics; this also makes the full row tappable.

---

### Low

#### [a11y-26] Location pill and community feed card are tappable GestureDetectors with no button role or action hint

**Severity:** Low | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/dashboard_screen.dart:752`

**Description:**

The location pill (GestureDetector, lines 752-820) refreshes GPS on tap, hinted only by a 14px refresh glyph, and the Community Feed card (GestureDetector, lines 919-1017) navigates on tap. Both contain readable text (so they are not silent like the icon-only cases) but expose no button role, so AT gives no 'double tap to activate' affordance context, and the 14px refresh icon is the only visual cue for the refresh behavior. Report screen's equivalent uses InkWell (report_noise_screen.dart:510) which at least ripples, but likewise lacks a role/label ('refresh location').

**Failure scenario:**

A TalkBack user hears 'Colombo' announced as plain text on the Dashboard and has no indication that double-tapping it would re-fetch their GPS location; sighted users routinely miss the refresh affordance because the icon is 14px.

**Recommended fix:**

Wrap both in Semantics(button: true) with labels ('Current location Colombo, double tap to refresh' / 'Open community feed, 12 reports today'), and prefer InkWell over GestureDetector for visual feedback.

---

#### [a11y-14] Sliders announce percentages instead of their real units (seconds / dB)

**Severity:** Low | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:495`

**Description:**

The three settings sliders (line 495-505: Recording Duration 1-60s, Save Frequency 5-30s, Alert Threshold 50-100 dB) and the manual report slider (report_noise_screen.dart:313-325, 0-120 dB) set no label or semanticFormatterCallback, so Flutter announces the default percentage of the track (e.g. '40%') rather than '70 decibels'. The visual value text is a separate node not merged with the slider.

**Failure scenario:**

A screen-reader user sets the Alert Threshold: while dragging they hear '52%', '54%'... and must stop, swipe away to the value text, and swipe back to learn the actual dB value — for the 50-100 range, '0%' actually means 50 dB, which is actively misleading.

**Recommended fix:**

Add semanticFormatterCallback: (v) => '${v.toInt()} $unit' (and label: '${value.toInt()} $unit') to each Slider, and wrap the title+value+slider column in MergeSemantics so the name travels with the control.

---

#### [a11y-8] Heatmap FAB and map location FAB have no tooltip; heatmap toggle state not exposed

**Severity:** Low | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/heatmap_fab.dart:21`

**Description:**

HeatmapFab's FloatingActionButton (line 21) has no tooltip and its Icon(Icons.terrain) no semanticLabel, so it announces as an unlabeled button; its on/off state (showHeatmap) is conveyed only by background color. The 'my location' FAB in map_view_screen.dart line 1059-1067 also lacks a tooltip.

**Failure scenario:**

A TalkBack user on the Map screen finds two unlabeled floating buttons in the bottom-right; activating the first silently toggles a heatmap they cannot perceive, with no announcement of what happened or the current toggle state.

**Recommended fix:**

Add tooltip: showHeatmap ? 'Hide noise heatmap' : 'Show noise heatmap' to HeatmapFab and tooltip: 'Go to my location' to the location FAB; optionally wrap HeatmapFab in Semantics(toggled: showHeatmap).

---

#### [a11y-20] Edit-profile hint text at 30% alpha is ~1.5:1 contrast in both themes

**Severity:** Low | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/screens/edit_profile_screen.dart:264`

**Description:**

Both fields set hintStyle with getSecondaryTextColor(context).withValues(alpha: 0.3) (lines 264 and 315). Composited over the card fill this yields roughly #D3D3D3 on white (~1.5:1) in light mode and a similarly faint result in dark mode (~1.9:1) — far below the 4.5:1 minimum for placeholder-weight text. Since the fields are pre-populated the hints matter most when a user clears a field to retype.

**Failure scenario:**

A low-vision user clears the email field to enter a new address: the 'Enter your email' placeholder is nearly invisible, so with two identical-looking empty rounded boxes they cannot tell which field is name and which is email (the section captions sit above, visually detached).

**Recommended fix:**

Drop the .withValues(alpha: 0.3) and use ThemeHelper.getSecondaryTextColor(context) directly for hintStyle (as login/search screens already do), or add labelText to the InputDecorations.

---

#### [a11y-22] Inactive nav icons at 50% white on primary color are ~2.2:1 in light mode

**Severity:** Low | **Status:** unverified | **Category:** accessibility | **Effort:** S

**Location:** `lib/widgets/shared_bottom_navbar.dart:66`

**Description:**

Inactive tab icons use Colors.white.withValues(alpha: 0.5) over the primary-color bar in light mode (lines 66-70). White@50% composited on #6C63FF is ~2.2:1 against the bar — below the 3:1 WCAG minimum for meaningful UI graphics — and drops further with lighter user-selected theme colors (e.g. the Orange #FF9800 theme option).

**Failure scenario:**

A low-vision user in light mode with the default purple theme looks at the bottom bar to find Settings: the four inactive icons are ghostly white-on-purple and hard to distinguish from the bar itself, especially with the lighter Orange or Green theme colors selected.

**Recommended fix:**

Raise inactive alpha to ~0.75-0.8 (white@75% on #6C63FF ≈ 3.2:1) or use a solid lighter tint of the bar color; verify against every entry in AppTheme.themeColors since primary is user-selectable.

---

### Enhancement

#### [a11y-25] Animations ignore the system reduce-motion / disable-animations setting

**Severity:** Enhancement | **Status:** unverified | **Category:** accessibility | **Effort:** M

**Location:** `lib/utils/animations.dart:313`

**Description:**

None of the animation utilities check MediaQuery.disableAnimationsOf(context) or accessibleNavigation: PulseAnimation repeats indefinitely (lines 313-357), ShimmerLoading loops at 1.5s (lines 238-309), FadeInListItem slides every history row in (used per-item in history_screen.dart:458), and page routes always animate 300-400ms. The splash screen also forces a 3s animated delay (splash_screen.dart:36).

**Failure scenario:**

A user with vestibular sensitivity enables 'Remove animations' in Android accessibility settings, then scrolls History: every list item still slides and fades in, and looping pulse/shimmer effects continue — the OS-level preference has no effect anywhere in the app.

**Recommended fix:**

In each animated widget's build, short-circuit when MediaQuery.disableAnimationsOf(context) is true (render the final state immediately, stop repeating controllers), and pick zero-duration page transitions under the same flag.

---

## Quick Wins (under 1 hour each)

- [ ] **a11y-26** - Location pill and community feed card are tappable GestureDetectors with no button role or action hint (`lib/screens/dashboard_screen.dart:752`)
- [ ] **a11y-17** - Hardcoded AppTheme.textGray on light backgrounds yields ~1.8:1 contrast (`lib/screens/dashboard_screen.dart:875`)
- [ ] **a11y-11** - Custom filter chips (period, sound type, donation amounts) expose no selected state or button role (`lib/screens/analytics_screen.dart:488`)
- [ ] **a11y-4** - Noise history LineChart has no semantic alternative — invisible to screen readers (`lib/widgets/noise_history_chart.dart:31`)
- [ ] **a11y-14** - Sliders announce percentages instead of their real units (seconds / dB) (`lib/screens/settings_screen_enhanced.dart:495`)
- [ ] **a11y-2** - Primary record/stop button is an unlabeled GestureDetector; recording state changes are never announced (`lib/screens/dashboard_screen.dart:836`)
- [ ] **a11y-18** - Classification badges use Colors.red[300]/green[300] text — ~2.9:1 / ~1.9:1 in light mode (`lib/screens/history_screen.dart:613`)
- [ ] **a11y-15** - Login fields have no labels — password field's only accessible name is bullet characters (`lib/screens/login_screen.dart:146`)
- [ ] **a11y-8** - Heatmap FAB and map location FAB have no tooltip; heatmap toggle state not exposed (`lib/widgets/heatmap_fab.dart:21`)
- [ ] **a11y-23** - Two-line AppBar title Columns overflow the fixed 56dp toolbar at large text scale (`lib/screens/history_screen.dart:358`)
- [ ] **a11y-9** - Multiple IconButtons across screens have no tooltip/label — including the destructive per-item delete (`lib/screens/history_screen.dart:644`)
- [ ] **a11y-10** - Search-history icon in map search bar is a bare 24px GestureDetector (`lib/screens/map_view_screen.dart:937`)
- [ ] **a11y-16** - AnimatedButton (login/registration submit) is a GestureDetector with no button role or disabled state (`lib/utils/animations.dart:150`)
- [ ] **a11y-1** - Bottom navigation is icon-only with no labels, roles, or selected-state semantics (`lib/widgets/shared_bottom_navbar.dart:57`)
- [ ] **a11y-21** - Guide tile YAMNet info text rendered in raw category color — yellow on near-white is ~1.1:1 (`lib/widgets/classification_guide_widget.dart:142`)
- [ ] **a11y-20** - Edit-profile hint text at 30% alpha is ~1.5:1 contrast in both themes (`lib/screens/edit_profile_screen.dart:264`)
- [ ] **a11y-12** - dBA/dBC and Fast/Slow segmented toggles are ~36dp tall unlabeled GestureDetectors (`lib/screens/settings_screen_enhanced.dart:409`)
- [ ] **a11y-3** - Decibel gauge (CustomPaint) has no semantic representation of the reading (`lib/widgets/decibel_meter_gauge.dart:19`)
- [ ] **a11y-22** - Inactive nav icons at 50% white on primary color are ~2.2:1 in light mode (`lib/widgets/shared_bottom_navbar.dart:66`)
- [ ] **a11y-7** - Sync status indicator tap target is roughly 34x26dp and lacks a button role (`lib/widgets/sync_status_indicator.dart:101`)
- [ ] **a11y-13** - Settings switches are not semantically associated with their text labels (`lib/screens/settings_screen_enhanced.dart:454`)
