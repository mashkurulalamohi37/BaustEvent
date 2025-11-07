import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      print('Starting notification initialization...');
      
      // Request permission for notifications (with timeout)
      try {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Notification permission request timed out');
            throw TimeoutException('Permission request timeout');
          },
        );
        
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          print('User granted notification permission');
        } else {
          print('User declined or has not accepted notification permission');
        }
      } catch (e) {
        print('Error requesting notification permission: $e');
        // Continue even if permission request fails
      }

      // Initialize local notifications
      try {
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

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (details) {
            // Handle notification tap
            print('Notification tapped: ${details.payload}');
          },
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Local notifications initialization timed out');
            throw TimeoutException('Local notifications timeout');
          },
        );
        print('Local notifications initialized');
        
        // Create Android notification channel (required for Android 8.0+)
        try {
          const androidChannel = AndroidNotificationChannel(
            'eventbridge_channel',
            'EventBridge Notifications',
            description: 'Notifications for EventBridge app',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );
          
          await _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(androidChannel);
          print('Android notification channel created');
        } catch (e) {
          print('Error creating Android notification channel: $e');
        }
      } catch (e) {
        print('Error initializing local notifications: $e');
        // Continue even if local notifications fail
      }

      // Handle background messages
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        print('Error setting up background message handler: $e');
      }

      // Handle foreground messages
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        print('Error setting up foreground message handler: $e');
      }

      // Handle notification taps
      try {
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      } catch (e) {
        print('Error setting up notification tap handler: $e');
      }
      
      // Subscribe participants to new events topic (non-blocking)
      try {
        await _messaging.subscribeToTopic('new_events').timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Topic subscription timed out');
            throw TimeoutException('Topic subscription timeout');
          },
        );
        print('Subscribed to new_events topic');
      } catch (e) {
        print('Error subscribing to topic: $e');
        // Continue even if topic subscription fails
      }
      
      print('Notification initialization completed');
    } catch (e) {
      print('Error initializing notifications: $e');
      // Don't rethrow - let app continue even if notifications fail
    }
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
    try {
      print('Showing local notification: $title - $body');
      
      const androidDetails = AndroidNotificationDetails(
        'eventbridge_channel',
        'EventBridge Notifications',
        channelDescription: 'Notifications for EventBridge app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
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

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
      print('Local notification shown successfully with ID: $notificationId');
    } catch (e, stackTrace) {
      print('Error showing local notification: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  // Store FCM token for a user
  static Future<void> saveFCMToken(String userId, String token) async {
    try {
      final usersCol = FirebaseFirestore.instance.collection('users');
      await usersCol.doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      print('FCM token saved for user: $userId');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
  
  // Send notification to all participants when a new event is created
  static Future<void> notifyNewEventCreated({
    required String eventTitle,
    required String eventId,
    required String category,
    required DateTime eventDate,
  }) async {
    try {
      print('Sending new event notification: $eventTitle');
      
      // Store notification in Firestore FIRST - this will trigger listeners for all users (participants, organizers, admins)
      // This is the primary method for showing notifications - Firestore listeners will show system notifications
      final notificationsCol = FirebaseFirestore.instance.collection('notifications');
      final notificationData = {
        'type': 'new_event',
        'eventId': eventId,
        'eventTitle': eventTitle,
        'category': category,
        'eventDate': eventDate.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
      };
      
      print('Creating notification in Firestore: $notificationData');
      final docRef = await notificationsCol.add(notificationData);
      print('✅ New event notification stored in Firestore with ID: ${docRef.id}');
      print('This notification will be visible to all authenticated users (participants, organizers, admins)');
      print('Firestore listeners in each dashboard will detect this and show system notifications');
      
      // Optional: Also try to get FCM tokens for future use (but don't block on this)
      try {
        final usersCol = FirebaseFirestore.instance.collection('users');
        final participantsSnapshot = await usersCol
            .where('type', isEqualTo: 'participant')
            .limit(1)
            .get();
        
        if (participantsSnapshot.docs.isNotEmpty) {
          // Subscribe to topic for future FCM push notifications (if needed)
          await _messaging.subscribeToTopic('new_events');
          print('Subscribed to FCM topic: new_events');
        }
      } catch (e) {
        print('Note: FCM topic subscription failed (non-critical): $e');
        // Don't fail notification creation if FCM fails
      }
    } catch (e, stackTrace) {
      print('❌ Error sending new event notification: $e');
      print('Stack trace: $stackTrace');
    }
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
