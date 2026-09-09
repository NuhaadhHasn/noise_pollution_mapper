import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/payment_url_utils.dart';
import '../utils/theme_helper.dart';
import '../services/donation_service.dart';

/// PayPal Donation WebView
/// Opens PayPal donation page in embedded WebView
class PayPalWebViewWidget extends StatefulWidget {
  final double amount;
  final String currency;

  const PayPalWebViewWidget({
    super.key,
    required this.amount,
    this.currency = 'USD',
  });

  @override
  State<PayPalWebViewWidget> createState() => _PayPalWebViewWidgetState();
}

class _PayPalWebViewWidgetState extends State<PayPalWebViewWidget> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _paymentComplete = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeHelper.getPrimaryColor(context);
    
    // Get PayPal email
    final paypalEmail = DonationService.clientId;
    final isSandbox = DonationService.isSandboxMode;
    
    // Generate PayPal donation URL with return/cancel_return markers so
    // completion and cancellation are observable (donate-1 / flow7-01).
    final paypalUrl = PaymentUrlUtils.buildPayPalDonationUrl(
      business: paypalEmail,
      amount: widget.amount,
      currency: widget.currency,
      sandbox: isSandbox,
    );

    AppLogger.info('Opening PayPal: $paypalUrl');

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkPurple : Colors.white,
      appBar: AppBar(
        title: const Text('PayPal Checkout'),
        backgroundColor: isDark ? AppTheme.darkPurple : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Close',
        ),
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
      ),
      body: Stack(
        children: [
          // WebView with PayPal donation page
          Container(
            color: isDark ? AppTheme.darkPurple : Colors.white,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(paypalUrl)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useHybridComposition: true,
                javaScriptCanOpenWindowsAutomatically: true,
                allowFileAccess: false,
                allowContentAccess: false,
                cacheMode: CacheMode.LOAD_DEFAULT,
                textZoom: 100,
                supportZoom: true,
                displayZoomControls: false,
                loadWithOverviewMode: true,
                useWideViewPort: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                AppLogger.debug('WebView created');
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                AppLogger.debug('PayPal loading: ${url?.toString()}');
              },
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
              onConsoleMessage: (controller, consoleMessage) {
                AppLogger.debug('PayPal console: ${consoleMessage.message}');
              },
            ),
          ),
          
          // Loading indicator
          if (_isLoading && !_hasError && !_paymentComplete) ...[
            Container(
              color: isDark ? AppTheme.darkPurple : Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      backgroundColor: primaryColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading PayPal...',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSandbox ? 'Sandbox Mode (Test)' : 'Real PayPal',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Payment complete overlay
          if (_paymentComplete) ...[
            Container(
              color: isDark ? AppTheme.darkPurple.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Complete!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Error state
          if (_hasError) ...[
            Container(
              color: isDark ? AppTheme.darkPurple : Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to Load PayPal',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
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
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _buildInfoBar(isDark),
    );
  }

  void _onPaymentSuccess() {
    AppLogger.info('PayPal payment completed');
    DonationService.recordDonation(widget.amount);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        DonationService.showThankYouDialog(context, widget.amount);
      }
    });
  }

  void _onPaymentCancelled() {
    AppLogger.info('PayPal payment cancelled');
    if (mounted) {
      DonationService.showCancellationMessage(context);
    }
  }

  Widget _buildInfoBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 18,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Secure payment processed by PayPal',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
