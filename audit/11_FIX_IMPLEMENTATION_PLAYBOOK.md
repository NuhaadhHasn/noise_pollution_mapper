# 11 — MASTER FIX IMPLEMENTATION PLAYBOOK

Master document for the executing AI (Claude Opus) applying the ten cluster
implementation specs in `audit/playbook/`. This file is the single entry point:
it fixes the execution order, resolves every shared-file conflict between
clusters, and defines what "done" means. The cluster specs contain the exact
BEFORE/AFTER edits; this document tells you the order to apply them in and the
adaptations required where clusters touch the same code.

Project root for all paths: `noise_pollution_mapper/`.

---

## 1. How to use this playbook

1. **Read this document fully first.** Then execute the cluster specs in the
   order given in §3, one spec at a time, front to back.
2. **One commit per step.** Every cluster spec is a sequence of numbered steps;
   each step is exactly one commit with the commit title given in the spec.
   Never merge steps, never split them. 58 cluster commits + 1 standalone
   test-quarantine commit (§6) = **59 commits total** (see §5 checklist).
3. **`flutter analyze` must be clean after every commit.** No exceptions. If
   analyze is not clean, fix it inside the same step before committing.
4. **Never run bare `flutter test` as a gate** until the final quarantine
   commit (§6). The suite has 53 pre-existing failures (audit finding arch-2).
   Gate each commit only on the test files named in that step's Verify section.
5. **Never re-audit.** Every finding in the cluster specs was adversarially
   verified (evidence in `audit/00_MASTER_AUDIT_REPORT.md` and the per-domain
   audit docs 01–07). Do not re-derive findings, do not second-guess verified
   BEFORE blocks, and do not drive-by fix things listed in a spec's
   "Out of scope" section.
