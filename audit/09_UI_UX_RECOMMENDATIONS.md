# UI/UX Recommendations - Noise Pollution Mapper

> Generated 2026-07-13. These are PROACTIVE improvement recommendations produced by a multi-agent research pass, complementary to the defect audits (docs 01-08) in this folder. Each is grounded in the current code; implement the related bug fixes first where they overlap. Total: 68 recommendations.

## Executive Summary

This document collects 68 UI/UX enhancement recommendations across five areas: the core recording and map experience, the data screens (analytics, history, feed, reporting), first-run and account surfaces, the design system, and motion/micro-interactions. The highest-leverage themes: (1) close the loop after recording with a session-summary card and instant classification feedback; (2) make the decibel gauge and history chart legible with zone-banded color and status words; (3) build a single dB-level semantic color scale and a small reusable component library (AppCard, StatTile, EmptyState) to replace ad-hoc styling repeated across screens; (4) teach the record-classify-map value loop with an interactive onboarding and permission priming; (5) add a coherent haptic + motion vocabulary that respects reduced-motion.

**Best impact-to-effort (High impact, Small effort) - do these first:**

- **Insight callout card: quietest/loudest hour and day** (analytics_screen.dart)
- **Compute on-colors instead of hardcoding white text on primary-colored surfaces** (Contrast / accessibility)
- **App-wide haptic vocabulary: threshold crossing, save success, nav taps** (lib/screens/dashboard_screen.dart, lib/screens/report_noise_screen.dart, lib/widgets/shared_bottom_navbar.dart)
- **Ship Forgot Password as a prefilled reset bottom sheet** (Login)
- **Enable password-manager autofill and keyboard flow on all auth forms** (Login / Registration / Profile)
- **Make the report dB slider self-explanatory with live category label and color** (report_noise_screen.dart)
- **Skip onboarding for returning users and shorten the fixed 3-second splash** (Splash / First-run)

## Priority Matrix

| # | Impact | Effort | Recommendation | Area |
|---|--------|--------|----------------|------|
| 1 | High | S | Insight callout card: quietest/loudest hour and day | analytics_screen.dart |
| 2 | High | S | Compute on-colors instead of hardcoding white text on primary-colored surfaces | Contrast / accessibility |
| 3 | High | S | App-wide haptic vocabulary: threshold crossing, save success, nav taps | lib/screens/dashboard_screen.dart, lib/screens/report_noise_screen.dart, lib/widgets/shared_bottom_navbar.dart |
| 4 | High | S | Ship Forgot Password as a prefilled reset bottom sheet | Login |
| 5 | High | S | Enable password-manager autofill and keyboard flow on all auth forms | Login / Registration / Profile |
| 6 | High | S | Make the report dB slider self-explanatory with live category label and color | report_noise_screen.dart |
| 7 | High | S | Skip onboarding for returning users and shorten the fixed 3-second splash | Splash / First-run |
| 8 | High | M | Add previous-period comparison deltas to analytics stat cards | analytics_screen.dart |
| 9 | High | M | Single source of truth for the dB semantic color scale via a NoiseColors ThemeExtension | Design tokens / dB color scale |
| 10 | High | M | Zone-banded gauge scale with status word | Gauge legibility (decibel_meter_gauge.dart) |
| 11 | High | M | Group history by day with sticky date headers | history_screen.dart |
| 12 | High | M | Recording pulse rings and start/stop haptics on the record button | lib/screens/dashboard_screen.dart |
| 13 | High | M | Spring-physics needle and smoothed readout on the decibel gauge | lib/widgets/decibel_meter_gauge.dart, lib/screens/dashboard_screen.dart |
| 14 | High | M | Time-range filter chips on the map | Map information design (map_view_screen.dart + heatmap_service.dart) |
| 15 | High | M | Map legend + data freshness chip | Map information design (map_view_screen.dart) |
| 16 | High | M | Reading detail sheet: add timestamp, zone framing, and actions | Map tap-through (map_view_screen.dart) |
| 17 | High | M | Bottom-anchored, always-reachable record control | One-handed reachability (dashboard_screen.dart) |
| 18 | High | M | Add permission priming screens before the mic and location OS dialogs | Permissions / First-run |
| 19 | High | M | Post-recording session summary card | Recording ritual (dashboard_screen.dart) |
| 20 | High | M | Replace the 17-item sound-class dropdown with a grouped chip grid | report_noise_screen.dart |
| 21 | High | M | Generate full Material 3 ColorSchemes with ColorScheme.fromSeed for the 8 user-selectable theme colors | Theming / Material 3 adoption |
| 22 | High | L | Extract a small design-system component library: AppCard, StatTile, SectionHeader, EmptyState, AppChipRow | Component library |
| 23 | High | L | Teach the record -> classify -> map value loop with an interactive onboarding walkthrough | Onboarding |
| 24 | Medium | S | Scope the sound-type filter chips to the sections they actually filter | analytics_screen.dart |
| 25 | Medium | S | Annotate the trend chart: WHO guideline line and time-aware tooltips | analytics_screen.dart |
| 26 | Medium | S | History chart: threshold line, zone coloring, and axis context | Chart legibility (noise_history_chart.dart) |
| 27 | Medium | S | Dark-mode tone variants for status/severity colors (one palette for the Pollution/Ambient badge) | Dark-mode contrast tuning |
| 28 | Medium | S | Skeleton rows for history initial load | history_screen.dart |
| 29 | Medium | S | Entrance/exit choreography for the live sound-classification card | lib/screens/dashboard_screen.dart |
| 30 | Medium | S | Animated count-up numbers for dashboard MIN/AVG/MAX and analytics stat grid | lib/screens/dashboard_screen.dart, lib/screens/analytics_screen.dart, lib/utils/animations.dart |
| 31 | Medium | S | Respect reduced-motion: a Motion helper gating all repeating and decorative animation | lib/utils/animations.dart (new helper), all animated widgets |
| 32 | Medium | S | Fix the stagger curve and extend list entrance animation to Community Feed | lib/utils/animations.dart, lib/screens/history_screen.dart, lib/screens/community_feed_screen.dart |
| 33 | Medium | S | Motion tokens, one theme-level page transition, and reduced-motion support | Motion / animations |
| 34 | Medium | S | Move logout out of the AppBar's prime position | One-handed reachability / error prevention (dashboard_screen.dart) |
| 35 | Medium | S | Instant classification feedback with a 'listening' placeholder | Recording ritual (dashboard_screen.dart) |
| 36 | Medium | S | Live recording feedback: elapsed timer and dB-driven pulse | Recording ritual (dashboard_screen.dart) |
| 37 | Medium | S | Live password strength meter on registration and change-password | Registration / Settings |
| 38 | Medium | S | Make default-location submissions explicit on the report form | report_noise_screen.dart |
| 39 | Medium | M | Replace analytics full-screen spinner with skeleton layout and add pull-to-refresh | analytics_screen.dart |
| 40 | Medium | M | Feed cards: surface sound classification and make cards tappable to the map | community_feed_screen.dart |
| 41 | Medium | M | Explicit token scale for spacing, radius, and icon sizes | Design tokens |
| 42 | Medium | M | Profile avatar upload â€” photoURL is modeled but never populated | Edit Profile |
| 43 | Medium | M | Semantic feedback tokens + one AppSnackBar helper to replace 75 ad-hoc SnackBars | Feedback / status colors |
| 44 | Medium | M | Needle smoothing, peak-hold marker, and repaint hygiene | Gauge legibility (decibel_meter_gauge.dart) |
| 45 | Medium | M | Make the Classification Guide reachable from the live classification card | Guide discoverability |
| 46 | Medium | M | Progressive disclosure for heatmap controls: tap toggles, long-press configures | Heatmap controls (heatmap_fab.dart + heatmap_settings_panel.dart) |
| 47 | Medium | M | Swipe-to-delete with undo instead of per-row delete icon + dialog | history_screen.dart |
| 48 | Medium | M | Draw-in animation for the analytics trend line and pie chart | lib/screens/analytics_screen.dart, lib/widgets/noise_history_chart.dart |
| 49 | Medium | M | Skeleton shimmer loading states for History list and Analytics (the ShimmerLoading widget already exists) | lib/screens/history_screen.dart, lib/screens/analytics_screen.dart, lib/utils/animations.dart |
| 50 | Medium | M | Live-reacting waveform and graded slider feedback on the manual report screen | lib/screens/report_noise_screen.dart |
| 51 | Medium | M | Cross-fade tab switches in MainAppShell and animate the bottom-nav active state | lib/widgets/main_app_shell.dart, lib/widgets/shared_bottom_navbar.dart |
| 52 | Medium | M | Give the login 'OR' divider a purpose: Google sign-in | Login |
| 53 | Medium | M | Cluster labels that carry noise information | Map information design (map_view_screen.dart) |
| 54 | Medium | M | Adopt M3 selection and button components: SegmentedButton for period filters, FilledButton hierarchy, themed chips | Material 3 adoption / components |
| 55 | Medium | M | Pre-roll countdown and optional timed measurement | Recording ritual (dashboard_screen.dart) |
| 56 | Medium | M | Regroup settings by domain, disable dependent toggles, and show current values on navigation rows | Settings |
| 57 | Medium | M | Replace the Change Password AlertDialog with a proper validated form | Settings / Account |
| 58 | Medium | M | Delete Account: re-authenticate in-flow instead of dead-ending on requires-recent-login | Settings / Account |
| 59 | Medium | M | Repoint ThemeHelper at ColorScheme roles (and fix theme-blind widgets like the gauge needle) | Theming architecture |
| 60 | Medium | L | Paginate the community feed and replace the fake pull-to-refresh | community_feed_screen.dart |
| 61 | Medium | L | Full Material 3 typography ramp; retire raw fontSize TextStyles | Typography |
| 62 | Low | S | Donation: put the amount on the CTA, validate inline, and check config upfront | Donation |
| 63 | Low | S | Edit Profile: keep the form visible while saving instead of a full-screen spinner swap | Edit Profile |
| 64 | Low | S | Pagination affordances: end-of-list marker and load-more error retry | history_screen.dart |
| 65 | Low | S | Equalizer-bounce splash logo instead of static bars | lib/screens/splash_screen.dart |
| 66 | Low | S | AnimatedSwitcher state changes and success pop on the sync status indicator | lib/widgets/sync_status_indicator.dart |
| 67 | Low | S | Delete the dead duplicate themes and demo widget; memoize generated ThemeData | Theme code health / performance |
| 68 | Low | M | Hero transitions: History FAB into Report screen, Dashboard community card into Community Feed | lib/screens/history_screen.dart, lib/screens/report_noise_screen.dart, lib/screens/dashboard_screen.dart, lib/screens/community_feed_screen.dart |

## Detailed Recommendations

### 1. Insight callout card: quietest/loudest hour and day

**Impact:** High | **Effort:** S | **Area:** analytics_screen.dart

**Today:**

All aggregation needed for insights already happens: _buildTimeAggregatedSpots (lib/screens/analytics_screen.dart:184-226) buckets readings by hour (Daily) or day (Weekly/Monthly) and averages dB per bucket â€” then only feeds it to the line chart. The user must eyeball the curve to find patterns; nothing states them.

**Proposal:**

Above the trend chart, add one or two auto-generated insight lines: 'Quietest hour: 3 AM (34 dB avg)' / 'Loudest day: Friday (78 dB avg)' plus a pollution-share insight from the already-computed _pollutionCount/_ambientCount ('61% of your readings were pollution sounds'). Insight callouts are the cheapest form of chart storytelling â€” near-zero query cost since the data is already in memory, and they make the analytics screen feel intelligent.

**How:**

In the trend chart's StreamBuilder (after line 1021 where spots are built), find min/max spots: quietest = spots.reduce((a,b) => a.y < b.y ? a : b). Map spot.x back to a label with the same math _getXAxisWidget uses (lines 236-257). Render a small Row of insight pills (lightbulb icon + text, primaryColor.withValues(alpha: 0.08) background matching the context banner style at 390-396). Guard with spots.length >= 3 so a single reading doesn't produce a silly 'insight'.

---

### 2. Compute on-colors instead of hardcoding white text on primary-colored surfaces

**Impact:** High | **Effort:** S | **Area:** Contrast / accessibility

**Today:**

ThemeHelper.getButtonTextColor always returns Colors.white with the comment 'Always white on colored buttons for contrast' (lib/utils/theme_helper.dart:53-55), and the light theme AppBar paints the user-selected primary color behind a white bold title (lib/theme/app_theme.dart:141-149). The theme picker offers Orange #FF9800 (app_theme.dart:33); white on #FF9800 is roughly 2.1:1 â€” well below WCAG AA 4.5:1 â€” so choosing the Orange or Green themes makes every button label and the app bar title hard to read in light mode. The light-mode bottom navbar has the same issue: inactive icons are white at 50% alpha on the primary color (lib/widgets/shared_bottom_navbar.dart:66-70).

**Proposal:**

Let the color system decide the on-color. With the fromSeed migration this is free (`scheme.onPrimary` is guaranteed accessible); without it, compute per-color. Buttons, app bar titles, and navbar icons stay legible for all 8 selectable theme colors, which matters because theme color choice is a headline personalization feature of the app.

**How:**

Replace getButtonTextColor body with `Theme.of(context).colorScheme.onPrimary`. If staying pre-seed for a while, use `ThemeData.estimateBrightnessForColor(primary) == Brightness.dark ? Colors.white : Colors.black87`. In generateLightTheme, set `appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, titleTextStyle: TextStyle(color: scheme.onPrimary, ...))`. In SharedBottomNavBar use `onPrimary` / `onPrimary.withValues(alpha: 0.7)` for active/inactive.

---

### 3. App-wide haptic vocabulary: threshold crossing, save success, nav taps

**Impact:** High | **Effort:** S | **Area:** lib/screens/dashboard_screen.dart, lib/screens/report_noise_screen.dart, lib/widgets/shared_bottom_navbar.dart

**Today:**

grep for HapticFeedback across lib/ returns zero matches â€” no interaction in the app produces tactile feedback. Three verified moments that should: (1) the >70 dB high-noise threshold crossing fires only a system notification (dashboard_screen.dart:428-432); (2) successful manual report submission shows only a green SnackBar (report_noise_screen.dart:234-243); (3) bottom-nav tab taps (shared_bottom_navbar.dart:57 InkWell, :82 GestureDetector) and analytics period/filter chip taps (analytics_screen.dart:488-495) are silent.

**Proposal:**

Introduce a small, consistent haptic vocabulary â€” this is the highest polish-per-line-of-code available in Flutter and is especially apt for a noise app: the phone physically reacting when sound crosses the danger threshold closes the loop between what the mic hears and what the user feels (works even when the phone is in a pocket, unlike the gauge). Success haptic on save makes the contribution feel acknowledged; selection ticks make navigation feel native.

**How:**

import 'package:flutter/services.dart' where needed. Dashboard threshold block (inside the existing _hasShownHighNoiseAlert guard at :428): HapticFeedback.heavyImpact() â€” the guard already debounces to once per session, so no buzz spam. report_noise_screen _submitReport success path (:234): HapticFeedback.mediumImpact() before showing the SnackBar; error path: HapticFeedback.vibrate(). SharedBottomNavBar onTap handlers (:57, :82): HapticFeedback.selectionClick(). Analytics chips (:489): selectionClick(). Optionally define an AppHaptics class (static success()/warning()/tick() methods) in lib/utils/ so the vocabulary stays consistent and can be disabled from settings later.

