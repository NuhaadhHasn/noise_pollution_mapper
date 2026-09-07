# Implementation Spec — Defect Cluster: Platform & Release Blockers

Executor: apply steps in order, one commit per step, `flutter analyze` clean after every commit. Do NOT re-audit; all findings below were adversarially verified (see `audit/00_MASTER_AUDIT_REPORT.md` and `audit/05_SECURITY_AUDIT.md` for verifier evidence). All paths are relative to the project root `noise_pollution_mapper/`.

## Scope

| ID | One-liner | Verifier status |
|---|---|---|
| critic-01 / sec-10 | `ios/Runner/Info.plist` has ZERO permission usage descriptions (`NSMicrophoneUsageDescription`, `NSLocationWhenInUseUsageDescription` missing) — iOS TCC-kills the app on first recording | CONFIRMED |
| critic-02 | `.env` is bundled as a Flutter asset (`pubspec.yaml:138`) and ships in every APK/IPA; donation config + API keys extractable with `unzip apk`. Verifier nuance: no real PayPal REST secret is in `.env` today (`PAYPAL_SECRET` is undefined; `PAYPAL_CLIENT_ID` is a PayPal business email), but the mechanism is real, `.env.example` instructs devs to put a real secret there, and `donation_service.dart` reads `PAYPAL_SECRET` on-device — the design must be removed, not patched | CONFIRMED (Critical, treat mechanism as the defect) |
| critic-05 | Release builds signed with the debug keystore (`android/app/build.gradle.kts:46`) — un-shippable to Play Store, trivially impersonated | CONFIRMED |
| boot-1 / flow1-1 | Unguarded `await Firebase.initializeApp(...)` (and every other pre-`runApp` await) at `lib/main.dart:38` — any failure leaves a permanent blank screen | CONFIRMED |
| flow1-2 | Onboarding is never persisted as seen — `lib/screens/splash_screen.dart:36` unconditionally pushes `OnboardingScreen`, so it replays on every signed-out launch and after every logout | CONFIRMED |

## Pre-reading

Open these files completely before editing anything:

1. `lib/main.dart` (entire file — you will restructure `main()` in Steps 4 and 6)
2. `ios/Runner/Info.plist`
3. `android/app/build.gradle.kts` and `android/.gitignore`
4. `lib/screens/splash_screen.dart`, `lib/screens/onboarding_screen.dart`, `lib/screens/login_screen.dart` (login only to confirm it has no Firebase call in `build`/`initState` — it does not; Firebase is only touched inside `_handleLogin`)
5. `lib/services/donation_service.dart`, `lib/screens/donation_screen.dart`, `lib/widgets/paypal_webview_widget.dart` (lines 1–60)
6. `pubspec.yaml`, `.env.example`, `.gitignore` (root; `.env` is gitignored at line 16 but still bundled as an asset)
7. `lib/utils/app_logger.dart`, `lib/utils/theme_helper.dart`, `lib/theme/app_theme.dart` (confirm `AppLogger.error(String, [dynamic error, StackTrace?])`, `ThemeHelper.getBackgroundColor/getTextColor/getSecondaryTextColor/getButtonColor/getButtonTextColor`, `AppTheme.generateDarkTheme(Color)`, `AppTheme.primaryPurple` all exist — verified)
8. `test/widget/splash_screen_test.dart` (existing tests must keep passing)

Facts verified during spec authoring (do not re-derive):

- The ONLY consumers of `flutter_dotenv` in `lib/` are `lib/main.dart` (load) and `lib/services/donation_service.dart` (reads `PAYPAL_CLIENT_ID`, `PAYPAL_SECRET`, `PAYPAL_SANDBOX_MODE`, `BUY_ME_A_COFFEE_URL`). The `FIREBASE_*`, `GOOGLE_MAPS_API_KEY`, `CONFIDENCE_THRESHOLD`, `CLASSIFICATION_INTERVAL_SECONDS`, `HIGH_NOISE_THRESHOLD` keys in `.env` are read by NOTHING (Firebase config comes from `lib/firebase_options.dart`).
- `DonationService.secret` has zero call sites. `DonationService.clientId` is consumed by `donation_screen.dart:44` and `paypal_webview_widget.dart:37` (where it is used as a PayPal *business email* in a public `cmd=_donations` URL).
- There is no `ios/Podfile` yet (generated on first iOS build on macOS).
- `android/.gitignore` already ignores `key.properties`, `**/*.keystore`, `**/*.jks`.
- No code anywhere reads/writes any `has_seen_onboarding`-style flag (project-wide grep is empty).
- Installed packages relevant here (from `pubspec.yaml`): `firebase_core: ^3.8.1` (`Firebase.apps`, `Firebase.initializeApp` exist), `cloud_firestore: ^5.5.0` (`collection().doc().get()`, `DocumentSnapshot.exists/.data()` exist), `shared_preferences: ^2.3.3` (`SharedPreferences.getInstance/getBool/setBool`, `setMockInitialValues` exist), `flutter_dotenv: ^5.1.0` (being removed).

---

## Step 1 — Add iOS permission usage descriptions (critic-01 / sec-10)

**Goal:** Stop iOS from TCC-killing the app on first microphone/location access by declaring the required usage-description strings.

