# Playbook 10 — Donation & PayPal WebView defect cluster

Implementation spec for Claude Opus. Execute steps in order; each step is exactly one commit. After EVERY commit `flutter analyze` must report no issues. Do not re-audit — all findings below were adversarially verified (see `audit/00_MASTER_AUDIT_REPORT.md`, `audit/01_BUGS_AND_CORRECTNESS.md`, `audit/03_E2E_FLOW_AUDIT.md`, grep the finding IDs).

## Scope

| ID | Status | One-liner |
|---|---|---|
| donate-6 | CONFIRMED | `late final InAppWebViewController _controller` crashes with LateInitializationError if Reload/Try Again is tapped before `onWebViewCreated` fires (`lib/widgets/paypal_webview_widget.dart:25,63,255`) |
| donate-2 | CONFIRMED | Substring URL allowlist (`url.contains('paypal.com')`) is trivially bypassed by `https://evil.com/paypal.com` or `https://evil-paypal.com` (`paypal_webview_widget.dart:145`) |
| donate-1 / flow7-01 | CONFIRMED | Success/cancel detection is dead code: donation URL has no `return`/`cancel_return`/`rm` params, so PayPal never redirects to any URL containing `payment=success`/`payment=cancel` (`paypal_webview_widget.dart:42,121`) |
| donate-3 | CONFIRMED | ANY failed non-paypal.com subresource (analytics beacon, font, even PayPal's own CDN `paypalobjects.com`) swaps a working checkout for the full-screen error — `onReceivedError` never checks `isForMainFrame` (`paypal_webview_widget.dart:134`) |
| donate-4 | CONFIRMED | "Open in Browser" shows a fake "Opening in browser..." snackbar and opens nothing; `url_launcher ^6.3.0` is ALREADY in pubspec.yaml line 93 but imported nowhere (`lib/widgets/buy_me_coffee_widget.dart:106`) |

## Pre-reading (open these before touching anything)

1. `lib/widgets/paypal_webview_widget.dart` (338 lines) — all PayPal findings live here
2. `lib/widgets/buy_me_coffee_widget.dart` (254 lines) — donate-4
3. `lib/services/donation_service.dart` — `clientId`, `isSandboxMode`, `recordDonation`, `showThankYouDialog`, `showCancellationMessage` (used by the widget; not modified)
4. `lib/utils/app_logger.dart` — `AppLogger.error(String message, [dynamic error, StackTrace? stackTrace])`
5. `pubspec.yaml` lines 89–93 — `webview_flutter: ^4.4.0`, `flutter_inappwebview: ^6.1.5`, `url_launcher: ^6.3.0` (all already declared; NO pubspec change needed)
6. `android/app/src/main/AndroidManifest.xml` — existing `<queries>` block (lines 46–51)

API facts verified against installed package versions (do not re-derive):
- flutter_inappwebview 6.x: `WebResourceRequest.isForMainFrame` is `bool?`; `NavigationAction.request.url` is `WebUri?` and `WebUri extends Uri` (so `.host` is available directly); `InAppWebViewController.reload()` exists; `InAppWebViewSettings.useShouldOverrideUrlLoading` exists (auto-inferred true when the handler is set, but we set it explicitly).
- url_launcher 6.x: top-level `Future<bool> launchUrl(Uri url, {LaunchMode mode = ...})` and `enum LaunchMode { ..., externalApplication }` from `package:url_launcher/url_launcher.dart`.
- PayPal classic `webscr` donations: `return=<url>` and `cancel_return=<url>` set the redirect targets; `rm=0` makes the buyer return via GET (required — Android `shouldOverrideUrlLoading` does not intercept POST navigations).

Conventions check for this cluster: no Firestore reads/writes are touched anywhere in these steps — no query changes, no new index. All colors in the touched files are left as-is (no new color literals are introduced). Logging is exclusively `AppLogger`, never `print`.

---

## Step 1 — donate-6: nullable WebView controller with guarded Reload/Try Again

**Goal:** Eliminate the LateInitializationError crash when Reload or Try Again is tapped before `onWebViewCreated` has run.

**Commit title:** `fix(donation): guard PayPal webview reload against uninitialized controller`

**Files:** `lib/widgets/paypal_webview_widget.dart`

**Exact changes:**

Change 1 — the field declaration (line 25):

BEFORE:
```dart
class _PayPalWebViewWidgetState extends State<PayPalWebViewWidget> {
  late final InAppWebViewController _controller;
  bool _isLoading = true;
```

AFTER:
```dart
class _PayPalWebViewWidgetState extends State<PayPalWebViewWidget> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
```

Change 2 — AppBar Reload action (lines 59–72):

BEFORE:
```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
              setState(() {
                _isLoading = true;
                _hasError = false;
                _paymentComplete = false;
              });
            },
            tooltip: 'Reload',
          ),
        ],
```

AFTER:
```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_controller == null) {
                AppLogger.warning('Reload tapped before WebView was created');
                return;
              }
              _controller?.reload();
              setState(() {
                _isLoading = true;
                _hasError = false;
                _paymentComplete = false;
              });
            },
            tooltip: 'Reload',
          ),
        ],
```

Change 3 — error-state Try Again button (lines 253–261):

BEFORE:
```dart
                      ElevatedButton.icon(
                        onPressed: () {
                          _controller.reload();
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                            _paymentComplete = false;
                          });
                        },
```

AFTER:
```dart
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_controller == null) {
                            AppLogger.warning(
                                'Try Again tapped before WebView was created');
                            return;
                          }
                          _controller?.reload();
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                            _paymentComplete = false;
                          });
                        },
```

No change to `onWebViewCreated` (line 96–99) — the assignment `_controller = controller;` remains valid for the nullable field.

**Edge cases to preserve:**
- `onWebViewCreated` fires once per platform-view creation; the guard only matters in the narrow window before that (or if platform-view creation fails entirely).
- The Reload button still resets `_isLoading`/`_hasError`/`_paymentComplete` when the controller exists — identical to today.

**Acceptance criteria:**
- Mashing the AppBar refresh icon immediately after the screen opens never throws; at worst a warning is logged and the tap is a no-op.
- Reload after the page has loaded still reloads the PayPal page.

**Verify:**
```
flutter analyze
```
Must be clean (the nullable rewrite removes the `late` field; there must be no remaining `_controller.` non-null-aware member access — grep the file for `_controller.` to confirm only `_controller?.` and `_controller ==`/`= controller` remain).
Manual: open Donation screen → Donate with PayPal → instantly tap refresh repeatedly → no crash.

---

## Step 2 — new pure-Dart URL utils + unit tests (foundation for donate-1 and donate-2)

**Goal:** Introduce a unit-testable helper with exact-host-suffix allowlisting, a donation-URL builder that carries real `return`/`cancel_return`/`rm=0` parameters, and a marker-URL classifier.

**Commit title:** `feat(donation): add PaymentUrlUtils with host allowlist and return-URL helpers`

**Files (both NEW):**
- `lib/utils/payment_url_utils.dart`
- `test/payment_url_utils_test.dart`

**Exact changes:**

New file `lib/utils/payment_url_utils.dart` — full contents:

```dart
/// Pure URL helpers for the donation webviews.
///
/// Deliberately free of Flutter and webview imports so every rule here is
/// unit-testable (see test/payment_url_utils_test.dart).
library;

/// Result of classifying a PayPal return/cancel marker URL.
enum PaymentReturnStatus { success, cancelled }

class PaymentUrlUtils {
  PaymentUrlUtils._();

  /// Marker URLs PayPal redirects the buyer to after the donation completes
  /// or is cancelled. These pages are never actually loaded: navigation to
  /// them is intercepted in shouldOverrideUrlLoading and cancelled, so the
  /// host does not need to serve anything.
  static const String returnUrl = 'https://noisemapper.app/donate/success';
  static const String cancelReturnUrl =
      'https://noisemapper.app/donate/cancelled';

  /// Domains the PayPal checkout webview may navigate to.
  /// Matched by exact host or dot-prefixed suffix only — never substring.
  static const List<String> allowedPaymentDomains = [
    'paypal.com',
    'paypalobjects.com',
    'braintreegateway.com',
  ];

  /// True when [uri]'s host is exactly one of [allowedPaymentDomains] or a
  /// subdomain of one (e.g. www.sandbox.paypal.com). Rejects substring
  /// bypasses such as https://evil.com/paypal.com and https://evil-paypal.com.
  static bool isAllowedPaymentHost(Uri? uri) {
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    return allowedPaymentDomains
        .any((domain) => host == domain || host.endsWith('.$domain'));
  }

  /// Builds the classic webscr donation URL, including return/cancel_return
  /// markers. rm=0 makes PayPal send the buyer back via GET so the redirect
  /// is interceptable by shouldOverrideUrlLoading on Android.
  /// Uri.queryParameters also percent-encodes the business email, which the
  /// previous hand-built string never did.
  static String buildPayPalDonationUrl({
    required String business,
    required double amount,
    required String currency,
    required bool sandbox,
  }) {
    final host = sandbox ? 'www.sandbox.paypal.com' : 'www.paypal.com';
    return Uri(
      scheme: 'https',
      host: host,
      path: '/cgi-bin/webscr',
      queryParameters: <String, String>{
        'cmd': '_donations',
        'business': business,
        'item_name': 'Donation to Noise Pollution Mapper',
        'amount': amount.toStringAsFixed(2),
        'currency_code': currency,
        'return': returnUrl,
        'cancel_return': cancelReturnUrl,
        'rm': '0',
      },
    ).toString();
  }

  /// Classifies a navigation target as a success/cancel marker.
  /// Returns null for anything that is not one of our marker URLs.
  /// Extra query parameters PayPal appends (tx, st, amt, ...) are ignored.
  static PaymentReturnStatus? classifyPaymentReturn(Uri? uri) {
    if (uri == null) return null;
    final success = Uri.parse(returnUrl);
    final cancelled = Uri.parse(cancelReturnUrl);
    if (uri.host == success.host && uri.path == success.path) {
      return PaymentReturnStatus.success;
    }
    if (uri.host == cancelled.host && uri.path == cancelled.path) {
      return PaymentReturnStatus.cancelled;
    }
    return null;
  }
}
```

New file `test/payment_url_utils_test.dart` — full contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/utils/payment_url_utils.dart';

void main() {
  group('PaymentUrlUtils.isAllowedPaymentHost', () {
    test('allows exact domains and subdomains', () {
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://paypal.com/checkout')),
          isTrue);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://www.paypal.com/signin')),
          isTrue);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://www.sandbox.paypal.com/cgi-bin/webscr')),
          isTrue);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://www.paypalobjects.com/js/checkout.js')),
          isTrue);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://client.braintreegateway.com/x')),
          isTrue);
    });

    test('rejects substring bypasses (donate-2)', () {
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://evil.com/paypal.com')),
          isFalse);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://evil-paypal.com')),
          isFalse);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://paypal.com.evil.com')),
          isFalse);
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse('https://evil.com/?q=paypal.com')),
          isFalse);
      expect(PaymentUrlUtils.isAllowedPaymentHost(null), isFalse);
      expect(PaymentUrlUtils.isAllowedPaymentHost(Uri.parse('about:blank')),
          isFalse);
    });

    test('marker host is NOT generally allowed (must be intercepted)', () {
      expect(
          PaymentUrlUtils.isAllowedPaymentHost(
              Uri.parse(PaymentUrlUtils.returnUrl)),
          isFalse);
    });
  });

  group('PaymentUrlUtils.buildPayPalDonationUrl', () {
    test('carries return, cancel_return and rm=0 (donate-1/flow7-01)', () {
      final url = PaymentUrlUtils.buildPayPalDonationUrl(
        business: 'owner@example.com',
        amount: 12.5,
        currency: 'USD',
        sandbox: true,
      );
      final uri = Uri.parse(url);
      expect(uri.host, 'www.sandbox.paypal.com');
      expect(uri.path, '/cgi-bin/webscr');
      expect(uri.queryParameters['cmd'], '_donations');
      expect(uri.queryParameters['business'], 'owner@example.com');
      expect(uri.queryParameters['amount'], '12.50');
      expect(uri.queryParameters['currency_code'], 'USD');
      expect(uri.queryParameters['return'], PaymentUrlUtils.returnUrl);
      expect(uri.queryParameters['cancel_return'],
          PaymentUrlUtils.cancelReturnUrl);
      expect(uri.queryParameters['rm'], '0');
    });

    test('uses live host when sandbox is false', () {
      final url = PaymentUrlUtils.buildPayPalDonationUrl(
        business: 'owner@example.com',
        amount: 5,
        currency: 'USD',
        sandbox: false,
      );
      expect(Uri.parse(url).host, 'www.paypal.com');
    });
  });

  group('PaymentUrlUtils.classifyPaymentReturn', () {
    test('classifies success marker even with PayPal-appended params', () {
      expect(
          PaymentUrlUtils.classifyPaymentReturn(Uri.parse(
              'https://noisemapper.app/donate/success?tx=1AB23456&st=Completed')),
          PaymentReturnStatus.success);
    });

    test('classifies cancel marker', () {
      expect(
          PaymentUrlUtils.classifyPaymentReturn(
              Uri.parse('https://noisemapper.app/donate/cancelled')),
          PaymentReturnStatus.cancelled);
    });

    test('returns null for ordinary PayPal pages and null input', () {
      expect(
          PaymentUrlUtils.classifyPaymentReturn(
              Uri.parse('https://www.paypal.com/cgi-bin/webscr?cmd=_donations')),
          isNull);
      expect(PaymentUrlUtils.classifyPaymentReturn(null), isNull);
      expect(
          PaymentUrlUtils.classifyPaymentReturn(
              Uri.parse('https://noisemapper.app/other')),
          isNull);
    });
  });
}
```

**Edge cases to preserve:** none (new code only; nothing else imports it yet).

**Acceptance criteria:** All new unit tests pass; no production behavior changes in this commit.

**Verify:**
```
flutter analyze
flutter test test/payment_url_utils_test.dart
```

---

## Step 3 — donate-2: exact-host allowlist in shouldOverrideUrlLoading

**Goal:** Replace the bypassable substring allowlist with `PaymentUrlUtils.isAllowedPaymentHost` so only paypal.com / paypalobjects.com / braintreegateway.com hosts (and their subdomains) can load.

**Commit title:** `fix(donation): allowlist PayPal navigation by exact host suffix, not substring`

**Files:** `lib/widgets/paypal_webview_widget.dart`

**Exact changes:**

Change 1 — add the import (after the existing line 5 `import '../utils/theme_helper.dart';`):

BEFORE:
```dart
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
import '../services/donation_service.dart';
```

AFTER:
```dart
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/payment_url_utils.dart';
import '../utils/theme_helper.dart';
import '../services/donation_service.dart';
```

Change 2 — the handler (lines 141–154):

BEFORE:
```dart
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url?.toString() ?? '';
                
                // Allow PayPal domain navigation
                if (url.contains('paypal.com') ||
                    url.contains('paypalobjects.com') ||
                    url.contains('braintreegateway.com')) {
                  return NavigationActionPolicy.ALLOW;
                }
                
                // Block external navigation
                AppLogger.warning('Blocked navigation to: $url');
                return NavigationActionPolicy.CANCEL;
              },
