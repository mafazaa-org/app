import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Only initialize notifications on supported mobile platforms to prevent crashes on Windows.
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Configure Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configure iOS initialization settings
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
      );

      debugPrint('[NotificationService] Initialized successfully');
      
      // Request permission
      await requestPermissions();
      
      // Schedule daily reminder
      await scheduleDailyReminder();
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> scheduleDailyReminder() async {
    // Check platform compatibility
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      // Cancel previous scheduled notifications to avoid duplicates
      await _notificationsPlugin.cancel(100);

      // Define notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Reminders',
        channelDescription: 'Remind users to watch their daily lessons',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      // Schedule at 8:00 PM local time
      final scheduledTime = _nextInstanceOfTime(20, 0); // 20:00 is 8:00 PM

      await _notificationsPlugin.zonedSchedule(
        100,
        'حان وقت درسك اليومي 📚',
        'تذكير بمشاهدة درسك اليومي ومتابعة استقامتك اليوم في مفازا.',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
      );
      
      debugPrint('[NotificationService] Daily reminder scheduled for: $scheduledTime');
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling daily reminder: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.Location local = tz.local;
    final tz.TZDateTime now = tz.TZDateTime.now(local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(local, now.year, now.month, now.day, hour, minute);
        
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
