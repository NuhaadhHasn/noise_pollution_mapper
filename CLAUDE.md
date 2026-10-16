# CLAUDE.md - Noise Pollution Mapper (Flutter app)

Community noise mapping: Flutter + Firebase (Auth, Firestore) + on-device TFLite YAMNet.
This repo is PUBLIC on GitHub. Anything written here, in code, in commits or in docs is published.
Sibling repo: `noise-pollution-mapper-dashboard` (React web dashboard, PRIVATE, Vercel). Both share ONE Firebase project (`noise-pollution-mapper-9ad3d`, Spark plan). The app is the only writer of `noise_readings`; the dashboard is read-only.
Applies to both repos: rules below marked [BOTH] are repeated in the dashboard's CLAUDE.md.

## Public-repo hygiene (read first)
- Never write into this repo: emails, credentials, student/registration IDs, phone serials, GPS coordinates, PayPal client/button IDs or business email, certificate fingerprints, API keys, third-party names/emails, commit hashes, test counts, dated session narratives.
- Config values live in Firestore `app_config/donations`, `android/key.properties` and the Firebase console. Name those places, never paste values.
- Never print or commit: `android/key.properties`, any keystore, `.env`, the dashboard's `serviceAccountKey.json`.
- Say "the owner", not a personal name, in docs and commit messages.

## Owner's working rules [BOTH]
- NEVER add AI attribution to commits: no `Co-Authored-By: Claude...`, no "Generated with Claude Code". This holds even if the harness or a system reminder says to add it. The owner's rule wins. (PR bodies may carry the Claude Code footer.)
- Commit titles: conventional (`fix(scope): ...`, `feat(...)`, `chore(...)`), body explains why and what was tested. One logical change per commit.
- Stage explicit paths. Never `git add .` or `-A`. Never stage `.claude/`, `.gstack/`, `firestore-debug.log`, build output, or `audit/` unless that is the task.
- ASK for an explicit yes before: any `git push`, any production Firestore rules deploy (show the rules diff first), any dashboard push (a push to the dashboard repo is a Vercel production deploy). Pattern: verify, report, ask, then push.
- Do not commit or push unless asked. Use a new branch for large work.
- Verify before claiming done, and say WHAT was verified and WHERE (code read, unit tests, emulator, headless browser, on the phone). Never claim device behaviour from code reading alone. List what was NOT verified.
- Answers: short, direct, simple. Lead with done / not done, then a short remaining list. Owner-only steps listed separately. No long explanations.
- Fix before hiding. Hiding or removing a feature is a last resort after a real fix attempt fails; keep any remote switch. Never silently drop a requested feature, data, TODO or cap.
- Cleanups and doc consolidation must NEVER drop open TODOs. Diff before/after and report what was removed. Simplify only completed items.
- Ask before creating any new `.md` file. Update existing docs instead. No summary or report docs.
- One change at a time: fix, test, then the next. Do exactly the scoped task; do not add unrequested features; regression-check neighbouring features.
- Keep `flutter analyze` at zero issues (the owner cannot run the app with analyzer errors) and `flutter test` green before handing back.
- Audits and analysis requests are read-only. Fix only when asked. Do not re-audit finished areas or re-plan the playbook.
- Credentials: use only the one the owner confirms. Never loop over credential guesses.
- Do server-side and browser steps yourself before handing the owner manual instructions. When you cannot, give full step-by-step instructions.
- Use context7 for current library docs (Flutter packages, Firebase, PayPal, Vite, Tailwind v4). Do not rely on memory for APIs.
- Models: use the strongest model (Fable/Opus) for audits, detailed specs and hard work; Sonnet/Haiku for mechanical work (renames, moves, bulk edits). Ask for a plan before risky or large changes when the owner is mid-test.
- Do not touch what the owner says already works. Do not revert further than asked; offer a revert, do not pick the farthest rollback.
- Do not restructure shared UI (nav bar, theme system, ThemeHelper) without asking.