```

AFTER:
```dart
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;

                // Allow PayPal domain navigation (exact host or subdomain
                // only — substring matching was bypassable, donate-2).
                if (PaymentUrlUtils.isAllowedPaymentHost(uri)) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Block external navigation
                AppLogger.warning(
                    'Blocked navigation to: ${uri?.toString() ?? '(null)'}');
                return NavigationActionPolicy.CANCEL;
              },
```

Note: `navigationAction.request.url` is a `WebUri?`; `WebUri extends Uri`, so passing it straight to `isAllowedPaymentHost(Uri?)` compiles without conversion.

**Edge cases to preserve:**
- `www.sandbox.paypal.com` (sandbox mode) must still be ALLOWED — covered by suffix match, and locked in by the Step 2 unit test.
- Everything else is still CANCELLED silently with a warning log — identical UX to today (the known "3-D Secure / issuer redirects get blocked" issue flow7-04 is intentionally NOT addressed here; see Out of scope).
- `about:blank` / null URLs: previously `''.contains(...)` was false → CANCEL; new code also returns CANCEL (host empty). Same behavior.

**Acceptance criteria:**
- Navigation to `https://evil.com/paypal.com` or `https://evil-paypal.com` inside the checkout is blocked (warning in log).
- Normal sandbox checkout still renders and is navigable.

