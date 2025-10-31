import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user.dart';
import 'firebase_event_service.dart';
import 'firebase_user_service.dart';
import 'firebase_notification_service.dart';

class FirebaseRealtimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Listen to all events with real-time updates
  static Stream<List<Event>> listenToAllEvents() {
    return FirebaseEventService.getAllEventsStream();
  }

  // Listen to user's events with real-time updates
  static Stream<List<Event>> listenToUserEvents(String userId) {
    return FirebaseEventService.getUserEventsStream(userId);
  }

  // Listen to organizer's events with real-time updates
  static Stream<List<Event>> listenToOrganizerEvents(String organizerId) {
    return FirebaseEventService.getEventsByOrganizerStream(organizerId);
  }

  // Listen to user authentication state changes
  static Stream<User?> listenToAuthStateChanges() {
    return FirebaseUserService.authStateChanges;
  }

  // Listen to specific event changes
  static Stream<Event?> listenToEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return EventFirestore.fromFirestore(doc);
      }
      return null;
    });
  }

  // Listen to event participants changes
  static Stream<List<String>> listenToEventParticipants(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['participants'] ?? []);
      }
      return [];
    });
  }

  // Listen to events by category with real-time updates
  static Stream<List<Event>> listenToEventsByCategory(String category) {
    return _firestore
        .collection('events')
        .where('category', isEqualTo: category)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          // Filter out deleted documents
          return snapshot.docs
              .where((doc) => doc.exists && doc.data() != null)
              .map((doc) => EventFirestore.fromFirestore(doc))
              .toList();
        });
  }

  // Listen to events by status with real-time updates
  static Stream<List<Event>> listenToEventsByStatus(EventStatus status) {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: status.name)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          // Filter out deleted documents
          return snapshot.docs
              .where((doc) => doc.exists && doc.data() != null)
              .map((doc) => EventFirestore.fromFirestore(doc))
              .toList();
        });
  }

  // Listen to upcoming events (next 30 days)
  static Stream<List<Event>> listenToUpcomingEvents() {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    
    return _firestore
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(thirtyDaysFromNow))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          // Filter out deleted documents
          return snapshot.docs
              .where((doc) => doc.exists && doc.data() != null)
              .map((doc) => EventFirestore.fromFirestore(doc))
              .toList();
        });
  }

  // Listen to events happening today
  static Stream<List<Event>> listenToTodaysEvents() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    return _firestore
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          // Filter out deleted documents
          return snapshot.docs
              .where((doc) => doc.exists && doc.data() != null)
              .map((doc) => EventFirestore.fromFirestore(doc))
              .toList();
        });
  }

  // Set up event reminders
  static Future<void> setupEventReminders(String userId) async {
    // Listen to user's events and set up reminders
    listenToUserEvents(userId).listen((events) {
      for (final event in events) {
        if (event.status == EventStatus.active || event.status == EventStatus.published) {
          _scheduleEventReminder(event);
        }
      }
    });
  }

  // Schedule event reminder
  static Future<void> _scheduleEventReminder(Event event) async {
    final now = DateTime.now();
    final eventDate = event.date;
    final timeUntilEvent = eventDate.difference(now);
    
    // Schedule reminder 24 hours before event
    if (timeUntilEvent.inHours >= 24) {
      final reminderTime = eventDate.subtract(const Duration(hours: 24));
      if (reminderTime.isAfter(now)) {
        await FirebaseNotificationService.sendEventReminder(
          eventTitle: event.title,
          eventId: event.id,
          eventDate: eventDate,
        );
      }
    }
    
    // Schedule reminder 1 hour before event
    if (timeUntilEvent.inHours >= 1) {
      final reminderTime = eventDate.subtract(const Duration(hours: 1));
      if (reminderTime.isAfter(now)) {
        await FirebaseNotificationService.sendEventReminder(
          eventTitle: event.title,
          eventId: event.id,
          eventDate: eventDate,
        );
      }
    }
  }

  // Listen to event updates and send notifications
  static void setupEventUpdateNotifications() {
    listenToAllEvents().listen((events) {
      for (final event in events) {
        // Check if event was recently updated
        // This would require storing last update timestamp
        // For now, we'll just listen to status changes
        if (event.status == EventStatus.cancelled) {
          _notifyEventCancellation(event);
        } else if (event.status == EventStatus.completed) {
          _notifyEventCompletion(event);
        }
      }
    });
  }

  // Notify event cancellation
  static Future<void> _notifyEventCancellation(Event event) async {
    await FirebaseNotificationService.sendEventUpdate(
      eventTitle: event.title,
      eventId: event.id,
      updateMessage: 'This event has been cancelled.',
    );
  }

  // Notify event completion
  static Future<void> _notifyEventCompletion(Event event) async {
    await FirebaseNotificationService.sendEventUpdate(
      eventTitle: event.title,
      eventId: event.id,
      updateMessage: 'This event has been completed. Thank you for participating!',
    );
  }
}