**Files:** `ios/Runner/Info.plist`

**Exact changes:**

BEFORE (`ios/Runner/Info.plist`, end of file, lines 44–49):

```xml
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
</dict>
</plist>
```

AFTER:

```xml
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Noise Mapper uses the microphone to measure ambient noise levels in decibels and classify environmental sounds. Audio is analyzed on-device and is never uploaded.</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Noise Mapper uses your location to place your noise readings on the community noise map.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Noise Mapper uses your location to place your noise readings on the community noise map.</string>
</dict>
</plist>
```

(The file uses TAB indentation — match it. `NSLocationAlwaysAndWhenInUseUsageDescription` is included because `geolocator` 13.x / `permission_handler` 11.x may surface the always-and-when-in-use prompt path; it is harmless when only when-in-use is requested.)

**Edge cases to preserve:**
- Do not touch any existing key; only append before `</dict>`.
- When `ios/Podfile` is later generated (first `flutter build ios` on macOS), optionally add `permission_handler` `GCC_PREPROCESSOR_DEFINITIONS` macros (`PERMISSION_MICROPHONE=1`, `PERMISSION_LOCATION=1`) in `post_install` to strip unused permission code — NOT required for correctness; `permission_handler` compiles all handlers by default. Do not create a Podfile by hand in this commit.

**Acceptance criteria:**
- `Info.plist` contains exactly the three new keys with non-empty user-facing strings.
- On an iOS device/simulator build, tapping record on the Dashboard shows the microphone permission dialog instead of crashing.

**Verify:**
```bash
# XML well-formedness. On macOS: plutil -lint ios/Runner/Info.plist
# On Windows, plistlib both parses and validates structure (trusted local file):
python -c "import plistlib; d=plistlib.load(open('ios/Runner/Info.plist','rb')); print('OK', 'NSMicrophoneUsageDescription' in d, 'NSLocationWhenInUseUsageDescription' in d)"
grep -c "UsageDescription" ios/Runner/Info.plist   # expect 3
flutter analyze                                     # unchanged, must be clean
```
Manual (macOS only, optional now): `flutter build ios --no-codesign` succeeds; run on simulator, tap the mic button → permission prompt appears.

**Commit title:** `fix(ios): add microphone and location usage descriptions to Info.plist`

---

## Step 2 — Sign release builds with a real keystore (critic-05)

**Goal:** Introduce a `key.properties`-driven release signing config so store builds are signed with a release keystore, while machines without the keystore still fall back to debug signing for local `flutter run --release`.

**Files:** `android/app/build.gradle.kts`, new `android/key.properties.example`

**Exact changes:**

1) BEFORE (`android/app/build.gradle.kts`, lines 1–9):

```kotlin
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
```

AFTER:

```kotlin
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: real keystore config lives in android/key.properties (gitignored).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
```

2) BEFORE (`android/app/build.gradle.kts`, lines 42–48):

```kotlin
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
```

AFTER:

```kotlin
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Store uploads REQUIRE android/key.properties + the release keystore.
            // Machines without it (fresh clones, CI without secrets) fall back to
            // debug signing so `flutter run --release` still works locally.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

3) NEW FILE `android/key.properties.example` (full contents — this template IS committed; the real `key.properties` is already gitignored via `android/.gitignore:key.properties`):

```properties
# Copy to android/key.properties and fill in real values. NEVER commit key.properties.
# Generate the keystore once (keep it backed up outside the repo — losing it means
# losing the ability to update the app on the Play Store):
#   keytool -genkey -v -keystore %USERPROFILE%\noise-mapper-release.jks ^
#     -keyalg RSA -keysize 2048 -validity 10000 -alias noise_mapper
storePassword=CHANGE_ME
keyPassword=CHANGE_ME
keyAlias=noise_mapper
# Absolute path, or path relative to android/app/
storeFile=C:/Users/YOUR_USER/noise-mapper-release.jks
```

**Edge cases to preserve:**
- `keystorePropertiesFile` must resolve against `rootProject` (the `android/` directory), so the file is `android/key.properties` — this matches the existing `android/.gitignore` entry.
- Keep the debug fallback: builds must NOT fail on machines without the keystore.
- Do not touch `externalNativeBuild`, desugaring, or `defaultConfig`.
- `**/*.jks` is already gitignored; do not store the keystore inside the repo anyway.

**Acceptance criteria:**
- Without `android/key.properties`: `flutter build apk --release` succeeds (debug-signed, as today).
- With `android/key.properties` + keystore present: `flutter build apk --release` produces an APK whose signer certificate is the release keystore (CN you entered at `keytool -genkey`), not `CN=Android Debug`.

**Verify:**
```bash
flutter analyze                          # clean (no Dart change, but run anyway)
flutter build apk --release              # succeeds without key.properties
# After creating a keystore + key.properties (manual, one-time):
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
#   -> Owner must NOT be "CN=Android Debug"
```

**Commit title:** `fix(android): sign release builds from key.properties keystore with debug fallback`

---

## Step 3 — Persist onboarding as seen (flow1-2)

**Goal:** Show onboarding only on true first launch by persisting a `has_seen_onboarding` flag; signed-out relaunches and logouts land directly on Login.

**Files:** `lib/screens/splash_screen.dart`, `lib/screens/onboarding_screen.dart`, new `test/widget/splash_navigation_test.dart`

**Exact changes:**

1) BEFORE (`lib/screens/splash_screen.dart`, lines 1–5):

```dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import 'onboarding_screen.dart';
```

AFTER:

```dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
```

2) BEFORE (`lib/screens/splash_screen.dart`, lines 35–43):

```dart
    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }
```

AFTER:

```dart
    // Navigate after 3 seconds. Onboarding is shown only until the user has
    // completed it once (flow1-2); afterwards signed-out launches go to Login.
    Timer(const Duration(seconds: 3), _navigateNext);
  }

  Future<void> _navigateNext() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            hasSeenOnboarding ? const LoginScreen() : const OnboardingScreen(),
      ),
    );
  }
```

3) BEFORE (`lib/screens/onboarding_screen.dart`, lines 1–5):

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import 'login_screen.dart';
import '../widgets/world_map_background.dart';
```

AFTER:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import 'login_screen.dart';
import '../widgets/world_map_background.dart';
```

4) BEFORE (`lib/screens/onboarding_screen.dart`, lines 36–41):

```dart
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
```

AFTER:

```dart
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('has_seen_onboarding', true);
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
```

5) NEW FILE `test/widget/splash_navigation_test.dart` (full contents):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:noise_pollution_mapper/screens/login_screen.dart';
import 'package:noise_pollution_mapper/screens/onboarding_screen.dart';
import 'package:noise_pollution_mapper/screens/splash_screen.dart';

// flow1-2: splash routes to Onboarding on first launch only, Login afterwards.
void main() {
  testWidgets('first launch: splash navigates to onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await tester.pump(const Duration(seconds: 3)); // fire the splash timer
    await tester.pump(); // start the pushReplacement transition
    await tester.pump(const Duration(seconds: 1)); // finish the route transition

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('returning launch: splash skips onboarding and shows login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
```

Do NOT use `pumpAndSettle()` in these tests — `WorldMapBackground`/screen animations may repeat and time it out; the explicit pumps above are sufficient. `LoginScreen` is safe to pump: it touches Firebase only inside `_handleLogin`, never in `build`/`initState` (verified).

**Edge cases to preserve:**
- Keep the 3-second timer and fade animation exactly as-is.
- The `mounted` guard before `Navigator` must remain (State is disposed if the auth stream swaps `home` mid-splash).
- `context.mounted` (not bare `mounted`) in the `StatelessWidget` onboarding button — required to keep `use_build_context_synchronously` lint clean.
- Logout flow: `FirebaseAuth.signOut()` re-shows `SplashScreen` via the auth `StreamBuilder` in `main.dart`; after this change it proceeds to `LoginScreen`, not onboarding — that is the intended behavior.
- Do not modify `test/widget/onboarding_screen_test.dart` or `test/widget/splash_screen_test.dart`; they only pump-render and are unaffected (the splash test pumps without firing navigation).

**Acceptance criteria:**
- Fresh install (or cleared app data): Splash → Onboarding → "Get started" → Login.
- Kill and relaunch while signed out: Splash → Login (no onboarding).
- Log out from the app: Splash → Login (no onboarding).

**Verify:**
```bash
flutter analyze                                        # clean
flutter test test/widget/splash_navigation_test.dart   # 2 tests pass
flutter test test/widget/splash_screen_test.dart       # still passes (no regression)
```
Manual: run app, complete onboarding once, log out → Login appears directly after splash.

**Commit title:** `fix(onboarding): persist has_seen_onboarding and skip replay on signed-out launches`

---

## Step 4 — Move donation config to Firestore; stop bundling .env (critic-02, code)

**Goal:** Remove the shipped-secrets mechanism entirely: drop the `.env` asset and `flutter_dotenv`, delete the on-device `PAYPAL_SECRET` reader, and serve donation display config from a server-side Firestore document `app_config/donations`.

Rationale for Firestore over Firebase Remote Config: `cloud_firestore` is already installed (zero new dependencies, zero unverifiable APIs), the donation screen is only reachable post-login (authenticated reads), and the config is three public display values. This is the "server" option of the remediation. This is a **doc-ID `get()`** — no query, therefore **no new composite index**; the project's only composite index remains `noise_readings (userId ASC, timestamp DESC)`.

**Files:** `pubspec.yaml`, `lib/main.dart`, `lib/services/donation_service.dart`, `lib/screens/donation_screen.dart`, new `test/unit/donation_service_config_test.dart`

**Exact changes:**

1) BEFORE (`pubspec.yaml`, lines 73–78):

```yaml
  # Utils
  intl: ^0.20.1
  logger: ^2.4.0
  flutter_dotenv: ^5.1.0
  http: ^1.2.0
  flutter_launcher_icons: ^0.14.4
```

AFTER:

```yaml
  # Utils
  intl: ^0.20.1
  logger: ^2.4.0
  http: ^1.2.0
  flutter_launcher_icons: ^0.14.4
```

2) BEFORE (`pubspec.yaml`, lines 133–138):

```yaml
  # To add assets to your application, add an assets section, like this:
  assets:
    - assets/images/backgrounds/
    - assets/icons/
    - assets/models/
    - .env
```

AFTER:

```yaml
  # To add assets to your application, add an assets section, like this:
  # SECURITY: never add .env or any credentials file here — assets ship
  # in plaintext inside every APK/IPA (audit finding critic-02).
  assets:
    - assets/images/backgrounds/
    - assets/icons/
    - assets/models/
```

3) BEFORE (`lib/main.dart`, lines 1–16 — imports):

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
```

AFTER (delete the dotenv import only):

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'firebase_options.dart';
```

4) BEFORE (`lib/main.dart`, lines 26–38):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    AppLogger.info('Environment variables loaded successfully');
  } catch (e) {
    AppLogger.warning('Failed to load .env file (using defaults): $e');
    // App will continue with hardcoded defaults if .env doesn't exist
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

AFTER:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

5) BEFORE (`lib/services/donation_service.dart`, lines 1–16):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service class for handling donation-related operations
class DonationService {
  // PayPal configuration from environment variables
  static String get clientId => dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
  static String get secret => dotenv.env['PAYPAL_SECRET'] ?? '';
  static bool get isSandboxMode => 
    (dotenv.env['PAYPAL_SANDBOX_MODE'] ?? 'true').toLowerCase() == 'true';

  // Buy Me a Coffee URL
  static String get buyMeACoffeeUrl => 
    dotenv.env['BUY_ME_A_COFFEE_URL'] ?? '';
```

AFTER (note: the `secret` getter is deleted with no replacement — it has zero call sites and merchant secrets must never exist on-device):

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service class for handling donation-related operations
class DonationService {
  /// Donation display config served from Firestore doc `app_config/donations`.
  /// Contains ONLY public values (a PayPal business email used in a public
  /// donation URL, a sandbox flag, and a Buy Me a Coffee URL). Merchant
  /// secrets must never be stored on-device (audit finding critic-02).
  static Map<String, dynamic>? _remoteConfig;

  /// Fetches the donation config once per app session. Safe to call
  /// repeatedly; failures leave the safe defaults in place.
  static Future<void> ensureConfigLoaded() async {
    if (_remoteConfig != null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('donations')
          .get();
      final data = doc.data();
      if (doc.exists && data != null) {
        applyRemoteConfig(data);
      } else {
        AppLogger.warning(
          '[DonationService] app_config/donations document is missing',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[DonationService] Failed to load donation config',
        e,
        stackTrace,
      );
    }
  }

  /// Applies a config map directly (also used by unit tests).
  @visibleForTesting
  static void applyRemoteConfig(Map<String, dynamic> data) {
    _remoteConfig = data;
  }

  @visibleForTesting
  static void resetConfigForTest() {
    _remoteConfig = null;
  }

  /// PayPal business email used to build the public donation URL.
  static String get clientId =>
      (_remoteConfig?['paypalBusinessEmail'] as String?) ?? '';

  static bool get isSandboxMode =>
      (_remoteConfig?['paypalSandboxMode'] as bool?) ?? true;

  // Buy Me a Coffee URL
  static String get buyMeACoffeeUrl =>
      (_remoteConfig?['buyMeACoffeeUrl'] as String?) ?? '';
```

(`@visibleForTesting` is exported by `package:flutter/material.dart` via foundation — already imported. Everything from `// Preset donation amounts` (line 18) down is unchanged.)

6) BEFORE (`lib/screens/donation_screen.dart`, lines 35–52):

```dart
  void _processPayPalDonation(double amount) {
    // Validate amount
    final error = DonationService.getValidationError(amount);
    if (error != null) {
      DonationService.showErrorSnackBar(context, error);
      return;
    }

    // Check if PayPal credentials are configured
    if (DonationService.clientId.isEmpty || 
        DonationService.clientId.contains('your_paypal')) {
      DonationService.showErrorSnackBar(
        context,
        'PayPal credentials not configured. Please contact the developer.',
      );
      AppLogger.error('PayPal credentials not configured in .env file');
      return;
    }
```

AFTER:

```dart
  Future<void> _processPayPalDonation(double amount) async {
    // Validate amount
    final error = DonationService.getValidationError(amount);
    if (error != null) {
      DonationService.showErrorSnackBar(context, error);
      return;
    }

    await DonationService.ensureConfigLoaded();
    if (!mounted) return;

    // Check if PayPal donation is configured
    if (DonationService.clientId.isEmpty ||
        DonationService.clientId.contains('your_paypal')) {
      DonationService.showErrorSnackBar(
        context,
        'PayPal donations are not configured. Please contact the developer.',
      );
      AppLogger.error(
        'PayPal donation config missing in app_config/donations',
      );
      return;
    }
```

7) BEFORE (`lib/screens/donation_screen.dart`, lines 66–75):

```dart
  void _openBuyMeACoffee() {
    if (DonationService.buyMeACoffeeUrl.isEmpty || 
        DonationService.buyMeACoffeeUrl.contains('yourusername')) {
      DonationService.showErrorSnackBar(
        context,
        'Buy Me a Coffee URL not configured. Please contact the developer.',
      );
      AppLogger.error('Buy Me a Coffee URL not configured in .env file');
      return;
    }
```

AFTER:

```dart
  Future<void> _openBuyMeACoffee() async {
    await DonationService.ensureConfigLoaded();
    if (!mounted) return;

    if (DonationService.buyMeACoffeeUrl.isEmpty ||
        DonationService.buyMeACoffeeUrl.contains('yourusername')) {
      DonationService.showErrorSnackBar(
        context,
        'Buy Me a Coffee URL not configured. Please contact the developer.',
      );
      AppLogger.error(
        'Buy Me a Coffee URL missing in app_config/donations',
      );
      return;
    }
```

(Both call sites already tolerate the new `Future<void>` return: the donate button wraps `_processPayPalDonation(amount)` in a closure at line ~354, and `onPressed: _openBuyMeACoffee` at line ~551 accepts a `Future<void> Function()`. No other edits needed there. `paypal_webview_widget.dart` line 37 keeps reading `DonationService.clientId` synchronously — by the time it is pushed, `_processPayPalDonation` has already awaited `ensureConfigLoaded()`.)

8) NEW FILE `test/unit/donation_service_config_test.dart` (full contents):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/services/donation_service.dart';

// critic-02: donation config comes from app_config/donations, with safe
// defaults when it has not loaded. No secrets exist on-device.
void main() {
  tearDown(DonationService.resetConfigForTest);

  test('defaults are safe when no config is loaded', () {
    expect(DonationService.clientId, '');
    expect(DonationService.isSandboxMode, true);
    expect(DonationService.buyMeACoffeeUrl, '');
  });

  test('applyRemoteConfig exposes the served values', () {
    DonationService.applyRemoteConfig({
      'paypalBusinessEmail': 'donations@example.com',
      'paypalSandboxMode': false,
      'buyMeACoffeeUrl': 'https://www.buymeacoffee.com/example',
    });

    expect(DonationService.clientId, 'donations@example.com');
    expect(DonationService.isSandboxMode, false);
    expect(
      DonationService.buyMeACoffeeUrl,
      'https://www.buymeacoffee.com/example',
    );
  });

  test('wrong-typed values fall back to defaults', () {
    DonationService.applyRemoteConfig({
      'paypalBusinessEmail': 42,
      'paypalSandboxMode': 'yes',
      'buyMeACoffeeUrl': null,
    });

    expect(DonationService.clientId, '');
    expect(DonationService.isSandboxMode, true);
    expect(DonationService.buyMeACoffeeUrl, '');
  });
}
```

Note: `applyRemoteConfig` must therefore use safe casts (`as String?` / `as bool?` would THROW on wrong types). To satisfy the third test, write the getters with `is`-checks instead of raw casts — final getter form to implement (replaces the three getters shown in change 5 if you keep the tests as written; PREFER this form):

```dart
  static String get clientId {
    final v = _remoteConfig?['paypalBusinessEmail'];
    return v is String ? v : '';
  }

  static bool get isSandboxMode {
    final v = _remoteConfig?['paypalSandboxMode'];
    return v is bool ? v : true;
  }

  // Buy Me a Coffee URL
  static String get buyMeACoffeeUrl {
    final v = _remoteConfig?['buyMeACoffeeUrl'];
    return v is String ? v : '';
  }
```

9) Server-side/manual (NOT in this commit, do immediately after merging — record in the PR description):

- Firebase Console → Firestore → create doc `app_config/donations` with fields:
  - `paypalBusinessEmail` (string) — the PayPal business email previously in `.env` `PAYPAL_CLIENT_ID`
  - `paypalSandboxMode` (boolean) — previous `.env` value
  - `buyMeACoffeeUrl` (string) — previous `.env` value
- Firestore security rules (rules are not in this repo — audit sec-1, out of scope here — but whoever deploys them must include):
  ```
  match /app_config/{docId} {
    allow read: if request.auth != null;
    allow write: if false;
  }
  ```

**Edge cases to preserve:**
- If the config doc is missing/unreachable, the donation screen must show the existing "not configured" snackbar — never crash, never open a malformed PayPal URL (guaranteed by the `''` defaults + existing `isEmpty` checks).
- `isSandboxMode` defaults to `true` (fail safe: never hit production PayPal without explicit config).
- Firestore offline persistence is enabled in `main.dart`, so the config doc is served from cache when offline after first fetch — keep the single in-memory cache (`_remoteConfig != null` early return) anyway.
- Convention check: doc-ID `get()`, no `where`/`orderBy` — no index changes; `firestore.indexes.json` untouched.
- Do not delete the local `.env` file in THIS commit (Step 5 does the cleanup); after this commit it is simply never read.

**Acceptance criteria:**
- `flutter pub get` succeeds with `flutter_dotenv` gone; `grep -r flutter_dotenv lib/ test/` finds nothing.
- Fresh release APK contains no `.env`: `unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "\.env"` → no match (in Git Bash on Windows).
- With the Firestore doc seeded: Donate button opens the PayPal webview with the business email in the URL; Buy Me a Coffee opens as before.
- Without the doc: both buttons show the "not configured" snackbar; no crash.

**Verify:**
```bash
flutter pub get
flutter analyze                                          # clean
flutter test test/unit/donation_service_config_test.dart # 3 tests pass
flutter build apk --release
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "\.env"   # expect NO output
```
Manual: sign in, Settings → Support This Project → Donate with PayPal → webview opens (with seeded doc).

**Commit title:** `fix(security): serve donation config from Firestore and stop bundling .env in the app`

---

## Step 5 — Purge secret files/templates and document key rotation (critic-02, ops)

**Goal:** Remove the now-dead `.env` files and the template that instructed developers to put a real PayPal REST secret on-device, fix stale docs, and commit a rotation/verification runbook for the already-shipped keys.

**Files:** delete `.env` and `.env.example`; edit `README.md`; new `docs/SECURITY_ROTATION.md`

**Exact changes:**

1) Delete `.env` (untracked/gitignored — remove from disk; it also contains a personal Gmail address in a comment) and delete `.env.example` (tracked — `git rm .env.example`). Nothing reads either file after Step 4. Keep the `.env` line in `.gitignore` as a belt-and-braces guard.

2) BEFORE (`README.md`, the setup step around line 79):

```markdown
3. **Create `.env` file** (root directory)
   ```env
   FIREBASE_API_KEY=your_api_key
   FIREBASE_APP_ID=your_app_id
   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_MESSAGING_SENDER_ID=your_sender_id
   CONFIDENCE_THRESHOLD=0.6
   CLASSIFICATION_INTERVAL_SECONDS=5
   HIGH_NOISE_THRESHOLD=70
   ```
```

AFTER:

```markdown
3. **Configuration** — no `.env` file is used. Firebase client config is
   generated in `lib/firebase_options.dart` (via `flutterfire configure`).
   Donation display config is served from the Firestore document
   `app_config/donations` (fields: `paypalBusinessEmail`, `paypalSandboxMode`,
   `buyMeACoffeeUrl`). Secrets are never bundled with the app
   (see `docs/SECURITY_ROTATION.md`).
```

(`HOW_TO_FIND_FIREBASE_VALUES.md` and `PRODUCTION_CHECKLIST.md` also reference `.env`/`flutter_dotenv`; they are historical audit-adjacent docs — add a single note at the top of each: `> OUTDATED: .env/flutter_dotenv were removed for security (audit critic-02). See docs/SECURITY_ROTATION.md.` Do not rewrite their bodies.)

3) NEW FILE `docs/SECURITY_ROTATION.md` (full contents):

```markdown
# Key Rotation & Verification Runbook (audit finding critic-02)

Prior releases bundled `.env` inside the APK (`assets/flutter_assets/.env`),
exposing every value in it to anyone who unzipped the APK. The bundling
mechanism was removed; the values below must be treated as public and
rotated/restricted. Perform each item once and check it off in the PR.

## 1. PayPal
- The shipped `PAYPAL_CLIENT_ID` was a PayPal *business email* (public by
  design in `cmd=_donations` URLs) — no rotation possible or needed.
- `PAYPAL_SECRET` was never present in the shipped `.env`, but `.env.example`
  instructed developers to place a real REST secret there. If any PayPal REST
  app credentials were EVER created for this project (the old `.env` carried a
  "PROD WORKING!" comment), log in to developer.paypal.com -> My Apps &
  Credentials and regenerate/delete that app's secret now.
- Policy going forward: the client only ever holds the business email, served
  from Firestore `app_config/donations`. Any future PayPal REST integration
  (orders/capture/refunds) MUST go through a server (e.g. Cloud Function)
  holding the secret.

## 2. Firebase API key (`FIREBASE_API_KEY`, also in firebase_options.dart)
Firebase client API keys are not secrets, but the exposed key should be
restricted: Google Cloud Console -> APIs & Services -> Credentials ->
the Android/iOS keys ->
- Application restrictions: Android apps (package
  `com.noisemapper.noise_pollution_mapper` + the SHA-1 of the NEW release
  keystore from playbook Step 2) / iOS bundle ID.
- If abuse is suspected, regenerate the key and re-run `flutterfire configure`
  to refresh `lib/firebase_options.dart` and `google-services.json`.

## 3. Google Maps API key
The shipped value was the placeholder `your_google_maps_key_here` — nothing to
rotate. If a real Maps key exists in any console project, restrict it the same
way before use.

## 4. Personal data
The old `.env` contained a personal Gmail address in a comment; the file is
deleted and gitignored. Do not reintroduce personal data in config files.

## 5. Release verification (every release)
```bash
flutter build apk --release
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "\.env"   # must print nothing
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk  # must NOT be CN=Android Debug
```
```

**Edge cases to preserve:**
- `.env.example` deletion must be a `git rm` (it is tracked); `.env` is untracked — plain file deletion.
- Do not remove the `.env` entry from `.gitignore`.
- Do not modify anything under `audit/` (historical record).

**Acceptance criteria:**
- Repo contains no `.env` / `.env.example`; `git ls-files | grep -i env` returns nothing env-related.
- README setup no longer instructs creating `.env`.
- `docs/SECURITY_ROTATION.md` exists with the four rotation items + release verification commands.

**Verify:**
```bash
flutter analyze                       # clean (no Dart change)
git ls-files | grep -i "\.env"        # expect NO output
flutter test test/unit/donation_service_config_test.dart   # still passes
```

**Commit title:** `chore(security): remove .env files, update docs, add key rotation runbook`

---

## Step 6 — Guarded startup with retry/error UI (boot-1 / flow1-1)

**Goal:** No startup failure may ever leave a permanent blank screen: fatal init (Firebase) shows a themed error screen with Retry; optional services (notifications, sync, theme prefs) fail soft and log.

**Files:** `lib/main.dart` (as it exists AFTER Step 4), new `lib/widgets/startup_error_app.dart`, new `test/widget/startup_error_app_test.dart`

**Exact changes:**

1) NEW FILE `lib/widgets/startup_error_app.dart` (full contents):

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

/// Shown instead of the normal app when a fatal startup step fails
/// (audit findings boot-1 / flow1-1). Offers a Retry that re-runs bootstrap.
///
/// On success the retry callback calls runApp(MyApp()) and replaces this
/// tree; on repeated failure it calls runApp with a fresh StartupErrorApp.
class StartupErrorApp extends StatefulWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const StartupErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    // No state reset needed: onRetry replaces the widget tree via runApp
    // whether it succeeds or fails again.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Noise Pollution Mapper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.generateDarkTheme(AppTheme.primaryPurple),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: ThemeHelper.getBackgroundColor(context),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 64,
                      color: ThemeHelper.getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Could not start the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A required service failed to initialize. '
                      'Check your internet connection and try again.\n\n'
                      '${widget.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeHelper.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _retrying ? null : _handleRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getButtonColor(context),
                          foregroundColor:
                              ThemeHelper.getButtonTextColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _retrying
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      ThemeHelper.getButtonTextColor(context),
                                ),
                              )
                            : const Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

2) `lib/main.dart` — add the import. BEFORE (line 10–11, post-Step-4 file):

```dart
import 'screens/splash_screen.dart';
import 'widgets/main_app_shell.dart';
```

AFTER:

```dart
import 'screens/splash_screen.dart';
import 'widgets/main_app_shell.dart';
import 'widgets/startup_error_app.dart';
```

3) `lib/main.dart` — restructure `main()`. BEFORE (post-Step-4 state, i.e. the block from `void main` through `runApp`; this is the current file minus the dotenv block removed in Step 4):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence for Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // Cache data locally
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache
  );

  // Initialize notifications
  await NotificationService.initialize();
  await NotificationService.requestPermission();

  // Initialize Sync Service for offline mode (Phase 1: Offline Mode)
  await SyncService().initialize();
  AppLogger.info('[Main] SyncService initialized for offline mode');

  // Load saved theme preferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Load saved theme color
  final savedColorValue = prefs.getInt('theme_color');
  if (savedColorValue != null) {
    themeColorNotifier.value = Color(savedColorValue);
  }

  // Test TFLite model loading (Step 1-3: Sound Classification)
  await _testModelLoading();

  // Initialize Sound Classification Service (Step 5: Sound Classification)
  await _initializeSoundClassification();

  runApp(const MyApp());
}
```

AFTER:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
}

/// Guarded startup (audit boot-1 / flow1-1): a fatal init failure shows a
/// retryable error screen instead of a permanent blank screen. Retries are
/// safe: Firebase.initializeApp is skipped once an app instance exists.
Future<void> _bootstrap() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Enable offline persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, // Cache data locally
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Unlimited cache
    );

    await _initializeOptionalServices();

    runApp(const MyApp());
  } catch (e, stackTrace) {
    AppLogger.error('[Main] Fatal startup failure', e, stackTrace);
    runApp(StartupErrorApp(error: e, onRetry: _bootstrap));
  }
}

/// Non-fatal startup work: a failure here degrades one feature but must
/// never block boot.
Future<void> _initializeOptionalServices() async {
  try {
    // Initialize notifications
    await NotificationService.initialize();
    await NotificationService.requestPermission();
  } catch (e, stackTrace) {
    AppLogger.error('[Main] Notification init failed (non-fatal)', e, stackTrace);
  }

  try {
    // Initialize Sync Service for offline mode (Phase 1: Offline Mode)
    await SyncService().initialize();
    AppLogger.info('[Main] SyncService initialized for offline mode');
  } catch (e, stackTrace) {
    AppLogger.error('[Main] SyncService init failed (non-fatal)', e, stackTrace);
  }

  try {
    // Load saved theme preferences
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('dark_mode') ?? true;
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

    // Load saved theme color
    final savedColorValue = prefs.getInt('theme_color');
    if (savedColorValue != null) {
      themeColorNotifier.value = Color(savedColorValue);
    }
  } catch (e, stackTrace) {
    AppLogger.error('[Main] Theme preference load failed (non-fatal)', e, stackTrace);
  }

  // Both helpers below are already internally try/catch-guarded.
  // Test TFLite model loading (Step 1-3: Sound Classification)
  await _testModelLoading();

  // Initialize Sound Classification Service (Step 5: Sound Classification)
  await _initializeSoundClassification();
}
```

4) NEW FILE `test/widget/startup_error_app_test.dart` (full contents):

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/widgets/startup_error_app.dart';

// boot-1 / flow1-1: fatal startup failures show a retryable error screen.
void main() {
  testWidgets('shows the error and a Retry button', (tester) async {
    await tester.pumpWidget(StartupErrorApp(
      error: Exception('firebase down'),
      onRetry: () async {},
    ));

    expect(find.text('Could not start the app'), findsOneWidget);
    expect(find.textContaining('firebase down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('tapping Retry invokes the callback and disables the button',
      (tester) async {
    final completer = Completer<void>();
    var retries = 0;

    await tester.pumpWidget(StartupErrorApp(
      error: Exception('boom'),
      onRetry: () {
        retries++;
        return completer.future;
      },
    ));

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
    // While retrying: spinner shown, button disabled.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button =
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pump();
  });
}
```

**Edge cases to preserve:**
- `Firebase.apps.isEmpty` guard is mandatory: a retry after a *partial* first attempt (Firebase OK, later step threw) must not throw `duplicate-app`.
- `_testModelLoading` and `_initializeSoundClassification` keep their own internal try/catch (do not change them); they stay OUTSIDE new guards to avoid double-wrapping — calling them last in `_initializeOptionalServices` is sufficient.
- The order of operations inside `_initializeOptionalServices` must match today's order (notifications → sync → prefs → model → classification).
- Theme defaults when prefs fail: dark mode + `AppTheme.primaryPurple` (the notifiers' initial values) — already the case, do not add extra fallbacks.
- All colors in the new widget go through `ThemeHelper.getX(context)` (project convention 2); the one `AppTheme.generateDarkTheme(AppTheme.primaryPurple)` usage is theme *construction*, which is the established pattern from `MyApp`.
- Do not touch `MyApp`, the auth `StreamBuilder`, or the dead `MyHomePage` class at the bottom of `main.dart`.

**Acceptance criteria:**
- Normal launch is behaviorally identical (same init order, same logs).
- If `Firebase.initializeApp` throws (e.g. airplane-mode first launch with no cached config, or corrupted `google-services.json`), the user sees "Could not start the app" with a Retry button instead of a blank screen; Retry with connectivity restored boots into the app.
- A `NotificationService` or `SyncService` failure no longer prevents `runApp`.

**Verify:**
```bash
flutter analyze                                          # clean
flutter test test/widget/startup_error_app_test.dart     # 2 tests pass
flutter test test/widget/splash_navigation_test.dart     # still passes
```
Manual fault-injection: temporarily throw at the top of `_bootstrap`'s try (e.g. `throw Exception('test');` after the Firebase call), hot-restart → error screen appears, Retry re-runs bootstrap; REMOVE the injected throw before committing.

**Commit title:** `fix(boot): guard startup init with retryable error screen instead of blank screen`

---

## Risks & rollback

- **Step 1 (Info.plist):** Near-zero risk; additive keys. Rollback: revert commit. Note this repo has never been built for iOS here (no Podfile) — full iOS validation requires a macOS machine.
- **Step 2 (signing):** If `key.properties` is malformed, release builds fail at Gradle config with a clear `Properties` error. The debug fallback preserves today's behavior everywhere else. CRITICAL OP: back up the generated `.jks` outside the repo; a lost release keystore permanently blocks Play Store updates of the same package name. Rollback: revert commit (returns to debug signing).
- **Step 3 (onboarding flag):** Behavior change is intentional (logout no longer replays onboarding). If SharedPreferences reads fail, the `?? false` default replays onboarding — safe. Rollback: revert commit; the stray `has_seen_onboarding` pref key is inert.
- **Steps 4–5 (.env removal):** Highest coordination risk: the donation feature shows "not configured" until the Firestore doc `app_config/donations` is seeded AND deployed rules allow authenticated reads on `app_config/*` — seed the doc before releasing. No other feature reads `.env` (verified), so nothing else can regress. Existing shipped APKs still contain the old `.env`; the rotation runbook (Step 5) is what mitigates that — code alone cannot un-ship it. Rollback: revert both commits and restore `.env` from a developer machine (it is untracked, so git cannot restore it — copy values from the Firestore doc).
- **Step 6 (guarded boot):** `runApp` called from a catch is standard but changes the widget-tree root on failure paths; if `StartupErrorApp` itself threw, Flutter's red error screen would still render (never blank). Retry loops are user-driven (button), not automatic — no retry storm. Rollback: revert commit (restores blank-screen-on-failure behavior).
- **Cross-step:** Steps 4 and 6 both edit `main.dart` and MUST be applied in the given order (Step 6's BEFORE block is the post-Step-4 file). Steps 1, 2, 3 are independent of everything else.

## Out of scope

- Firestore security rules deployment (audit sec-1) — only the `app_config` rule snippet is specified here for whoever deploys rules.
- All other audit clusters: PayPal webview URL allowlist/substring bypass (donate-1/2/3/6), offline queue ownership and sync bugs (flow2-x, flow5-x), settings no-ops, dashboard/analytics defects, classification threshold 0.30 alignment (flow2-6/arch-3), test-suite repair (arch-2).
- Removing the dead `MyHomePage` scaffold class in `main.dart` and the broken pre-existing expectations in `test/widget/onboarding_screen_test.dart` (they reference a PageView/`Skip` that never existed — part of the arch-2 cluster).
- Building/notarizing iOS on macOS, creating `ios/Podfile`, App Store metadata.
- Server-side PayPal REST integration (orders/capture) — donations remain the public `cmd=_donations` URL flow.