---

### 4. Ship Forgot Password as a prefilled reset bottom sheet

**Impact:** High | **Effort:** S | **Area:** Login

**Today:**

lib/screens/login_screen.dart:237-245: the 'Forgot Password?' button shows a SnackBar reading 'Forgot password feature coming soon!' (TODO comment at line 239). A user who mistypes their password has no recovery path other than abandoning the app.

**Proposal:**

Implement the real flow: tapping Forgot Password opens a bottom sheet with the email field prefilled from the login form's _emailController, a single Send button, and a success state ('If an account exists, a reset link was sent â€” check your inbox'). Password reset is the highest-volume auth support request in any consumer app, and Firebase makes it a one-call feature â€” this converts locked-out users back into active ones at near-zero cost.

**How:**

showModalBottomSheet with one TextFormField (initialValue: _emailController.text.trim(), autofillHints: [AutofillHints.email]) and a loading-aware button calling await FirebaseAuth.instance.sendPasswordResetEmail(email: email). Show the same generic success copy for user-not-found to avoid account enumeration. Roughly 60 lines in login_screen.dart.

---

### 5. Enable password-manager autofill and keyboard flow on all auth forms

**Impact:** High | **Effort:** S | **Area:** Login / Registration / Profile

**Today:**

No text field on any auth surface declares autofill metadata: lib/screens/login_screen.dart:141-203 (email + password), lib/screens/registration_screen.dart:200-380 (name, email, password, confirm), and lib/screens/edit_profile_screen.dart:259-347 all lack autofillHints, textInputAction, and onFieldSubmitted; there is no AutofillGroup anywhere. Result: Google/Apple/1Password never offer to fill or save credentials, and users must manually tap between fields and then hunt for the submit button.

**Proposal:**

Wrap each Form in AutofillGroup and tag fields with AutofillHints (email, password on login; name, email, newPassword on registration). Add textInputAction: TextInputAction.next/done and onFieldSubmitted chaining so Enter advances fields and submits the form. This is the single cheapest friction cut on the whole first-run funnel â€” returning users get one-tap credential fill, and new users get a save-password prompt so they never hit the (stubbed) forgot-password path.

**How:**

AutofillGroup(child: Form(...)); login email: autofillHints: const [AutofillHints.email], textInputAction: TextInputAction.next; login password: const [AutofillHints.password], textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _handleLogin(); registration passwords: const [AutofillHints.newPassword]. After successful registration call TextInput.finishAutofillContext() so the OS prompts to save the new credential. Pure Flutter SDK, no packages.

---

### 6. Make the report dB slider self-explanatory with live category label and color

**Impact:** High | **Effort:** S | **Area:** report_noise_screen.dart

**Today:**

The manual-entry card shows '${_manualDb.toInt()} dB' in plain theme text color (lib/screens/report_noise_screen.dart:294-301) over a 0-120 slider whose only anchors are '0 dB' and '120 dB' labels (328-334). Non-expert users have no idea whether 65 dB is loud; every other screen (history_screen.dart:507-514, community_feed_screen.dart:18-29) color-codes dB, but the input screen doesn't.

**Proposal:**

As the slider moves, color the big dB number with the app's existing low/moderate/high palette and show a live descriptor with a real-world reference: 'Moderate â€” busy office / normal conversation' at 60, 'High â€” heavy traffic, prolonged exposure harmful' at 85. Users submit more accurate readings and learn the scale, which improves community data quality.

**How:**

Reuse the exact thresholds from history: Color dbColor = db<50 ? AppTheme.lowNoise : db<70 ? AppTheme.moderateNoise : AppTheme.highNoise. Add a const list of (min, label, example) tuples â€” e.g. (0,'Quiet','library, whisper'), (50,'Moderate','conversation, office'), (70,'Loud','traffic, vacuum'), (90,'Very loud','tuk-tuk horn, construction'), (110,'Painful','sirens, concerts') â€” and look up by _manualDb. Apply dbColor to the 48px Text and to Slider.activeColor (line 318). Optionally add HapticFeedback.selectionClick() when crossing a threshold. Pure UI, no data changes.

---

### 7. Skip onboarding for returning users and shorten the fixed 3-second splash

**Impact:** High | **Effort:** S | **Area:** Splash / First-run

**Today:**

lib/screens/splash_screen.dart:36-42 hard-codes Timer(Duration(seconds: 3)) then always pushes OnboardingScreen â€” no 'seen onboarding' flag is ever written, so every signed-out launch replays splash (3s) -> onboarding -> login. Worse, lib/main.dart:150-173 already shows its own spinner while authStateChanges resolves, so signed-out users sit through two consecutive waiting states before doing anything.

**Proposal:**

Persist an onboarding_complete flag when 'Get started' is tapped, and have the splash route directly to LoginScreen when the flag is set. Cut the splash to ~1.2s (the fade animation is 1.5s anyway, splash_screen.dart:24). Returning signed-out users reach the login form roughly 2+ seconds faster on every launch, and the walkthrough (recommendation 1) stays a genuine first-run experience instead of a recurring toll.

**How:**

In OnboardingScreen's Get Started handler (onboarding_screen.dart:37-41): (await SharedPreferences.getInstance()).setBool('onboarding_complete', true). In splash: read the flag during initState, Timer(const Duration(milliseconds: 1200), ...) navigating to seen ? LoginScreen : OnboardingScreen. SharedPreferences is already imported app-wide.

---

### 8. Add previous-period comparison deltas to analytics stat cards

**Impact:** High | **Effort:** M | **Area:** analytics_screen.dart

**Today:**

The stat grid (lib/screens/analytics_screen.dart:359-375, _buildStatCard 1127-1157) shows Average/Lowest/Highest/Duration as bare numbers for the selected period. There is no baseline: a user seeing 'Average 62 dB' has no idea if their environment is getting louder or quieter â€” the core question a personal noise tracker exists to answer.

**Proposal:**

Fetch the same stats for the preceding window (e.g. Weekly selected -> the 7 days before the current 7) and render a delta chip on each card: '+4 dB vs last week' in highNoise red when louder, lowNoise green when quieter. This turns static numbers into a trend story and gives users a reason to return weekly.

**How:**

Add FirebaseService.calculateStatsBetween(DateTime start, DateTime end) mirroring calculateStatsByPeriod (firebase_service.dart:283) but with .where('timestamp', isGreaterThan: start).where('timestamp', isLessThan: end) â€” both filters are on the orderBy field, so the existing (userId ASC, timestamp DESC) composite index still serves it; do NOT add new inequality fields. In _loadStatistics (analytics_screen.dart:81) compute prevSince = since.subtract(since-to-now duration), await both stats in Future.wait, store _prevAvgDb etc. Extend _buildStatCard with an optional double? delta and render Row(Icon(delta>0?Icons.arrow_upward:Icons.arrow_downward), Text('${delta.abs().toStringAsFixed(0)} dB vs prior')). Hide the chip when previous period has count==0.

---

### 9. Single source of truth for the dB semantic color scale via a NoiseColors ThemeExtension

**Impact:** High | **Effort:** M | **Area:** Design tokens / dB color scale

**Today:**

The db-to-color mapping `if (db < 50) low; else if (db < 70) moderate; else high` is copy-pasted at least six times: lib/screens/map_view_screen.dart:1285-1287 and again for clusters at :704-710, lib/screens/community_feed_screen.dart:19-21, lib/screens/history_screen.dart:508-514, lib/screens/search_list_screen.dart:570-579, lib/widgets/decibel_meter_gauge.dart:177-185. Meanwhile the heatmap painter defines a DIFFERENT 4-tier scale with a yellow band that exists nowhere else in the app (lib/screens/map_view_screen.dart:1429-1434: green <50, yellow 50-70, orange 70-85, red >85), so the heatmap and the markers on the same map screen disagree about what 65 dB looks like (orange marker, yellow heat blob).

**Proposal:**

Define one `NoiseLevel` enum (quiet/moderate/loud/dangerous) with a `NoiseLevel.fromDb(double)` factory holding the thresholds, and a `NoiseColors` ThemeExtension carrying the color for each level (plus container/onContainer tints). Every consumer â€” gauge, map markers, cluster pins, heatmap gradient + legend, history rows, search city cards, analytics stat cards â€” reads the same scale. Users get an identical color language across all five surfaces, and re-tuning thresholds to WHO noise bands later becomes a one-line change instead of a six-file hunt.

**How:**

Create lib/theme/noise_colors.dart: `class NoiseColors extends ThemeExtension<NoiseColors> { final Color quiet, moderate, loud, dangerous; Color forDb(double db) => forLevel(NoiseLevel.fromDb(db)); ... copyWith/lerp }`. Register it in both `generateDarkTheme`/`generateLightTheme` via `extensions: [NoiseColors.dark(...)]`. Consumers call `Theme.of(context).extension<NoiseColors>()!.forDb(db)`. Rebuild the heatmap `_gradientColors` map and its legend from the same extension so the two can never diverge. Delete the six local mappings.

---

### 10. Zone-banded gauge scale with status word

**Impact:** High | **Effort:** M | **Area:** Gauge legibility (decibel_meter_gauge.dart)

**Today:**

The gauge arc is a purple-to-purple sweep gradient whose final stop is the zone color (lib/widgets/decibel_meter_gauge.dart:93-105), so green/orange/red only tint the very tip of the arc; the scale itself carries no zone information. Ticks are at 0/25/50/75/100 (line 136), which do not align with the app's actual thresholds of 50 and 70 dB (_getDbColor, lines 177-185). The big 72pt number (lines 36-44) is always white/dark with no interpretation.

**Proposal:**

Paint the background track as three fixed colored zone segments (green 0-50, orange 50-70, red 70-100 at ~25% alpha), put ticks/labels at the meaningful boundaries (50, 70), color the big number with the current zone color, and add a status word under 'dB' ('Quiet' / 'Moderate' / 'Loud â€” harmful over time'). Users can then read at a glance both where they are and how far from the next threshold â€” the core job of a meter.

**How:**

In DecibelGaugePainter.paint, replace the single bgPaint circle (lines 85-90) with three canvas.drawArc calls using AppTheme.lowNoise/moderateNoise/highNoise .withValues(alpha: 0.25) over sweep fractions 0-0.5, 0.5-0.7, 0.7-1.0 of the 270-degree range. Keep the progress arc but drop the SweepGradient for a solid _getDbColor(currentDb) stroke. In DecibelMeterGauge, wrap the number's TextStyle color in _getDbColor and add a Text status line mapped from the same thresholds so gauge, markers, and heatmap all speak one color language.

---

### 11. Group history by day with sticky date headers

**Impact:** High | **Effort:** M | **Area:** history_screen.dart

**Today:**

History renders a flat ListView.builder (lib/screens/history_screen.dart:432-472) where every card repeats the full date string 'MMM dd, yyyy â€¢ hh:mm a' (line 566). Scanning 50+ rows means re-reading the same date dozens of times, and there is no visual anchor when fast-scrolling through pages of readings.

**Proposal:**

Group recordings under day headers ('Today', 'Yesterday', 'Jul 10') that stick to the top while scrolling, and show only the time on each row. This is the single biggest scanability win for a paginated 50-per-page list: users orient by day, and each row drops ~20 characters of redundant text. Pair each header with a per-day mini-summary (count + avg dB) to give history the same storytelling as analytics.

**How:**

Build a List<Object> of alternating DayHeader/DocumentSnapshot items from _recordings (already sorted timestamp DESC by getUserReadingsPaginated, firebase_service.dart:214-230), regenerated in setState after each page load. Render with CustomScrollView + SliverMainAxisGroup + SliverPersistentHeader(pinned: true) per day group (pure Flutter, no package), or add flutter_sticky_header. Header label helper: DateUtils.isSameDay(ts, now) ? 'Today' : DateUtils.isSameDay(ts, yesterday) ? 'Yesterday' : DateFormat('EEE, MMM d').format(ts). In _buildHistoryItem change line 566 to DateFormat('hh:mm a'). Keep the existing _scrollController for infinite scroll â€” it works unchanged on CustomScrollView.

---

### 12. Recording pulse rings and start/stop haptics on the record button

**Impact:** High | **Effort:** M | **Area:** lib/screens/dashboard_screen.dart

**Today:**

The record button (dashboard_screen.dart:836-869) is a GestureDetector around an AnimatedContainer that only cross-fades gradient color and shadow over 300ms when _isRecording flips; while recording it sits completely still with the static caption 'Recording...' (:872-878). There is no haptic on tap. Meanwhile PulseAnimation exists unused in animations.dart:313-357.

**Proposal:**

Give the recording state a heartbeat: emanating ripple rings behind the button while recording (the universal 'mic is live' idiom, cf. voice assistants), a subtle breathing scale on the button itself, and tactile confirmation â€” medium impact haptic on start, light impact on stop. Users get glanceable + tactile certainty that measurement is running, which matters for a data-collection app where a dead mic means lost readings.

**How:**

Add a RecordingRipple widget near PulseAnimation in animations.dart: AnimationController(duration: 1500ms)..repeat(); paint 2 rings offset by 0.5 phase â€” for each, t = (controller.value + phase) % 1, draw a circle scaled 1.0 -> 1.8 with opacity (1 - t) in the recording red, using AnimatedBuilder + CustomPaint (or two ScaleTransition/FadeTransition pairs). Stack it behind the existing AnimatedContainer only when _isRecording. Wrap the mic/stop icon swap in AnimatedSwitcher(duration: 200ms, transitionBuilder: ScaleTransition). In onTap: HapticFeedback.mediumImpact() before _startRecording(), HapticFeedback.lightImpact() before _stopRecording() (import package:flutter/services.dart). Gate the repeat() behind the reduced-motion helper from the accessibility recommendation.

---

### 13. Spring-physics needle and smoothed readout on the decibel gauge

**Impact:** High | **Effort:** M | **Area:** lib/widgets/decibel_meter_gauge.dart, lib/screens/dashboard_screen.dart

**Today:**

DecibelMeterGauge is a StatelessWidget (decibel_meter_gauge.dart:6) that paints the needle angle directly from currentDb (NeedlePainter, :203-204) and renders the big digital number as plain Text of currentDb.toStringAsFixed(0) (:36-44). The dashboard pushes every raw noise_meter reading straight into it via setState (dashboard_screen.dart:385-439, gauge at :747), so the needle and the 72pt number teleport to each new value many times per second â€” the centerpiece of the app reads as jittery rather than instrument-like. Both painters also declare shouldRepaint => true (:188, :235), repainting even when nothing changed.

**Proposal:**

Make the needle behave like a physical VU meter: it should chase the live dB value with slight inertia and overshoot, and the digital readout should glide between values. This is the screen users stare at during every recording session, so smoothing here is the single most visible motion upgrade in the app. Bonus: pass the previous value to shouldRepaint so identical frames stop repainting.

**How:**

