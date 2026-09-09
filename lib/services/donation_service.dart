import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
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

  // Preset donation amounts
  static const List<double> presetAmounts = [5.0, 10.0, 20.0];
  
  // Default currency
  static const String currency = 'USD';

  /// Get impact message for a donation amount
  static String getImpactMessage(double amount) {
    if (amount >= 50) {
      return 'Your generous \$${amount.toStringAsFixed(0)} donation helps maintain servers for ${((amount / 0.77) * 100).toInt()}+ users for a month! 🎉';
    } else if (amount >= 20) {
      return 'Your \$${amount.toStringAsFixed(0)} donation helps maintain servers for ${((amount / 0.77) * 10).toInt()}+ users for a month! 🙏';
    } else if (amount >= 10) {
      return 'Your \$${amount.toStringAsFixed(0)} donation helps maintain servers for 100+ users for a month! ❤️';
    } else if (amount >= 5) {
      return 'Your \$${amount.toStringAsFixed(0)} donation helps support our development efforts! 💪';
    }
    return 'Thank you for your support! Every contribution helps! 🌟';
  }

  /// Get monthly expenses breakdown
  static Map<String, double> getMonthlyExpenses() {
    return {
      'Firebase Hosting': 25.0,
      'Domain & SSL': 2.0,
      'Development Tools': 50.0,
    };
  }

  /// Get total monthly goal
  static double getMonthlyGoal() {
    return getMonthlyExpenses().values.fold(0.0, (sum, value) => sum + value);
  }

  /// Get current month's donations (from local storage)
  static Future<double> getCurrentMonthDonations() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    
    final storedMonth = prefs.getString('donation_month') ?? '';
    if (storedMonth != currentMonth) {
      return 0.0;
    }
    
    return prefs.getDouble('donations_amount') ?? 0.0;
  }

  /// Record a donation (local storage only)
  static Future<void> recordDonation(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    
    final storedMonth = prefs.getString('donation_month') ?? '';
    double currentTotal = 0.0;
    
    if (storedMonth == currentMonth) {
      currentTotal = prefs.getDouble('donations_amount') ?? 0.0;
    } else {
      // New month, reset
      await prefs.setString('donation_month', currentMonth);
    }
    
    await prefs.setDouble('donations_amount', currentTotal + amount);
    
    // Store donation history
    final history = prefs.getStringList('donation_history') ?? [];
    final newEntry = '${now.toIso8601String()}:$amount';
    await prefs.setStringList('donation_history', [...history, newEntry]);
    
    AppLogger.info('Donation recorded: \$${amount.toStringAsFixed(2)}');
  }

  /// Get donation history
  static Future<List<Map<String, dynamic>>> getDonationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('donation_history') ?? [];
    
    return history.map((entry) {
      final parts = entry.split(':');
      return {
        'date': DateTime.parse(parts[0]),
        'amount': double.parse(parts[1]),
      };
    }).toList();
  }

  /// Clear donation history (for testing)
  static Future<void> clearDonationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('donation_history');
    await prefs.remove('donations_amount');
    await prefs.remove('donation_month');
  }

  /// Validate donation amount
  static bool isValidAmount(double amount) {
    return amount >= 1.0 && amount <= 1000.0;
  }

  /// Get validation error message
  static String? getValidationError(double amount) {
    if (amount < 1.0) {
      return 'Minimum donation is \$1.00';
    }
    if (amount > 1000.0) {
      return 'Maximum donation is \$1000.00';
    }
    return null;
  }

  /// Show thank you dialog
  static void showThankYouDialog(BuildContext context, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Thank You! ❤️',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your \$${amount.toStringAsFixed(2)} donation helps us continue development!',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    getImpactMessage(amount),
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Show cancellation message
  static void showCancellationMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Donation cancelled. You can try again anytime.'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