**Verify:**
```
flutter analyze
flutter test test/payment_url_utils_test.dart
```
Manual (sandbox): open PayPal checkout, confirm page loads and internal PayPal navigation works.

---

## Step 4 — donate-1 / flow7-01: real return/cancel_return URLs + marker interception

**Goal:** Make success/cancel detection actually fire by putting `return`, `cancel_return`, and `rm=0` on the donation URL and intercepting the marker redirects in `shouldOverrideUrlLoading`.

**Commit title:** `fix(donation): wire real PayPal return/cancel URLs so completion detection can fire`

**Files:** `lib/widgets/paypal_webview_widget.dart`

**Exact changes:**

Change 1 — URL construction (lines 40–43). Note: after Step 1 the surrounding code is unchanged, so this block still matches.

BEFORE:
```dart
    // Generate PayPal donation URL
    final paypalUrl = isSandbox
        ? 'https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_donations&business=$paypalEmail&item_name=Donation+to+Noise+Pollution+Mapper&amount=${widget.amount.toStringAsFixed(2)}&currency_code=${widget.currency}'
        : 'https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=$paypalEmail&item_name=Donation+to+Noise+Pollution+Mapper&amount=${widget.amount.toStringAsFixed(2)}&currency_code=${widget.currency}';
```

AFTER:
```dart
    // Generate PayPal donation URL with return/cancel_return markers so
    // completion and cancellation are observable (donate-1 / flow7-01).
    final paypalUrl = PaymentUrlUtils.buildPayPalDonationUrl(
      business: paypalEmail,
      amount: widget.amount,
      currency: widget.currency,
      sandbox: isSandbox,
    );
```

