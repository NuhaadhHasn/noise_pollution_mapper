import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

/// Shown instead of the normal app when a fatal startup step fails
/// (audit findings boot-1 / flow1-1). Offers a Retry that re-runs bootstrap.
///
/// On success the retry callback calls runApp(MyApp()) and replaces this
/// tree; on repeated failure it calls runApp with a fresh StartupErrorApp.
class StartupErrorApp extends StatefulWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const StartupErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  State<StartupErrorApp> createState() => _StartupErrorAppState();
}

class _StartupErrorAppState extends State<StartupErrorApp> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    setState(() => _retrying = true);
    await widget.onRetry();
    // No state reset needed: onRetry replaces the widget tree via runApp
    // whether it succeeds or fails again.
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Urban Noise Pollution Mapper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.generateDarkTheme(AppTheme.primaryPurple),
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: ThemeHelper.getBackgroundColor(context),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 64,
                      color: ThemeHelper.getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Could not start the app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A required service failed to initialize. '
                      'Check your internet connection and try again.\n\n'
                      '${widget.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeHelper.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _retrying ? null : _handleRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getButtonColor(context),
                          foregroundColor:
                              ThemeHelper.getButtonTextColor(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _retrying
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      ThemeHelper.getButtonTextColor(context),
                                ),
                              )
                            : const Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
