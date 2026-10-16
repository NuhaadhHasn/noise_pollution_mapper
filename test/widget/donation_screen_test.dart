import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noise_pollution_mapper/screens/donation_screen.dart';
import 'package:noise_pollution_mapper/services/donation_service.dart';

// PayPal remote switch: the donation screen offers PayPal only when
// app_config/donations has paypalEnabled == true. Otherwise only Buy Me a
// Coffee is shown, with no broken option and no error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DonationService.resetConfigForTest);

  Future<void> pumpDonationScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DonationScreen()));
    // Let the initState config load (and its setState) complete.
    await tester.pumpAndSettle();
  }

  void expectPayPalAbsent() {
    expect(find.text('Donate with PayPal'), findsNothing);
    expect(find.text('Select Donation Amount'), findsNothing);
    expect(find.text('Secure payment processed by PayPal'), findsNothing);
    expect(find.text(r'$5'), findsNothing);
  }

  void expectOnlyBuyMeACoffee() {
    expect(find.text('Support via Buy Me a Coffee'), findsOneWidget);
    // It is the only option, so it must not call itself the alternative.
    expect(find.text('Alternative donation method'), findsNothing);
    // No broken option and no error message.
    expect(find.byType(SnackBar), findsNothing);
  }

  testWidgets('PayPal is absent by default (config has no paypalEnabled)',
      (tester) async {
    // The production document today: an email, but no switch.
    DonationService.applyRemoteConfig({
      'paypalBusinessEmail': 'donations@example.com',
      'paypalSandboxMode': false,
      'buyMeACoffeeUrl': 'https://www.buymeacoffee.com/example',
    });

    await pumpDonationScreen(tester);

    expectPayPalAbsent();
    expectOnlyBuyMeACoffee();
    // The rest of the page is unaffected.
    expect(find.text('Help Keep This App Free'), findsOneWidget);
    expect(find.text('Monthly Expenses'), findsOneWidget);
  });

  testWidgets('PayPal stays hidden when the config cannot be loaded',
      (tester) async {
    // No Firebase app in tests: ensureConfigLoaded fails and is caught.
    await pumpDonationScreen(tester);

    expectPayPalAbsent();
    expectOnlyBuyMeACoffee();
  });

  testWidgets('PayPal section is shown when the config enables it',
      (tester) async {
    DonationService.applyRemoteConfig({
      'paypalEnabled': true,
      'paypalBusinessEmail': 'donations@example.com',
      'buyMeACoffeeUrl': 'https://www.buymeacoffee.com/example',
    });

    await pumpDonationScreen(tester);

    expect(find.text('Select Donation Amount'), findsOneWidget);
    expect(find.text('Donate with PayPal'), findsOneWidget);
    expect(find.text('Secure payment processed by PayPal'), findsOneWidget);
    expect(find.text('Support via Buy Me a Coffee'), findsOneWidget);
    expect(find.text('Alternative donation method'), findsOneWidget);
  });
}