Two tiers. Tier 1 (30 min): wrap the whole gauge in TweenAnimationBuilder<double>(tween: Tween(end: currentDb), duration: 250ms, curve: Curves.easeOutCubic, builder: (_, db, __) => existing Stack with db) â€” TweenAnimationBuilder retargets mid-flight, so rapid stream updates chain smoothly, and the same interpolated value drives needle, arc, and Text so they stay in sync. Tier 2 (the 'spring' feel): convert to StatefulWidget with AnimationController.unbounded(vsync: this); on didUpdateWidget run _controller.animateWith(SpringSimulation(SpringDescription(mass: 1, stiffness: 170, damping: 14), _controller.value, widget.currentDb, velocity)) â€” an underdamped spring gives the analog-meter overshoot. In NeedlePainter/DecibelGaugePainter change shouldRepaint to oldDelegate.currentDb != currentDb || oldDelegate.isDark != isDark.

---

### 14. Time-range filter chips on the map

**Impact:** High | **Effort:** M | **Area:** Map information design (map_view_screen.dart + heatmap_service.dart)

**Today:**

The map always shows the latest 100 readings of all time (_kMapReadingLimit, lib/screens/map_view_screen.dart:42; query at lib/services/firebase_service.dart:174-180), so a month-old reading looks identical to one from five minutes ago. Meanwhile the plumbing for time filtering already exists and is dead code: HeatmapService.filterByTimeRange and getTimeRangePresets (lib/services/heatmap_service.dart:30-61) and FirebaseService.getNoiseReadingsForHeatmap with start/end params (lib/services/firebase_service.dart:183-202) have no callers (verified by grep).

**Proposal:**

Surface a horizontal row of time chips under the search bar â€” Today / Week / Month / All â€” that filters both markers and heatmap. Noise is inherently temporal (rush hour vs night); letting users scope the map to 'today' turns a static archive into a living picture and directly reuses code that was already written and tested.

**How:**

Add _selectedRange state; render a SingleChildScrollView(scrollDirection: horizontal) of ChoiceChips below the search Container (after line 968). On selection, either re-query via getNoiseReadingsForHeatmap(startTime: ...) or, cheaper, keep the raw snapshot and filter client-side with heatmapService.filterByTimeRange + rebuild markers from the filtered docs. Note the memory rule: the Firestore query must use isGreaterThan + orderBy descending to match the existing (userId, timestamp DESC) index constraints â€” the client-side filter path avoids index concerns entirely.

---

### 15. Map legend + data freshness chip

**Impact:** High | **Effort:** M | **Area:** Map information design (map_view_screen.dart)

**Today:**

The map shows four encodings with zero explanation: colored dB circles (_buildNoiseMarker, lib/screens/map_view_screen.dart:1080-1148), emoji classification badges (lines 1121-1145), colored cluster pins (builder at 681-736), and the heatmap gradient (HeatmapPainter._gradientColors, lines 1429-1434). There is also no indication of how fresh the data is â€” _loadNoiseMarkers (lines 123-156) fetches the latest 100 readings once at startup, and the only refresh path is a RefreshIndicator (lines 603-607) that is practically unreachable because FlutterMap consumes vertical drags.

**Proposal:**

Add a compact, collapsible legend card (bottom-left, opposite the FABs) explaining the three dB colors with their ranges and the heatmap gradient, plus a pill above it reading 'Updated 3m ago - 100 readings' that acts as an explicit tap-to-refresh. First-time viewers can decode the map, and everyone gets a working, discoverable refresh instead of a hidden pull gesture.

**How:**

Positioned(bottom: 16, left: 16) containing an AnimatedCrossFade between a small 'i' icon button and the expanded legend (three color dots from AppTheme.lowNoise/moderateNoise/highNoise + a 4-stop gradient bar built with LinearGradient from the same _gradientColors map). Track a _lastLoadedAt DateTime set in _loadNoiseMarkers; render relative time with a periodic 30s Timer or timeago package; chip onTap calls _refreshAllData() and shows a brief spinner in place of the clock icon.

---

### 16. Reading detail sheet: add timestamp, zone framing, and actions

**Impact:** High | **Effort:** M | **Area:** Map tap-through (map_view_screen.dart)

**Today:**

Tapping a marker opens _showMarkerDetailsFromData (lib/screens/map_view_screen.dart:1151-1282): location name, raw lat/lng, big dB number, a level string, and classification. It omits when the reading was taken â€” even though the Firestore doc's timestamp is available in _buildMarkersFromSnapshot (lines 174-221), it is simply not extracted or passed through. The sheet is also a dead end: no way to act on what you see.

**Proposal:**

Pass the timestamp through and show 'Measured 2h ago - Tue 14:05' prominently â€” for community noise data, recency is half the meaning of the number. Upgrade the sheet with two actions: 'Directions/Center here' (recenters map) and 'Share' (share text summary via share_plus). Replace the raw coordinates subtitle with the relative time, keeping coords behind a long-press copy.

**How:**

Extract final ts = (data['timestamp'] as Timestamp?)?.toDate() in _buildMarkersFromSnapshot and add a DateTime? parameter to _showMarkerDetailsFromData. Format with intl (DateFormat) plus a relative helper. Add a Row of two OutlinedButton.icon actions at the sheet bottom; 'Center' calls _mapController.move(LatLng(lat,lng), 16) then Navigator.pop. Consider showModalBottomSheet(isScrollControlled: true) with DraggableScrollableSheet if content grows.

---

### 17. Bottom-anchored, always-reachable record control

**Impact:** High | **Effort:** M | **Area:** One-handed reachability (dashboard_screen.dart)

**Today:**

The record button is a 70px GestureDetector embedded mid-way down a SingleChildScrollView column (lib/screens/dashboard_screen.dart:720-891, button at 836-869), below the greeting, stat row, 320px gauge, location chip, and (when present) the classification card. On small screens it sits near or past the fold, and it scrolls away entirely when the user looks at the history chart or community card. The primary action of the entire app has no fixed position.

**Proposal:**

Pin the record button (plus its status text) in a docked bar at the bottom of the dashboard, above the shell's bottom nav, so it is always in thumb reach regardless of scroll position. The scrollable content (gauge, chart, community card) stays above it. This makes start/stop a one-thumb operation from any state â€” critical for an app people use while walking down a street holding the phone in one hand.

**How:**

Restructure the body as Column[Expanded(SingleChildScrollView(...)), _RecordBar()], removing the button from the scroll column. Alternatively use Scaffold.floatingActionButton with a custom 72px FAB and FloatingActionButtonLocation.centerDocked. Add Semantics(button: true, label: _isRecording ? 'Stop measuring' : 'Start measuring') and HapticFeedback.mediumImpact() on tap â€” the current GestureDetector has neither semantics nor haptics.

---

### 18. Add permission priming screens before the mic and location OS dialogs

**Impact:** High | **Effort:** M | **Area:** Permissions / First-run

**Today:**

lib/screens/dashboard_screen.dart:90-99 fires _requestPermissions() and _getCurrentLocation() in initState, so a first-time user gets the microphone OS dialog (Permission.microphone.request(), line 152) and the location OS dialog (Geolocator.requestPermission(), line 192) back-to-back the instant the dashboard appears, with no explanation of why a 'noise map' app wants the mic. Denial jumps straight to _showPermissionDeniedDialog (line 156). Notification permission is requested even earlier â€” at app boot in lib/main.dart:48, before any UI exists.

**Proposal:**

Show an in-app primer before each OS dialog: a bottom sheet with icon, one-line rationale ('Sound is analyzed on your device to measure noise levels â€” audio is never uploaded' / 'Your readings are pinned to the community map'), and Allow / Not now buttons; only Allow triggers the real OS prompt. Sequence them by need: mic when the user first taps record, location when a reading is saved or the map opened. Priming is the standard fix for the one-shot Android permission â€” denied prompts cannot be re-shown, and un-primed double dialogs are the most common cause of permanent denial. Move the notification request out of main() entirely and tie it to the 'Enable Notifications' toggle in settings.

**How:**

permission_handler is already a dependency. Build a reusable PermissionPrimerSheet(icon, title, rationale, onAllow) shown via showModalBottomSheet; gate with await Permission.microphone.status â€” only prime when .isDenied (not yet asked). In dashboard, replace the initState call with a check inside the record-button handler: if (!status.isGranted) await _showPrimer(...). For permanently-denied, deep-link with openAppSettings(). Delete NotificationService.requestPermission() from main.dart:48 and call it from the notifications switch in settings_screen_enhanced.dart:171-179.

---

### 19. Post-recording session summary card

**Impact:** High | **Effort:** M | **Area:** Recording ritual (dashboard_screen.dart)

**Today:**

Stopping a recording is anticlimactic: _stopRecording (lib/screens/dashboard_screen.dart:544-585) cancels timers, clears the classification card (line 581), and flips the button back to 'Tap to measure' (line 873). The MIN/AVG/MAX stat row (lines 735-741) silently keeps its stale values, and _dbHistory/_maxDb/_minDb (lines 54-58) are never reset, so the next session's stats blend into the previous one. The user gets no confirmation that anything was saved or what the session found.

**Proposal:**

After stop, show a session summary bottom sheet: duration, min/avg/max dB, dominant sound class (mode of classifications seen), number of readings uploaded, and location â€” with actions 'View on map' and 'Done'. Then reset the session stats for a clean next run. This gives the recording a satisfying end state, confirms the community contribution actually happened (key for a crowdsourcing app), and fixes the stale-stats confusion as a side effect.

**How:**

Accumulate a small _SessionStats object during recording (start time, classification counts, save counter incremented in the _saveTimer callback at line 487). In _stopRecording, after state reset, call showModalBottomSheet with a summary card styled like _buildCommunityFeedCard; 'View on map' switches the MainAppShell IndexedStack to the map tab centered on _latitude/_longitude. Reset _dbHistory/_minDb/_maxDb/_avgDb when the sheet is dismissed or on next _startRecording.

---

### 20. Replace the 17-item sound-class dropdown with a grouped chip grid

**Impact:** High | **Effort:** M | **Area:** report_noise_screen.dart

**Today:**

Sound classification is a single DropdownButton containing all 17 options in one flat scrolling menu (lib/screens/report_noise_screen.dart:380-444, options at 37-55). The user must open the menu, scroll blindly through Pollution and Ambient entries interleaved by definition order, and can't see or compare choices; there is also no way to deselect once chosen.

**Proposal:**

Render the options inline as two labeled sections â€” 'Pollution' and 'Ambient' â€” each a Wrap of selectable icon chips. All options become visible at a glance, category context (red vs green) is spatial instead of a tiny badge inside a menu row, selection takes one tap instead of tap-scroll-tap, and tapping the selected chip again clears it. This directly reduces friction on the one field that gives readings their analytical value.

**How:**

Replace the DropdownButton container with: for each type in ['Pollution','Ambient'], a section header + Wrap(spacing: 8, runSpacing: 8, children: _soundClassOptions.where((o) => o['type']==type).map((o) => ChoiceChip(avatar: Icon(o['icon'], size: 16), label: Text(o['value']), selected: _selectedSoundClass==o['value'], onSelected: (sel) => setState(() => _selectedSoundClass = sel ? o['value'] : null)))). Style selected chips with the existing red/green alpha treatment from lines 414-434. If vertical space is a concern, show the top 6 chips + a 'More...' chip that opens a showModalBottomSheet with the full grid.

---

### 21. Generate full Material 3 ColorSchemes with ColorScheme.fromSeed for the 8 user-selectable theme colors

**Impact:** High | **Effort:** M | **Area:** Theming / Material 3 adoption

**Today:**

