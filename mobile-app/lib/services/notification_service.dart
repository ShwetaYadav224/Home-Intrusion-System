import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
      },
    );

    await _createChannels();
    await _requestPermissions();
  }

  static Future<void> _createChannels() async {
    const AndroidNotificationChannel securityChannel = AndroidNotificationChannel(
      'security_alerts',
      'Security Alerts',
      description: 'Critical security notifications for strangers and door events',
      importance: Importance.max,
      showBadge: true,
      enableVibration: true,
      playSound: true,
    );

    const AndroidNotificationChannel doorChannel = AndroidNotificationChannel(
      'door_events',
      'Door Events',
      description: 'Notifications for door open/close events',
      importance: Importance.high,
      showBadge: true,
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(securityChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(doorChannel);
  }

  static Future<void> _requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.security,
  }) async {
    print('📢 [NotificationService] Showing $type notification: $title - $body');

    final String channelId;
    final String channelName;
    final String channelDescription;

    switch (type) {
      case NotificationType.door:
        channelId = 'door_events';
        channelName = 'Door Events';
        channelDescription = 'Door open/close notifications';
        break;
      case NotificationType.security:
        channelId = 'security_alerts';
        channelName = 'Security Alerts';
        channelDescription = 'Security alert notifications';
        break;
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      ticker: 'ticker',
      visibility: NotificationVisibility.public,
      category: type == NotificationType.security
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.status,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    print('✅ [NotificationService] Notification displayed');
  }

  static Future<void> showStrangerAlert({
    required int id,
    required String deviceName,
    String? imageUrl,
  }) async {
    await showNotification(
      id: id,
      title: '🚨 STRANGER DETECTED',
      body: 'Unknown person detected by $deviceName',
      payload: imageUrl,
      type: NotificationType.security,
    );
  }

  static Future<void> showDoorEvent({
    required int id,
    required String doorName,
    required String action,
  }) async {
    final emoji = action.toLowerCase() == 'opened' ? '🚪' : '🔒';
    await showNotification(
      id: id,
      title: '$emoji Door $action',
      body: '$doorName was ${action.toLowerCase()}',
      type: NotificationType.door,
    );
  }

  static Future<void> showTestNotification() async {
    final now = DateTime.now();
    await showNotification(
      id: 999999,
      title: '🧪 Test Notification',
      body: 'Test at ${now.hour}:${now.minute}:${now.second}',
      type: NotificationType.security,
    );
  }
}

enum NotificationType {
  security,
  door,
}