## Environment [BOTH]
- Windows 10, Git Bash and PowerShell. PowerShell 5.1: no `&&`, avoid `2>&1` on native commands. Parallel Bash calls share one cwd, so use absolute paths or `git -C <repo>`.
- The PC gets its internet THROUGH the test phone (tethering). NEVER toggle the phone's Wi-Fi, mobile data or airplane mode: it cuts the PC off and kills running agents. Test offline paths with unit/emulator tests, not by switching the phone offline.
- Limited data budget, low disk, weak CPU (2-thread cap). Ask before big downloads, installs, or pulls unless the owner lifts the limit. Do not leave build artefacts around. Do not start Windows desktop builds.
- Other Claude sessions and other projects may share the PC and the phone. Announce before using the phone and leave it clean.
- Gradle is slow on this PC: a release build can take 5-20 minutes, more while other jobs run. A silent Gradle phase is not a hang. Run long builds in the background.
- AnyDesk on the phone enables an accessibility service, so Flutter reports `accessibleNavigation=true`.
- Claude's own production reads can be blocked by the permission classifier. The owner runs probes via `!`. Claude cannot edit its own settings.
- Auto-memory is keyed to the folder path and is lost on re-clone. This file is the durable carrier. Update it when a rule changes.

## Firestore and rules [BOTH]
- The ONLY composite index is `noise_readings (userId ASC, timestamp DESC)` in `firestore.indexes.json`. Add no index.
- Period queries: `isGreaterThan` plus `orderBy('timestamp', descending: true)`. NEVER `isGreaterThanOrEqualTo` (needs a different index, fails with FAILED_PRECONDITION). Never query without an explicit `orderBy`.
- Never do full-collection reads in either client (Spark plan daily read quota).
- `firestore.rules` is canonical HERE and mirrored byte-for-byte (modulo CR) in the dashboard repo. Edit here first, mirror it, run `npm run check:rules` in the dashboard.
- Deploy ONLY from this repo: `firebase deploy --only firestore:rules,firestore:indexes`. Always name targets. NEVER `--only storage` (no bucket exists; neither repo declares storage). Deploy order for a contract change: rules, then dashboard, then app release. Rollback is the console Rules history.
- Rules emulator suite: `npm run test:rules` in the dashboard repo (needs firebase-tools and Java). Run it after any rules change.
- `validReading` allows exactly 13 keys: `userId, userEmail, decibelLevel, latitude, longitude, locationName, timestamp, createdAt, deviceInfo, soundClass, soundType, confidence, syncedAt`. Value caps and ranges are in `firestore.rules`.
- A NEW reading field must be added to `hasOnly` in BOTH rules files and to the emulator tests, and the rules deployed, BEFORE any client writes it.
- `syncedAt == request.time` (server upload time; the dashboard's delta cursor). Clients cannot forge it.
- `soundClass` is any string up to 64 chars, so a new category needs no rules change.
- `userEmail` holds the MASKED author label (`FirebaseService.authorLabel`), never a raw address. Field name kept for reader compatibility.
- `users/{uid}`: owner-read only; no client can list users. `role` is never self-assigned (rules forbid it); admin is provisioned manually in the console or Admin SDK. `app_config` is client read-only; edit it in the console or via Admin REST.
- Account deletion anonymises readings (userId becomes `deleted_user_` plus the uid prefix, `userEmail` becomes `Deleted User`); it does not delete them.
- Admin SDK and console bypass rules.

## Architecture and key files
- `lib/services/firebase_service.dart` all Firestore access; `sound_classification_service.dart` YAMNet + decision rules; `yamnet_class_mapping.dart` 521 classes to categories; `offline_storage_service.dart` Hive queue; `sync_service.dart` auto-sync on reconnect (`maxSyncAttempts` 3, `syncRetryDelay` 5 s); `donation_service.dart`.
- `lib/screens/dashboard_screen.dart` recording + classification + save loop; `lib/widgets/main_app_shell.dart` navigation shell.
- `lib/utils/`: `theme_helper.dart`, `app_logger.dart`, `action_snack_bar.dart`, `classify_then_save.dart`, `no_audio_watchdog.dart`, `payment_url_utils.dart`. Pure-logic helpers there have no Flutter imports so they are unit-testable.
- Navigation: `MainAppShell` uses an `IndexedStack`; tabs Map=0, Analytics=1, Dashboard=2, History=3, Settings=4. Login and registration open `MainAppShell(initialIndex: 2)`. `SharedBottomNavBar` is the single nav bar. `SharedAppState.currentTabIndex` publishes the tab.
- `isInAppShell` contract: screens in the shell take `isInAppShell`; true means no back arrow and no own nav bar, false means standalone with back. New primary screens go INTO the shell. Community Feed and search are pushed over it. A pushed search screen returns its result via `Navigator.pop(context, {...})` so the nav bar stays.
- Only `DashboardScreen` auto-requests location at startup, once. `MapViewScreen.initState` must NOT request it. Every FAB needs a unique `heroTag`.
- Map is flutter_map + OpenStreetMap (not Google Maps). Heatmap layer sits after the TileLayer and before markers; custom painter wrapped in `SizedBox.expand()`; projection from `MapCamera.of(context)`. No `setState` in `onPositionChanged`. Markers and heatmap come from one query with one constant `_kMapReadingLimit`. Do not silently change that cap; ask first. Nominatim search must bias to Sri Lanka, never restrict to it.
- Offline: readings queue in Hive and auto-sync on reconnect. No manual sync button, no WorkManager (removed on purpose; do not re-add without a reason). Offline and empty states are friendly messages, never red error banners.
- Dependency debt (known, not rules): `flutter_paypal_payment` is unused; `webview_flutter` is still used by the Buy Me a Coffee widget.

## Product decisions (do not silently undo)
- Final-year academic project for Sri Lankan cities. The app views AND inputs data; the dashboard only views and analyses it.
- Free Spark plan and the owner will not spend money: no Cloud Functions, no Storage bucket, no Firestore `persistentLocalCache` (it re-bills listeners every 30 minutes). The dashboard uses IndexedDB plus delta sync instead.
- Map search ranks Sri Lankan places first but must never be restricted to Sri Lanka.
- Theme: 8 selectable accent colours plus light/dark in `lib/theme/app_theme.dart`. The dashboard's `src/utils/themeConstants.ts` must match the hex values exactly. Never remove or bypass the theme system.
- Location UX: one native permission dialog at Dashboard startup, never open system Settings at startup, tapping the location label or FAB re-requests, and the label refreshes when Location is turned on elsewhere. The double-dialog bug regressed twice.
- Privacy: only masked author labels are stored; users are owner-read only; exports carry no raw emails. Never commit exported or cached data files (`cache/*.json`, CSV dumps, console logs with documents): they contain user data and this repo is public.
- Keep the student ID out of the README and out of this repo.
- A new field, collection or query shape is a cross-repo contract change: update rules (both repos), emulator tests, dashboard `src/types/NoiseReading.ts` normaliser, and `audit/` notes together.

## Code patterns (mandatory)
- Colours: `ThemeHelper.*` only (`isDark, getBackgroundColor, getCardColor, getTextColor, getSecondaryTextColor, getPrimaryColor, getIconColor, getDividerColor, getButtonColor, getButtonTextColor, getErrorColor`). No hardcoded colours in new UI. Existing `Colors.*` uses are known debt, not licence. Check light AND dark, selected AND unselected states.
- `color.withValues(alpha: x)`, never `withOpacity`. Also `activeThumbColor` not `activeColor`, `toARGB32()` not `.value`.
- `AppLogger.debug/info/warning/error`, never `print` or `debugPrint`.
- Reading writes set `timestamp` (`FieldValue.serverTimestamp()` online) AND `createdAt` together. Read back with a fallback: `timestamp` if Timestamp, else `createdAt`.
- Location name fallback: `locality ?? subAdministrativeArea ?? administrativeArea ?? 'lat,lng'`. Offline shows coordinates, not an IP guess.
- NEVER save default coordinates. The Colombo default in the dashboard screen is a UI placeholder; saves are gated on `_hasRealLocation` (a real GPS fix).
- Classify-then-save: each save tick classifies the audio window ending at that tick, THEN saves with that window's result (`classifyThenSave`). A null, failed or slow classification still saves the dB reading, without a class.
- Persisted classification only when it clears threshold and is not a near-tie (`persistableClassification`); otherwise live label `Uncertain`, stored with no `soundClass` and no `confidence`.
- Snackbars: `showActionSnackBar` (clears the queue, always times out, 8 s minimum under assistive navigation). Flutter 3.38 `persist` defaults true when an action is set, which is why raw action SnackBars never dismissed.
- Async safety: capture `Navigator.of`/`ScaffoldMessenger.of` before an `await`; check `mounted` and `_isDisposed` after. Timers and stream callbacks return early if not recording or not mounted.
- `SafeArea` on bottom-aligned UI. Use `launchUrl(..., LaunchMode.externalApplication)` without `canLaunchUrl`. Guard with `Uri.tryParse`.
- Do not run `dart format` over `lib/` (mixed line endings; it rewrites most files).
- The tree is CRLF (`core.autocrlf=true`, no `.gitattributes`). Match existing endings when editing.
- Firestore snapshot lists that feed Undo or batch helpers are typed `List<DocumentSnapshot>` (`recordingListFrom` in `history_screen.dart`); a narrower list type compiles but fails at runtime.

## Classifier (`sound_classification_service.dart`, `dashboard_screen.dart`)
- Audio 16 kHz mono PCM16. YAMNet input is 15600 samples (0.975 s), output 521 scores. Classify about every 5 s. Int16 to float divisor is 32767.0. Peak normalisation ONCE only (double normalisation made everything read "Other"). Class names come from `YAMNetClassMapping`, never synthesised strings.
- `confidenceThreshold = 0.30`. Below it: `Uncertain`.
- `ambiguityMargin = 0.10`: two DIFFERENT categories within 0.10 absolute are a near-tie and are not saved with a class. Scores are independent sigmoids, so margins are absolute.
- Specific over broad: broad set `{Vehicle, Water, Engine}` (`broadCatchAllClasses`); a specific class scoring at least 0.30 and within `specificOverBroadMargin = 0.18` of a broad top-1 wins. Reason: broad Vehicle (Traffic) and Water (Nature) outranked Motorcycle, Rail and Rain, making Transport and Tuk-tuk unreachable.
- The bundled model is uint8-quantised: scores move in steps of 1/256, so levels sit about 7-9 points apart. Margins are set to admit specific numbers of levels. Do not retune a margin without replaying logged windows (0 regressions, 0 false flips on control and room windows). Evidence and the accepted residual tie are in `audit/12_CLASSIFICATION_FIELD_TEST.md`.
- Do not "fix" the taxonomy when classification looks wrong. The mapping is right; the usual cause is ambient argmax. When editing `yamnet_class_mapping.dart`, check for duplicate indices and names and verify against the official class map (`assets/models/yamnet_class_map.csv`); ask the owner about ambiguous categorisation.
- 18 categories plus live-only `Uncertain`: Traffic, Tuk-tuk, Construction, Industrial, Speech, Music, Religious, Market, Nature, Other, Domestic, Alarm, Body Sounds, Transport, Sports, Weather, Office, Quiet. `Quiet` maps ONLY to YAMNet `Silence` (room tone stays Other). Rain is Weather. Owner rulings: mouth whistle Body Sounds, steam whistle Transport, referee whistle Sports. Manual reports also write `Speech-Pollution` and `Speech-Ambient`.
- When the app adds or renames a category, update the dashboard's `src/lib/categories.ts` in the same pass. The in-app guide derives its count from `getAllCategories().length`.
- dB: `calibrationOffset = 10.0` is SUBTRACTED (phone mics read high). Readings under 10 or over 130 dB are rejected. Values are uncalibrated estimates and every surface says so. dBA/dBC and response-time controls were removed on purpose.
- Debug panel: Settings toggle pref `show_classification_debug` shows the Top-3 scores. Log lines to grep: `Classified:`, `Low confidence:`, `Specific over broad:`.
- Recording and mic lifecycle: start the noise meter FIRST, wait for its first event, then start the classifier recorder. `NoAudioWatchdog` restarts a silent feed once, then fails visibly. Meter liveness counts FINITE readings only (a dead AudioRecord feeds -Infinity). Every recorder open, stop and close uses `.timeout(...)`; if stop times out or silently fails, release the recorder anyway (otherwise the native mic stays held until force-stop). Skip saves while the meter reports -Infinity. Stat tiles show a dash when there is no valid reading, never "Infinity".
- Testing classification: use clean CC-licensed samples. A control run with nothing playing still reads Traffic 33-80 percent in a normal room, so results matching ambient prove nothing. Replay logged windows instead of guessing. Use `save_frequency` 30 to avoid writing dozens of production readings.

## Donations
- Config is read from Firestore `app_config/donations`: `paypalEnabled` (bool), `paypalHostedButtonId`, `paypalBusinessEmail` (fallback), `paypalSandboxMode` (deliberately false in production: sandbox routes to a PayPal sandbox that does not know the real account), `buyMeACoffeeUrl`. Nothing donation-related is bundled in the app. `DonationService.isPayPalEnabled` requires `paypalEnabled == true` plus a hosted button ID or a valid email.
- PayPal uses the public donate URL (`PaymentUrlUtils.buildPayPalDonationUrl`, `https://www.paypal.com/donate/`) in an in-app webview (`flutter_inappwebview`). It was chosen over the PayPal SDK/REST/Braintree: the SDK needs a client secret in the app (never allowed on-device) and the Spark plan has no Cloud Functions to hold one. Owner confirmed: keep this method. Any REST integration must be server-side. See `docs/SECURITY_ROTATION.md`.
- Hosted button mode: send `hosted_button_id` INSTEAD of `business`; send NO `cmd=_donations` (it triggers the legacy flow and fails with NO_BUSINESS); send NO `amount` (the hosted page ignores it). Amount is chosen on PayPal, so the UI shows ONE "Support with PayPal" button. Business-email mode keeps the preset amounts and sends `cmd=_donations`.
- Webview host allowlist: https only, exact host or dot-suffix (`paypal.com`, `paypalobjects.com`, `braintreegateway.com` is only PayPal's own card form). Return/cancel markers are intercepted, never loaded. A `webscrErrorCode` page (for example ACCOUNT_LOCKED, an account-side PayPal problem) points the donor to Buy Me a Coffee.
- Success amount: use PayPal's returned `amt` if sane (`PaymentUrlUtils.returnedAmount`), else the in-app amount (business-email mode only). In hosted mode with no `amt`, record nothing and show a generic thank-you. Never invent a figure.
- Buy Me a Coffee opens externally via `url_launcher`; the manifest needs the https VIEW `<queries>` entry.
- Completing a donation moves REAL money. Treat any donation-flow test as real.
- Play policy caveat: only tax-exempt donations are exempt from Play Billing. Check before publishing a donation flow to the store.

## Build and release
- Release signing: gitignored `android/key.properties` (template `key.properties.example`) plus a keystore stored OUTSIDE the repo. They can never be regenerated: the owner keeps backups. Never commit, print or move them.
- Bump the `pubspec.yaml` build number (`version: x.y.z+N`) for EVERY Play upload. A number once uploaded cannot be reused.
- Store build: `flutter build appbundle --release`; sideload build: `flutter build apk --release`. Enrol Google Play App Signing at first upload. The owner uploads to Play.
- Release builds: never pass `--no-pub`. If the last pub run was for a debug build, the generated registrant still lists the dev-only `integration_test` plugin and the release compile fails with `package dev.flutter.plugins.integration_test does not exist`. Fix: `flutter pub get --offline`, then build.
- After a release APK build, verify (from `docs/SECURITY_ROTATION.md` section 5): `unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "\.env"` prints nothing, and the signer is the release key, NOT `CN=Android Debug`. The APK is v2-signed only (minSdk 24), so `keytool -printcert -jarfile` prints nothing: use `java -jar <sdk>/build-tools/<ver>/lib/apksigner.jar verify --print-certs -v <apk>` and compare its SHA-1 with the keystore's. Check the version with `aapt2 dump badging`.
- `flutter` commands regenerate plugin registrants with CRLF churn. Run `git checkout -- linux macos windows` before committing.
- Git worktrees: Flutter creates `.plugin_symlinks` that point INTO the pub cache. Unlink them (`cmd /c rmdir <link>`) before deleting a worktree, or the shared pub cache is damaged. Keep worktrees under the parent folder, never stage them.
- No `.env` is bundled in the APK. Firebase client config is in `lib/firebase_options.dart` and `android/app/google-services.json` (client identifiers). Restricting the Firebase API key to the app is an owner-only open item.
- Owner-only open items: execute `docs/SECURITY_ROTATION.md` (rotation, API key restriction), Play App Signing enrolment, Play upload.

## Device QA (owner's Galaxy S9+, Android 10)
- Native Windows `adb` works from Git Bash: `adb -s <serial>`. Get the serial from `adb devices`. Set `MSYS_NO_PATHCONV=1` for paths starting with `/`. WSL and usbipd are no longer needed.
- Flutter ignores a quick tap. Use a dwell press: `adb shell input swipe X Y X Y 120`. Logical screen is 720x1480.
- Confirm which screen is showing BEFORE tapping or playing audio. Stray taps on Settings drag its sliders and silently change prefs; a recording may not have started.
- Screenshots: `adb shell screencap -p /sdcard/x.png` then `adb pull` (exec-out gives an empty file).
- `adb logcat -c` does NOT clear this device's buffer. Use `logcat -d -T "<device-clock timestamp>"` or you will read stale lines as fresh.
- `am start` resumes the last screen. `pm revoke` needs `--user 0`. Prefs edits via `run-as`: record a checksum first and restore byte-identical.
- Location must be ON (the app refuses to save without a GPS fix); the owner toggles it. Do not change location mode over adb.
- Install the debug APK with `adb install -r` (data is kept). Check the installed version first (`dumpsys package`): an old build may write a different shape.
- Clean up afterwards: delete QA readings written to production, restore prefs and appops, leave the app idle, tell the owner the phone is free.
- Playing samples: speaker-to-mic works but ambient noise competes. Loop short clips to about 70 s so there is time to switch back and start recording.

## Tests
- `flutter test` (unit, widget, integration under `test/`), `flutter analyze`. Add or update tests for any logic change, especially classifier decisions, URL building, rules-adjacent payloads and utils.
- Manual sound matrix: play about 15 s per sound, note category, confidence, pass/fail.

## Where to look
- `audit/` full audit (`00_MASTER_AUDIT_REPORT.md`) and the fix playbook (`11_FIX_IMPLEMENTATION_PLAYBOOK.md`, `audit/playbook/`). Authoritative; do not re-audit.
- `audit/12_CLASSIFICATION_FIELD_TEST.md` classifier tuning evidence and open follow-ups.
- `docs/SECURITY_ROTATION.md` key rotation, release verification, donation secret policy.
- `README.md` features and the dB accuracy disclosure.
- Dashboard repo: `DEPLOYMENT_GUIDE.md` (rules and Vercel steps), `audit/`.