generateDarkTheme/generateLightTheme (lib/theme/app_theme.dart:41-55 and :125-139) build the accent by naive lerp toward white/black (`Color.lerp(primaryColor, Colors.white, 0.1)`) and populate only 4 of ~30 ColorScheme roles (primary, secondary, surface, error). Because useMaterial3 defaults to true on this Flutter version, every M3 widget that reads unset roles (dialogs, chips, switches, progress indicators, menus) falls back to constructor defaults that have nothing to do with the brand â€” which is why settings_screen_enhanced.dart:582-593 has to manually force AlertDialog backgroundColor and title color. The dark surfaces also stay purple (#1E1932/#322E4A) even when the user picks the Green or Teal theme from AppTheme.themeColors (app_theme.dart:29-38), so a 'Green theme' is really 'green buttons on someone else's purple app'.

**Proposal:**

Derive the whole scheme from the user's chosen color: `ColorScheme.fromSeed(seedColor: themeColor, brightness: ...)`, optionally with `dynamicSchemeVariant: DynamicSchemeVariant.vibrant` to keep saturation. Every M3 component instantly harmonizes (dialogs, chips, switches, snackbars), dark surfaces take on the chosen hue, and the manual per-widget color overrides scattered through settings can be deleted. The theme-color picker feature the app already ships becomes dramatically more satisfying â€” picking Teal actually re-tints the whole app.

**How:**

In generateDarkTheme: `final scheme = ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark); return ThemeData(colorScheme: scheme, scaffoldBackgroundColor: scheme.surface, ...)`. If the signature purple-dark look must be preserved for the default Purple theme, override surface roles only for that seed: `scheme.copyWith(surface: darkBackground, surfaceContainerHigh: cardBackground)`. Keep component themes (card shape, button padding) but drop hardcoded fills so they inherit scheme roles. Verify the 8 seeds in both brightnesses on the settings screen picker.

---

### 22. Extract a small design-system component library: AppCard, StatTile, SectionHeader, EmptyState, AppChipRow

**Impact:** High | **Effort:** L | **Area:** Component library

**Today:**

The same five patterns are hand-rolled with drifting values across screens. Card shell: `Container(decoration: BoxDecoration(color: ThemeHelper.getCardColor(context), borderRadius: BorderRadius.circular(12|16)))` appears 36+ times (e.g. history_screen.dart:516-525, search_list_screen.dart:583-589, analytics_screen.dart:1129-1134, settings_screen_enhanced.dart:360-368). Stat tiles: four incompatible implementations â€” dashboard_screen.dart:1023-1054 (icon+number+label), analytics_screen.dart:1127-1157 (number+label card), search_list_screen.dart:675, heatmap_settings_panel.dart:263-274 â€” with 'average' colored primary in one, Colors.blue in another (heatmap_settings_panel.dart:212). Empty states: three variants with icon sizes 80/64/64, icon alphas 0.3/0.5/1.0, and different text sizes (history_screen.dart:404-431, search_list_screen.dart:161-174, community_feed_screen.dart:111-146). Section headers exist only in settings (settings_screen_enhanced.dart:339-357) while other screens improvise. Selection chips are built three ways (analytics_screen.dart:485-525 GestureDetector pills, heatmap_settings_panel.dart:237-261 ChoiceChip).

**Proposal:**

Create lib/widgets/ds/ with five widgets extracted from the best existing variant of each: AppCard (padding, radius, optional onTap reusing the AnimatedCard press effect), StatTile (label/value/unit/accent color), SectionHeader (icon+title, the settings implementation generalized), EmptyState (icon, title, subtitle, optional action button), and AppChoiceChips (single-select pill row). Screens shrink by hundreds of lines, and every future screen automatically matches. This is the highest-leverage step for visual coherence: users currently see three different 'no data' treatments and four different stat cards in one session.

**How:**

Pure-Flutter extraction, no packages. Example: `class EmptyState extends StatelessWidget { final IconData icon; final String title; final String? subtitle; final Widget? action; build => Center(Column([Icon(icon, size: 72, color: cs.onSurfaceVariant.withValues(alpha: .4)), Text(title, style: tt.titleMedium), if(subtitle) Text(subtitle!, style: tt.bodyMedium), if(action) action!]))}`. Migrate screen-by-screen starting with history, search, analytics, community feed (the four screens with duplicated empty/stat patterns). Wire StatTile and AppCard colors to the NoiseColors extension and colorScheme rather than parameters where semantics are known.

---

### 23. Teach the record -> classify -> map value loop with an interactive onboarding walkthrough

**Impact:** High | **Effort:** L | **Area:** Onboarding

**Today:**

lib/screens/onboarding_screen.dart:7-132 is a single static StatelessWidget: one card ('Protect your hearing from harmful noise', lines 106-127) over a world-map background, with a 'Get started' button (lines 36-41) that pushes LoginScreen. Nothing explains what the app actually does â€” that you record ambient sound, on-device YAMNet classifies it into 17 categories, and readings build a community noise map. New users hit the signup wall with zero mental model of the product.

**Proposal:**

Replace the single card with a 3-page swipeable walkthrough mirroring the value loop: page 1 'Record' with a live (or simulated) dB meter, page 2 'Classify' showing sample sounds resolving into category chips (Traffic, Construction, Nature...), page 3 'Map' with a heatmap preview. Page 1 can offer a 'Try it now' that primes the mic permission and shows a real live level via the noise_meter package already in pubspec â€” a live demo converts far better than static slides because users experience the payoff before creating an account. Add a Skip button so returning users are not blocked.

**How:**

PageView.builder + custom dot indicator (Row of AnimatedContainers) + Skip TextButton. Page 1 live demo: after an in-app primer, NoiseMeter().noise.listen((r) => setState(() => _db = r.meanDecibel)) driving an AnimatedContainer bar-meter (reuse the splash sound-bar visual from splash_screen.dart:95-129); fall back to a looping TweenAnimationBuilder simulation if permission deferred. Page 2: staggered AnimatedOpacity chips reusing categoryIcon/categoryColor from ClassificationResult. Page 3: a static asset screenshot of the heatmap (assets/images/backgrounds/ already registered) â€” no map SDK needed pre-auth.

---

### 24. Scope the sound-type filter chips to the sections they actually filter

**Impact:** Medium | **Effort:** S | **Area:** analytics_screen.dart

**Today:**

The All/Pollution/Ambient chips sit at page level directly under the period chips (lib/screens/analytics_screen.dart:330-331, built at 527-574), implying they filter the whole screen â€” but _selectedFilter is only consulted by the pie chart (582-586) and category breakdown (716-754); the trend chart, confidence card, and the four stat cards ignore it entirely. Users tap 'Pollution' and see Average/Highest and the trend line unchanged, which reads as the filter being broken.

**Proposal:**

Either scope it visually â€” move the chips inside the 'Sound Type Distribution' card header as a segmented control so the affected area is unambiguous â€” or make the filter honest by applying it everywhere. The scoped option is an hour of work and immediately removes the mismatch between what the control promises and what it does.

**How:**

Scoped option: delete _buildFilterChips() from the page Column (line 331) and render a compact SegmentedButton<String>(segments: All/Pollution/Ambient, selected: {_selectedFilter}) in the title Row of _buildSoundTypePieChart (line 605) and reuse the same state for the breakdown card. Global option (M effort instead): keep chips where they are, but in _loadStatistics filter snapshot.docs by soundType before computing stats, and filter docs in _buildTimeAggregatedSpots â€” note dB stats over a soundType subset are computed client-side from the already-fetched docs, so no new Firestore queries or indexes are needed.

---

### 25. Annotate the trend chart: WHO guideline line and time-aware tooltips

**Impact:** Medium | **Effort:** S | **Area:** analytics_screen.dart

**Today:**

The trend LineChart draws a single purple line with grid disabled (lib/screens/analytics_screen.dart:1060), no left axis labels (1070-1071), and tooltips that show only '62.3 dB' with no indication of which hour/day was touched (1046-1057). The chart shows shape but gives no reference for 'is this bad?' or 'when was this?'.

**Proposal:**

Add a dashed horizontal reference line at 55 dB labeled 'WHO night guideline' (or 70 dB 'harmful over 24h'), and prepend the bucket's time label to the tooltip ('Tue â€” 62.3 dB', '14h â€” 71.0 dB'). A single annotated threshold turns the line from decoration into a health story: users instantly see which days breached the guideline.

**How:**

fl_chart supports this natively: add extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: 55, color: AppTheme.moderateNoise.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [6,4], label: HorizontalLineLabel(show: true, labelResolver: (_) => 'WHO 55 dB', alignment: Alignment.topRight))]) inside LineChartData (after line 1077). For tooltips, in getTooltipItems reuse the bucket-to-label math from _getXAxisWidget (lines 236-257) â€” extract it into String _bucketLabel(int bucket) and build LineTooltipItem('$label\n${spot.y.toStringAsFixed(1)} dB', ...). Also set minY to 20 instead of 0 (line 1080) so variation isn't flattened.

---

### 26. History chart: threshold line, zone coloring, and axis context

**Impact:** Medium | **Effort:** S | **Area:** Chart legibility (noise_history_chart.dart)

**Today:**

The chart hides everything contextual: grid off (lib/widgets/noise_history_chart.dart:51), titles off (line 54), border off (line 57), fixed 0-100 Y range (lines 60-61), and a uniform purple line/gradient regardless of level (lines 64-84). It plots the last 50 samples (line 43) with no hint of the time span. A reading of 75 dB looks exactly like 35 dB except for height.

**Proposal:**

Add a dashed horizontal reference line at 70 dB labeled 'High', minimal left-axis labels at 0/50/100, and color the line by zone using a gradient with hard stops at the 50/70 thresholds so dangerous stretches literally turn red. Caption the card 'Last ~50 readings'. The chart then answers the actual user question â€” 'how often was it too loud?' â€” instead of just drawing a pretty line.

**How:**

fl_chart supports all of it: extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: 70, dashArray: [6,4], color: AppTheme.highNoise.withValues(alpha: .6), label: HorizontalLineLabel(show: true, labelResolver: (_) => '70 dB'))]); leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 50, reservedSize: 28)); and LineChartBarData(gradient: LinearGradient(begin: bottomCenter, end: topCenter, colors: [low, low, moderate, moderate, high, high], stops: [0, .5, .5, .7, .7, 1])).

---

### 27. Dark-mode tone variants for status/severity colors (one palette for the Pollution/Ambient badge)

**Impact:** Medium | **Effort:** S | **Area:** Dark-mode contrast tuning

**Today:**

The same 'Pollution vs Ambient' concept is colored three different ways: dashboard badge uses raw AppTheme.highNoise/lowNoise at 11px on a 20%-alpha tint over the dark card (dashboard_screen.dart:1126-1139) â€” #F44336 text on that composite is about 2.9:1, failing AA; history uses the lighter Colors.red[300]/green[300] (history_screen.dart:607-628), which reads fine in dark mode; map_view uses plain Colors.red/green (map_view_screen.dart:1236-1255). So one concept has three palettes, and the most prominent one (live dashboard) is the least legible in dark mode.

**Proposal:**

Add brightness-aware tones to the NoiseColors/StatusColors extension: in dark mode the extension resolves to lightened tones (the red[300]/green[300] treatment history already discovered), in light mode to the deeper 500-series. Then build a single `SoundTypeBadge(soundType)` widget used by dashboard, history, and map. Dark-mode legibility of the classification badge â€” the thing users stare at while recording â€” improves immediately, and the concept gets one consistent color everywhere.

**How:**

In the ThemeExtension's dark factory: `pollution: Color(0xFFEF9A9A)`-ish tones (or `Color.alphaBlend(Colors.white.withValues(alpha:.35), highNoise)`), light factory keeps 500-series. Badge widget: container with `color: tone.withValues(alpha: .18)`, border `tone.withValues(alpha: .5)`, text `tone`, labelSmall w600. Replace the three inline badge builds. Validate with the Flutter DevTools contrast checker in both modes.

---

### 28. Skeleton rows for history initial load

**Impact:** Medium | **Effort:** S | **Area:** history_screen.dart

**Today:**

During the first page fetch, _recordings is empty and _isLoading is true, so the list body falls through to ListView.builder with itemCount 0 + 1, rendering a single small spinner row (lib/screens/history_screen.dart:432-447) in an otherwise blank screen â€” the count header at 388-398 also hasn't appeared yet, so the screen looks broken for a beat on slow connections.

**Proposal:**

Render 6-8 shimmer placeholder cards shaped like real history items (circle + two text bars) during the initial load. Users perceive skeletons as ~30% faster than spinners and the page structure is stable from frame one.

**How:**

Reuse ShimmerLoading (lib/utils/animations.dart:238). Add: if (_recordings.isEmpty && _isLoading) return ListView.builder(padding: EdgeInsets.all(16), itemCount: 7, itemBuilder: (_, __) => Container(margin: EdgeInsets.only(bottom: 12), padding: EdgeInsets.all(16), decoration: cardDecoration, child: Row(children: [ShimmerLoading(width: 60, height: 60, borderRadius: BorderRadius.circular(30)), SizedBox(width: 16), Expanded(child: Column(children: [ShimmerLoading(width: double.infinity, height: 14), SizedBox(height: 8), ShimmerLoading(width: 120, height: 12)]))]))) â€” inserted as a branch before the existing empty-state check at line 403.

---

### 29. Entrance/exit choreography for the live sound-classification card

**Impact:** Medium | **Effort:** S | **Area:** lib/screens/dashboard_screen.dart

**Today:**

The YAMNet classification card is conditionally inserted with a bare `if (_isRecording && _currentClassification != null) _buildSoundClassificationCard()` (dashboard_screen.dart:825-826), so it pops into the column with zero transition (shoving the record button down instantly) and vanishes the same way on stop. Its AnimatedContainer (:1063) only tweens decoration changes after it exists, and when the detected category changes (e.g. 'Traffic' -> 'Music', :639-642) the icon and label swap with no transition.

**Proposal:**

The first classification arriving ~5s into a recording is the app's magic moment â€” the phone just recognized the sound. Have the card grow+fade in, collapse out on stop, and cross-fade its icon/label when the category changes, so classification updates read as live inference rather than flicker. Also fixes the layout jump of the record button.

**How:**

Wrap the slot in AnimatedSize(duration: 300ms, curve: Curves.easeOutCubic, child: AnimatedSwitcher(duration: 250ms, transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween(begin: Offset(0, .15), end: Offset.zero).animate(anim), child: child)), child: showCard ? _buildSoundClassificationCard() : const SizedBox.shrink())) â€” AnimatedSize handles the column height change, AnimatedSwitcher the fade. Inside the card, key the icon container and category Text with ValueKey(result.category) inside their own AnimatedSwitcher so category flips cross-fade. Optionally HapticFeedback.selectionClick() when result.category != previous category.

---

### 30. Animated count-up numbers for dashboard MIN/AVG/MAX and analytics stat grid

**Impact:** Medium | **Effort:** S | **Area:** lib/screens/dashboard_screen.dart, lib/screens/analytics_screen.dart, lib/utils/animations.dart

**Today:**

Dashboard stat cards render value.toStringAsFixed(0) as static Text (dashboard_screen.dart:1023-1054, used at :738-740), so MIN/AVG/MAX snap to new integers on every stream reading. The analytics 2x2 stat grid (Average/Lowest/Highest/Duration, analytics_screen.dart:359-375 and _buildStatCard :1127-1157) pops from blank to final values the instant _isLoading flips (:299).

**Proposal:**

Numbers that roll to their value read as 'live data' and draw the eye to change; static snapping reads as a rerender. On the dashboard, gliding MIN/AVG/MAX makes the stats row feel connected to the gauge. On analytics, a 600-800ms count-up from 0 on first load (and between filter switches) is the classic dashboard-delight moment and costs one widget.

**How:**

Add AnimatedCount to animations.dart: class AnimatedCount extends StatelessWidget { final double value; final TextStyle style; final String Function(double) format; build => TweenAnimationBuilder<double>(tween: Tween(end: value), duration: Motion.scale(context, 500ms), curve: Curves.easeOutCubic, builder: (_, v, __) => Text(format(v), style: style)); }. TweenAnimationBuilder animates from its current animated value whenever `end` changes, which handles both the initial 0->value count-up and subsequent value->value glides for free. Replace the Text at dashboard_screen.dart:1039 and analytics_screen.dart:1138. For analytics, values change when _selectedPeriod/_selectedFilter reload (:489-494), so filter taps get the same rolling response.

---

### 31. Respect reduced-motion: a Motion helper gating all repeating and decorative animation

**Impact:** Medium | **Effort:** S | **Area:** lib/utils/animations.dart (new helper), all animated widgets

**Today:**

grep for disableAnimations / accessibleNavigation across lib/ returns nothing. Every animation runs unconditionally: ShimmerLoading repeats forever (animations.dart:262-265), PulseAnimation repeats with reverse (:335-338), FadeInListItem staggers every list item (:402-406), and the three PageRouteBuilder routes hardcode 300-400ms transitions (:43, :60, :88). Users who enable 'Remove animations' in Android accessibility settings get the full motion anyway.

**Proposal:**

Add a tiny central helper and thread it through the animation toolkit, so vestibular-sensitive users (and battery savers) get instant, motion-free UI while everyone else keeps the polish. Doing this now, before the recommendations above add pulse rings and shimmer skeletons, means every new animation is born accessible instead of retrofitted.

**How:**

In animations.dart add: class Motion { static bool reduced(BuildContext c) => MediaQuery.of(c).disableAnimations; static Duration scale(BuildContext c, Duration d) => reduced(c) ? Duration.zero : d; }. Usage: (1) ShimmerLoading/PulseAnimation/RecordingRipple â€” in build (or didChangeDependencies), if Motion.reduced(context) stop the controller and render the static frame (shimmer becomes a flat grey box; pulse renders child unscaled); (2) FadeInListItem â€” skip the Future.delayed and jump _controller.value = 1.0; (3) page routes take a BuildContext-free approach: keep durations but in transitionsBuilder return child directly when MediaQuery.of(context).disableAnimations is true (the builder receives a context). Every TweenAnimationBuilder added by other recommendations passes duration: Motion.scale(context, ...).

---

### 32. Fix the stagger curve and extend list entrance animation to Community Feed

**Impact:** Medium | **Effort:** S | **Area:** lib/utils/animations.dart, lib/screens/history_screen.dart, lib/screens/community_feed_screen.dart

**Today:**

FadeInListItem delays each item by delay * index with default 100ms (animations.dart:402), and History wraps every item including infinite-scroll pages (history_screen.dart:458-470) â€” item 30 of a paginated load waits 3 seconds off-screen, and items loaded via _loadMoreRecordings re-stagger from their absolute index. Community Feed builds its cards with no entrance animation at all (community_feed_screen.dart:163-192).

**Proposal:**

Make the stagger a proper cascade: cap the delay so the first ~8 visible items ripple in over half a second and everything after appears immediately, animate only on first page (not on pagination appends), and give the Community Feed â€” the app's social proof surface â€” the same entrance so fresh community reports visibly 'arrive'.

**How:**