6. **If a BEFORE block does not match**, STOP. First check §4 of this document
   — most mismatches are caused by an earlier cluster having legitimately
   edited the same region, and §4 tells you exactly how to adapt. Only if §4
   has no entry for that file/region should you re-read the file and adapt the
   edit semantically (preserving every earlier cluster's change). Never revert
   another cluster's work to make an anchor match. Match on exact text, never
   on line numbers (they drift after every step).
7. **Revert discipline:** each step is an independently revertible commit, but
   later steps' BEFORE anchors build on earlier steps' AFTER text — when
   reverting multiple steps, revert tail-first (newest first).
8. **Server-side actions** (Firestore doc seeding, rules deploy, keystore
   creation) are flagged inside the specs; they are deliberate manual actions,
   not commits. Track them in the §6 done-checklist.

---

## 2. Global conventions (verbatim — every step of every cluster must respect these)

1. **Firestore index rule (CRITICAL):** The ONLY composite index is
   `noise_readings (userId ASC, timestamp DESC)`. Every per-user period query
   uses `where('userId', isEqualTo: uid)` + `isGreaterThan` +
   `orderBy('timestamp', descending: true)` — **never
   `isGreaterThanOrEqualTo`**. No step in any cluster adds or requires a new
   composite index. `firestore.indexes.json` (created in cluster 04 Step 5)
   codifies exactly this one index and nothing else.
2. **Colors:** All UI colors via `ThemeHelper.getX(context)` or existing
   `AppTheme` constants — no new hardcoded colors. Alpha via
   `color.withValues(alpha: …)`, **never** `withOpacity`. (Pre-existing
   hardcoded colors in untouched regions are left alone; findings dash-19/20,
   donate-16 etc. are out of scope.)
3. **Dual timestamp writes:** New `noise_readings` documents carry both
   `timestamp` (`FieldValue.serverTimestamp()`) and `createdAt` (client
   `DateTime`); readers handle both. **Documented sole exception:** the
   offline-sync writer (`SyncService._saveToFirebase`, cluster 02 Step 5)
   writes `timestamp: Timestamp.fromDate(recording.timestamp)` so offline
   readings land on the correct day — do not "fix" this back.
4. **MainAppShell IndexedStack tab indices:** Map=0, Analytics=1, Dashboard=2
   (home), History=3, Settings=4. All five children are constructed with
   `isInAppShell: true`. Screens stay mounted when hidden (IndexedStack) —
   `dispose()` is not a "screen hidden" hook.
5. **Classification confidence threshold is 0.30** (enforced by cluster 06
   Step 4; below-threshold results become live-only `Uncertain` and are never
   persisted). No other cluster may drift this value.
6. **Logging via `AppLogger`** (`lib/utils/app_logger.dart`) — never `print`.
7. **`flutter analyze` clean after every commit.**
8. **Test gating:** only the per-step named test files gate commits (arch-2:
   53/149 tests fail for pre-existing reasons) until the final quarantine
   commit makes the whole suite green (§6).

---

## 3. Execution order

### 3.1 Order and rationale

| # | Cluster | Spec file | Steps | Session (1M ctx) | Why here |
|---|---------|-----------|-------|------------------|----------|
| 1 | 01 Platform & Release Blockers | `playbook/01_platform_release_blockers.md` | 6 | **S1** · ~56K | Independent; unblocks everything (guarded boot, signing, secrets removal). Its `main.dart` restructure (Step 6) must land before 09 touches `main.dart`. Its DonationService rework (Step 4) must land before cluster 10. |
| 2 | 02 Offline Storage & Sync Overhaul | `playbook/02_offline_sync_overhaul.md` | 7 | **S1** · ~68K | Foundation: `OfflineRecording.userId/userEmail`, foreign-entry skip, deterministic doc IDs, auth-listener sync. Hard prerequisite of 03 Step 4; its `firebase_service.dart` edits must precede 04's rewrite of `saveNoiseReading`. |
| 3 | 03 Account Lifecycle | `playbook/03_account_lifecycle.md` | 4 | **S1** · ~105K | Step 4 hard-depends on 02 being FULLY applied (its BEFORE blocks are the post-02 `sync_service.dart`). Lands its `main_app_shell.dart` edit before 05 and 08 touch that file. |
| 4 | 04 Data Layer, Privacy & Security Rules | `playbook/04_data_layer_privacy.md` | 5 | **S1** · ~104K | Rewrites `saveNoiseReading` (must adapt to 02 — see §4.2). Its dashboard save-timer edit (Step 1d) is the base the 05/06/09 timer edits build on. Rules (Step 5) must be authored knowing every write path that exists after 01–03. |
| 5 | 05 Recording Pipeline & Dashboard | `playbook/05_recording_pipeline.md` | 7 | **S2** · ~78K | Heaviest `dashboard_screen.dart` cluster; goes after 04 (see §4.3) and before 06/09, and 09 explicitly mandates "apply 05 first". Its `main_app_shell.dart` edit (Step 3b) goes after 03's and before 08's. |
| 6 | 06 YAMNet Classification Correctness | `playbook/06_classification_ml.md` | 6 | **S2** · ~150K | Its dashboard edit (Step 4g) adapts to the post-04/05 save timer (§4.3). Its `analytics_screen.dart` filter edit (Step 6) lands before 07's structural analytics rewrite so 07's import/method anchors still match. |
| 7 | 07 Analytics & History Correctness | `playbook/07_analytics_history.md` | 7 | **S2** · ~87K | `analytics_screen.dart` after 06; `history_screen.dart` after 04 Step 3 (different methods — CSV export vs load/delete/empty-state; only an import-anchor shift, §4.6). Adds service methods next to `getUserReadingsCount` — region untouched by 02/04. |
| 8 | 08 Map & Search | `playbook/08_map_search.md` | 5 | **S3** · ~84K | Step 5 REPLACES `main_app_shell.dart` in full — must come after 03 (Step 3c) and 05 (Step 3b) and must be applied as a MERGE, not verbatim (§4.4 — the single most dangerous cross-cluster edit in this playbook). |
| 9 | 09 Settings: Wire or Remove Dead Controls | `playbook/09_settings_wiring.md` | 5 | **S3** · ~93K | Spec itself mandates: apply 05 first (Steps 3–4 edit the same `_startRecording`/`_stopRecording` regions). Also adapts to 01's `main.dart` restructure (§4.5) and 03's settings-screen edits (import anchors). |
| 10 | 10 Donation & PayPal WebView | `playbook/10_donation_webview.md` | 6 | **S3** · ~59K | Lowest coupling; after 01 because DonationService config now comes from Firestore, not `.env` (§4.7). Manifest edits don't collide with 09's (different regions). |
| — | Standalone final commit: arch-2 test quarantine | this document, §6 | 1 | **S3** · ~10K | Runs LAST because clusters 06 and 09 rewrite/fix test files that would otherwise be quarantined prematurely. |

### 3.2 Hard dependencies (must not be violated)

- **02 → 03 Step 4** (foreign-owner skip, `_onAuthStateChanged`, userId tagging).
- **03 Step 1 → 03 Steps 2–3** (`FirestoreBatchUtils`).
- **01 Step 4 → 01 Step 6** (both edit `main.dart`; Step 6's BEFORE assumes post-Step-4 state).
- **06 Step 1 → 06 Steps 2–3** (official CSV class map).
- **07 Step 1 → 07 Step 3** (Duration formula carried into `_applySnapshot`).
- **10 Step 2 → 10 Steps 3–4** (`PaymentUrlUtils`).
- **02 → 04 Steps 1–2**, **04+05 → 06 Step 4g**, **05 → 09 Steps 3–4**,
  **03+05 → 08 Step 5**, **01 → 09 Step 5e**, **01 → 10** — all soft
  dependencies with explicit adaptations in §4.

### 3.3 Shared-file conflict table

Built from the specs' touched files. "Later must re-check" = the later
cluster's BEFORE anchors will NOT match verbatim; apply the referenced §4 note.

| File | Touched by (in execution order) | First | Later cluster must re-check |
|------|--------------------------------|-------|------------------------------|
| `lib/main.dart` | 01 (S4, S6), 09 (S5e) | 01 | 09: insert re-sync inside `_initializeOptionalServices()` — §4.5 |
| `lib/services/firebase_service.dart` | 02 (S2e, S7e/f), 04 (S1, S2), 07 (S6a) | 02 | 04 S1: preserve `SyncService().notifyQueued()` + import — §4.2. 07 S6a: region (`getUserReadingsCount`) untouched by 02/04 — should match verbatim |
| `lib/services/sync_service.dart` | 02 (S3–S7), 03 (S4c/d) | 02 | 03's BEFORE blocks are written against post-02 state — they only match AFTER 02 |
| `lib/screens/dashboard_screen.dart` | 03 (S4a/b), 04 (S1d, S4), 05 (all), 06 (S4g), 09 (S3, S4) | 03 | 03 edits only the logout IconButton (no overlap). 04→05→06→09 all edit `_startRecording`/save timer — §4.3 gives the composite target shape |
| `lib/widgets/main_app_shell.dart` | 03 (S3c), 05 (S3b), 08 (S5 full-file replace) | 03 | 08 S5 must be applied as a MERGE — §4.4 |
| `lib/screens/settings_screen_enhanced.dart` | 03 (S1b/c, S2), 09 (S1, S2, S4, S5d) | 03 | 09's import anchors shifted by 03's added imports (`firestore_batch_utils`, `app_logger`); regions otherwise disjoint (03: delete-account/clear-history; 09: fields/_loadSettings/toggles) |
| `lib/screens/analytics_screen.dart` | 06 (S6b/c), 07 (S1–S3) | 06 | 07's anchors still match post-06 (verified: 06 adds one import mid-block and edits `_buildSoundCategoryBreakdown` only) |
| `lib/screens/history_screen.dart` | 04 (S3), 07 (S4–S7) | 04 | 07 S4a import anchor shifted by 04's added imports (`foundation`, `csv_builder`) — insert `app_logger` import into the current import block; methods edited are disjoint |
| `lib/screens/report_noise_screen.dart` | 04 (S1c) only | — | 06 references its values read-only |
| `lib/screens/donation_screen.dart`, `lib/services/donation_service.dart` | 01 (S4) only | — | 10 consumes `DonationService.clientId/isSandboxMode` — names unchanged post-01 |
| `android/app/src/main/AndroidManifest.xml` | 09 (S5b: permissions + receivers), 10 (S6: `<queries>`) | 09 | Different regions; 10's `<queries>` anchor unaffected by 09 |
| `pubspec.yaml` | 01 (S4: remove dotenv + `.env` asset), 09 (S5a: add timezone pkgs) | 01 | No overlap (different blocks) |
| `lib/utils/theme_helper.dart` | 02 (S6f) only | — | — |
| `lib/utils/shared_app_state.dart` | 05 (S3a) only | — | 08's shell merge depends on it existing (§4.4) |
| `firestore.rules` / `firebase.json` etc. | 04 (S5) only | — | Must ALSO include 01's `app_config` rule — §4.1 |
| `test/widget/settings_screen_test.dart` | 09 (S2e rewrite) | — | Final quarantine commit must not re-skip it |
| `test/unit/sound_classification_test.dart` | 06 (S4h, S6d) | — | Same |

---

### 3.4 Session batching for a 1M-context window

**Bottom line: the whole playbook fits in 3 sessions of a 1M-context model.**
Clusters must stay in the §3.1 order (the dependencies are sequential), so every
batch is a *contiguous* run of clusters. Do not reorder to balance sessions.

| Session | Clusters | Commits | Est. context | % of 1M |
|---------|----------|---------|--------------|---------|
| **S1** | 01 → 02 → 03 → 04 | 22 | ~333K | ~33% |
| **S2** | 05 → 06 → 07 | 20 | ~315K | ~32% |
| **S3** | 08 → 09 → 10 + final quarantine commit | 17 | ~236K | ~24% |

Where the estimate comes from, per cluster: the spec file plus every source file
its steps must read, at ~270 tokens/KB, times ~2.5 for real working overhead
(re-reads after edits, `flutter analyze` output, test runs, failed-anchor
retries) — plus ~30K fixed per session for system prompt, tool schemas, memory
and this document. Cluster 06 is the single heaviest (~150K) because it must read
`yamnet_class_mapping.dart` (48KB), `analytics_screen.dart` (41KB) and
`dashboard_screen.dart` (42KB); never batch 06 with more than two neighbours.

**Rules for whoever executes this:**

1. **Never start a cluster you cannot finish in the current session.** A
   half-applied cluster leaves the repo in a state no later BEFORE block
   matches. Above ~70% context, stop at the last completed commit and open a
   new session — the git log is the resume pointer.
2. **One commit per step, always.** `flutter analyze` clean before each commit
   (§2). Never merge two steps into one commit to save context.
3. **Drop stale copies between clusters.** Nothing from a finished cluster is
   needed later except what §4 explicitly calls out. Re-read files fresh in the
   next cluster — the post-edit file on disk is the truth, not the copy in
   context.
4. **Do NOT use plan mode for these clusters.** The spec *is* the plan (exact
   BEFORE/AFTER blocks, acceptance criteria, verify commands); plan mode would
   re-derive it and burn 20–40% of the window for nothing. Use plan mode only
   for the three genuinely open decisions the specs flag: 06's below-threshold
   behaviour (`Uncertain` vs `lowConfidence:true`), 09's wire-or-remove call per
   dead setting, and 04 Step 5's rules review before deploy.
5. **Aggressive alternative (2 sessions):** 01–05 (~410K) then 06–10 (~473K).
   It fits, but leaves no headroom for a bad edit run — only take it if the
   early clusters apply cleanly with no anchor mismatches.
6. **Ultra-safe alternative (10 sessions):** one cluster per session, ~60–150K
   each. Use this if a human reviews each cluster's diff before the next.

**Parallelism:** these clusters **cannot** be run concurrently by multiple
agents. Six of the ten share `dashboard_screen.dart`,
`settings_screen_enhanced.dart`, `main_app_shell.dart` or
`firebase_service.dart`, and the later BEFORE anchors are written against the
earlier clusters' output (§3.3). Sequential execution is not a performance
preference here — it is a correctness requirement.

---

## 4. Cross-cluster interactions and required adaptations

These are interactions the individual specs call out plus gaps only visible
when reading all ten together. Each is mandatory.

### 4.1 Firestore rules must include the `app_config` read rule (01 ↔ 04)

Cluster 01 Step 4 serves donation config from Firestore doc
`app_config/donations` and specifies the required rule (01, "Server-side"
note 9). Cluster 04 Step 5 authors `firestore.rules` with a deny-all catch-all
— **as written, deploying 04's rules breaks the donation feature**
(permission-denied → permanent "not configured"). When executing 04 Step 5,
add this block to `firestore.rules` (between the `users` match and the
catch-all), and include it in the same commit:

```
    // Donation display config (cluster 01 Step 4): read-only, authenticated.
    match /app_config/{docId} {
      allow read: if isSignedIn();
      allow write: if false;
    }
```

Also verify during 04 Step 5's smoke pass: Settings → Support This Project →
Donate opens the PayPal webview (with the doc seeded).

### 4.2 `saveNoiseReading` rewrite must preserve 02's sync trigger (02 → 04 Step 1)

04 Step 1's BEFORE block for `saveNoiseReading` was copied from the
pre-cluster-02 tree. After 02 Step 7, the fallback path contains
`SyncService().notifyQueued();` and the file imports `sync_service.dart`.
Adaptation when applying 04 Step 1:

- Keep the `import 'sync_service.dart';` line (02 Step 7e).
- In 04's new merged offline/fallback block, after a successful
  `await _saveOffline(...)` and its log line, add `SyncService().notifyQueued();`
  before `return SaveOutcome.queuedOffline;`. `notifyQueued()` self-guards on
  `_isInitialized && _isOnline && !_isSyncing`, so calling it on the
  genuinely-offline path too is a harmless no-op — one call site is fine.

**Privacy follow-through (02 Step 2e ↔ 04 Step 2):** 04 Step 2's edge note
says the sync path "does NOT write userEmail" — true pre-02, false post-02
(02 Step 5 writes `recording.userEmail ?? _auth.currentUser?.email`). To keep
sec-2 masking consistent for offline-synced docs, when applying 04 Step 2 also
change `_saveOffline`'s recording construction (02 Step 2e's AFTER):

```dart
      userId: userId,
      userEmail: _auth.currentUser?.email,
```
becomes
```dart
      userId: userId,
      userEmail: authorLabel(
        displayName: _auth.currentUser?.displayName,
        email: _auth.currentUser?.email,
      ),
```

(`authorLabel` is in the same file.) New queue entries then carry the masked
label; `SyncService` writes it verbatim. Accepted residual: legacy queue
entries written between 02 and 04 keep a raw email in Hive and sync it once —
document in the 04 Step 2 commit body, do not build a migration.

### 4.3 The dashboard save-timer composite (04 → 05 → 06 → 09)

Four clusters edit `_startRecording` / the `_saveTimer` block. Apply in the
order 04 → 05 → 06 → 09 with these adaptations (each spec's own
"If playbook X already applied" notes still apply):

- **05 Step 1b** deletes the mid-method `setState(() { _isRecording = true; })`
  block — post-04 that block also contains `_hasShownSaveErrorSnackbar = false;`.
  Move that reset into 05 Step 1a's new synchronous setState at the top:
  `setState(() { _isRecording = true; _hasShownSaveErrorSnackbar = false; });`
- **05 Steps 2d and 3h** show the pre-04 timer body. Post-04 the save call is
  wrapped in `.then((outcome) {...})`. Insert the GPS gate and the stall gate
  immediately after `if (!_isRecording || !mounted) return;` and before
  `if (_currentDb > 0 && _currentDb.isFinite)`, leaving the `.then` chain
  untouched; apply `locationName: _locationNameIsStatus ? null : _locationName`
  inside the wrapped call.
- **06 Step 4g**'s BEFORE is the original save call. Post-04/05, apply
  semantically: compute
  `final classification = (_currentClassification?.meetsThreshold ?? false) ? _currentClassification : null;`
  directly above the `_firebaseService.saveNoiseReading(` call (inside the
  `if (_currentDb > 0 ...)` branch) and pass `classification?.category`,
  `classification?.soundType`, `classification?.confidence`. Keep the `.then`
  outcome handling byte-identical.
- **09 Step 3a — SKIP the import edit**: 05 Step 5a already added
  `import 'package:shared_preferences/shared_preferences.dart';` to
  `dashboard_screen.dart`. Adding it again is an analyzer error.
- **09 Step 3b**: insert the `prefs`/`saveFrequencySeconds` lines immediately
  above the (post-04/05/06) `_saveTimer = Timer.periodic(...)` creation and
  replace only `const Duration(seconds: 5)` with
  `Duration(seconds: saveFrequencySeconds)`. Do not touch the timer body.
- **09 Step 4e** ("auto-stop after last timer creation") uses that same
  `prefs` variable; place it after the classification timer, before `} catch`.
  09 Step 4f (`_stopRecording` cancels) should match — 05 does not edit
  `_stopRecording`'s head; if 05's Step 1 rollback block confuses matching,
  put `_autoStopTimer?.cancel(); _autoStopTimer = null;` alongside
  `_saveTimer?.cancel();`.

Target final shape of the timer callback (for verification, not verbatim):
guard → GPS gate (05) → stall gate (05) → `if (_currentDb > 0 ...)` →
threshold-gated classification (06) → `saveNoiseReading(...)` with sanitized
locationName (05) → `.then` failure snackbar (04); interval from
`save_frequency` (09).

### 4.4 `main_app_shell.dart`: 08 Step 5 is a MERGE, never a verbatim replace (03 + 05 + 08)

08 Step 5 says "replace the FULL file contents" — written before 03 and 05
landed their shell edits. Pasting 08's file verbatim would silently delete:

- 03 Step 3c: `import 'dart:async';`, `import '../services/profile_sync_service.dart';`,
  and `unawaited(ProfileSyncService().reconcileUserEmail());` in `initState`
  → email reconciliation (settings-9/flow6-06) never runs again.
- 05 Step 3b: `import '../utils/shared_app_state.dart';`,
  `SharedAppState.currentTabIndex.value = widget.initialIndex;` in `initState`,
  and `SharedAppState.currentTabIndex.value = index;` in `onTap`
  → the dashboard stop-on-tab-switch (dash-6) silently dies: the dashboard
  listens to a notifier that never fires again. **This would be an invisible
  regression — no analyzer error, no test failure.**

Required merged result (08's structure + 03's + 05's lines):

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/map_view_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen_enhanced.dart';
import '../services/profile_sync_service.dart';
import '../utils/shared_app_state.dart';
import 'shared_bottom_navbar.dart';
```

`initState`:
```dart
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SharedAppState.currentTabIndex.value = widget.initialIndex;
    // settings-9/flow6-06 (cluster 03): reconcile verified Auth email.
    unawaited(ProfileSyncService().reconcileUserEmail());
  }
```

`onTap`:
```dart
          onTap: (index) {
            final previousIndex = _currentIndex;
            SharedAppState.currentTabIndex.value = index;   // dash-6 (cluster 05)
            setState(() {
              _currentIndex = index;
            });
            // map-2 (cluster 08): reload map data on Map-tab activation.
            if (index == 0 && previousIndex != 0) {
              _mapKey.currentState?.refreshMapData();
            }
          },
```

Everything else (GlobalKey field, `MapViewScreen(key: _mapKey, isInAppShell: true)`,
PopScope, IndexedStack, `isInAppShell: true` on all five children) as 08
specifies. After the merge, re-run 05 Step 3's acceptance check (start
recording → switch tab → "Dashboard hidden by tab switch" log) in addition to
08's own checks.

### 4.5 `main.dart`: 09 Step 5e adapts to 01 Step 6's guarded bootstrap

Post-01, the notification init lives inside
`_initializeOptionalServices()` in its own try/catch. 09 Step 5e's BEFORE
(top-level `main()` lines) will not match. Adaptation: insert the daily-reminder
re-sync INSIDE the notifications try-block of `_initializeOptionalServices`,
directly after `await NotificationService.requestPermission();`:

```dart
    // Re-sync the daily reminder schedule with saved settings (settings-5).
    final notifPrefs = await SharedPreferences.getInstance();
    final dailyRemindersOn =
        (notifPrefs.getBool('notifications_enabled') ?? true) &&
        (notifPrefs.getBool('daily_reminders') ?? false);
    if (dailyRemindersOn) {
      await NotificationService.scheduleDailyReminder();
    } else {
      await NotificationService.cancelDailyReminder();
    }
```

Keeping it inside that try means a scheduling failure degrades the reminder
only, never boot — consistent with 01 Step 6's design. The `notifPrefs` name
avoids colliding with the theme-prefs `prefs` in the adjacent try-block.

### 4.6 History screen: 04 Step 3 then 07 Steps 4–7

Disjoint methods (`_exportDataToCSV` vs `_loadInitialRecordings`/
`_loadMoreRecordings`/item builder/delete/empty state), but 04 Step 3b changed
the import block. When applying 07 Step 4a, add
`import '../utils/app_logger.dart';` into the import block as it exists
post-04 (anchor on `import '../services/firebase_service.dart';`).

### 4.7 Donation config source: 01 changed `.env` semantics for 10

10's Step 4 verify note says "run the app with `PAYPAL_SANDBOX_MODE=true`" and
Step 6's edge note references `.env BUY_ME_A_COFFEE_URL` — both stale post-01.
Sandbox mode and the BMC URL come from the Firestore doc
`app_config/donations` (`paypalSandboxMode: true`, `buyMeACoffeeUrl`). Seed the
doc accordingly before manual QA of cluster 10. No code adaptation needed:
10 consumes `DonationService.isSandboxMode`/`clientId`/`buyMeACoffeeUrl`,
whose names 01 preserved.

### 4.8 Other spec-declared interactions (already handled if order in §3 is followed)

- **03 Step 4 ↔ 02:** logout flush + mid-sync abort rely on 02's per-recording
  `userId`, the foreign-owner skip, and idempotent deterministic doc IDs
  (a timed-out flush retried later is an overwrite, not a duplicate).
- **02 Step 4 ↔ 04 Step 5 rules:** a retried `set()` on an already-committed
  doc is an UPDATE; 04's rules allow owner updates via `resource.data.userId`
  — verified compatible; do not tighten update rules later without re-checking
  the sync path.
- **09 defers** `db_threshold`/`high_noise_alerts` wiring to 05 Step 5 and
  `anonymize_location` to 04 Step 2 — 09 must not touch those prefs/controls.
- **05 Step 3 (dash-6) narrows 03 Step 2's residual risk:** stopping recording
  on tab switch means the dashboard auto-save cannot fire while the user is on
  the Settings tab deleting their account (a live-uid reading during the
  anonymize pass). Residual only for a pushed (non-shell) settings route.
- **06 Step 4 ↔ 04 Step 1:** the offline path receives the same nulls for
  below-threshold classifications; `sync_service` writes `soundClass`/
  `soundType` only when non-null — no extra work.
- **07 Step 3 ↔ 06 Step 6:** `_applySnapshot` populates `_soundTypeCounts`
  exactly as before; 06's `soundTypeForStoredClass` filter keeps working
  untouched by 07's rewrite.
- **01 Step 3 (onboarding) ↔ 03 Step 4 (logout):** logout lands on Splash →
  Login without onboarding replay — intended combined behavior.
- **02 Step 6f** adds `ThemeHelper.getErrorColor` — available to all later
  clusters; do not duplicate it.

---

## 5. Master commit checklist (final execution order)

One checkbox = one commit. Titles verbatim from the cluster specs.

**Cluster 01 — Platform & Release Blockers**
- [ ] 1. `fix(ios): add microphone and location usage descriptions to Info.plist`
- [ ] 2. `fix(android): sign release builds from key.properties keystore with debug fallback`
- [ ] 3. `fix(onboarding): persist has_seen_onboarding and skip replay on signed-out launches`
- [ ] 4. `fix(security): serve donation config from Firestore and stop bundling .env in the app`
- [ ] 5. `chore(security): remove .env files, update docs, add key rotation runbook`
- [ ] 6. `fix(boot): guard startup init with retryable error screen instead of blank screen`

**Cluster 02 — Offline Storage & Sync Overhaul**
- [ ] 7. `fix(offline): deserialize Hive maps safely so queue survives app restart`
- [ ] 8. `feat(offline): store userId/userEmail on OfflineRecording at save time`
- [ ] 9. `fix(sync): upload recordings under their owner and skip foreign queue entries`
- [ ] 10. `fix(sync): make uploads idempotent with deterministic Firestore doc IDs`
- [ ] 11. `fix(sync): write true recording time and userEmail on synced readings`
- [ ] 12. `feat(sync): reset failed attempts and surface failed uploads with retry`
- [ ] 13. `feat(sync): trigger sync at startup, on login, and after fallback saves`

**Cluster 03 — Account Lifecycle**
- [ ] 14. `feat(firestore): add chunked WriteBatch helper and chunk Clear History deletes`
- [ ] 15. `fix(settings): re-authenticate before anonymizing data in account deletion`
- [ ] 16. `fix(profile): propagate email to Firestore only after Auth email is verified`
- [ ] 17. `fix(sync): flush offline queue on logout and abort in-flight sync on auth change`

**Cluster 04 — Data Layer, Privacy & Security Rules** (apply §4.1, §4.2)
- [ ] 18. `fix(data): saveNoiseReading returns SaveOutcome; callers surface save failures (fb-1)`
- [ ] 19. `fix(privacy): mask author identity and honor anonymize_location at write time (sec-2, flow6-03)`
- [ ] 20. `fix(export): scope CSV export to current user, paginate, build off UI thread (fb-4, uiux-3, perf-5)`
- [ ] 21. `fix(dashboard): cache community-feed stream and conform count query to index rule (fb-5, dash-5)`
- [ ] 22. `feat(security): add Firestore/Storage rules, index manifest, and firebase.json wiring (sec-1)`

**Cluster 05 — Recording Pipeline & Dashboard** (apply §4.3)
- [ ] 23. `fix(dashboard): set recording flag synchronously to prevent double-start leaks`
- [ ] 24. `fix(dashboard): gate reading saves on a real GPS fix, never save Colombo defaults`
- [ ] 25. `fix(dashboard): stop recording when hidden and skip saves when meter stalls`
- [ ] 26. `fix(dashboard): compute AVG as energy-based Leq instead of arithmetic dB mean`
- [ ] 27. `fix(dashboard): honor high-noise alert toggle and threshold from settings`
- [ ] 28. `perf(dashboard): rebuild only gauge/stats/chart per noise reading`
- [ ] 29. `fix(a11y): label record button and announce recording state changes`

**Cluster 06 — YAMNet Classification Correctness** (apply §4.3 for Step 4g)
- [ ] 30. `fix(ml): replace fabricated YAMNet class table with official yamnet_class_map.csv asset (ml-1)`
- [ ] 31. `fix(ml): re-audit classMapping against official AudioSet class names (ml-1)`
- [ ] 32. `fix(ml): align YAMNet_Class_ fallback prefix and correct range buckets to official ontology (ml-2)`
- [ ] 33. `fix(ml): enforce 0.30 threshold; below-threshold results Uncertain, never persisted (ml-3, ml-4, flow2-6, arch-3)`
- [ ] 34. `fix(guide): regenerate classification guide from the actual YAMNet mapping (donate-5)`
- [ ] 35. `fix(analytics): exact-match category filter via shared taxonomy in YAMNetClassMapping (flow3-8, analytics-4)`

**Cluster 07 — Analytics & History Correctness** (apply §4.6)
- [ ] 36. `fix(analytics): Duration stat uses 5s-per-reading math (fb-6, flow3-7)`
- [ ] 37. `fix(analytics): bucket trend chart by calendar day/hour (analytics-2)`
- [ ] 38. `refactor(analytics): derive all aggregates from one live stream (analytics-3, flow3-4, perf-4)`
- [ ] 39. `fix(history): always reset _isLoading in finally (fb-3)`
- [ ] 40. `fix(history): safe-parse decibelLevel with 0 fallback (social-2, uiux-7)`
- [ ] 41. `fix(history): delete updates list, adds undo and error handling (social-3, uiux-2, flow3-3)`
- [ ] 42. `fix(history): scrollable empty state enables pull-to-refresh (flow3-5)`

**Cluster 08 — Map & Search** (apply §4.4 for Step 5)
- [ ] 43. `fix(map): cluster color key mismatch — shared markerNoiseKey helper + regression test`
- [ ] 44. `fix(heatmap): read soundClass with soundCategory fallback in HeatmapPoint + tests`
- [ ] 45. `fix(search): case-insensitive Timer-based search debounce in SearchListScreen`
- [ ] 46. `fix(map): handle denied/deniedForever location permission with visible feedback`
- [ ] 47. `feat(map): reachable refresh — tab-activation reload, refresh FAB, remove dead RefreshIndicator`

**Cluster 09 — Settings Wiring** (apply §4.3, §4.5)
- [ ] 48. `fix(settings): remove hardware-unsupported dBA/dBC and Response Time controls (settings-6, uiux-1)`
- [ ] 49. `fix(settings): remove no-op Share Data with Researchers toggle (arch-1)`
- [ ] 50. `feat(dashboard): honor save_frequency setting for periodic Firestore saves (settings-6)`
- [ ] 51. `feat(recording): auto-stop recording via recording_duration_minutes setting (settings-6)`
- [ ] 52. `feat(notifications): schedule real daily reminder via zonedSchedule (settings-5)`

**Cluster 10 — Donation & PayPal WebView** (apply §4.7)
- [ ] 53. `fix(donation): guard PayPal webview reload against uninitialized controller`
- [ ] 54. `feat(donation): add PaymentUrlUtils with host allowlist and return-URL helpers`
- [ ] 55. `fix(donation): allowlist PayPal navigation by exact host suffix, not substring`
- [ ] 56. `fix(donation): wire real PayPal return/cancel URLs so completion detection can fire`
- [ ] 57. `fix(donation): show PayPal load error only for main-frame failures`
- [ ] 58. `fix(donation): launch Buy Me a Coffee externally instead of fake snackbar`

**Standalone final commit (§6 decision)**
- [ ] 59. `test(arch-2): quarantine pre-existing Firebase-dependent test failures so flutter test runs green`

---

## 6. Definition of done

The playbook is DONE when all of the following hold:

1. **All Critical/High CONFIRMED findings in the ten cluster scopes are fixed**
   — the finding IDs listed in each spec's Scope table, verified by that
   spec's per-step acceptance criteria and Verify commands. Do not re-audit;
   the acceptance criteria ARE the verification.
2. **`flutter analyze` is clean** at HEAD (and was after every one of the 59
   commits).
3. **The full test suite is green: `flutter test` passes at HEAD.**
   Decision on the 53 pre-existing failures (audit arch-2: 53/149 tests fail
   today, mostly Firebase-dependent tests with no mock harness):
   **they are handled in a dedicated STANDALONE final commit (#59), not in
   cluster 07.** Rationale: (a) cluster 07's scope is analytics/history
   correctness, and none of the 53 failures gate its steps; (b) clusters 06
   and 09 legitimately FIX or REWRITE some of these test files
   (`sound_classification_test.dart` threshold assertion,
   `settings_screen_test.dart` full rewrite) — quarantining before those
   clusters would churn; (c) building a real Firebase mock harness is
   out of scope of every spec.
   Commit #59 rules:
   - For each remaining failing test file, first check whether the failure is
     a stale assertion made true by this playbook (fix it — e.g. any test
     asserting old onboarding/threshold behavior) or a genuine
     Firebase-initialization failure (quarantine it).
   - Quarantine via a file-level `@Skip('arch-2: pre-existing failure — requires Firebase test harness; see audit/06_ARCHITECTURE_AND_CODE_QUALITY.md')`
     annotation. Never delete test files; never skip a test file that this
     playbook created or rewrote (those must pass).
   - After #59: `flutter test` exits 0; every playbook-added test runs (not
     skipped) and passes.
4. **Server-side/manual checklist complete** (not commits; record in PR
   descriptions):
   - [ ] Firestore doc `app_config/donations` seeded (`paypalBusinessEmail`,
         `paypalSandboxMode`, `buyMeACoffeeUrl`) — 01 Step 4.
   - [ ] `firebase deploy --only firestore:rules` (rules INCLUDE the
         `app_config` block per §4.1), `--only firestore:indexes` (review the
         deletion prompt — only the one composite index may be listed),
         `--only storage` — 04 Step 5.
   - [ ] Release keystore generated, `android/key.properties` created,
         keystore backed up OUTSIDE the repo — 01 Step 2 (losing it
         permanently blocks Play Store updates).
   - [ ] Key rotation runbook `docs/SECURITY_ROTATION.md` executed
         (PayPal secret regeneration check, Firebase API key restriction with
         the NEW keystore SHA-1) — 01 Step 5.
   - [ ] Full logged-in smoke pass after rules deploy: Map(0), Analytics(1),
         Dashboard(2) record 30 s, History(3) + export + delete/undo,
         Settings(4), donation flow.
5. **No convention violated:** grep-checks — `withOpacity` not introduced;
   `isGreaterThanOrEqualTo` absent from all `noise_readings` period queries;
   `print(` absent from `lib/`; `flutter_dotenv`/`.env` absent from `lib/`,
   `test/`, `pubspec.yaml`; `Unknown_Class_` absent from `lib/`;
   confidence threshold reads 0.30.
6. **Known accepted residuals** (documented, NOT bugs to fix): historical
   Firestore docs keep old wrong classification labels and raw emails (no
   migration possible/planned); analytics discontinuity at deploy (06);
   classified share of readings drops (0.15→0.30 + persistence gating);
   device clock skew propagates into offline readings' `timestamp` (02 S5);
   PayPal completion detection is best-effort without merchant Auto Return
   (10); `users/{uid}` doc not deleted on account deletion (settings-11,
   out of scope); legacy pre-04 queue entries may sync one raw email (§4.2).

---

## 7. After the playbook — follow-up work (do NOT start during execution)

This playbook covers the defect backlog (verified bugs). Two recommendation
waves remain as separate, subsequent efforts:

1. **`audit/09_UI_UX_RECOMMENDATIONS.md`** — UI/UX improvement wave:
   theming-consistency sweep (the deferred hardcoded-color findings dash-19/20,
   donate-16/uiux-30), dead navigation stubs in Settings (Privacy Policy /
   Export All Data / Rate Us / Contact Support / Terms), a Settings sign-out
   entry (flow6-17), logout/delete landing-screen consistency (flow1-9),
   empty-state and feedback polish.
2. **`audit/10_PERFORMANCE_RECOMMENDATIONS.md`** — performance wave:
   classification off the UI thread, interpreter disposal (ml-13),
   marker/heatmap scaling beyond the 100-doc limit, count() aggregate for the
   community badge when volume grows, startup-time work.

Also parked for later (from the specs' Out-of-scope sections): a real Firebase
test harness to un-quarantine the arch-2 tests; PayPal Orders API with
server-side capture (flow7-13, flow7-04 3-D Secure handling); background
recording as a foreground service (the long-term dash-6 answer); removal of
the orphaned `calculateStatsByPeriod`/`getUserReadingsByPeriodOnce` service
methods (07's rollback path); iOS build/notarization on macOS.

Consult `audit/00_MASTER_AUDIT_REPORT.md` + `audit/08_IMPROVEMENTS_ROADMAP.md`
before scheduling either wave — do not re-audit the codebase.
