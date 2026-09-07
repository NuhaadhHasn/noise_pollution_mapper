import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/donation_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
import '../widgets/buy_me_coffee_widget.dart';
import '../widgets/paypal_webview_widget.dart';

/// Donation screen with PayPal and Buy Me a Coffee options
class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  String? _selectedAmount;
  final TextEditingController _customAmountController = TextEditingController();
  bool _isCustomAmount = false;
  double? _customAmountValue;

  @override
  void initState() {
    super.initState();
    _selectedAmount = DonationService.presetAmounts.first.toString();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

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

    // Navigate to PayPal WebView
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayPalWebViewWidget(
          amount: amount,
          currency: DonationService.currency,
        ),
      ),
    );
  }

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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuyMeACoffeeWidget(
          url: DonationService.buyMeACoffeeUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeHelper.getPrimaryColor(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkPurple : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Support This Project'),
        backgroundColor: isDark ? AppTheme.darkPurple : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            _buildHeaderCard(isDark, primaryColor),
            
            const SizedBox(height: 16),
            
            // Donation Options
            _buildDonationOptionsCard(isDark, primaryColor),
            
            const SizedBox(height: 16),
            
            // Impact Tracker
            _buildImpactTrackerCard(isDark, primaryColor),
            
            const SizedBox(height: 24),
            
            // Alternative donation method
            _buildAlternativeDonationCard(isDark, primaryColor),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.8),
            primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Help Keep This App Free',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your donation helps us maintain servers and continue development',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationOptionsCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Donation Amount',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),

          // Preset amounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: DonationService.presetAmounts.map((amount) {
              final amountStr = amount.toString();
              final isSelected = _selectedAmount == amountStr && !_isCustomAmount;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAmount = amountStr;
                    _isCustomAmount = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : (isDark ? AppTheme.cardBackground : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? primaryColor : (isDark ? Colors.white24 : Colors.grey.shade300),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '\$${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey.shade800),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Custom amount
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCustomAmount = true;
                      _selectedAmount = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isCustomAmount ? primaryColor : (isDark ? AppTheme.cardBackground : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCustomAmount ? primaryColor : (isDark ? Colors.white24 : Colors.grey.shade300),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit,
                          size: 18,
                          color: _isCustomAmount ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isCustomAmount ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_isCustomAmount) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Enter Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'e.g., 25',
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                setState(() {
                  _customAmountValue = parsed;
                });
              },
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Impact message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getImpactPreview(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Donate button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                double amount;
                if (_isCustomAmount) {
                  amount = _customAmountValue ?? 0;
                } else {
                  amount = double.tryParse(_selectedAmount ?? '0') ?? 0;
                }
                _processPayPalDonation(amount);
              },
              icon: const Icon(Icons.favorite, size: 24),
              label: Text(
                'Donate with PayPal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.blue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Security note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Secure payment processed by PayPal',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactTrackerCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Expenses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          
          // Expense items
          ...DonationService.getMonthlyExpenses().entries.map((entry) {
            final percentage = entry.value / DonationService.getMonthlyGoal();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '\$${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        primaryColor.withValues(alpha: 0.7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
          
          const Divider(height: 24),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Goal:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              Text(
                '\$${DonationService.getMonthlyGoal().toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeDonationCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.local_cafe,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy Me a Coffee',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Alternative donation method',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openBuyMeACoffee,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Support via Buy Me a Coffee'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getImpactPreview() {
    double amount;
    if (_isCustomAmount) {
      amount = _customAmountValue ?? 0;
    } else {
      amount = double.tryParse(_selectedAmount ?? '0') ?? 0;
    }
    
    if (amount <= 0) {
      return 'Select an amount to see your impact';
    }
    
    return DonationService.getImpactMessage(amount);
  }
}
