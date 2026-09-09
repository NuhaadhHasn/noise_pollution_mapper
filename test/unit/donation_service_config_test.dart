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
