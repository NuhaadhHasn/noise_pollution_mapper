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
