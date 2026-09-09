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