In FadeInListItem change the delay computation to Future.delayed(widget.delay * math.min(widget.index, 8), ...) and add a bool animate parameter (default true) that jumps _controller.value = 1.0 when false. History passes animate: index < _pageSize && _isFirstLoad (track a _hasAnimatedInitialLoad flag flipped after first successful _loadInitialRecordings) so load-more rows appear instantly. Community Feed: wrap the _buildReportCard return at community_feed_screen.dart:185 in FadeInListItem(index: index, ...) â€” the import is one line and the widget already handles dark/light. Honor Motion.reduced via the toolkit-level gate from the reduced-motion recommendation.

---

### 33. Motion tokens, one theme-level page transition, and reduced-motion support

**Impact:** Medium | **Effort:** S | **Area:** Motion / animations

**Today:**

lib/utils/animations.dart defines three custom routes with three different durations (Slide 300ms :43, Scale 350ms :88, Fade 400ms :60), but they're used in only 4 places (dashboard_screen.dart:710, 923; login_screen.dart:286; registration_screen.dart:80) while 12 other pushes use default MaterialPageRoute â€” so navigation animation is inconsistent by screen. Component durations are also scattered (100ms button :122, 150ms card :201, 500ms list item :386, 1000ms pulse :320, 1500ms shimmer :263). PulseAnimation and ShimmerLoading repeat forever with no check of MediaQuery.disableAnimations for motion-sensitive users.

**Proposal:**

Declare motion once: a `Motion` token class (fast 100ms, base 250ms, slow 400ms, standard curves) and a theme-level `pageTransitionsTheme` so every push animates identically without per-call-site route classes. Gate looping animations (pulse, shimmer) behind `MediaQuery.disableAnimationsOf(context)`. Navigation feels like one app instead of four, and the app respects the OS 'remove animations' accessibility setting.

**How:**

In both generated themes: `pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()})` (or SharedAxisPageTransitionsBuilder from the `animations` package for the M3 shared-axis pattern). lib/theme/tokens.dart gains `abstract final class Motion { static const fast = Duration(milliseconds: 100); static const base = Duration(milliseconds: 250); static const emphasized = Curves.easeInOutCubicEmphasized; }`. In PulseAnimation/ShimmerLoading initState: `if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;` (checked in didChangeDependencies) and render the static frame. Delete SlidePageRoute/FadePageRoute/ScalePageRoute after migrating the 4 call sites.

---

### 34. Move logout out of the AppBar's prime position

**Impact:** Medium | **Effort:** S | **Area:** One-handed reachability / error prevention (dashboard_screen.dart)

**Today:**

The dashboard AppBar exposes a one-tap logout IconButton (lib/screens/dashboard_screen.dart:682-703) that signs out of Firebase and hard-resets the navigation stack with pushAndRemoveUntil to the splash screen â€” no confirmation dialog â€” sitting directly next to the settings icon users tap routinely. A destructive, session-ending action is one mis-tap away from a common one.

**Proposal:**

Remove logout from the AppBar and house it inside SettingsScreenEnhanced (already one tap away at lines 705-716) behind a confirmation dialog. The top bar keeps sync status + settings only. This follows the platform convention (sign-out lives in settings/profile), prevents accidental sign-outs that dump users to splash mid-measurement, and declutters the header of the app's core screen.

**How:**

Delete the logout IconButton from actions; add a ListTile(leading: Icons.logout, iconColor: AppTheme.highNoise) at the bottom of the settings list that calls showDialog(AlertDialog with 'Cancel'/'Sign out' actions) before FirebaseAuth.instance.signOut() and the existing pushAndRemoveUntil. Also guard: if _isRecording, stop the recording (and offer the session summary) before signing out.

---

### 35. Instant classification feedback with a 'listening' placeholder

**Impact:** Medium | **Effort:** S | **Area:** Recording ritual (dashboard_screen.dart)

**Today:**

The sound classification card only renders once a result exists (condition at lib/screens/dashboard_screen.dart:825-826), and the first classification cannot arrive before the 5-second Timer.periodic fires (lines 507-514). So for the first ~5 seconds of every session the flagship ML feature is invisible, and when the card does appear it shoves the record button down by ~90px mid-session (the conditional SizedBox at lines 828-830 changes height too).

**Proposal:**

Show the card immediately on record start in a skeleton state â€” pulsing icon circle, 'Listening... identifying sound' â€” then morph it into the result. Reserve the card's space for the whole recording so nothing below it jumps. Users see the AI working from second zero, and the tap target they just pressed stops moving under their thumb.

**How:**

Change the condition to if (_isRecording) and branch inside _buildSoundClassificationCard on _currentClassification == null: render Shimmer-style placeholders (two Containers with borderRadius, animated via AnimatedOpacity loop or the shimmer package) in place of category/badge text. Wrap the card in AnimatedSize(duration: 200ms) for the placeholder-to-result transition. Fire the first _performSoundClassification about 1.5s after start with a one-shot Timer so early results replace the skeleton fast.

---

### 36. Live recording feedback: elapsed timer and dB-driven pulse

**Impact:** Medium | **Effort:** S | **Area:** Recording ritual (dashboard_screen.dart)

**Today:**

During recording the only live affordances are the static text 'Recording...' (lib/screens/dashboard_screen.dart:872-878) and the gauge needle. The button itself shows a fixed red gradient with a constant 20px glow (lines 842-861) â€” nothing conveys elapsed time or that audio is actively being heard.

**Proposal:**

Replace 'Recording...' with a live monospace elapsed counter ('0:47') and make the button's glow ring breathe with the sound: scale the boxShadow blur/spread with _currentDb so loud environments visibly energize the button. This is the cheapest possible 'live waveform' â€” it reassures users the mic is working without any new audio plumbing, since _currentDb already updates several times per second.

**How:**

Store _sessionStart = DateTime.now() in _startRecording; a 1s Timer (or StreamBuilder on Stream.periodic) updates the label. For the pulse, compute glow = 12 + 24 * ((_currentDb - 30) / 70).clamp(0, 1) and feed it into the existing AnimatedContainer's BoxShadow blurRadius/spreadRadius â€” AnimatedContainer (line 838) already interpolates decoration changes. Optionally add a ~24px tall mini bar-waveform (Row of AnimatedContainers fed from the last N _dbHistory values) between button and text.

---

### 37. Live password strength meter on registration and change-password

**Impact:** Medium | **Effort:** S | **Area:** Registration / Settings

**Today:**

registration_screen.dart:319-327 validates only 'at least 6 characters' and gives no feedback until submit; weak passwords surface post-hoc as a Firebase 'weak-password' SnackBar (lines 93-94). The Change Password dialog (settings_screen_enhanced.dart:704-714, 740-747) applies the same blind 6-char minimum with zero guidance while typing.

**Proposal:**

Show a live strength bar (weak / fair / strong) beneath the password field as the user types, with short hint text ('add a number or symbol'). Users correct weak passwords before submitting instead of round-tripping through server errors, and account security in a community app with shared data improves as a side effect. Pairs with the AutofillHints.newPassword work in the autofill recommendation.

**How:**

onChanged: (v) => setState(() => _score = _strength(v)) where _strength awards points for length >= 8, mixed case, digits, symbols (0-4). Render TweenAnimationBuilder<double> + LinearProgressIndicator(value: _score / 4) colored red/orange/green from the theme, plus a caption Text. About 40 lines, no package (or use the tiny password_strength pub package). Reuse the same widget inside the rebuilt change-password form.

---

### 38. Make default-location submissions explicit on the report form

**Impact:** Medium | **Effort:** S | **Area:** report_noise_screen.dart

**Today:**

The form initializes to hardcoded Colombo coordinates (lib/screens/report_noise_screen.dart:22-24) and _submitReport (208-261) saves whatever _latitude/_longitude currently hold, while the only location feedback is the small pill at the bottom (509-577) â€” below the Submit button (453-479) â€” which may read 'Fetching location...' or 'Location services disabled' at the moment the user submits. Nothing tells the user their report may be pinned to a default spot on the community map.

**Proposal:**

Move the location pill above the Submit button and give it three explicit visual states: resolved (green check + place name), resolving (spinner + 'Getting your location...'), and fallback (amber warning + 'Using approximate location â€” tap to retry'). In the fallback state, submitting shows a one-line inline caption 'This report will use an approximate location'. Data quality on the community map improves and users stop being surprised by misplaced pins â€” with zero added friction for the happy path.

**How:**

Track an enum LocationStatus {resolved, resolving, fallback} instead of overloading _locationName strings (set in _getCurrentLocation's success/catch branches, 122-176). Reorder the build Column so _buildLocationActionButton renders between the classification card and the Submit button; tint the pill border amber (AppTheme.moderateNoise) in fallback and add the caption Text below it. Optionally gate Submit with a lightweight confirm only in fallback state: showModalBottomSheet('Submit with approximate location?').

---

### 39. Replace analytics full-screen spinner with skeleton layout and add pull-to-refresh

**Impact:** Medium | **Effort:** M | **Area:** analytics_screen.dart

**Today:**

While loading, analytics shows a centered spinner + 'Loading analytics...' replacing the entire layout (lib/screens/analytics_screen.dart:299-314), causing a full layout pop-in when data arrives. Switching period chips clears every stat to 0 (lines 102-115) without any loading affordance, so cards visibly flash '0 dB' until the query resolves. The body is a plain SingleChildScrollView (line 315) with no RefreshIndicator, even though History and Feed both have one. Meanwhile a ready-made ShimmerLoading widget exists unused at lib/utils/animations.dart:238-310.

**Proposal:**

Show a skeleton that mirrors the real layout (banner bar, chip row, two card blocks, 2x2 stat grid) during initial load and period switches, and wrap the scroll view in RefreshIndicator. No layout shift, and the '0 dB' flash becomes a deliberate shimmer, which reads as 'updating' instead of 'your data vanished'.

**How:**

Add bool _isRefreshingPeriod; set it true at the top of _loadStatistics and false in the final setState. Build _buildSkeleton(): Column of ShimmerLoading(width: double.infinity, height: 64, borderRadius: BorderRadius.circular(14)) for the banner, height 200 for chart card, and GridView.count of four ShimmerLoading(height: 110) tiles matching the real grid at 359-375. Swap body: _isLoading ? _buildSkeleton() : RefreshIndicator(onRefresh: _loadStatistics, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), ...)). While _isRefreshingPeriod, render skeleton tiles in place of the stat cards only.

---

### 40. Feed cards: surface sound classification and make cards tappable to the map

**Impact:** Medium | **Effort:** M | **Area:** community_feed_screen.dart

**Today:**

Feed cards (lib/screens/community_feed_screen.dart:200-390) show dB circle, location, Safe/Moderate/High badge, masked email, and time â€” but never read soundClass/soundType even though readings store them (history_screen.dart renders exactly this badge at 582-638). Cards are also inert: no onTap, so a user seeing 'High, 92 dB, Galle Road' cannot see where that is, and the report's latitude/longitude (fetched at line 167) are simply dropped.

**Proposal:**

Add the classification chip ('Traffic', 'Construction'...) to each card â€” it is the most interesting fact about a community report â€” and make the whole card tappable to open that reading's location on the map tab. This turns the feed from a passive list into the entry point for exploring noise hotspots, which is the app's core promise.

**How:**