Change 2 — make `shouldOverrideUrlLoading` (as rewritten in Step 3) intercept the markers FIRST:

BEFORE (result of Step 3):
```dart
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;

                // Allow PayPal domain navigation (exact host or subdomain
                // only — substring matching was bypassable, donate-2).
                if (PaymentUrlUtils.isAllowedPaymentHost(uri)) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Block external navigation
                AppLogger.warning(
                    'Blocked navigation to: ${uri?.toString() ?? '(null)'}');
                return NavigationActionPolicy.CANCEL;
              },
```

AFTER:
```dart
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;

                // Intercept our return/cancel markers before anything else.
                // The marker pages are never loaded — navigation is cancelled.
                final returnStatus = PaymentUrlUtils.classifyPaymentReturn(uri);
                if (returnStatus == PaymentReturnStatus.success) {
                  if (!_paymentComplete) {
                    setState(() {
                      _paymentComplete = true;
                    });
                    _onPaymentSuccess();
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                if (returnStatus == PaymentReturnStatus.cancelled) {
                  _onPaymentCancelled();
                  return NavigationActionPolicy.CANCEL;
                }

                // Allow PayPal domain navigation (exact host or subdomain
                // only — substring matching was bypassable, donate-2).
                if (PaymentUrlUtils.isAllowedPaymentHost(uri)) {
                  return NavigationActionPolicy.ALLOW;
                }

                // Block external navigation
                AppLogger.warning(
                    'Blocked navigation to: ${uri?.toString() ?? '(null)'}');
                return NavigationActionPolicy.CANCEL;
              },
```

