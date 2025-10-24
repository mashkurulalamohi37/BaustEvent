import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission for notifications
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  // Get FCM token
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  // Send local notification
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'eventbridge_channel',
      'EventBridge Notifications',
      channelDescription: 'Notifications for EventBridge app',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    showLocalNotification(
      title: message.notification?.title ?? 'EventBridge',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  // Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // Handle navigation based on notification data
    final data = message.data;
    if (data['type'] == 'event_reminder') {
      // Navigate to event details
    } else if (data['type'] == 'event_update') {
      // Navigate to event details
    }
  }

  // Send event reminder notification
  static Future<void> sendEventReminder({
    required String eventTitle,
    required String eventId,
    required DateTime eventDate,
  }) async {
    final timeUntilEvent = eventDate.difference(DateTime.now());
    
    if (timeUntilEvent.inHours <= 24 && timeUntilEvent.inHours > 0) {
      await showLocalNotification(
        title: 'Event Reminder',
        body: '$eventTitle is happening tomorrow!',
        payload: 'event_reminder:$eventId',
      );
    } else if (timeUntilEvent.inMinutes <= 60 && timeUntilEvent.inMinutes > 0) {
      await showLocalNotification(
        title: 'Event Starting Soon',
        body: '$eventTitle starts in ${timeUntilEvent.inMinutes} minutes!',
        payload: 'event_reminder:$eventId',
      );
    }
  }

  // Send event update notification
  static Future<void> sendEventUpdate({
    required String eventTitle,
    required String eventId,
    required String updateMessage,
  }) async {
    await showLocalNotification(
      title: 'Event Update: $eventTitle',
      body: updateMessage,
      payload: 'event_update:$eventId',
    );
  }

  // Send registration confirmation
  static Future<void> sendRegistrationConfirmation({
    required String eventTitle,
    required String eventId,
  }) async {
    await showLocalNotification(
      title: 'Registration Confirmed',
      body: 'You have successfully registered for $eventTitle',
      payload: 'event_registration:$eventId',
    );
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  print('Handling a background message: ${message.messageId}');
}
