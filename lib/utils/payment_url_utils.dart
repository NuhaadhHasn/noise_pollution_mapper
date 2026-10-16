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

  /// True when [uri] is https AND its host is exactly one of
  /// [allowedPaymentDomains] or a subdomain of one (e.g.
  /// www.sandbox.paypal.com). Rejects substring bypasses such as
  /// https://evil.com/paypal.com and https://evil-paypal.com.
  ///
  /// The https requirement matters because the webview runs with
  /// [MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW]: without it,
  /// http://www.paypal.com would be an allowed navigation and a checkout
  /// page could be served over cleartext.
  static bool isAllowedPaymentHost(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    return allowedPaymentDomains
        .any((domain) => host == domain || host.endsWith('.$domain'));
  }

  /// Builds PayPal's Donate link in the form PayPal's own button generator
  /// emits (https://www.paypal.com/donate/?...). The legacy
  /// /cgi-bin/webscr?cmd=_donations URL only 302-redirects here with every
  /// parameter kept, so this saves a hop on the deprecated endpoint.
  /// return/cancel_return are the completion markers. rm=0 makes PayPal
  /// send the donor back via GET, so the redirect is interceptable by
  /// shouldOverrideUrlLoading on Android.
  ///
  /// When [hostedButtonId] is non-empty (a Donate button the owner created
  /// at paypal.com/donate/buttons), it is sent INSTEAD of `business`.
  /// PayPal takes one or the other. The button carries its own item name.
  /// `cmd=_donations` is sent only with `business`: alongside
  /// `hosted_button_id` it switches PayPal to the legacy flow, which ignores
  /// the button and fails with webscrErrorCode NO_BUSINESS (live-tested
  /// 2026-10-17).
  /// Uri.queryParameters percent-encodes the business email.
  static String buildPayPalDonationUrl({
    required String business,
    required double amount,
    required String currency,
    required bool sandbox,
    String hostedButtonId = '',
  }) {
    final host = sandbox ? 'www.sandbox.paypal.com' : 'www.paypal.com';
    final hosted = hostedButtonId.isNotEmpty;
    return Uri(
      scheme: 'https',
      host: host,
      path: '/donate/',
      queryParameters: <String, String>{
        if (!hosted) 'cmd': '_donations',
        if (hosted) 'hosted_button_id': hostedButtonId,
        if (!hosted) 'business': business,
        if (!hosted) 'item_name': 'Donation to Noise Pollution Mapper',
        'amount': amount.toStringAsFixed(2),
        'currency_code': currency,
        'return': returnUrl,
        'cancel_return': cancelReturnUrl,
        'rm': '0',
      },
    ).toString();
  }

  /// Strips a single trailing slash so `/donate/success` and
  /// `/donate/success/` classify identically. PayPal (and intermediate
  /// redirectors) may normalize the path either way, and a missed match
  /// means a donation that completed is never recorded.
  static String _normalizePath(String path) =>
      path.length > 1 && path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;

  /// Classifies a navigation target as a success/cancel marker.
  /// Returns null for anything that is not one of our marker URLs.
  /// Extra query parameters PayPal appends (tx, st, amt, ...) are ignored,
  /// as is a trailing slash on the path.
  static PaymentReturnStatus? classifyPaymentReturn(Uri? uri) {
    if (uri == null) return null;
    final success = Uri.parse(returnUrl);
    final cancelled = Uri.parse(cancelReturnUrl);
    // Uri normalizes host case; paths are compared case-sensitively because
    // PayPal echoes back the path we supplied.
    final path = _normalizePath(uri.path);
    if (uri.host == success.host && path == _normalizePath(success.path)) {
      return PaymentReturnStatus.success;
    }
    if (uri.host == cancelled.host && path == _normalizePath(cancelled.path)) {
      return PaymentReturnStatus.cancelled;
    }
    return null;
  }
}