Change 3 — delete the dead substring checks in `onLoadStop` (lines 107–129). The `payment=success`/`payment=cancel` strings can never appear (verifier evidence, flow7-01) and detection now lives in `shouldOverrideUrlLoading`:

BEFORE:
```dart
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                final urlString = url?.toString() ?? '';
                AppLogger.debug('PayPal loaded: $urlString');
                
                // Check if PayPal page loaded successfully
                if (urlString.contains('genericError') || 
                    urlString.contains('error')) {
                  AppLogger.warning('PayPal showed error page');
                }
                
                // Check for payment success
                if (urlString.contains('payment=success') || 
                    urlString.contains('payment=completed')) {
                  _paymentComplete = true;
                  _onPaymentSuccess();
                } else if (urlString.contains('payment=cancel') || 
                           urlString.contains('payment=cancelled')) {
                  _onPaymentCancelled();
                }
              },
```

AFTER:
```dart
              onLoadStop: (controller, url) async {
                setState(() {
                  _isLoading = false;
                });
                final urlString = url?.toString() ?? '';
                AppLogger.debug('PayPal loaded: $urlString');

                // Check if PayPal page loaded successfully
                if (urlString.contains('genericError') ||
                    urlString.contains('error')) {
                  AppLogger.warning('PayPal showed error page');
                }
              },
```

