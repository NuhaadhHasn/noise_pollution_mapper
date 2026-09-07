# Security Audit - Noise Pollution Mapper

> **FINAL (journal build)** - generated 2026-07-13 from the complete multi-agent audit: 23 specialized auditors + 2 supplemental flow tracers + coverage critic. Status legend: `confirmed` = an independent adversarial reviewer re-verified it against the code; `disputed` = reviewer found it partially true (re-check before fixing); `refuted` = reviewer disproved it (kept for transparency, excluded from the roadmap); `unverified` = not individually re-checked.

## Executive Summary

Total findings in this area: **23** (3 Critical, 7 High, 9 Medium, 4 Low).

## Summary Table

| ID | Severity | Status | File:Line | Title | Effort |
|----|----------|--------|-----------|-------|--------|
| sec-1 | Critical | disputed | `firebase.json:1` | No Firestore/Storage security rules in the app repo; deployed rules are unverifiable and likely open | M |
| critic-02 | Critical | disputed | `pubspec.yaml:138` | PayPal merchant secret and all API keys shipped inside the APK via bundled .env | L |
| sec-3 | Critical | confirmed | `lib/screens/settings_screen_enhanced.dart:901` | Account deletion anonymizes all readings BEFORE deleting the auth user — requires-recent-login leaves data destroyed but account alive | S |
| offline-6 | High | confirmed | `lib/services/sync_service.dart:162` | Offline recordings are uploaded under whichever user is logged in at sync time, not the user who recorded them | M |
| sec-2 | High | confirmed | `lib/services/firebase_service.dart:119` | Full user email plus precise coordinates written to shared noise_readings docs; masking is client-side only and fails for short emails | M |
| fb-4 | High | confirmed | `lib/screens/history_screen.dart:231` | CSV export downloads the entire global noise_readings collection including every user's email | M |
| sec-10 | High | confirmed | `ios/Runner/Info.plist:4` | Info.plist missing NSMicrophoneUsageDescription and NSLocationWhenInUseUsageDescription — iOS build crashes on first recording | S |
| settings-3 | High | confirmed | `lib/screens/settings_screen_enhanced.dart:205` | 'Anonymize Location' privacy toggle is a complete no-op — precise coordinates always uploaded | M |
| donate-2 | High | confirmed | `lib/widgets/paypal_webview_widget.dart:145` | Substring-based URL allowlist in PayPal webview is trivially bypassable - arbitrary URLs can load | S |
| critic-05 | High | confirmed | `android/app/build.gradle.kts:46` | Release builds are signed with the debug keystore | M |
| donate-11 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:94` | MIXED_CONTENT_ALWAYS_ALLOW enabled on the payment webview | S |
| donate-10 | Medium | unverified | `lib/services/donation_service.dart:10` | PAYPAL_SECRET getter reads from a .env that ships inside the APK; bundled .env also leaks developer PII | S |
| sec-11 | Medium | unverified | `lib/utils/app_logger.dart:22` | Debug-level logging left enabled for production; logs include PII and payment URLs | S |
| settings-11 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:883` | Account deletion never deletes the users/{uid} profile document — PII retained after deletion | S |
| sec-13 | Medium | unverified | `lib/screens/edit_profile_screen.dart:115` | Unverified new email is written to the users doc and broadcast into all noise_readings before ownership verification | M |
| settings-7 | Medium | unverified | `lib/screens/settings_screen_enhanced.dart:214` | 'Share Data with Researchers' consent toggle is never consulted — data shared regardless | M |
| sec-7 | Medium | unverified | `lib/widgets/paypal_webview_widget.dart:121` | Donation 'success' is detected by URL substring with no server verification — spoofable and effectively dead code | M |
| donate-8 | Medium | unverified | `lib/widgets/buy_me_coffee_widget.dart:64` | Substring-based navigation allowlist in BMC webview is bypassable (same flaw as PayPal webview) | S |
| social-8 | Medium | unverified | `lib/screens/community_feed_screen.dart:216` | Email masking is skipped entirely for local parts of 3 characters or fewer — full email of other users displayed | S |
| sec-17 | Low | unverified | `lib/screens/login_screen.dart:65` | Login error handling enables account enumeration | S |
| sec-16 | Low | unverified | `lib/screens/registration_screen.dart:323` | Weak auth input validation: 6-char password minimum, naive email check, raw exception text shown to users | S |
| sec-14 | Low | unverified | `lib/screens/map_view_screen.dart:363` | User search text interpolated unencoded into Nominatim URLs — query-string parameter injection | S |
| boot-15 | Low | unverified | `lib/firebase_options.dart:50` | Firebase API keys committed without evidence of key restrictions or App Check — abuse surface for Auth endpoints | S |

## Detailed Findings

### Critical

#### [sec-1] No Firestore/Storage security rules in the app repo; deployed rules are unverifiable and likely open

**Severity:** Critical | **Status:** disputed | **Category:** security | **Effort:** M

**Location:** `firebase.json:1`

