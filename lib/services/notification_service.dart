import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart'; // For kIsWeb

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Skip initialization for web
    if (kIsWeb) {
      print("Skipping notification initialization for web.");
      return;
    }

    // Initialize timezone database
    tz.initializeTimeZones();
    // TODO: Consider getting the local time zone dynamically if needed
    // tz.setLocalLocation(tz.getLocation('Asia/Shanghai')); // Example

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use app icon

    // iOS initialization settings
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    // Linux initialization settings (optional, placeholder)
    // const LinuxInitializationSettings initializationSettingsLinux =
    //     LinuxInitializationSettings(defaultActionName: 'Open notification');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      // linux: initializationSettingsLinux,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions for Android 13+
    // You might need to call this explicitly based on user interaction
    // or app lifecycle state if needed.
    await _requestAndroidPermissions();
    await _requestIOSPermissions(); // Also request iOS permissions explicitly
  }

  // Callback for when a notification is received while the app is in the foreground (iOS only)
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    print('Notification received while foregrounded (iOS): $id, $title, $body, $payload');
    // You might want to show an in-app alert here instead of a notification
  }

  // Callback for when a user taps on a notification (app is open or background)
  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      debugPrint('notification payload: $payload');
    }
    // Handle payload navigation here if needed
    // e.g., navigate to a specific screen based on the payload
  }

  // Callback for when a user taps on a notification that launched the app (terminated state)
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    // handle action
    print('Notification tapped in background: ${notificationResponse.payload}');
    // You might need to store this payload and handle it after the app initializes
  }


  Future<void> _requestAndroidPermissions() async {
     // Request permission for Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
       final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
       final bool? granted = await androidImplementation?.requestNotificationsPermission();
       print("Android Notification Permission Granted: $granted");
       // Optionally, request exact alarm permission if needed for precise scheduling
       // final bool? exactAlarmGranted = await androidImplementation?.requestExactAlarmsPermission();
       // print("Android Exact Alarm Permission Granted: $exactAlarmGranted");
    }
  }

   Future<void> _requestIOSPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
       await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }


  // --- Basic Notification ---
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
     if (kIsWeb) return; // Don't show on web

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'workout_reminder_channel', // Channel ID
      'Workout Reminders', // Channel Name
      channelDescription: 'Channel for workout reminder notifications', // Channel Description
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      // icon: '@mipmap/ic_launcher' // Ensure you have this icon
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(presentSound: true, presentBadge: true, presentAlert: true);
    // const LinuxNotificationDetails linuxPlatformChannelSpecifics =
    //     LinuxNotificationDetails(); // Optional Linux details

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
      // linux: linuxPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload ?? 'Default Payload',
    );
  }

  // --- Scheduled Notification ---
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
  }) async {
     if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_workout_channel', // Channel ID
          'Daily Workout Reminders', // Channel Name
          channelDescription: 'Channel for daily scheduled workout reminders', // Channel Description
          importance: Importance.max,
          priority: Priority.high,
          // icon: '@mipmap/ic_launcher'
        ),
         iOS: DarwinNotificationDetails(presentSound: true, presentBadge: true, presentAlert: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // More precise scheduling
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Match only the time component daily
      payload: payload ?? 'Scheduled Payload $id',
    );
     print("Scheduled notification $id for $scheduledTime daily.");
  }

  // Helper to calculate the next instance of a specific time
  // tz.TZDateTime _nextInstanceOfTime(Time time) {
  //   final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  //   tz.TZDateTime scheduledDate = tz.TZDateTime(
  //       tz.local, now.year, now.month, now.day, time.hour, time.minute, time.second);
  //   if (scheduledDate.isBefore(now)) {
  //     scheduledDate = scheduledDate.add(const Duration(days: 1));
  //   }
  //   return scheduledDate;
  // }

  // --- Cancel Notifications ---
  Future<void> cancelNotification(int id) async {
     if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id);
     print("Cancelled notification $id");
  }

  Future<void> cancelAllNotifications() async {
     if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
     print("Cancelled all notifications");
  }

   // --- Check Pending Notifications ---
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (kIsWeb) return [];
    final List<PendingNotificationRequest> pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return pendingNotificationRequests;
  }
}