Change 4 — set `useShouldOverrideUrlLoading` explicitly in `initialSettings` (lines 81–95). flutter_inappwebview 6 infers it from the registered handler, but explicit is safer and self-documenting:

BEFORE:
```dart
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
```

AFTER:
```dart
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
```

**Edge cases to preserve:**
- `_paymentComplete` is now assigned INSIDE `setState` (the old line 123 assigned it outside, so the green "Payment Complete!" overlay never repainted — this change also cures that).
- The `!_paymentComplete` guard prevents double `recordDonation`/double thank-you dialog if PayPal fires the return redirect more than once (redirect retry, user back-forward).
- `_onPaymentSuccess()` and `_onPaymentCancelled()` (lines 285–301) are unchanged — they already handle `mounted` and delayed dialog display.
- The Reload button resets `_paymentComplete = false`, allowing a fresh attempt after cancel — unchanged.
- `rm=0` is mandatory: with the default POST return, Android's `shouldOverrideUrlLoading` would not fire for the redirect.

**Acceptance criteria:**
- The initial URL logged by `AppLogger.info('Opening PayPal: ...')` (line 45, unchanged) contains `return=`, `cancel_return=`, and `rm=0`, with the business email percent-encoded.
- In sandbox: completing a donation and clicking PayPal's "Return to merchant" link shows the "Payment Complete!" overlay, records the donation (SharedPreferences via `DonationService.recordDonation`), and shows the thank-you dialog after ~500 ms.
- Cancelling on PayPal (which redirects to `cancel_return`) shows the orange "Donation cancelled" snackbar.
- The marker URLs themselves never load (no white error page for noisemapper.app).

**Verify:**
```
flutter analyze
flutter test test/payment_url_utils_test.dart
```
Manual (sandbox account required): run the app with `PAYPAL_SANDBOX_MODE=true`, complete and cancel a sandbox donation, confirm the two flows above. Without a sandbox account, at minimum confirm from logs that the opening URL carries the three new params and that navigating the webview to `https://noisemapper.app/donate/success` (e.g. via a debug deep link) triggers the success overlay.

---

## Step 5 — donate-3: only main-frame errors show the full-screen error

