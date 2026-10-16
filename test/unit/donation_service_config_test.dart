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

  // PayPal remote switch: the configured account is currently "ineligible
  // to receive donations", so PayPal is offered only when app_config
  // opts in with paypalEnabled == true.
  group('isPayPalEnabled', () {
    const email = 'donations@example.com';

    test('is off when no config is loaded', () {
      expect(DonationService.isPayPalEnabled, isFalse);
    });

    test('is off when paypalEnabled is absent (production config today)', () {
      DonationService.applyRemoteConfig({
        'paypalBusinessEmail': email,
        'paypalSandboxMode': false,
        'buyMeACoffeeUrl': 'https://www.buymeacoffee.com/example',
      });
      expect(DonationService.isPayPalEnabled, isFalse);
      // The email itself still loads: only the switch is missing.
      expect(DonationService.clientId, email);
    });

    test('is off when paypalEnabled is false', () {
      DonationService.applyRemoteConfig({
        'paypalEnabled': false,
        'paypalBusinessEmail': email,
      });
      expect(DonationService.isPayPalEnabled, isFalse);
    });

    test('is off when enabled without a usable business email', () {
      for (final config in <Map<String, dynamic>>[
        {'paypalEnabled': true},
        {'paypalEnabled': true, 'paypalBusinessEmail': ''},
        {'paypalEnabled': true, 'paypalBusinessEmail': '   '},
        {'paypalEnabled': true, 'paypalBusinessEmail': 42},
        {
          'paypalEnabled': true,
          'paypalBusinessEmail': 'your_paypal_sandbox_client_id',
        },
      ]) {
        DonationService.applyRemoteConfig(config);
        expect(DonationService.isPayPalEnabled, isFalse,
            reason: config.toString());
      }
    });

    test('requires the bool true, not a truthy look-alike', () {
      for (final flag in <Object>['true', 1, 'yes']) {
        DonationService.applyRemoteConfig({
          'paypalEnabled': flag,
          'paypalBusinessEmail': email,
        });
        expect(DonationService.isPayPalEnabled, isFalse, reason: '$flag');
      }
    });

    test('is on when enabled with a business email', () {
      DonationService.applyRemoteConfig({
        'paypalEnabled': true,
        'paypalBusinessEmail': email,
      });
      expect(DonationService.isPayPalEnabled, isTrue);
    });

    test('is on when enabled with only a hosted Donate button ID', () {
      DonationService.applyRemoteConfig({
        'paypalEnabled': true,
        'paypalHostedButtonId': ' ABCDEF123456 ',
      });
      expect(DonationService.paypalHostedButtonId, 'ABCDEF123456');
      expect(DonationService.isPayPalEnabled, isTrue);
    });

    test('ignores a malformed hosted button ID', () {
      for (final id in <Object>['abc/../x', 'lower123456', '', 42]) {
        DonationService.applyRemoteConfig({
          'paypalEnabled': true,
          'paypalHostedButtonId': id,
        });
        expect(DonationService.paypalHostedButtonId, '', reason: '$id');
        expect(DonationService.isPayPalEnabled, isFalse, reason: '$id');
      }
    });
  });
}