Extract the badge builder from history_screen.dart:582-638 into a shared widget (lib/widgets/sound_class_badge.dart) taking soundClass/soundType/confidence, and use it in both screens (also fixes the feed's repeated Theme.of(context).brightness ternaries by using ThemeHelper per project convention). Read soundClass/soundType from report data in itemBuilder (line 167). Wrap Card content in InkWell(onTap: ...) that either pushes the map screen with an initial camera target or, since the feed lives beside MainAppShell's IndexedStack, invokes a callback/provider that switches to the map tab and animates to LatLng(report['latitude'], report['longitude']).

---

### 41. Explicit token scale for spacing, radius, and icon sizes

**Impact:** Medium | **Effort:** M | **Area:** Design tokens

**Today:**

Values are ad hoc throughout: 10 distinct corner radii (48x circular(12), 18x circular(16), 15x circular(8), 15x circular(20), 7x circular(30), plus one-offs 3/4/6/10/14 â€” grep across lib), 22+ distinct EdgeInsets combinations (all(16) x24, all(20) x13, all(24) x10, symmetric(16,8) x7, plus long-tail one-offs like symmetric(horizontal:16, vertical:14)), and card padding that varies 16/20/24 between sibling cards on the same screens (analytics_screen.dart:1130 uses all(20) while history_screen.dart:518 uses all(16)).

**Proposal:**

Add a tokens file with a 4pt-based scale â€” `Insets` (xs 4, sm 8, md 12, lg 16, xl 24, xxl 32), `Corners` (sm 8, md 12, lg 16, pill 30) as BorderRadius constants, and `IconSizes` (sm 16, md 20, lg 28, empty 72). Consume them in the new AppCard/StatTile/EmptyState components first so the component library enforces the scale, then adopt opportunistically in screens. The one-off values (14, 6, circular(3)) disappear, and spacing rhythm becomes consistent without a big-bang rewrite.

**How:**

lib/theme/tokens.dart: `abstract final class Insets { static const xs = 4.0; ... static const allLg = EdgeInsets.all(16); }` and `abstract final class Corners { static final md = BorderRadius.circular(12); ... }` (const via BorderRadius.all(Radius.circular(12))). Wire cardTheme/inputDecorationTheme/elevatedButtonTheme in app_theme.dart to the same constants so theme and widgets can't drift. Optionally add a lint rule via custom_lint or a grep-based CI check for `BorderRadius.circular(` outside tokens.dart.

---

### 42. Profile avatar upload â€” photoURL is modeled but never populated

**Impact:** Medium | **Effort:** M | **Area:** Edit Profile

**Today:**

Registration writes 'photoURL': null into users/{uid} (registration_screen.dart:63), and edit_profile_screen.dart:231-246 renders a static Icons.person circle with no interaction â€” even though image_picker (pubspec.yaml:65), flutter_image_compress (pubspec.yaml:101), and firebase_storage (pubspec.yaml:34) are all already dependencies. The entire avatar pipeline is paid for and unused.

**Proposal:**

Make the avatar tappable with a camera badge: pick from gallery/camera, compress, upload to Storage, save the URL to both Firebase Auth and the users doc, and render it wherever the person icon appears. Profile personalization is a cheap, proven engagement lever for community apps, and it makes the Edit Profile screen feel complete rather than placeholder.

**How:**

GestureDetector on the avatar -> showModalBottomSheet(camera/gallery) -> ImagePicker().pickImage(maxWidth: 512, imageQuality: 85) -> FlutterImageCompress.compressWithFile(quality: 80) -> FirebaseStorage.instance.ref('avatars/${user.uid}.jpg').putFile(file) -> final url = await ref.getDownloadURL() -> await user.updatePhotoURL(url) plus _firestore.collection('users').doc(uid).set({'photoURL': url, 'updatedAt': FieldValue.serverTimestamp(), 'updatedAtClient': DateTime.now()}, SetOptions(merge: true)). Display: CircleAvatar(backgroundImage: photoURL != null ? NetworkImage(photoURL) : null, child: photoURL == null ? Icon(Icons.person) : null).

---

### 43. Semantic feedback tokens + one AppSnackBar helper to replace 75 ad-hoc SnackBars

**Impact:** Medium | **Effort:** M | **Area:** Feedback / status colors

**Today:**

There are 75 `SnackBar(` construction sites in screens/widgets, hardcoding `backgroundColor: Colors.green` for success and `Colors.red` for errors (e.g. settings_screen_enhanced.dart:114, 626, 782, 802, 921, 941, 1044-1071; map_view_screen.dart:565, 577; history_screen.dart:324, 727). No snackBarTheme is defined in either theme, so shape, behavior (fixed vs floating), and text style also vary by call site. The raw Colors.green/red ignore the dB palette (AppTheme.lowNoise/highNoise are different greens/reds) and the user's theme.

**Proposal:**

Add success/warning tokens next to the NoiseColors extension (or a small `StatusColors` extension), define `snackBarTheme` once (floating, 12px radius, themed colors), and expose `context.showSuccess(msg)` / `context.showError(msg)` / `context.showInfo(msg)` extension methods. All 75 sites collapse to one-liners, feedback becomes visually consistent app-wide, and error snackbars automatically use `colorScheme.error`/`onError` with correct contrast in both modes.

**How:**

lib/utils/feedback.dart: `extension AppFeedback on BuildContext { void showSuccess(String msg) => ScaffoldMessenger.of(this).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Theme.of(this).extension<StatusColors>()!.success, content: Text(msg))); ... }`. Set `snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))` in both generated themes. Mechanical find-and-replace sweep of the 75 sites.

---

### 44. Needle smoothing, peak-hold marker, and repaint hygiene

**Impact:** Medium | **Effort:** M | **Area:** Gauge legibility (decibel_meter_gauge.dart)

**Today:**

The needle position is computed directly from the latest reading (NeedlePainter, lib/widgets/decibel_meter_gauge.dart:200-217), so it teleports with every noise_meter emission â€” jittery and hard to read against the 50/70 thresholds. There is no peak indicator on the dial (MAX lives only in the stat row far above). Both painters return shouldRepaint => true unconditionally (lines 188 and 235), repainting the full 320px gauge stack every frame even when the value is unchanged.

**Proposal:**

Animate the needle toward each new value with a short ease-out tween (real SPL meters have ballistics â€” 'fast' response is ~125ms), and draw a thin peak-hold tick at the session max that decays after a few seconds. The gauge becomes readable at a glance and feels like a physical instrument; the repaint fix keeps the recording screen cheap while timers, classification, and charts are all active.

**How:**

Wrap the gauge in TweenAnimationBuilder<double>(tween: Tween(end: currentDb), duration: 150ms, curve: Curves.easeOut) and pass the animated value into both painters. Track peakDb in the parent, pass to NeedlePainter, draw a 2px radial tick at its angle in AppTheme.highNoise. Fix shouldRepaint to compare currentDb/maxDb/isDark (and peak), and wrap the static DecibelGaugePainter layer in a RepaintBoundary so only the needle layer repaints per reading.

---

### 45. Make the Classification Guide reachable from the live classification card

**Impact:** Medium | **Effort:** M | **Area:** Guide discoverability

**Today:**

ClassificationGuideScreen is navigated to from exactly one place in the app: Settings -> About & Support -> 'Sound Classification Guide' (settings_screen_enhanced.dart:291-302; a project-wide grep confirms no other call site). Meanwhile the dashboard's live classification card (dashboard_screen.dart:1057-1097) shows category, emoji icon, and confidence with no tap affordance â€” at the exact moment a user wonders 'why did it label this Traffic?', the explainer content is buried three levels deep in settings.

**Proposal:**

Make the classification card tappable with a small info chevron, opening the guide scrolled to and expanded on the detected category. This connects the existing teaching content to the moment of peak curiosity for free â€” the guide, the data model, and the card all already exist; only the link is missing. Optionally show a one-time 'Tap to learn what this means' tooltip on first classification.

**How:**

Add ClassificationGuideScreen({this.initialCategory}) ; the guide list uses ExpansionTile per category (classification_guide_widget.dart:23), so pass initiallyExpanded: categoryData.name == initialCategory down through CategoryGuideTile and jump with a post-frame Scrollable.ensureVisible (or ScrollController.animateTo(index * itemExtent)). On the dashboard wrap _buildSoundClassificationCard's AnimatedContainer in InkWell(onTap: () => Navigator.push(... ClassificationGuideScreen(initialCategory: result.category))). First-run tooltip via a SharedPreferences bool + Overlay or the built-in Tooltip triggered manually.

---

### 46. Progressive disclosure for heatmap controls: tap toggles, long-press configures

**Impact:** Medium | **Effort:** M | **Area:** Heatmap controls (heatmap_fab.dart + heatmap_settings_panel.dart)

**Today:**

HeatmapFab is a bare on/off toggle (lib/widgets/heatmap_fab.dart:21-33; header comment: 'No settings panel - just toggle on/off'), opacity is a hardcoded final 0.7 (lib/screens/map_view_screen.dart:69), and a fully built HeatmapSettingsPanel with opacity slider, time-range chips, and avg/max/min stats (lib/widgets/heatmap_settings_panel.dart:118-231) is orphaned â€” grep confirms nothing imports it. The FAB also uses Icons.terrain in AppTheme.highNoise red (heatmap_fab.dart:24-30), which reads as elevation/danger rather than a data layer.

**Proposal:**

Keep the one-tap toggle as the fast path, and open the existing settings panel as a modal bottom sheet on long-press (or via a small chevron chip that appears next to the FAB only while the heatmap is on). Swap the icon to Icons.layers with a tooltip. Casual users keep a single tap; power users get opacity, time range, and stats without permanently cluttering the map â€” textbook progressive disclosure that resurrects ~250 lines of finished UI.

**How:**

FloatingActionButton has no onLongPress, so wrap it: GestureDetector(onLongPress: _openHeatmapSheet, child: FloatingActionButton(...)). _openHeatmapSheet calls showModalBottomSheet hosting HeatmapSettingsPanel with _isExpanded defaulted true; promote _heatmapOpacity from final to state, wire onOpacityChanged to setState, onTimeRangeChanged to the time-filter logic from the time-chips recommendation, and statistics from heatmapService.calculateStatistics(_heatmapPoints) (lib/services/heatmap_service.dart:101-124). Add Tooltip(message: 'Noise heatmap') on the FAB.

---

### 47. Swipe-to-delete with undo instead of per-row delete icon + dialog

**Impact:** Medium | **Effort:** M | **Area:** history_screen.dart

**Today:**

Every history card carries a permanent trash IconButton (lib/screens/history_screen.dart:643-649) that opens a blocking confirmation dialog (704-737); confirmed deletes are immediate and irreversible, announced by a red 'Recording deleted' SnackBar (723-729). The always-visible icon adds visual noise to every row and the dialog adds two taps to a rare action, while offering no recovery from a wrong tap.

**Proposal:**

Move deletion to swipe-left (Dismissible with red delete background) and replace the confirmation dialog with an undoable SnackBar ('Recording deleted â€” UNDO', 5 s). Rows get cleaner (more room for location text), intentional deletes get faster, and accidental ones become recoverable â€” the modern forgiving pattern instead of the interrogating one.

**How:**

Wrap _buildHistoryItem's Container in Dismissible(key: ValueKey(docId), direction: DismissDirection.endToStart, background: red container with delete icon). In onDismissed: remove the doc from _recordings and stash data+id; show SnackBar(action: SnackBarAction(label: 'UNDO', onPressed: reinsert locally and skip deletion)). Perform the Firestore .doc(docId).delete() only when the SnackBar closes without undo (SnackBarClosedReason != action) â€” or simpler, write the stashed map back with .doc(docId).set(data) on undo. Also decrement/increment _totalCount so the 'Showing X of Y' header stays truthful, and keep the trash icon as a secondary affordance only if discoverability testing demands it.

---

### 48. Draw-in animation for the analytics trend line and pie chart

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/analytics_screen.dart, lib/widgets/noise_history_chart.dart

**Today:**

fl_chart 0.70.1 is already the chart engine (pubspec.yaml:59). NoiseHistoryChart passes duration: 250ms so live data swaps tween (noise_history_chart.dart:31-34), but the analytics trend LineChart (analytics_screen.dart:1039-1116) passes no duration and the PieChart (:619-649) none either â€” both render fully formed the moment the stream delivers, with no draw-in on first paint or on Daily/Weekly/Monthly period switches (:489-494).

**Proposal:**

Animate the trend line rising from the baseline and the pie sections sweeping open on first load and on every period/filter change. Charts that draw themselves communicate 'freshly computed from your data' and make the period chips feel responsive â€” right now switching Daily->Monthly teleports the chart, so the causal link between tap and data is easy to miss.

**How:**

Trend line: wrap the LineChart in TweenAnimationBuilder<double>(key: ValueKey(_selectedPeriod + _selectedFilter), tween: Tween(begin: 0, end: 1), duration: Motion.scale(context, 700ms), curve: Curves.easeOutCubic, builder: (_, t, __) => LineChart(data.copyWith? no â€” build spots as spots.map((s) => FlSpot(s.x, s.y * t)))) â€” scaling y by t rises the line from minY; the ValueKey restarts the draw-in per period. Also pass duration: 400ms to LineChart itself so subsequent stream updates morph. Pie: same TweenAnimationBuilder driving PieChartSectionData(value: count * t + epsilon) with startDegreeOffset: -90 * (1 - t) for a sweep-open feel, or simpler: pass duration/curve to PieChart and initialize sections empty then setState â€” fl_chart's implicit animation morphs 0->value. Skip both when Motion.reduced.

---

### 49. Skeleton shimmer loading states for History list and Analytics (the ShimmerLoading widget already exists)

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/history_screen.dart, lib/screens/analytics_screen.dart, lib/utils/animations.dart

**Today:**

ShimmerLoading is fully implemented in animations.dart:238-310 (gradient sweep, dark/light aware) but has zero call sites. History's initial Firestore page load (history_screen.dart:78-115) renders the ListView with itemCount 0+1 showing a lone bottom spinner (:432-447); Analytics shows a centered CircularProgressIndicator with 'Loading analytics...' text (analytics_screen.dart:299-314) that then hard-cuts to the full dashboard.

**Proposal:**

Replace both spinners with content-shaped shimmer skeletons. Skeletons set layout expectations (perceived performance improves because the eye starts parsing structure before data lands) and eliminate the jarring blank->everything cut on Analytics, which is the heaviest screen. This finally pays off the shimmer code the project already carries.

**How:**

Build a _HistoryItemSkeleton mirroring _buildHistoryItem's geometry (history_screen.dart:516-546: card with a 60px ShimmerLoading circle via borderRadius: BorderRadius.circular(30), then 16px/13px-height ShimmerLoading bars of decreasing width) and show ListView(children: List.generate(6, ...)) while _recordings.isEmpty && _isLoading. For Analytics replace the :300-313 Center with a Column: a row of 3 pill shimmers (the chips), a 180px rounded-rect shimmer (trend chart), and a 2x2 GridView of card shimmers matching :359-375. Wrap the real content's appearance in AnimatedSwitcher(duration: 300ms) so skeleton cross-fades into data instead of swapping. Honor Motion.reduced by rendering static grey blocks (already trivial since ShimmerLoading owns its controller).

---

### 50. Live-reacting waveform and graded slider feedback on the manual report screen

**Impact:** Medium | **Effort:** M | **Area:** lib/screens/report_noise_screen.dart

**Today:**

The Report Noise screen tops with a purely decorative static waveform â€” _buildWaveformDisplay is a CustomPaint with a fixed WaveformPainter (report_noise_screen.dart:494-506). Below it, the dB Slider (:313-325) updates a static '${_manualDb.toInt()} dB' headline (:295-301) with no color, motion, or tactile response; 40 dB and 110 dB look identical except for the digits.

**Proposal:**

Bind the decoration to the data: as the user drags the slider, the waveform's amplitude and agitation grow with the dB value and the headline color sweeps green -> orange -> red through the app's existing noise palette, with a haptic tick at 10-dB detents and a heavier pulse crossing the 70 dB pollution threshold. Users submitting manual reports get an intuitive feel for what the number means â€” directly supporting data quality in a community-sourced dataset.

**How:**

Make the waveform card a StatefulWidget with AnimationController(duration: 1200ms)..repeat() feeding phase to WaveformPainter; pass amplitude: _manualDb / 120 so paint scales wave height and adds jitter above 0.6. Headline color: Color.lerp between AppTheme.lowNoise/moderateNoise/highNoise using the same <50/<70 breakpoints as _getDbColor in decibel_meter_gauge.dart:177-185 (extract to ThemeHelper for reuse), applied via AnimatedDefaultTextStyle(duration: 200ms). Slider onChanged: if ((value ~/ 10) != (_manualDb ~/ 10)) HapticFeedback.selectionClick(); if crossing 70 in either direction HapticFeedback.mediumImpact(). Freeze the waveform (static frame at current amplitude) when Motion.reduced.

---

### 51. Cross-fade tab switches in MainAppShell and animate the bottom-nav active state

**Impact:** Medium | **Effort:** M | **Area:** lib/widgets/main_app_shell.dart, lib/widgets/shared_bottom_navbar.dart

**Today:**

MainAppShell swaps tabs with a bare IndexedStack(index: _currentIndex) (main_app_shell.dart:38-46) â€” a hard cut between Map/Analytics/Dashboard/History/Settings. In SharedBottomNavBar the icon active color flips instantly (shared_bottom_navbar.dart:62-73) and the home button's border width (2->3), shadow blur (8->12) and spread (0->2) are computed statically in a plain Container (:84-112), so its 'active glow' also snaps.

**Proposal:**

A 200ms cross-fade between tabs plus an eased glow/scale on the nav icons makes the five-tab shell feel like one continuous surface instead of five apps sharing a nav bar â€” while keeping IndexedStack's state preservation (map position, scroll offsets), which the audit architecture depends on (isInAppShell contract).

**How:**

FadeIndexedStack pattern (state-preserving, Flutter-native): a StatefulWidget owning AnimationController(duration: 200ms); didUpdateWidget { if (index changed) _controller.forward(from: 0); } build => FadeTransition(opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut), child: IndexedStack(index: index, children: children)). Children never rebuild or lose state; only opacity animates. In SharedBottomNavBar: replace the icon with AnimatedScale(scale: isActive ? 1.15 : 1.0, duration: 200ms) around an AnimatedSwitcher-free Icon whose color comes from an implicit TweenAnimationBuilder<Color?> or simply wrap the padding Container in AnimatedContainer; convert the home button's Container (:84) to AnimatedContainer(duration: 250ms, curve: Curves.easeOut) so border/shadow ease. Add HapticFeedback.selectionClick() in onTap (ties into the haptics recommendation).

---

### 52. Give the login 'OR' divider a purpose: Google sign-in

**Impact:** Medium | **Effort:** M | **Area:** Login

**Today:**

login_screen.dart:257-299 renders a full-width divider labeled 'OR' â€” the universal signal for an alternative auth method â€” but the only thing below it is the 'Don't have an account? Sign Up' text row. The visual promise of social login is made and broken on the app's front door.

**Proposal:**