**Verifier verdict (PARTIAL):** The repo-level facts are CONFIRMED: firebase.json (C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/firebase.json) contains only a flutterfire "flutter" config block — no "firestore" or "storage" rules entries — and a glob for *rules*/firestore* across the whole project finds no firestore.rules or storage.rules file (only build-artifact proguard rules). So security rules are not version-controlled and cannot be deployed or verified from the repo. However, the severity claim "the database is likely open to any client" is overstated and contradicted by repo evidence: PRODUCTION_CHECKLIST.md lines 182-256 documents Section 3 "Firebase Security Rules ✅ COMPLETE", stating the user published production rules directly in the Firebase Console for project noise-pollution-mapper-9ad3d ("User updated Firestore security rules in Firebase Console", "Production rules now active"), and includes the full rules text requiring authentication, ownership checks, and type validation for noise_readings and users collections. The rules text itself lives in the checklist (lines 199-248). Deployed state remains unverifiable from the repo (the console claim can't be proven from code), but the best available evidence points to auth-gated rules being active, not an open database. Also, the Storage half of the finding is low-impact: firebase_storage ^12.3.8 is declared in pubspec.yaml (line 34) but grep finds zero FirebaseStorage usage anywhere in lib/, so missing Storage rules have no client code path in this app. Net: real hygiene defect (rules not in repo, not deployable via `firebase deploy`, drift-prone), but the "likely open to any client" Critical framing is not supported.

**Description:**

The app repo contains no firestore.rules or storage.rules, and firebase.json has only a 'flutter' section (no firestore/storage deploy targets), so the security posture of the production project noise-pollution-mapper-9ad3d is unverifiable from this repo. A firestore.rules file exists only in the sibling repo noise-pollution-mapper-dashboard/firestore.rules, and those rules DENY cross-user reads of noise_readings (owner or admin only). Yet the app's core features read ALL users' readings without a userId filter: community_feed_screen.dart:62-67, firebase_service.dart getNoiseReadings()/getNoiseReadingsOnce()/getNoiseReadingsForHeatmap() (lines 165-202). Since these features reportedly work, the actually-deployed rules must be broader than the dashboard rules — most plausibly open to all authenticated users or fully open — meaning every noise_readings document (full userEmail + exact lat/lng, see sec-2) is readable, and possibly writable/deletable, by anyone with the public web API key from firebase_options.dart. There is also no storage.rules anywhere despite a configured storageBucket.

**Failure scenario:**

Anyone extracts the web API key and projectId from the shipped app (they are public by design), authenticates or connects anonymously against the Firestore REST API, and dumps the entire noise_readings collection — emails plus precise location/time trails for every user — or mass-deletes/overwrites community data if writes are also open.

**Recommended fix:**

Add firestore.rules and storage.rules to THIS repo and wire them in firebase.json ({"firestore": {"rules": "firestore.rules"}, "storage": {"rules": "storage.rules"}}). Write rules that match app behavior: allow read of noise_readings for authenticated users but only of non-PII fields (see sec-2 for removing userEmail), allow create only with request.resource.data.userId == request.auth.uid, allow update/delete only for owners, lock users/{uid} to the owner, and default-deny Storage. Deploy with 'firebase deploy --only firestore:rules,storage' and verify in the console.

---

#### [critic-02] PayPal merchant secret and all API keys shipped inside the APK via bundled .env

**Severity:** Critical | **Status:** disputed | **Category:** security | **Effort:** L

**Location:** `pubspec.yaml:138`

**Verifier verdict (PARTIAL):** Mechanism real, headline wrong. pubspec.yaml:138 bundles `.env` as an asset and it ships (present in build/app/intermediates/assets/release/mergeReleaseAssets/flutter_assets/.env). But `.env` contains NO PayPal merchant secret: PAYPAL_CLIENT_ID (.env:27) is just a PayPal email used to build a public donation URL (paypal_webview_widget.dart:41-43), and PAYPAL_SECRET is never defined — donation_service.dart:10 falls back to ''. "All API keys" is also overstated: FIREBASE_API_KEY (.env:3) is a non-confidential Firebase client key that ships in any Firebase APK, and GOOGLE_MAPS_API_KEY is the placeholder "your_google_maps_key_here" (.env:9). Real residual issues: bundling .env into the APK is bad practice, and a personal Gmail address leaks in a comment (.env:23). Not Critical as configured.

**Description:**

pubspec.yaml line 138 declares `.env` as a Flutter asset, so the entire file (FIREBASE_API_KEY, GOOGLE_MAPS_API_KEY, PAYPAL_CLIENT_ID, PAYPAL_SECRET) is packaged in plaintext inside every release APK/IPA (extractable with `unzip apk; cat assets/flutter_assets/.env`). lib/services/donation_service.dart line 10 reads `dotenv.env['PAYPAL_SECRET']`, and .env.example lines 19-21 instruct developers to put the real PayPal REST secret there. The local .env even carries a comment 'PROD WORKING! - Real PayPal account tested successfully' with a production client ID. A PayPal REST client-id+secret pair grants full merchant API access (refunds, payouts, transaction history). The flutter_paypal_payment package requires the secret client-side, which means the donation feature as designed cannot ship safely.

**Failure scenario:**

Anyone downloads the release APK, unzips it, reads assets/flutter_assets/.env, and obtains the production PayPal client ID and secret; they can then call PayPal REST APIs as the merchant and issue refunds or drain the account. Firebase/Maps keys are also harvested for quota abuse.

**Recommended fix:**

Remove `.env` from the pubspec assets list and stop reading PAYPAL_SECRET on-device: route PayPal order creation/capture through a Cloud Function that holds the secret server-side (or replace with the Buy Me a Coffee URL flow only). Rotate the exposed PayPal credentials. Keep only genuinely public config (e.g. BUY_ME_A_COFFEE_URL) in any bundled file.

---

#### [sec-3] Account deletion anonymizes all readings BEFORE deleting the auth user — requires-recent-login leaves data destroyed but account alive

**Severity:** Critical | **Status:** confirmed | **Category:** security | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:901`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. In C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/lib/screens/settings_screen_enhanced.dart, _deleteAccount() (line 864) executes in this order: (1) it queries all noise_readings where userId == uid and commits a batch update (line 901) that irreversibly rewrites each doc to userEmail: 'Deleted User' and userId: 'deleted_user_<first-8-chars-of-uid>'; (2) only THEN calls user.delete() (line 904). Firebase Auth's user.delete() is a security-sensitive operation that throws FirebaseAuthException with code 'requires-recent-login' when the session is stale — and the code's own catch block explicitly handles that exact code at line 932, telling the user to 'log out and log in again before deleting your account'. At that point the batch has already committed: all of the user's readings are permanently disassociated from their uid (the original uid is unrecoverable from the truncated 8-char suffix), but the auth account still exists. The user's history/analytics are gone from their account whether or not they ever complete the deletion, and if they retry after re-login, the readings query finds nothing so only the auth user is removed. There is no reauthentication in the delete flow — the only reauthenticateWithCredential call (line 772) belongs to the separate change-password dialog. The call chain (settings row at line 247 -> _showDeleteAccountConfirmation at 828 -> _deleteAccount at 854/864) contains no precondition check or verifyBeforeUpdate pattern. The correct order would be to reauthenticate (or attempt user.delete() first / verify recency) before mutating Firestore data. One pedantic nuance that does not change the verdict: the readings are anonymized rather than deleted, but the ownership linkage is destroyed irreversibly, which is precisely the harm the finding describes.

**Description:**

_deleteAccount (settings_screen_enhanced.dart:864-959) first batch-overwrites userId ('deleted_user_<uid8>') and userEmail ('Deleted User') on every one of the user's noise_readings (lines 887-901), and only then calls user.delete() (line 904). Firebase requires a recent sign-in for user.delete(); for any session older than a few minutes it throws 'requires-recent-login'. That exception is caught at line 924-943 and shows 'Please log out and log in again' — but the batch has already committed. The user's readings are now permanently disassociated (userId no longer matches), their History/Analytics/Dashboard go empty, and there is no way to restore the linkage, while the account itself still exists.

**Failure scenario:**

A user logged in for a week taps Delete Account and confirms. The anonymization batch commits, then user.delete() throws requires-recent-login. The user sees an error telling them to re-login; their account still works but all their recordings are irreversibly stripped of their userId — History shows 0 recordings forever.

**Recommended fix:**

Reorder and gate the flow: first reauthenticateWithCredential (prompt for password) exactly like the change-password flow at lines 767-772, then run the anonymization batch, then user.delete(). Alternatively call user.delete() first and only anonymize after it succeeds.

---

### High

#### [offline-6] Offline recordings are uploaded under whichever user is logged in at sync time, not the user who recorded them

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** M

**Location:** `lib/services/sync_service.dart:162`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. In lib/services/sync_service.dart, syncOfflineRecordings() reads `final user = _auth.currentUser` at sync time (line 133) and passes `user.uid` to `_saveToFirebase(recording, user.uid)` (line 162), which writes `'userId': userId` into the noise_readings collection (line 212). The OfflineRecording model (lib/models/offline_recording.dart) has no userId field — the recorder's uid exists only as an unparsed suffix in the string id created at queue time (firebase_service.dart:148, `'${timestamp}_$userId'`) and is never used for attribution. The Hive queue is a single device-global box ('recordings_queue', offline_storage_service.dart:13) shared by all accounts, and logout (dashboard_screen.dart:689) only calls FirebaseAuth.signOut() without clearing it — clearAllRecordings() has no call sites. Therefore if user A records offline, logs out, and user B logs in when connectivity returns, A's recordings are uploaded to Firestore attributed to B's uid, with no stored field to recover the true owner.

**Description:**

`OfflineRecording` (lib/models/offline_recording.dart:5-16) has no `userId` field — the recording user's uid is only mangled into the `id` string by firebase_service.dart:148 (`'${ms}_$userId'`) and never read back. `syncOfflineRecordings` passes the *current* `user.uid` (sync_service.dart:133, 162) into `_saveToFirebase`, which writes it as `userId` (line 212). On a shared device, user A's offline recordings are attributed to user B, appearing in B's personal analytics/history and leaking A's location trail (lat/lng + time) into B's account.

**Failure scenario:**

User A records readings offline, logs out. User B logs in on the same device and walks into wifi; the connectivity handler syncs A's queued recordings with `userId = B.uid`. B's analytics now contain A's timestamped GPS coordinates, and A's readings are gone from A's history.

**Recommended fix:**

Add a `userId` field to OfflineRecording (persisted in toMap/fromMap), set it at save time in firebase_service._saveOffline, and in the sync loop upload only recordings whose stored userId matches `_auth.currentUser.uid` (leave others queued for their owner). Also clear or partition the queue on logout.

---

#### [sec-2] Full user email plus precise coordinates written to shared noise_readings docs; masking is client-side only and fails for short emails

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** M

**Location:** `lib/services/firebase_service.dart:119`

**Verifier verdict (CONFIRMED):** All variants check out. firebase_service.dart:119 writes `'userEmail': _auth.currentUser?.email` (full email) plus raw `'latitude'/'longitude'` (121-122) to the shared `noise_readings` collection; the offline queue also stores raw coords (150-151). Email masking exists only client-side at display time (community_feed_screen.dart:210-216) and its `emailParts[0].length > 3` guard means local parts of 3 or fewer chars are shown unmasked; the raw email remains readable in Firestore regardless. The 'Anonymize Location' toggle only persists prefs key 'anonymize_location' (settings_screen_enhanced.dart:54, 211); project-wide grep shows no other code reads it — the upload path never consults it, so exact GPS coordinates are always uploaded. Silent no-op confirmed.

**Description:**

_saveToFirebase (firebase_service.dart:117-127) stores 'userEmail': _auth.currentUser?.email together with exact 'latitude'/'longitude' in every community-visible noise_readings document. The community feed (community_feed_screen.dart:171) receives the raw document — so every client downloads every reporter's full email; the 'first 3 chars + ***' masking at community_feed_screen.dart:210-218 happens after the PII is already on the attacker's device and is trivially bypassed by reading the snapshot data. Worse, the mask condition 'emailParts[0].length > 3' means emails with a local part of 3 or fewer characters (e.g. bob@gmail.com) are displayed completely unmasked. Combined with the map (map_view_screen.dart marker bottom-sheet shows exact coords to 4 decimals, ~11 m) users who record at home are linkable by email to their home address.

**Failure scenario:**

User with email tm@company.com records noise from their bedroom nightly. Any other signed-in user opens the community feed, sees tm@company.com fully unmasked (local part <= 3 chars skips masking), cross-references the timestamped reading with the map marker at 4-decimal precision, and now has the person's identity, employer domain, home coordinates, and daily schedule.

**Recommended fix:**

Stop writing userEmail into noise_readings entirely — store only userId and resolve a non-identifying display handle (or 'Anonymous') server-side or from a public-profile subset. Backfill-remove userEmail from existing docs. If any label is needed, write a pre-masked or hashed value at save time, and fix the mask to cover all local-part lengths. Also consider coarsening public coordinates (e.g. round to 3 decimals / snap to a grid) for other users' readings.

---

#### [fb-4] CSV export downloads the entire global noise_readings collection including every user's email

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** M

**Location:** `lib/screens/history_screen.dart:231`

**Verifier verdict (CONFIRMED):** The defect is real exactly as described. In C:/Users/nuhaa/Downloads/Chatgpt/noise_pollution_mapper/lib/screens/history_screen.dart, `_exportDataToCSV` (lines 219-329) runs `FirebaseFirestore.instance.collection('noise_readings').orderBy('timestamp', descending: true).get()` at lines 230-233 with NO `userId` filter and no limit — unlike every other read in this screen, which goes through `_firebaseService.getUserReadingsPaginated(userId: ...)`. The CSV header at line 248 includes a "User Email" column, line 262 reads `data['userEmail']`, and line 273 writes it verbatim into every row. That field genuinely contains other users' real email addresses: lib/services/firebase_service.dart:119 writes `'userEmail': _auth.currentUser?.email` into every noise_readings document. The query will succeed at runtime, not be blocked by security rules: no firestore rules file exists anywhere in the repo, and the app's design requires globally readable noise_readings (lib/screens/community_feed_screen.dart:62-67 streams the same collection unfiltered for all users). Aggravating details: the export lives on the "History / Your Recordings" screen, so the user believes they are exporting their own data; the community feed at least masks emails into display names (community_feed_screen.dart:211-218), but the CSV dumps raw emails plus GPS latitude/longitude per row — a PII leak of every user's identity tied to precise locations, saved to a local file. High severity is justified.

**Description:**

_exportDataToCSV queries FirebaseFirestore.instance.collection('noise_readings').orderBy('timestamp', descending: true).get() with no userId filter and no limit (lines 230-233), then writes userEmail (line 262), coordinates, and timestamps of ALL users into a CSV on the device. The screen is titled 'Your Recordings' and the export button sits in the History AppBar, so users believe they are exporting their own data. This is both a PII disclosure (emails + location traces of other community members) and an unbounded query that grows with the whole collection.

**Failure scenario:**

Any logged-in user taps the download icon on the History screen: the app fetches every reading ever recorded by every user (thousands of docs, one read each) and saves a CSV containing other users' email addresses paired with their GPS coordinates and timestamps to local storage.

**Recommended fix:**

Scope the export to the current user via _firebaseService.getUserReadingsPaginated / a where('userId', isEqualTo: uid) query with orderBy timestamp desc (matches the existing composite index), and drop the userEmail column or restrict it to the current user's own email. Additionally, verify Firestore security rules don't need tightening for cross-user reads.

---

#### [sec-10] Info.plist missing NSMicrophoneUsageDescription and NSLocationWhenInUseUsageDescription — iOS build crashes on first recording

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** S

**Location:** `ios/Runner/Info.plist:4`

**Verifier verdict (CONFIRMED):** ios/Runner/Info.plist:4-48 contains zero usage-description keys; grep for NSMicrophone|NSLocation across ios/ finds nothing. pubspec.yaml:42-50 declares noise_meter ^5.0.2 (mic), permission_handler ^11.3.1, geolocator ^13.0.2, so the app accesses mic and location. iOS kills an app that touches the microphone without NSMicrophoneUsageDescription (TCC privacy crash), so "crashes on first recording" is accurate. Missing NSLocationWhenInUseUsageDescription is also real (location requests silently fail/deny rather than crash, a minor overstatement in one variant, but the core defect is exactly as described).

**Description:**

The app records audio (noise_meter, flutter_sound) and reads GPS (geolocator), and an iOS Firebase app is configured (firebase_options.dart ios section), but ios/Runner/Info.plist contains no NSMicrophoneUsageDescription and no NSLocationWhenInUseUsageDescription (verified: no matches anywhere under ios/). On iOS, requesting microphone or location access without the corresponding usage-description key terminates the app immediately (TCC crash), and App Store review rejects the binary. By contrast the Android manifest is correctly scoped (RECORD_AUDIO, fine/coarse location, INTERNET only — no over-broad permissions, no embedded keys).

**Failure scenario:**

User installs the iOS build and taps record on the Report Noise screen; iOS kills the app instantly with 'This app has crashed because it attempted to access privacy-sensitive data without a usage description'.

**Recommended fix:**

Add to Info.plist: NSMicrophoneUsageDescription ('Used to measure ambient noise levels'), NSLocationWhenInUseUsageDescription ('Used to place your noise readings on the map'). Audit permission_handler setup in the Podfile for the matching PERMISSION_* macros.

---

#### [settings-3] 'Anonymize Location' privacy toggle is a complete no-op — precise coordinates always uploaded

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:205`

**Verifier verdict (CONFIRMED):** The toggle only writes SharedPreferences key 'anonymize_location' (settings_screen_enhanced.dart:211) and reads it back to render the switch (line 54) — a project-wide grep of lib/ shows no other reader. The upload path never consults it: FirebaseService._saveToFirebase writes raw 'latitude'/'longitude' unconditionally (firebase_service.dart:121-122), and the offline queue stores raw coords too (lines 150-151), with no rounding/jitter anywhere. So enabling the toggle changes nothing; precise coordinates (plus userEmail, line 119) are always uploaded to the shared noise_readings collection. Finding is real as described.

**Description:**

The toggle (lines 205-213) writes prefs key 'anonymize_location', but a project-wide grep shows the key is read nowhere except this screen's own _loadSettings. Every reading is uploaded with full-precision latitude/longitude plus reverse-geocoded locationName and the user's email (lib/services/firebase_service.dart lines 117-127), regardless of the setting. A privacy control that silently does nothing is worse than not having it: users toggle it on and believe their home location is protected while exact coordinates tied to their email are published to the community map.

**Failure scenario:**

User enables 'Anonymize Location', records at home nightly. Every doc in noise_readings still contains exact home lat/lng + userEmail, visible to any other app user through the community map/feed.

**Recommended fix:**

Read the pref in FirebaseService before writing: when enabled, round lat/lng to ~2-3 decimal places (or snap to a grid cell) and omit locationName, in both _saveToFirebase and the offline queue path; or remove the toggle until implemented.

---

#### [donate-2] Substring-based URL allowlist in PayPal webview is trivially bypassable - arbitrary URLs can load

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:145`

**Verifier verdict (CONFIRMED):** Real. lib/widgets/paypal_webview_widget.dart:141-153 gates navigation with `url.contains('paypal.com') || url.contains('paypalobjects.com') || url.contains('braintreegateway.com')` on the full URL string, not host parsing. Any URL containing the substring anywhere passes: `https://evil-paypal.com`, `https://paypal.com.attacker.io`, or even `https://attacker.com/?ref=paypal.com`. No scheme check either, so `http://` also passes. Same flaw at line 134 (error suppression) and lines 121-127, where payment success/cancel is detected via `urlString.contains('payment=success')` — spoofable by any allowed page, triggering recordDonation (line 287). Correct fix is parsing `navigationAction.request.url?.host` and exact/suffix-matching the domain.

**Description:**

shouldOverrideUrlLoading (lines 141-154) allows navigation when url.contains('paypal.com'), url.contains('paypalobjects.com'), or url.contains('braintreegateway.com'). A raw substring check on the whole URL string matches attacker-controlled URLs such as https://paypal.com.evil.io/, https://evil.com/paypal.com, or https://evil.com/?ref=paypal.com. I verified in the flutter_inappwebview 6.1.5 package source that the handler IS active (useShouldOverrideUrlLoading is auto-inferred to true when the handler is set, _inferInitialSettings in in_app_webview.dart), so this check is the only navigation gate. Combined with MIXED_CONTENT_ALWAYS_ALLOW (line 94), a MITM or any malicious/injected link inside the page can steer the webview - which sits under a trusted 'PayPal Checkout' app bar - to an arbitrary phishing page.

**Failure scenario:**

During checkout the page (or injected mixed content) navigates to https://paypal.com.evil.io/login which mimics the PayPal login form. The allowlist passes it, the app bar still says 'PayPal Checkout', and the user types PayPal credentials into an attacker's site.

**Recommended fix:**

Parse the URL and compare hosts, not substrings: final host = navigationAction.request.url?.host ?? ''; allow only host == 'www.paypal.com' || host == 'www.sandbox.paypal.com' || host.endsWith('.paypal.com') || host.endsWith('.paypalobjects.com') || host.endsWith('.braintreegateway.com'); also require scheme == 'https'.

---

#### [critic-05] Release builds are signed with the debug keystore

**Severity:** High | **Status:** confirmed | **Category:** security | **Effort:** M

**Location:** `android/app/build.gradle.kts:46`

**Verifier verdict (CONFIRMED):** android/app/build.gradle.kts lines 42-48: the release buildType sets `signingConfig = signingConfigs.getByName("debug")`, with the comment at lines 44-45 explicitly admitting "Signing with the debug keys for now". No release signingConfig is defined anywhere in the file (no signingConfigs block, no key.properties loading). Release builds are therefore signed with the debug keystore exactly as claimed.

**Description:**

android/app/build.gradle.kts lines 42-48: the release buildType still contains the template TODO and `signingConfig = signingConfigs.getByName("debug")`. There is no release keystore, no key.properties handling, and no minify/shrinkResources/proguard configuration. PRODUCTION_CHECKLIST.md line 4 claims '100% PRODUCTION READY' and README line 95-98 documents `flutter build apk --release` for distribution.

**Failure scenario:**

The 'release' APK distributed to the Sri Lankan government stakeholders is signed with the publicly-known Android debug key: it cannot be uploaded to Play Store, updates cannot be verified as coming from the developer, and anyone can build an identically-signed APK to replace/impersonate the app on sideload-based distribution.

**Recommended fix:**

Generate an upload keystore, add key.properties (gitignored) loading in build.gradle.kts, define signingConfigs.release and point the release buildType at it; optionally enable isMinifyEnabled/shrinkResources with keep rules for tflite_flutter and flutter_local_notifications.

---

### Medium

#### [donate-11] MIXED_CONTENT_ALWAYS_ALLOW enabled on the payment webview

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/widgets/paypal_webview_widget.dart:94`

**Description:**

InAppWebViewSettings sets mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW (line 94), permitting plaintext-HTTP scripts/frames/images to load inside HTTPS PayPal pages. PayPal is fully HTTPS, so this setting only widens the attack surface: a network MITM can inject active HTTP content into the checkout page, which pairs badly with the bypassable navigation allowlist (donate-2).

**Failure scenario:**

User donates over an untrusted coffee-shop Wi-Fi. An attacker MITMs an HTTP subresource request the webview is now allowed to load, injecting a script into the payment page context that overlays a fake card form or redirects (allowed by the substring check) to a phishing site.

**Recommended fix:**

Use MixedContentMode.MIXED_CONTENT_NEVER_ALLOW (or omit the setting; never-allow is the safe default for API 21+ payment flows).

---

#### [donate-10] PAYPAL_SECRET getter reads from a .env that ships inside the APK; bundled .env also leaks developer PII

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/services/donation_service.dart:10`

**Description:**

DonationService.secret (line 10) reads dotenv.env['PAYPAL_SECRET'], and pubspec.yaml line 138 bundles '.env' as a Flutter asset - verified the file lands in build/app/.../flutter_assets/.env for both debug and release. Any secret a developer follows this getter's lead and adds to .env ships in plaintext to every user (unzip the APK to read it). The getter is currently unused (grep: zero call sites) and no PAYPAL_SECRET is set today, but the shipped .env already contains the developer's personal Gmail address and production-switch instructions in comments (.env lines 20-24), which every installed copy of the app carries.

**Failure scenario:**

A developer implementing server-verified payments sees the existing 'secret' getter, adds PAYPAL_SECRET=<real secret> to .env, and releases. Anyone who downloads the APK extracts flutter_assets/.env and gains full PayPal API access (refunds, payouts) for the account.

**Recommended fix:**

Delete the unused 'secret' getter (PayPal secrets must live server-side only), strip comments/personal email and non-client values from the bundled .env, and add a comment in donation_service.dart stating that .env is a shipped asset and must never hold secrets.

---

#### [sec-11] Debug-level logging left enabled for production; logs include PII and payment URLs

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/utils/app_logger.dart:22`

**Description:**

AppLogger is hard-coded to Level.debug with the comment 'TODO: Change to Level.error for production' (line 22) — the debug flag was never flipped. Release builds therefore emit full logs to logcat/console including: the complete PayPal URL with the merchant business email (paypal_webview_widget.dart:45), every WebView navigation during checkout (lines 105, 112), Nominatim search queries typed by the user (search_list_screen.dart:51,82), sync record IDs embedding userIds (sync_service.dart:159,168), and location names per marker (map_view_screen.dart:194-196).

**Failure scenario:**

A user's device with USB debugging or a support-log capture shares logcat output; it contains their location search history, the merchant email, and their checkout navigation trail.

**Recommended fix:**

Gate the level on build mode: level: kReleaseMode ? Level.warning : Level.debug (import package:flutter/foundation.dart), and stop logging full URLs/emails at info level (log host or redacted forms only).

---

#### [settings-11] Account deletion never deletes the users/{uid} profile document — PII retained after deletion

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/screens/settings_screen_enhanced.dart:883`

**Description:**

The delete flow (lines 883-904) anonymizes noise_readings and deletes the Auth user, but the users/{uid} document — which registration_screen.dart line 61 and edit_profile_screen.dart lines 90-95/115-119 populate with displayName and email — is never touched. After 'successful' account deletion, the user's name and email remain in Firestore indefinitely, contradicting the dialog's promise that only anonymous community data is preserved.

**Failure scenario:**

User deletes their account and later exercises a GDPR-style erasure expectation; their email and display name are still stored in users/{uid} and readable by anything with access to that collection.

**Recommended fix:**

Add `batch.delete(firestore.collection('users').doc(uid))` (or a separate delete before user.delete()) to the anonymization step.

---

#### [sec-13] Unverified new email is written to the users doc and broadcast into all noise_readings before ownership verification

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** M

**Location:** `lib/screens/edit_profile_screen.dart:115`

**Description:**

When the email changes, _updateProfile calls user.verifyBeforeUpdateEmail(newEmail) (line 100) — which only SENDS a verification mail; the auth email does not change until the link is clicked — but then immediately writes 'email': newEmail into users/{uid} (lines 115-119) and batch-updates 'userEmail': newEmail across every one of the user's noise_readings (lines 126-140). Nothing validates that the user owns newEmail, so any string typed into the field is published as that user's identity in community-visible data (community feed shows it masked, raw doc holds it fully — see sec-2). Firestore and Auth also permanently diverge if the user never completes verification.

**Failure scenario:**

A malicious user edits their profile email to victim@company.com. Verification never completes, but all their noise readings now carry userEmail=victim@company.com, shown as vic***@company.com in the community feed — framing the victim as the source of noise reports at arbitrary locations.

**Recommended fix:**

Do not write newEmail to Firestore at edit time. Listen for the auth email actually changing (user.reload() after re-login, or an idTokenChanges listener / a Cloud Function on auth events) and only then propagate user.email (the verified value) to users/{uid} and noise_readings.

---

#### [settings-7] 'Share Data with Researchers' consent toggle is never consulted — data shared regardless

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** M

**Location:** `lib/screens/settings_screen_enhanced.dart:214`

**Description:**

The toggle saves 'share_data_with_researchers' (line 220) but the key has zero readers in the codebase. All readings are written identically to the shared noise_readings collection whether the toggle is on or off, so opting out has no effect on what researchers (or anyone querying the collection) can access. This is a consent control that misrepresents actual data handling.

**Failure scenario:**

Privacy-conscious user turns the toggle off before recording. Their readings land in noise_readings exactly as before, indistinguishable from consenting users' data.

**Recommended fix:**

Stamp each reading with a sharedWithResearchers boolean read from prefs at save time (firebase_service.dart _saveToFirebase and offline path) so downstream consumers can filter, or remove the toggle.

---

#### [sec-7] Donation 'success' is detected by URL substring with no server verification — spoofable and effectively dead code

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** M

**Location:** `lib/widgets/paypal_webview_widget.dart:121`

**Description:**

onLoadStop (lines 121-128) declares payment complete when any loaded URL contains 'payment=success' or 'payment=completed', then records the donation locally and shows a 'Payment Complete!' overlay (lines 285-294). The classic webscr _donations flow launched at lines 41-43 passes no return/cancel URLs, so PayPal never redirects with these parameters — legitimate payments are never confirmed. Conversely, ANY URL containing that substring (e.g. a paypal.com page with ?payment=success in a query, or any URL slipping through the sec-6 allow-list bypass) triggers the success path. Donation totals in the impact tracker are thus unverifiable client-side state.

**Failure scenario:**

A user completes a real PayPal donation: the app never shows success and records nothing. Alternatively a crafted page navigates to any URL containing 'payment=success': the app shows 'Payment Complete!' and increments the monthly donation tracker although no money moved.

**Recommended fix:**

Pass explicit 'return' and 'cancel_return' URLs (e.g. https://<your-domain>/donation/success) to the webscr URL and match them by exact parsed URL, or move to the PayPal Orders API with server-side capture verification via a backend/Cloud Function. Do not record donations from URL heuristics.

---

#### [donate-8] Substring-based navigation allowlist in BMC webview is bypassable (same flaw as PayPal webview)

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/widgets/buy_me_coffee_widget.dart:64`

**Description:**

onNavigationRequest (lines 62-72) allows any URL where request.url.contains('buymeacoffee.com'), contains('stripe.com'), or contains('paypal.com'). URLs like https://buymeacoffee.com.evil.io/ or https://evil.com/pay?to=stripe.com pass the check, letting the webview - titled 'Buy Me a Coffee' - navigate to arbitrary sites. BMC creator pages contain user-configurable links, and the checkout embeds third-party content, so untrusted URLs do flow through this gate.

**Failure scenario:**

A link on the loaded page (or a redirect chain) points to https://stripe.com.evil.io/checkout mimicking a card form. The substring check allows it; the user enters card details into a phishing page inside the app's trusted chrome.

**Recommended fix:**

Compare parsed hosts instead of substrings: final host = Uri.parse(request.url).host; allow host == 'buymeacoffee.com' || host.endsWith('.buymeacoffee.com') || host.endsWith('.stripe.com') || host == 'stripe.com' || host.endsWith('.paypal.com'); require https scheme.

---

#### [social-8] Email masking is skipped entirely for local parts of 3 characters or fewer — full email of other users displayed

**Severity:** Medium | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/screens/community_feed_screen.dart:216`

**Description:**

Lines 212-218: masking only happens inside `if (emailParts[0].length > 3)`. For emails like 'sam@gmail.com', 'joe@company.lk' or 'a.b@x.com', displayName stays the untouched full address and is rendered for every app user (line 346). The privacy feature is silently defeated for exactly the class of users it was built to protect.

**Failure scenario:**

A user registered as 'sam@company.com' submits a reading. Every other user opening Community Feed sees 'sam@company.com' verbatim next to their location and time — full PII disclosure.

**Recommended fix:**

Handle short local parts: mask to at most the first character (or fixed '***@domain'), e.g. `final visible = emailParts[0].length > 3 ? emailParts[0].substring(0,3) : emailParts[0].substring(0, 1); displayName = '$visible***@${emailParts[1]}';` — better yet, stop persisting/displaying raw emails and store a display name.

---

### Low

#### [sec-17] Login error handling enables account enumeration

**Severity:** Low | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/screens/login_screen.dart:65`

**Description:**

The FirebaseAuthException handler maps 'user-not-found' to 'No user found with this email' and 'wrong-password' to 'Wrong password' (login_screen.dart:65-71), deliberately distinguishing whether an email is registered. If the Firebase project has email-enumeration protection disabled (default for older projects), an attacker can probe which emails have accounts — emails that are then linkable to home locations via sec-2.

**Failure scenario:**

An attacker scripts the login endpoint (or drives the UI) with a candidate email list; 'No user found' vs 'Wrong password' responses reveal exactly which people use this noise-mapping app.

**Recommended fix:**

Show a single generic message ('Incorrect email or password') for user-not-found, wrong-password, and invalid-credential codes, and enable email enumeration protection in Firebase Authentication settings.

---

#### [sec-16] Weak auth input validation: 6-char password minimum, naive email check, raw exception text shown to users

**Severity:** Low | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/screens/registration_screen.dart:323`

**Description:**

Registration accepts any 6-character password (line 323-326) with no complexity/breach checks, and validates email only via contains('@') && contains('.') (lines 271-274; login uses just contains('@') at login_screen.dart:159). The generic catch at registration_screen.dart:111-119 surfaces raw e.toString() to the UI (also settings_screen_enhanced.dart:810), leaking internal error details. Change-password enforces the same weak 6-char minimum (settings_screen_enhanced.dart:740).

**Failure scenario:**

Users register with 'aaaaaa' as their password; credential-stuffing and brute-force attacks succeed at high rates against accounts that guard location-history PII. A Firestore write failure during registration shows the user a raw exception string with internal details.

**Recommended fix:**

Enforce a stronger client policy (>= 8 chars, mixed classes or a passphrase length rule) mirrored by the Firebase Auth password policy setting in the console; validate emails with a proper regex or RFC-lite check; replace e.toString() in user-facing snackbars with a generic message while logging the detail.

---

#### [sec-14] User search text interpolated unencoded into Nominatim URLs — query-string parameter injection

**Severity:** Low | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/screens/map_view_screen.dart:363`

**Description:**

Both search paths build the Nominatim URL with raw string interpolation: map_view_screen.dart:363 and search_list_screen.dart:56 use '...search?format=json&q=$query&limit=50...'. Input containing '&', '#', '=' or '%' rewrites the request: typing 'colombo&limit=500&polygon_geojson=1' overrides API parameters, and '#' truncates the query. Impact is limited to the third-party OSM API (no local injection), but it breaks searches with legitimate special characters and lets users manipulate request parameters sent under the app's User-Agent.

**Failure scenario:**

A user searches for 'M&S Colombo'; everything after '&' becomes a bogus parameter, the query silently becomes 'M', and wrong results are shown. A mischievous user injects '&limit=50000' style parameters against Nominatim usage policy under the app's identity.

**Recommended fix:**

Build the URL with Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'json', 'q': query, 'limit': '50', 'addressdetails': '1', ...}) so every parameter is percent-encoded, in both files.

---

#### [boot-15] Firebase API keys committed without evidence of key restrictions or App Check — abuse surface for Auth endpoints

**Severity:** Low | **Status:** unverified | **Category:** security | **Effort:** S

**Location:** `lib/firebase_options.dart:50`

**Description:**

firebase_options.dart commits web/android/ios API keys (lines 49-73). Firebase API keys are identifiers, not secrets, so committing them is expected — but they allow anyone to call Identity Toolkit endpoints for this project (sign-up spam, password brute-force attempts, email enumeration probing) unless mitigations exist. Nothing in the repo indicates Google Cloud API-key application restrictions (Android package+SHA-1, iOS bundle ID) or Firebase App Check enforcement, and the login code's reliance on legacy 'user-not-found'/'wrong-password' codes (login_screen.dart:65-67) suggests email-enumeration protection may have been toggled off during development.

**Failure scenario:**

A scraper harvests the API key from the public repo/APK and scripts createUserWithEmailAndPassword calls, flooding the project's user table and consuming the Auth quota; with enumeration protection off, they can also probe which emails have accounts.

**Recommended fix:**

In Google Cloud console, restrict the Android key to the app's package name + signing SHA-1 and the iOS key to the bundle ID; enable Firebase App Check (Play Integrity / App Attest) and enforce it for Auth and Firestore; confirm email-enumeration protection is ON (and fix login error mapping per boot-4 accordingly).

---

## Quick Wins (under 1 hour each)

- [ ] **sec-17** - Login error handling enables account enumeration (`lib/screens/login_screen.dart:65`)
- [ ] **donate-11** - MIXED_CONTENT_ALWAYS_ALLOW enabled on the payment webview (`lib/widgets/paypal_webview_widget.dart:94`)
- [ ] **donate-10** - PAYPAL_SECRET getter reads from a .env that ships inside the APK; bundled .env also leaks developer PII (`lib/services/donation_service.dart:10`)
- [ ] **sec-10** - Info.plist missing NSMicrophoneUsageDescription and NSLocationWhenInUseUsageDescription — iOS build crashes on first recording (`ios/Runner/Info.plist:4`)
- [ ] **sec-11** - Debug-level logging left enabled for production; logs include PII and payment URLs (`lib/utils/app_logger.dart:22`)
- [ ] **sec-16** - Weak auth input validation: 6-char password minimum, naive email check, raw exception text shown to users (`lib/screens/registration_screen.dart:323`)
- [ ] **settings-11** - Account deletion never deletes the users/{uid} profile document — PII retained after deletion (`lib/screens/settings_screen_enhanced.dart:883`)
- [ ] **sec-14** - User search text interpolated unencoded into Nominatim URLs — query-string parameter injection (`lib/screens/map_view_screen.dart:363`)
- [ ] **donate-2** - Substring-based URL allowlist in PayPal webview is trivially bypassable - arbitrary URLs can load (`lib/widgets/paypal_webview_widget.dart:145`)
- [ ] **sec-3** - Account deletion anonymizes all readings BEFORE deleting the auth user — requires-recent-login leaves data destroyed but account alive (`lib/screens/settings_screen_enhanced.dart:901`)
- [ ] **donate-8** - Substring-based navigation allowlist in BMC webview is bypassable (same flaw as PayPal webview) (`lib/widgets/buy_me_coffee_widget.dart:64`)
- [ ] **social-8** - Email masking is skipped entirely for local parts of 3 characters or fewer — full email of other users displayed (`lib/screens/community_feed_screen.dart:216`)
- [ ] **boot-15** - Firebase API keys committed without evidence of key restrictions or App Check — abuse surface for Auth endpoints (`lib/firebase_options.dart:50`)