**Goal:** Stop failed subresources (analytics beacons, fonts, even PayPal's own CDN) from replacing a working checkout with the full-screen error UI.

**Commit title:** `fix(donation): show PayPal load error only for main-frame failures`

**Files:** `lib/widgets/paypal_webview_widget.dart`

**Exact changes (lines 130–140):**

BEFORE:
```dart
              onReceivedError: (controller, request, error) {
                final requestUrl = request.url.toString();
                AppLogger.error('PayPal error: ${error.description} (URL: $requestUrl)');
                // Don't show error for PayPal domain errors (they're expected)
                if (!requestUrl.contains('paypal.com')) {
                  setState(() {
                    _hasError = true;
                    _errorMessage = error.description;
                  });
                }
              },
```

AFTER:
```dart
              onReceivedError: (controller, request, error) {
                final requestUrl = request.url.toString();
                AppLogger.error(
                    'PayPal error: ${error.description} '
                    '(URL: $requestUrl, mainFrame: ${request.isForMainFrame})');
                // Subresource failures (images, scripts, analytics, CDN
                // assets) must not replace a working checkout with a
                // full-screen error (donate-3). Only main-frame failures
                // mean the checkout itself is broken.
                if (request.isForMainFrame != true) {
                  return;
                }
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                });
              },
```

`request.isForMainFrame` is `bool?` in flutter_inappwebview 6 — the `!= true` comparison treats null (platforms that don't report it) as "not main frame", which fails safe toward not destroying a working checkout.

**Edge cases to preserve:**
- Deliberate behavior change bundled with the fix: a MAIN-FRAME failure on paypal.com (e.g. airplane mode mid-checkout) now correctly shows the error UI with Try Again — previously it was suppressed by the `contains('paypal.com')` check, making the error screen unreachable for real failures (flow7-14). This is the intended semantics per the verified finding.
- All errors are still logged via `AppLogger.error`, including suppressed subresource ones.
- The Try Again button in the error UI already guards the nullable controller (Step 1).

**Acceptance criteria:**
- A blocked/failed third-party subresource during checkout leaves the checkout visible (log entry only).
- Loading the widget with no network shows the full-screen error with a working Try Again.

**Verify:**
```
flutter analyze
```
Manual: open the PayPal screen in airplane mode → error screen appears; enable network → Try Again reloads checkout. Then, with network on, complete a normal load and confirm no error flash even if the console logs subresource errors.

---

## Step 6 — donate-4: make "Open in Browser" actually launch the browser

**Goal:** Replace the fake snackbar with a real external-browser launch via url_launcher (already declared in pubspec.yaml line 93 — do NOT touch pubspec).

**Commit title:** `fix(donation): launch Buy Me a Coffee externally instead of fake snackbar`

**Files:**
- `lib/widgets/buy_me_coffee_widget.dart`
- `android/app/src/main/AndroidManifest.xml`

**Exact changes:**

Change 1 — import (buy_me_coffee_widget.dart lines 1–5):

BEFORE:
```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

AFTER:
```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
```

Change 2 — the AppBar action (lines 103–117):

BEFORE:
```dart
          // Open in browser
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              // Note: You may need to add url_launcher package
              AppLogger.info('Opening in browser: ${widget.url}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening in browser...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Open in Browser',
          ),
```

AFTER:
```dart
          // Open in browser
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              AppLogger.info('Opening in browser: ${widget.url}');
              final uri = Uri.tryParse(widget.url);
              if (uri == null) {
                AppLogger.warning('Invalid URL: ${widget.url}');
                return;
              }
              var launched = false;
              try {
                launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
              } catch (e, stackTrace) {
                AppLogger.error('Failed to open browser', e, stackTrace);
              }
              if (!launched && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open browser'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: 'Open in Browser',
          ),
```

Change 3 — AndroidManifest.xml: extend the existing `<queries>` block so https VIEW intents are resolvable on Android 11+ (package visibility). Lines 46–51:

BEFORE:
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
```

AFTER:
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <!-- Required by url_launcher to open https links externally -->
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
```

**Edge cases to preserve:**
- Do NOT call `canLaunchUrl` first — for plain https it produces false negatives on some devices; `launchUrl` + try/catch + `false` return covers all failure modes.
- `context.mounted` check after the await satisfies `use_build_context_synchronously` (flutter_lints 6 enforces it; without the check `flutter analyze` will not be clean).
- No success snackbar at all anymore: the OS browser opening IS the feedback. Only failure produces a snackbar ("Could not open browser").
- `widget.url` comes from `DonationService.buyMeACoffeeUrl` (.env `BUY_ME_A_COFFEE_URL`), already guarded non-empty by `donation_screen.dart` before this widget is pushed — `Uri.tryParse` guard is belt-and-braces.
- The in-app WebView and its Reload button are untouched.

**Acceptance criteria:**
- Tapping "Open in Browser" opens the device's default browser at the Buy Me a Coffee page and no longer shows "Opening in browser...".
- On a device with no browser (or launch failure), a "Could not open browser" snackbar appears and the error is logged.

**Verify:**
```
flutter analyze
```
Manual (Android device/emulator with a browser): Donation screen → Buy Me a Coffee → tap the open-in-browser AppBar icon → external browser opens. iOS needs no Info.plist change (launchUrl without canLaunchUrl does not require LSApplicationQueriesSchemes for https).

---

## Risks & rollback

- **PayPal "Return to merchant" is user-initiated by default.** With classic webscr donations, PayPal only auto-redirects to `return` if Auto Return is enabled in the merchant account settings; otherwise the buyer must tap "Return to merchant" on the receipt page. Detection (Step 4) is therefore best-effort: a donor who completes payment and closes the webview without returning is still not recorded. This is strictly better than today (detection currently NEVER fires) but not a guarantee. Long-term fix is the PayPal Orders API with server-side capture (out of scope; see flow7-13 — the recorded amount is app-side and unverified either way).
- **Step 5 behavior change:** main-frame paypal.com failures now surface the error screen (previously suppressed). This is intended, but if PayPal performs odd intermediate navigations that report transient main-frame errors, users could see an error flash; the Try Again button recovers. Watch logs for `mainFrame: true` entries during QA.
- **Stricter allowlist (Step 3)** could in theory block a legitimate PayPal-owned host outside the three domains (e.g. `paypal.cn`, `venmo.com`). None are used by the classic webscr donation flow; if sandbox QA shows a blocked legitimate host in the `Blocked navigation to:` log, add that exact domain to `PaymentUrlUtils.allowedPaymentDomains` with a unit test.
- **noisemapper.app is not an owned/served domain.** Safe because marker navigations are always CANCELLED before load, and the host is deliberately NOT in the allowlist, so nothing can ever render from it. If the org later owns a real domain, change only the two constants in `PaymentUrlUtils` (plus tests).
- **Rollback:** each step is one self-contained commit touching at most two files; `git revert <sha>` of any single step compiles and passes analyze independently. Step 4 depends on Step 2 (utils) and Step 3 (rewritten handler); revert in reverse order if unwinding multiple steps.
- No Firestore reads, writes, or queries are touched — zero index risk; the single composite index rule (noise_readings userId ASC + timestamp DESC) is unaffected. No new index needed.

## Out of scope

- flow7-04: allowlist silently blocks 3-D Secure / bank-issuer redirects mid-payment (needs a deliberate UX decision: open blocked hosts externally vs. broaden allowlist).
- flow7-13: recorded donation amount is app-side and never verified against the actual PayPal transaction (needs Orders API + server component).
- donate-5 (donation guide vs. YAMNet mapping contradictions), donate-15 (impact-message math discontinuity), donate-16 / uiux-30 (donation screens hardcode AppTheme/Material colors instead of ThemeHelper — cluster-wide restyle belongs in the UI/theming playbook).
- flow7-02's broader concern about the success overlay leaving the user on a dead screen after closing the thank-you dialog (an intentional-UX item; only the `setState` repaint aspect is incidentally fixed in Step 4).
- flow7-07: no PopScope/system-back handling in either webview.
- Migrating the Buy Me a Coffee widget off `webview_flutter` to unify on `flutter_inappwebview` (flow7-12).
- donate-7: Buy Me a Coffee widget's own subresource-error overlay (`buy_me_coffee_widget.dart:55-61`) — unverified finding; `webview_flutter`'s `onWebResourceError` gained `isForMainFrame` only in newer API surface and needs its own verification pass first.