Add a 'Continue with Google' button under the divider. For a community mapping app the account exists only to attribute readings, so one-tap OAuth removes the password entirely for most users, cuts registration abandonment, and yields displayName (and photoURL) for free â€” feeding the profile surface too. If social login is out of scope, remove the divider so the layout stops implying it.

**How:**

google_sign_in package + firebase_auth: final gUser = await GoogleSignIn().signIn(); final gAuth = await gUser.authentication; await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: gAuth.idToken, accessToken: gAuth.accessToken)). On first sign-in upsert the users/{uid} doc with SetOptions(merge: true) mirroring the field set registration writes at registration_screen.dart:57-74 (dual createdAt/createdAtClient per project convention). Requires SHA-1/SHA-256 fingerprints registered in the Firebase console.

---

### 53. Cluster labels that carry noise information

**Impact:** Medium | **Effort:** M | **Area:** Map information design (map_view_screen.dart)

**Today:**

Cluster pins show only the marker count in black text (lib/screens/map_view_screen.dart:723-733), while the pin color encodes average noise via a lookup from _markerNoiseLevels keyed by coordinate strings (lines 683-694) â€” a fragile side-channel between the marker list and a parallel map. Color alone is the only noise signal, which fails for color-blind users and says nothing precise.

**Proposal:**

Make clusters state their meaning: count in the bulb plus a tiny 'avg 68' dB caption under it (or a small colored ring segment showing the loud/moderate/quiet mix). A cluster then answers 'is this area loud?' before the user zooms, which is the entire point of aggregating markers on a community noise map.

**How:**

Carry the dB value on the marker itself instead of the parallel map: markers.add(Marker(key: ValueKey(db), ...)) in _buildMarkersFromSnapshot, then in the cluster builder read markers.map((m) => (m.key as ValueKey<double>).value) to average â€” this also removes the string-keyed lookup. Render Column[bulb with count, Container(padding 2, color: clusterColor, borderRadius 6, child: Text('${avg.round()} dB', 9px white bold))] and bump the cluster size to ~Size(50, 64) so the caption fits.

---

### 54. Adopt M3 selection and button components: SegmentedButton for period filters, FilledButton hierarchy, themed chips

**Impact:** Medium | **Effort:** M | **Area:** Material 3 adoption / components

**Today:**

Selection controls are hand-rolled GestureDetector+Container pills in analytics (period chips analytics_screen.dart:485-525, filter chips :539+), while the heatmap panel uses real ChoiceChips but colors selection with the DANGER red `selectedColor: AppTheme.highNoise` (heatmap_settings_panel.dart:256) â€” a time-range selection painted in the same red that means '>70 dB dangerous' elsewhere. Buttons are a mix of ElevatedButton (8 files), the custom AnimatedButton (login_screen.dart:210, registration_screen.dart:385), and bare GestureDetector containers; no FilledButton/OutlinedButton/TextButton hierarchy or themes exist (app_theme.dart only defines elevatedButtonTheme).

**Proposal:**

Use `SegmentedButton<T>` for the single-select period filter (Day/Week/Month) â€” it's the canonical M3 control, ships selected-state semantics for screen readers, and inherits scheme colors. Theme ChoiceChips once (chipTheme with secondaryContainer selection, never the danger red). Define filledButtonTheme/outlinedButtonTheme/textButtonTheme so primary/secondary/tertiary actions have a visible hierarchy (today every action is a filled pill). Selection states become instantly recognizable and stop colliding with the dB severity language.

**How:**

`SegmentedButton(segments: [ButtonSegment(value: Period.day, label: Text('Day')), ...], selected: {_period}, onSelectionChanged: ...)` styled via segmentedButtonTheme. Add `chipTheme: ChipThemeData(selectedColor: scheme.secondaryContainer, labelStyle: ...)` and remove the per-chip color overrides. Map existing usages: primary CTA â†’ FilledButton, destructive â†’ FilledButton with error scheme or TextButton(style: foregroundColor: scheme.error), secondary â†’ OutlinedButton. Keep AnimatedButton's press-scale by wrapping FilledButton in it if the effect is valued.

---

### 55. Pre-roll countdown and optional timed measurement

**Impact:** Medium | **Effort:** M | **Area:** Recording ritual (dashboard_screen.dart)

**Today:**

Tapping the mic starts capture instantly (_startRecording, lib/screens/dashboard_screen.dart:361-518), so the first seconds of every session record the rustle of the user positioning the phone â€” and those readings feed _dbHistory and the 5-second Firebase saves (line 487) just like clean data. Sessions are open-ended; there is no guided 'take a 30-second measurement' mode.

**Proposal:**

On tap, run a 3-2-1 countdown overlay ('Hold your phone still') before the meters go live, and offer an optional fixed 30s measurement mode where a progress ring fills around the record button and the session auto-stops into the summary card. The countdown improves data quality at the source (fewer handling-noise readings uploaded to the shared map) and the timed mode gives new users a clear, completable ritual instead of an ambiguous start/stop.

**How:**

Add an enum _RecordPhase {idle, countdown, recording}. On tap: setState to countdown, animate 3-2-1 with an AnimatedSwitcher over the gauge area (large numerals, scale+fade transition) driven by a 1s Timer, then invoke the existing _startRecording. For timed mode, paint the ring with a TweenAnimationBuilder<double> (0-1 over 30s) as a CircularProgressIndicator(value:) sized just outside the 70px button; onEnd calls _stopRecording. HapticFeedback.lightImpact on each countdown tick.

---

### 56. Regroup settings by domain, disable dependent toggles, and show current values on navigation rows

**Impact:** Medium | **Effort:** M | **Area:** Settings

**Today:**

lib/screens/settings_screen_enhanced.dart: the 'Appearance' section (lines 87-124) contains 'Decibel Scale' (dBA/dBC) and 'Response Time' (Fast/Slow) â€” acoustics settings, not appearance. 'Alert Threshold' (lines 153-163) sits under Measurement while the 'High Noise Alerts' switch it governs is under Notifications (lines 180-188). The 'High Noise Alerts' and 'Daily Reminders' switches remain fully interactive when the master 'Enable Notifications' is off (lines 171-198), silently doing nothing. Navigation rows show no current state â€” 'Theme Colors' (lines 119-123) gives no hint of the active color until the dialog opens.

**Proposal:**

Three targeted IA fixes: (1) move Decibel Scale and Response Time into the Measurement section and Alert Threshold adjacent to High Noise Alerts so cause and effect live together; (2) disable and dim the two child notification switches when the master is off â€” the canonical dependent-setting pattern; (3) add trailing current-value indicators to nav rows (a color swatch dot for Theme Colors). Users can then scan their configuration at a glance and stop flipping switches that have no effect.

**How:**

Reorder the _buildSettingCard children lists (pure move). Dependent toggles: Switch(onChanged: _notificationsEnabled ? (val) {...} : null) â€” Flutter renders a disabled switch automatically â€” plus Opacity(opacity: _notificationsEnabled ? 1 : 0.4) on the row. Extend _buildNavigationItem (line 512) with an optional trailing widget parameter; for Theme Colors pass Container(width: 16, height: 16, decoration: BoxDecoration(color: themeColorNotifier.value, shape: BoxShape.circle)).

---

### 57. Replace the Change Password AlertDialog with a proper validated form

**Impact:** Medium | **Effort:** M | **Area:** Settings / Account

**Today:**

settings_screen_enhanced.dart:677-825: change-password is a bare AlertDialog with two always-obscured TextFields (no visibility toggles, lines 692-714), no confirm-new-password field, validation done imperatively in the button handler via SnackBars (lines 733-758) that render underneath the dialog barrier, and no loading state while the two network calls run (reauthenticate + updatePassword, lines 767-775) â€” the dialog just sits inert until it pops.

**Proposal:**

Promote to a dedicated screen or tall bottom sheet reusing the registration form's field styling: visibility toggles on all three fields (current, new, confirm), inline validator errors, the strength meter, and a disabled button with spinner during submission. Brings the weakest form in the app up to the standard the registration screen already sets, and fixes feedback appearing behind the modal.

**How:**

Extract the rounded filled InputDecoration builder from registration_screen.dart:203-225 into a shared helper (also reusable by edit_profile). New ChangePasswordScreen with Form + GlobalKey, three TextFormFields with per-field _obscure booleans (copy the suffixIcon IconButton pattern from registration_screen.dart:289-299), validator for confirm == new, and _isSubmitting gating an AnimatedButton identical to login's (login_screen.dart:208-232). Keep the existing reauthenticateWithCredential logic unchanged.

---

### 58. Delete Account: re-authenticate in-flow instead of dead-ending on requires-recent-login

**Impact:** Medium | **Effort:** M | **Area:** Settings / Account

**Today:**

settings_screen_enhanced.dart:828-861 confirms deletion with a plain Cancel/Delete dialog, then _deleteAccount (lines 864-923) calls user.delete() (line 904) without re-authenticating. Firebase requires a recent login for deletion, so for any session older than a few minutes the flow fails and the user is told 'Please log out and log in again before deleting your account' (lines 932-935) â€” a dead end on the app's most sensitive action. The code already knows the correct pattern: change-password re-authenticates at lines 767-772.

**Proposal:**

Add a password field to the delete confirmation dialog and call reauthenticateWithCredential before the anonymize-and-delete batch, mirroring the existing change-password flow. The password entry doubles as a deliberate-friction confirmation for a destructive action (stronger than a second tap on 'Delete'), and the flow succeeds on the first attempt every time instead of bouncing users to a logout round-trip.

**How:**

In _showDeleteAccountConfirmation add an obscured TextFormField ('Enter your password to confirm'); on Delete: final cred = EmailAuthProvider.credential(email: user.email!, password: entered); await user.reauthenticateWithCredential(cred); then run the existing anonymization batch (lines 887-901) and user.delete(). Map wrong-password to an inline field error rather than a SnackBar so it renders above the dialog barrier.

---

### 59. Repoint ThemeHelper at ColorScheme roles (and fix theme-blind widgets like the gauge needle)

**Impact:** Medium | **Effort:** M | **Area:** Theming architecture

**Today:**

ThemeHelper.getCardColor/getTextColor/getSecondaryTextColor/getIconColor (lib/utils/theme_helper.dart:16-38) branch on brightness and return fixed AppTheme constants, bypassing ColorScheme entirely. With 300+ call sites (51 in analytics_screen alone), this hard-wires the app to exactly two surface palettes and guarantees any ColorScheme improvement (like fromSeed) never reaches most of the UI. Related theme-blindness: the decibel gauge needle and hub are painted AppTheme.primaryPurple regardless of the user's selected theme color (lib/widgets/decibel_meter_gauge.dart:96, 208, 221), so a Green-themed app still has a purple needle on its centerpiece widget.

**Proposal:**

Keep the ThemeHelper API (so 300+ call sites keep compiling) but reimplement each getter to read scheme roles: getCardColor â†’ surfaceContainerHigh, getTextColor â†’ onSurface, getSecondaryTextColor â†’ onSurfaceVariant, getDividerColor â†’ outlineVariant. Pass Theme.of(context).colorScheme.primary into DecibelMeterGauge's painters instead of the static purple. The entire app then responds correctly to theme-color changes and any future scheme tuning, with zero call-site churn.

**How:**

theme_helper.dart: `static Color getCardColor(BuildContext c) => Theme.of(c).colorScheme.surfaceContainerHigh;` etc. Ensure generateDark/LightTheme set those roles to today's exact hex values first (surfaceContainerHigh: cardBackground / lightCardBackground) so this lands as a pure refactor with no visual diff, then tune. For the gauge, add a `Color accentColor` field to GaugePainter/NeedlePainter constructors, supplied from the widget's build context.

---

### 60. Paginate the community feed and replace the fake pull-to-refresh

**Impact:** Medium | **Effort:** L | **Area:** community_feed_screen.dart

**Today:**

The feed is a live StreamBuilder over the newest 100 documents (lib/screens/community_feed_screen.dart:62-67): every screen open costs 100 document reads regardless of how far the user scrolls, anything older than the 100th report is unreachable, and the RefreshIndicator's onRefresh is a cosmetic 500 ms delay (lines 157-162). Because it is a live stream, new community reports also insert at the top and yank the list downward while someone is reading.

**Proposal:**

