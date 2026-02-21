import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Initialize notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  // Request notification permission
  static Future<bool> requestPermission() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  // Show high noise alert
  static Future<void> showHighNoiseAlert(double decibelLevel) async {
    // Check if notifications are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'high_noise_channel',
      'High Noise Alerts',
      channelDescription: 'Alerts when noise level is dangerously high',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0, // Notification ID
      '⚠️ High Noise Alert!',
      'Noise level: ${decibelLevel.toStringAsFixed(0)} dB - This may be harmful to your hearing',
      notificationDetails,
    );
  }

  // Show daily reminder
  static Future<void> showDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily reminders to record noise levels',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      1,
      '📊 Record Today',
      'Help map noise pollution in your area - Record now!',
      notificationDetails,
    );
  }

  // Show data export notification
  static Future<void> showExportComplete(int recordCount) async {
    const androidDetails = AndroidNotificationDetails(
      'export_channel',
      'Export Notifications',
      channelDescription: 'Notifications for data export completion',
      importance: Importance.low,
      priority: Priority.low,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      2,
      '✅ Export Complete',
      'Successfully exported $recordCount noise recordings to CSV',
      notificationDetails,
    );
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
