import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import 'firebase_notification_service.dart';

enum RegistrationStatus {
  success,
  alreadyRegistered,
  eventFull,
  adminNotAllowed,
  eventNotFound,
  permissionDenied,
  networkError,
  registrationClosed,
  error,
}

class RegistrationResult {
  final RegistrationStatus status;
  final String? message;

  const RegistrationResult(this.status, {this.message});

  bool get isSuccess => status == RegistrationStatus.success;
}

class FirebaseEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _firestore.collection('events');

  // Queries
  static Future<List<Event>> getAllEvents() async {
    final snap = await _eventsCol.orderBy('date', descending: false).get();
    // Filter out deleted documents
    return snap.docs
        .where((d) => d.exists)
        .map((d) => EventFirestore.fromFirestore(d))
        .toList();
  }

  static Stream<List<Event>> getAllEventsStream() {
    return _eventsCol
        .orderBy('date', descending: false)
        .snapshots()
        .map((s) {
          // Log deletions from docChanges
          for (var docChange in s.docChanges) {
            if (docChange.type == DocumentChangeType.removed) {
              print('Document ${docChange.doc.id} was removed from getAllEventsStream');
            }
          }
          
          // Process all current documents in the snapshot
          // Firestore automatically excludes deleted documents from s.docs
          final events = <Event>[];
          for (var doc in s.docs) {
            // Double-check that document exists and has data
            if (!doc.exists) {
              print('Warning: Found non-existent document ${doc.id} in snapshot');
              continue;
            }
            
            final data = doc.data();
            if (data == null || data.isEmpty) {
              print('Warning: Document ${doc.id} has no data');
              continue;
            }
            
            try {
              events.add(EventFirestore.fromFirestore(doc));
            } catch (e) {
              print('Error parsing event document ${doc.id}: $e');
            }
          }
          print('getAllEventsStream: ${events.length} events (from ${s.docs.length} docs, ${s.docChanges.length} changes)');
          return events;
        })
        .handleError((error) {
          print('Error in getAllEventsStream: $error');
          return <Event>[]; // Return empty list on error
        });
  }

  static Future<List<Event>> getEventsByOrganizer(String organizerId) async {
    try {
      // Try with orderBy first (requires index)
      final snap = await _eventsCol
          .where('organizerId', isEqualTo: organizerId)
          .orderBy('date', descending: false)
          .get();
      // Filter out deleted documents
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      // Sort manually as fallback
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      // If index doesn't exist, fetch without orderBy and sort manually
      print('Index not found, fetching without orderBy: $e');
      final snap = await _eventsCol
          .where('organizerId', isEqualTo: organizerId)
          .get();
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      // Sort manually
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    }
  }

  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    // Use query without orderBy to avoid index requirement, then sort manually
    return _eventsCol
        .where('organizerId', isEqualTo: organizerId)
        .snapshots()
        .map((s) {
          // Log deletions from docChanges
          for (var docChange in s.docChanges) {
            if (docChange.type == DocumentChangeType.removed) {
              print('Document ${docChange.doc.id} was removed from getEventsByOrganizerStream');
            }
          }
          
          // Process all current documents in the snapshot
          // Firestore automatically excludes deleted documents from s.docs
          final events = <Event>[];
          for (var doc in s.docs) {
            // Double-check that document exists and has data
            if (!doc.exists) {
              print('Warning: Found non-existent document ${doc.id} in snapshot');
              continue;
            }
            
            final data = doc.data();
            if (data == null || data.isEmpty) {
              print('Warning: Document ${doc.id} has no data');
              continue;
            }
            
            try {
              events.add(EventFirestore.fromFirestore(doc));
            } catch (e) {
              print('Error parsing event document ${doc.id}: $e');
            }
          }
          // Sort manually since we're not using orderBy
          events.sort((a, b) => a.date.compareTo(b.date));
          print('getEventsByOrganizerStream: ${events.length} events (from ${s.docs.length} docs, ${s.docChanges.length} changes)');
          return events;
        })
        .handleError((error) {
          print('Error in getEventsByOrganizerStream: $error');
          return <Event>[]; // Return empty list on error
        });
  }

  static Future<List<Event>> getUserEvents(String userId) async {
    final snap = await _eventsCol.where('participants', arrayContains: userId).get();
    // Filter out deleted documents
    return snap.docs
        .where((d) => d.exists)
        .map((d) => EventFirestore.fromFirestore(d))
        .toList();
  }

  static Stream<List<Event>> getUserEventsStream(String userId) {
    return _eventsCol
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((s) {
          // Log deletions from docChanges
          for (var docChange in s.docChanges) {
            if (docChange.type == DocumentChangeType.removed) {
              print('Document ${docChange.doc.id} was removed from getUserEventsStream');
            }
          }
          
          // Process all current documents in the snapshot
          // Firestore automatically excludes deleted documents from s.docs
          final events = <Event>[];
          for (var doc in s.docs) {
            // Double-check that document exists and has data
            if (!doc.exists) {
              print('Warning: Found non-existent document ${doc.id} in snapshot');
              continue;
            }
            
            final data = doc.data();
            if (data == null || data.isEmpty) {
              print('Warning: Document ${doc.id} has no data');
              continue;
            }
            
            try {
              events.add(EventFirestore.fromFirestore(doc));
            } catch (e) {
              print('Error parsing event document ${doc.id}: $e');
            }
          }
          print('getUserEventsStream: ${events.length} events (from ${s.docs.length} docs, ${s.docChanges.length} changes)');
          return events;
        })
        .handleError((error) {
          print('Error in getUserEventsStream: $error');
          return <Event>[]; // Return empty list on error
        });
  }

  static Future<List<Event>> searchEvents(String query) async {
    // Simple search over title/category; Firestore requires indexing for complex queries
    final snap = await _eventsCol.get();
    final q = query.toLowerCase();
    // Filter out deleted documents first, then search
    return snap.docs
        .where((d) => d.exists)
        .map((d) => EventFirestore.fromFirestore(d))
        .where((e) => e.title.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q))
        .toList();
  }

  static Future<List<Event>> getEventsByCategory(String category) async {
    try {
      // Try with orderBy first (requires index)
      final snap = await _eventsCol
          .where('category', isEqualTo: category)
          .orderBy('date', descending: false)
          .get();
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    } catch (e) {
      // If index doesn't exist, fetch without orderBy and sort manually
      print('Category index not found, fetching without orderBy: $e');
      final snap = await _eventsCol
          .where('category', isEqualTo: category)
          .get();
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      // Sort manually
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    }
  }

  // Mutations
  static Future<bool> createEvent(Event event) async {
    try {
      print('=== CREATING EVENT IN FIRESTORE ===');
      print('Event ID: ${event.id}');
      print('Event title: ${event.title}');
      print('Organizer ID: ${event.organizerId}');
      
      final eventData = event.toFirestore();
      print('Event data to save: $eventData');
      
      print('Calling Firestore set()...');
      await _eventsCol.doc(event.id).set(eventData);
      print('Firestore set() completed successfully');
      
      // Verify the document was created
      final doc = await _eventsCol.doc(event.id).get();
      if (doc.exists) {
        print('Event document verified in Firestore');
        
        // Send notification to all participants about the new event
        try {
          await _notifyNewEvent(event);
        } catch (e) {
          print('Error sending new event notification: $e');
          // Don't fail event creation if notification fails
        }
        
        return true;
      } else {
        print('WARNING: Event document not found after creation');
        throw Exception('Event document was not created in Firestore');
      }
    } catch (e, stackTrace) {
      print('=== ERROR CREATING EVENT IN FIRESTORE ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('==========================================');
      // Re-throw to get more details in the UI
      throw Exception('Firestore error: ${e.toString()}');
    }
  }

  static Future<bool> updateEvent(Event event) async {
    try {
      await _eventsCol.doc(event.id).update(event.toFirestore());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteEvent(String eventId) async {
    try {
      print('Attempting to delete event: $eventId');
      await _eventsCol.doc(eventId).delete();
      print('Event deleted successfully: $eventId');
      return true;
    } catch (e, stackTrace) {
      print('=== ERROR DELETING EVENT ===');
      print('Event ID: $eventId');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('============================');
      return false;
    }
  }

  static Future<bool> markEventAsCompleted(String eventId) async {
    try {
      print('Attempting to mark event as completed: $eventId');
      await _eventsCol.doc(eventId).update({'status': 'completed'});
      print('Event marked as completed successfully: $eventId');
      return true;
    } catch (e, stackTrace) {
      print('=== ERROR MARKING EVENT AS COMPLETED ===');
      print('Event ID: $eventId');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('========================================');
      return false;
    }
  }

  static Future<RegistrationResult> registerForEvent(String eventId, String userId) async {
    try {
      // Check if user is an admin - admins cannot register for events
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null && userData['type'] == 'admin') {
          print('Admin users cannot register for events');
          return const RegistrationResult(
            RegistrationStatus.adminNotAllowed,
            message: 'Admins cannot register for events.',
          );
        }
      }
      
      final ref = _eventsCol.doc(eventId);
      final status = await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          print('registerForEvent: Event $eventId not found during transaction');
          return RegistrationStatus.eventNotFound;
        }
        final event = EventFirestore.fromFirestore(snap);
        if (event.registrationCloseDate != null &&
            DateTime.now().isAfter(event.registrationCloseDate!)) {
          print('registerForEvent: Event $eventId registration closed at ${event.registrationCloseDate}');
          return RegistrationStatus.registrationClosed;
        }
        if (event.participants.contains(userId)) {
          print('registerForEvent: User $userId already registered for event $eventId');
          return RegistrationStatus.alreadyRegistered;
        }
        if (event.participants.length >= event.maxParticipants) {
          print('registerForEvent: Event $eventId is full (${event.participants.length}/${event.maxParticipants})');
          return RegistrationStatus.eventFull;
        }
        final updated = List<String>.from(event.participants)..add(userId);
        tx.update(ref, {'participants': updated});
        return RegistrationStatus.success;
      });
      
      // Send registration confirmation notification if successful
      if (status == RegistrationStatus.success) {
        try {
          final eventDoc = await _eventsCol.doc(eventId).get();
          if (eventDoc.exists) {
            final eventData = eventDoc.data();
            final eventTitle = eventData?['title'] as String? ?? 'Event';
            await FirebaseNotificationService.sendRegistrationConfirmation(
              eventTitle: eventTitle,
              eventId: eventId,
            );
          }
        } catch (e) {
          print('Error sending registration confirmation: $e');
          // Don't fail registration if notification fails
        }
      }
      
      return RegistrationResult(
        status,
        message: _statusToMessage(status),
      );
    } catch (e, stackTrace) {
      print('Error registering for event $eventId with user $userId: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          return RegistrationResult(
            RegistrationStatus.permissionDenied,
            message: 'You do not have permission to register for this event.',
          );
        }
        if (e.code == 'unavailable' || e.code == 'network-request-failed') {
          return RegistrationResult(
            RegistrationStatus.networkError,
            message: 'Network error occurred. Please check your connection and try again.',
          );
        }
        return RegistrationResult(
          RegistrationStatus.error,
          message: e.message ?? 'Failed to update registration. Please try again.',
        );
      }
      return const RegistrationResult(
        RegistrationStatus.error,
        message: 'Failed to update registration. Please try again.',
      );
    }
  }

  static String _statusToMessage(RegistrationStatus status) {
    switch (status) {
      case RegistrationStatus.success:
        return 'Registered successfully!';
      case RegistrationStatus.alreadyRegistered:
        return 'You are already registered for this event.';
      case RegistrationStatus.eventFull:
        return 'This event has reached its participant limit.';
      case RegistrationStatus.adminNotAllowed:
        return 'Admins cannot register for events.';
      case RegistrationStatus.eventNotFound:
        return 'Unable to find this event. Please refresh and try again.';
      case RegistrationStatus.registrationClosed:
        return 'Registration is closed for this event.';
      case RegistrationStatus.permissionDenied:
        return 'You do not have permission to register for this event.';
      case RegistrationStatus.networkError:
        return 'Network error occurred. Please check your connection and try again.';
      case RegistrationStatus.error:
      default:
        return 'Failed to update registration. Please try again.';
    }
  }

  static Future<bool> unregisterFromEvent(String eventId, String userId) async {
    try {
      final ref = _eventsCol.doc(eventId);
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final event = EventFirestore.fromFirestore(snap);
        if (!event.participants.contains(userId)) return true;
        final updated = List<String>.from(event.participants)..remove(userId);
        tx.update(ref, {'participants': updated});
        return true;
      });
    } catch (e) {
      return false;
    }
  }
  
  // Notify all participants about a new event
  static Future<void> _notifyNewEvent(Event event) async {
    try {
      await FirebaseNotificationService.notifyNewEventCreated(
        eventTitle: event.title,
        eventId: event.id,
        category: event.category,
        eventDate: event.date,
      );
    } catch (e) {
      print('Error in _notifyNewEvent: $e');
    }
  }
}