Switch to cursor pagination (20 per page, matching History's pattern) with a real refresh, and use a lightweight listener only to show a floating 'N new reports' pill that scrolls to top and reloads when tapped. Reads per session drop from a flat 100 to ~20 for typical usage (a direct Firestore cost saving at scale), older reports become reachable, and the reading position stops jumping.

**How:**

Mirror history_screen.dart's pagination scaffolding: _reports list, _lastDocument cursor, ScrollController threshold loader, using .orderBy('timestamp', descending: true).limit(20).startAfterDocument(cursor).get() â€” timestamp-only ordering uses Firestore's automatic single-field index, no composite needed. onRefresh re-runs the first-page query. For the new-reports pill: after first load, listen to .where('timestamp', isGreaterThan: newestLoadedTimestamp).limit(1).snapshots() and when non-empty show an AnimatedSlide chip ('New reports â€” tap to refresh') anchored below the AppBar; on tap, jumpTo(0) and reload page one, then re-arm the listener.

---

### 61. Full Material 3 typography ramp; retire raw fontSize TextStyles

**Impact:** Medium | **Effort:** L | **Area:** Typography

**Today:**

The theme defines only 4 text styles (headlineLarge/Medium, bodyLarge/Medium â€” app_theme.dart:101-120), so screens fall back to 220 inline `TextStyle(...)` constructions versus just 14 textTheme references. The result is 17 distinct font sizes in use including one-off 9/10/11/13/15/22px values, and hierarchy drift: card titles are 16-bold in one screen (history_screen.dart:557-561), 14-w700 in another (analytics_screen.dart:414-419). Nothing responds to the user's system font-size setting in a coordinated way.

**Proposal:**

Define the full M3 ramp in both generated themes, mapped from the observed clusters (display 32, headline 24, title 20/16, body 16/14, label 12/11), with colors baked in (onSurface / onSurfaceVariant) so call sites don't restate color. Then sweep screens replacing `TextStyle(color: ThemeHelper.getTextColor(context), fontSize: 16, fontWeight: w600)` with `Theme.of(context).textTheme.titleMedium`. Text hierarchy becomes consistent across all 15 screens, and future rebrands (font family, sizes) become a single-file change. Optionally adopt google_fonts for a distinctive brand face at the same time.

**How:**

In generateDark/LightTheme build `textTheme: Typography.material2021().white.copyWith(titleMedium: ..., labelSmall: ...)` applied with `.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)`. Do the sweep screen-by-screen (start with dashboard + analytics, the most-seen screens); add a `context.text` extension (`extension on BuildContext { TextTheme get text => Theme.of(this).textTheme; }`) to keep call sites short. Sizes below 11px (the 9/10px labels in heatmap_settings_panel.dart:269) should move up to labelSmall for legibility.

---

### 62. Donation: put the amount on the CTA, validate inline, and check config upfront

**Impact:** Low | **Effort:** S | **Area:** Donation

**Today:**

donation_screen.dart:343-371: the CTA always reads 'Donate with PayPal' regardless of the selected amount, and stays enabled even when the custom amount is empty or unparseable â€” errors only appear after tapping (validation at lines 36-41). The PayPal and Buy Me a Coffee credential checks also run only at tap time (lines 44-50, 67-75), so on an unconfigured build a user selects an amount, reads the impact message, and only then learns donating is impossible. The custom TextField (lines 292-309) gives no inline feedback for invalid input.

**Proposal:**

Three small tightenings: dynamic CTA label ('Donate $10 with PayPal') so the user confirms the exact charge at the moment of commitment â€” a standard checkout-conversion pattern; disable the button while the resolved amount is invalid; and evaluate credential configuration in initState so unavailable methods are hidden or annotated before any effort is invested.

**How:**

double? _resolvedAmount() from existing state; ElevatedButton(onPressed: (_resolvedAmount() ?? 0) >= DonationService.minimum ? _donate : null, label: Text(amt != null ? 'Donate \$${amt.toStringAsFixed(0)} with PayPal' : 'Select an amount')). Custom field: errorText in InputDecoration when text.isNotEmpty && double.tryParse == null. In initState compute _paypalConfigured / _bmcConfigured from the same clientId/url checks currently inline at lines 44-45 and 67-68, and conditionally render the cards.

---

### 63. Edit Profile: keep the form visible while saving instead of a full-screen spinner swap

**Impact:** Low | **Effort:** S | **Area:** Edit Profile

**Today:**

edit_profile_screen.dart:218-224 replaces the entire body with a centered CircularProgressIndicator whenever _isLoading is true, so the user's entered values vanish mid-save. This also makes the Save button's own spinner branch (lines 395-403) unreachable dead UI, since the button is unmounted the moment loading starts.

**Proposal:**

Keep the form mounted during save: disable inputs and buttons and let the Save button's existing inline spinner do its job. The user retains visual context of what they submitted, and a failed save (e.g. requires-recent-login, lines 178-181) returns them to an intact form instead of a re-rendered one.

**How:**

Delete the _isLoading ternary at the body level; wrap the Form's Column in AbsorbPointer(absorbing: _isLoading) (or set enabled: !_isLoading on both TextFormFields and onPressed: null on Cancel while saving). The Save button already renders the spinner when _isLoading â€” no other change needed.

---

### 64. Pagination affordances: end-of-list marker and load-more error retry

**Impact:** Low | **Effort:** S | **Area:** history_screen.dart

**Today:**

Infinite scroll loads silently 200 px before the end (lib/screens/history_screen.dart:161-167). When the final page arrives, the bottom spinner row simply disappears (itemCount drops the +1 at line 435) with no signal that everything is loaded, and a failed _loadMoreRecordings deliberately swallows the error (comment at line 155) â€” the list just stops growing with no way to retry except pull-to-refresh from the top of a long list.

**Proposal:**

Always render a footer row with three states: shimmer/spinner while loading, 'All N recordings loaded' with a check icon when _hasMore is false, and 'Couldn't load more â€” Retry' button when the last page fetch failed. Users of long histories stop wondering whether the app froze.

**How:**

Add bool _loadMoreFailed; set true in the catch of _loadMoreRecordings, clear on retry. Change itemCount to _recordings.length + 1 and make the footer builder switch on (_isLoading, _hasMore, _loadMoreFailed): loading -> existing spinner (437-447); failed -> TextButton.icon(Icons.refresh, 'Retry', onPressed: _loadMoreRecordings); done -> Padding(Text('All $_totalCount recordings loaded', secondary text style)). About 20 lines total.

---

### 65. Equalizer-bounce splash logo instead of static bars

**Impact:** Low | **Effort:** S | **Area:** lib/screens/splash_screen.dart

**Today:**

The splash screen already runs a 1500ms fade-in AnimationController (splash_screen.dart:23-33) over a hand-built sound-wave icon, but the three sound bars are fixed-height Containers (heights 40/60/40, :95-129) sitting still for the full 3-second Timer (:36-42) before navigation. A sound-visualization app opens on a frozen equalizer.

**Proposal:**

Animate the three bars like a live equalizer â€” each oscillating its height out of phase â€” for the 3 seconds the user is already forced to wait. It turns dead wait time into brand expression ('Visualize your sound environment', the literal subtitle at :80) at near-zero cost, reusing the controller that already exists.

**How:**

Reuse _animationController but set duration: 900ms and ..repeat(reverse: true) after the initial forward() completes (await _animationController.forward(); then repeat). Drive each bar with a phase-shifted CurvedAnimation: Interval-free approach â€” height_i = base_i + 20 * sin((controller.value + i * 0.33) * pi), computed in an AnimatedBuilder wrapping the Row; bars stay rounded Containers, only height changes. Alternatively three Intervals (0-0.6, 0.2-0.8, 0.4-1.0) with Curves.easeInOut for a wave that travels left to right. When Motion.reduced(context), skip repeat and keep the current static bars â€” the existing fade already covers entrance.

---

### 66. AnimatedSwitcher state changes and success pop on the sync status indicator

**Impact:** Low | **Effort:** S | **Area:** lib/widgets/sync_status_indicator.dart

**Today:**

SyncStatusIndicator polls every 2 seconds (sync_status_indicator.dart:30-33) and rebuilds a four-state icon (syncing spinner / offline cloud / pending upload / green done, :75-129) inside a plain Container whose tint color also changes per state (:105-111). Every transition â€” including the meaningful one, 'your queued recordings just uploaded' â€” is an instant icon swap in the app bar that users never notice.

**Proposal:**

Animate the state changes so sync activity registers peripherally: scale+fade between icons, ease the pill's tint, and give the offline->synced transition a brief elastic pop of the green check. For an offline-first field app, quietly confirming 'your data made it to the cloud' builds trust without a SnackBar interruption.

**How:**

Wrap the icon/spinner slot in AnimatedSwitcher(duration: 250ms, transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)), child: KeyedSubtree(key: ValueKey(icon.codePoint or a state enum), child: currentIcon)). Convert the pill Container (:105) to AnimatedContainer(duration: 300ms) so color: iconColor.withValues(alpha: 0.1) tweens. Track the previous state in the State class; when previous had pendingCount > 0 and new state is 'all synced', render the check inside AnimatedScale(scale: 1, duration: 500ms, curve: Curves.elasticOut) starting from 0.6 (one-shot flag reset after build). All durations via Motion.scale.

---

### 67. Delete the dead duplicate themes and demo widget; memoize generated ThemeData

**Impact:** Low | **Effort:** S | **Area:** Theme code health / performance

**Today:**

app_theme.dart:208-364 contains static `darkTheme`/`lightTheme` marked 'kept for backward compatibility' â€” grep confirms zero references anywhere in lib/, yet they duplicate ~160 lines that must be kept in sync with the generate* functions by hand. main.dart:183-267 still carries the Flutter counter-demo MyHomePage, also unreferenced. And MyApp regenerates both full ThemeData objects on every ValueListenableBuilder rebuild (main.dart:141-142), including rebuilds triggered by the unrelated ThemeMode notifier.

**Proposal:**

Remove the two dead static themes and MyHomePage (~250 lines), leaving generateDark/LightTheme as the only theme definition â€” future theme edits happen in exactly one place, which directly de-risks every other recommendation here. Cache generated themes per color so toggling dark/light mode doesn't rebuild two ThemeData graphs.

**How:**

Delete app_theme.dart:208-364 and main.dart:183-267. Memoize: `static final _darkCache = <int, ThemeData>{}; static ThemeData generateDarkTheme(Color c) => _darkCache.putIfAbsent(c.toARGB32(), () => _buildDark(c));` (8 possible colors, so the cache is tiny). Run `flutter analyze` to confirm no references break.

---

### 68. Hero transitions: History FAB into Report screen, Dashboard community card into Community Feed

**Impact:** Low | **Effort:** M | **Area:** lib/screens/history_screen.dart, lib/screens/report_noise_screen.dart, lib/screens/dashboard_screen.dart, lib/screens/community_feed_screen.dart

**Today:**

There are no Hero widgets in the app (grep confirms; only heatmap_fab.dart:22 sets a heroTag to dedupe FABs). History's 'Add Manual' FloatingActionButton.extended pushes ReportNoiseScreen via plain MaterialPageRoute (history_screen.dart:478-491); the Dashboard community card with its 56px circular people-icon (dashboard_screen.dart:946-958) pushes CommunityFeedScreen with a FadePageRoute (:919-924) that shares no visual element with the destination.

**Proposal:**

Add two cheap, high-legibility shared-element transitions: the FAB morphing into the Report screen's header card (FloatingActionButton ships with built-in Hero support â€” it only needs a matching tag on the other side), and the community people-circle flying into the Community Feed app bar. Shared elements teach navigation structure ('this thing became that screen') and are the standard Material pattern for FAB->form flows.

**How:**

FAB->Report: give the FAB heroTag: 'add-manual' (history_screen.dart:478) and in ReportNoiseScreen wrap the waveform header container (:494-506 call site at :281) in Hero(tag: 'add-manual', child: Material(type: MaterialType.transparency, child: ...)); use a MaterialPageRoute or MaterialRectArcTween default â€” the FAB's circular shape morphing into the rounded card is handled by Hero's default flightShuttleBuilder; for a cleaner morph provide createRectTween: (b, e) => MaterialRectArcTween(begin: b, end: e). Dashboard->Feed: wrap the 56px icon Container (dashboard_screen.dart:946) in Hero(tag: 'community-icon') and place a matching small Hero-wrapped icon in CommunityFeedScreen's AppBar leading/title row. Keep FadePageRoute â€” Hero flights run across PageRouteBuilder transitions automatically.

---

## Suggested Implementation Order

### Wave 1 - Quick wins (S effort, 28 items)

- [ ] [High] Insight callout card: quietest/loudest hour and day
- [ ] [High] Compute on-colors instead of hardcoding white text on primary-colored surfaces
- [ ] [High] App-wide haptic vocabulary: threshold crossing, save success, nav taps
- [ ] [High] Ship Forgot Password as a prefilled reset bottom sheet
- [ ] [High] Enable password-manager autofill and keyboard flow on all auth forms
- [ ] [High] Make the report dB slider self-explanatory with live category label and color
- [ ] [High] Skip onboarding for returning users and shorten the fixed 3-second splash
- [ ] [Medium] Annotate the trend chart: WHO guideline line and time-aware tooltips
- [ ] [Medium] Scope the sound-type filter chips to the sections they actually filter
- [ ] [Medium] History chart: threshold line, zone coloring, and axis context
- [ ] [Medium] Dark-mode tone variants for status/severity colors (one palette for the Pollution/Ambient badge)
- [ ] [Medium] Skeleton rows for history initial load
- [ ] [Medium] Entrance/exit choreography for the live sound-classification card
- [ ] [Medium] Animated count-up numbers for dashboard MIN/AVG/MAX and analytics stat grid
- [ ] [Medium] Respect reduced-motion: a Motion helper gating all repeating and decorative animation
- [ ] [Medium] Fix the stagger curve and extend list entrance animation to Community Feed
- [ ] [Medium] Motion tokens, one theme-level page transition, and reduced-motion support
- [ ] [Medium] Move logout out of the AppBar's prime position
- [ ] [Medium] Live recording feedback: elapsed timer and dB-driven pulse
- [ ] [Medium] Instant classification feedback with a 'listening' placeholder
- [ ] [Medium] Live password strength meter on registration and change-password
- [ ] [Medium] Make default-location submissions explicit on the report form
- [ ] [Low] Donation: put the amount on the CTA, validate inline, and check config upfront
- [ ] [Low] Edit Profile: keep the form visible while saving instead of a full-screen spinner swap
- [ ] [Low] Pagination affordances: end-of-list marker and load-more error retry
- [ ] [Low] Equalizer-bounce splash logo instead of static bars
- [ ] [Low] AnimatedSwitcher state changes and success pop on the sync status indicator
- [ ] [Low] Delete the dead duplicate themes and demo widget; memoize generated ThemeData

### Wave 2 - Next sprint (M effort, 36 items)

- [ ] [High] Add previous-period comparison deltas to analytics stat cards
- [ ] [High] Single source of truth for the dB semantic color scale via a NoiseColors ThemeExtension
- [ ] [High] Zone-banded gauge scale with status word
- [ ] [High] Group history by day with sticky date headers
- [ ] [High] Recording pulse rings and start/stop haptics on the record button
- [ ] [High] Spring-physics needle and smoothed readout on the decibel gauge
- [ ] [High] Time-range filter chips on the map
- [ ] [High] Map legend + data freshness chip
- [ ] [High] Reading detail sheet: add timestamp, zone framing, and actions
- [ ] [High] Bottom-anchored, always-reachable record control
- [ ] [High] Add permission priming screens before the mic and location OS dialogs
- [ ] [High] Post-recording session summary card
- [ ] [High] Replace the 17-item sound-class dropdown with a grouped chip grid
- [ ] [High] Generate full Material 3 ColorSchemes with ColorScheme.fromSeed for the 8 user-selectable theme colors
- [ ] [Medium] Replace analytics full-screen spinner with skeleton layout and add pull-to-refresh
- [ ] [Medium] Feed cards: surface sound classification and make cards tappable to the map
- [ ] [Medium] Explicit token scale for spacing, radius, and icon sizes
- [ ] [Medium] Profile avatar upload â€” photoURL is modeled but never populated
- [ ] [Medium] Semantic feedback tokens + one AppSnackBar helper to replace 75 ad-hoc SnackBars
- [ ] [Medium] Needle smoothing, peak-hold marker, and repaint hygiene
- [ ] [Medium] Make the Classification Guide reachable from the live classification card
- [ ] [Medium] Progressive disclosure for heatmap controls: tap toggles, long-press configures
- [ ] [Medium] Swipe-to-delete with undo instead of per-row delete icon + dialog
- [ ] [Medium] Draw-in animation for the analytics trend line and pie chart
- [ ] [Medium] Skeleton shimmer loading states for History list and Analytics (the ShimmerLoading widget already exists)
- [ ] [Medium] Live-reacting waveform and graded slider feedback on the manual report screen
- [ ] [Medium] Cross-fade tab switches in MainAppShell and animate the bottom-nav active state
- [ ] [Medium] Give the login 'OR' divider a purpose: Google sign-in
- [ ] [Medium] Cluster labels that carry noise information
- [ ] [Medium] Adopt M3 selection and button components: SegmentedButton for period filters, FilledButton hierarchy, themed chips
- [ ] [Medium] Pre-roll countdown and optional timed measurement
- [ ] [Medium] Regroup settings by domain, disable dependent toggles, and show current values on navigation rows
- [ ] [Medium] Delete Account: re-authenticate in-flow instead of dead-ending on requires-recent-login
- [ ] [Medium] Replace the Change Password AlertDialog with a proper validated form
- [ ] [Medium] Repoint ThemeHelper at ColorScheme roles (and fix theme-blind widgets like the gauge needle)
- [ ] [Low] Hero transitions: History FAB into Report screen, Dashboard community card into Community Feed

### Wave 3 - Larger initiatives (L effort, 4 items)

- [ ] [High] Extract a small design-system component library: AppCard, StatTile, SectionHeader, EmptyState, AppChipRow
- [ ] [High] Teach the record -> classify -> map value loop with an interactive onboarding walkthrough
- [ ] [Medium] Paginate the community feed and replace the fake pull-to-refresh
- [ ] [Medium] Full Material 3 typography ramp; retire raw fontSize TextStyles
