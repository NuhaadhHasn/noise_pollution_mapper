import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';

/// WebView widget for Buy Me a Coffee donations
class BuyMeACoffeeWidget extends StatefulWidget {
  final String url;

  const BuyMeACoffeeWidget({
    super.key,
    required this.url,
  });

  @override
  State<BuyMeACoffeeWidget> createState() => _BuyMeACoffeeWidgetState();
}

class _BuyMeACoffeeWidgetState extends State<BuyMeACoffeeWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Initialize WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
            AppLogger.debug('WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            AppLogger.debug('WebView loading: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            AppLogger.debug('WebView loaded: $url');
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _errorMessage = error.description;
            });
            AppLogger.error('WebView error', error);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within Buy Me a Coffee domain
            if (request.url.contains('buymeacoffee.com') ||
                request.url.contains('stripe.com') ||
                request.url.contains('paypal.com')) {
              return NavigationDecision.navigate;
            }
            // Block external navigation
            AppLogger.warning('Blocked navigation to: ${request.url}');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeHelper.getPrimaryColor(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkPurple : Colors.white,
      appBar: AppBar(
        title: const Text('Buy Me a Coffee'),
        backgroundColor: isDark ? AppTheme.darkPurple : primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Reload button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            },
            tooltip: 'Reload',
          ),
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
        ],
      ),
      body: Stack(
        children: [
          // WebView with proper background
          Container(
            color: isDark ? AppTheme.darkPurple : Colors.white,
            child: WebViewWidget(controller: _controller),
          ),
          
          // Loading indicator
          if (_isLoading && !_hasError) ...[
            Container(
              color: isDark ? AppTheme.darkPurple : Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: primaryColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                    if (_progress > 0 && _progress < 1) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Loading... ${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
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
                        'Failed to Load',
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
                          _controller.reload();
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
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
            Icons.info_outline,
            size: 18,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Buy Me a Coffee is a secure platform for supporting creators',
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
