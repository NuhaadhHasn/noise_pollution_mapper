import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../utils/app_logger.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Notification id for the recurring daily reminder (settings-5).
  // Ids 0 (high-noise) and 2 (export) are used elsewhere in this file.
  static const int dailyReminderId = 1;

  // Hour of day (local time) at which the daily reminder fires.
  static const int dailyReminderHour = 19;

  // Initialize notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Timezone database is required for zonedSchedule (settings-5).
    tzdata.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (e) {
      AppLogger.warning('Could not resolve local timezone, using default: $e');
    }

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

  // Schedule the recurring daily reminder at dailyReminderHour local time.
  // Re-scheduling with the same id replaces any existing schedule (settings-5).
  static Future<void> scheduleDailyReminder() async {
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

    await _notifications.zonedSchedule(
      dailyReminderId,
      '📊 Record Today',
      'Help map noise pollution in your area - Record now!',
      _nextInstanceOfReminderTime(),
      notificationDetails,
      // Still REQUIRED in flutter_local_notifications 18.0.1 (the spec claimed
      // v18 removed it). iOS-only effect; this app initializes Android-only.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    AppLogger.info(
      'Daily reminder scheduled for $dailyReminderHour:00 local time',
    );
  }

  // Cancel the recurring daily reminder.
  static Future<void> cancelDailyReminder() async {
    await _notifications.cancel(dailyReminderId);
    AppLogger.info('Daily reminder cancelled');
  }

  static tz.TZDateTime _nextInstanceOfReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      dailyReminderHour,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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
