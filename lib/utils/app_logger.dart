import 'package:logger/logger.dart';

/// Centralized logging utility for the application
///
/// Usage:
/// - AppLogger.debug('Debug message') - Development info
/// - AppLogger.info('Info message') - General information
/// - AppLogger.warning('Warning message') - Non-critical issues
/// - AppLogger.error('Error message', error, stackTrace) - Critical errors
///
/// Production: Set level to Level.error in main.dart before release
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,         // Don't show method stack
      errorMethodCount: 5,    // Show 5 methods for errors
      lineLength: 50,         // Console width
      colors: true,           // Colorful logs
      printEmojis: true,      // Use emojis for log levels
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // Show timestamp
    ),
    level: Level.debug, // TODO: Change to Level.error for production
  );

  /// Debug logs - for development only
  static void debug(String message) => _logger.d(message);

  /// Info logs - general information
  static void info(String message) => _logger.i(message);

  /// Warning logs - non-critical issues
  static void warning(String message) => _logger.w(message);

  /// Error logs - critical issues with optional error and stack trace
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
