import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/participant_registration_info.dart';
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
    try {
      // Fetch all events without orderBy to include events without createdAt field
      final snap = await _eventsCol.get();
      // Filter out deleted documents
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      // Sort by createdAt descending (newest first)
      // Events without createdAt will use event date as fallback from fromFirestore
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    } catch (e) {
      print('Error fetching all events: $e');
      return [];
    }
  }

  static Stream<List<Event>> getAllEventsStream() {
    // Fetch without orderBy to include events without createdAt field, then sort manually
    return _eventsCol
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
          // Sort by createdAt descending (newest first) to ensure correct order
          // Events without createdAt will use event date as fallback from fromFirestore
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      // Fetch all events without orderBy to include events without createdAt field
      final snap = await _eventsCol
          .where('organizerId', isEqualTo: organizerId)
          .get();
      // Filter out deleted documents
      final events = snap.docs
          .where((d) => d.exists)
          .map((d) => EventFirestore.fromFirestore(d))
          .toList();
      // Sort by createdAt descending (newest first)
      // Events without createdAt will use DateTime.now() from fromFirestore, which is fine for sorting
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events;
    } catch (e) {
      print('Error fetching organizer events: $e');
      return [];
    }
  }

  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    // Fetch without orderBy to include events without createdAt field, then sort manually
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
          // Sort by createdAt descending (newest first) to ensure correct order
          // Events without createdAt will use DateTime.now() from fromFirestore, which is fine for sorting
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      
      // Create event with current timestamp for createdAt
      final eventWithTimestamp = event.copyWith(
        createdAt: DateTime.now(),
        createdAtSet: true,
      );
      
      final eventData = eventWithTimestamp.toFirestore();
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
          await _notifyNewEvent(eventWithTimestamp);
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
        // Check if event date has passed - participants cannot register for past events
        if (event.isEventDatePassed) {
          print('registerForEvent: Event $eventId date has passed (${event.date})');
          return RegistrationStatus.registrationClosed;
        }
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
        // Note: Participant registration info should be saved before calling this
        // The UI will call saveParticipantRegistrationInfo separately
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
      final success = await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final event = EventFirestore.fromFirestore(snap);
        if (!event.participants.contains(userId)) return true;
        final updated = List<String>.from(event.participants)..remove(userId);
        tx.update(ref, {'participants': updated});
        return true;
      });
      
      // Also delete participant registration info if exists
      if (success) {
        try {
          final participantRef = _firestore
              .collection('event_participants')
              .where('eventId', isEqualTo: eventId)
              .where('userId', isEqualTo: userId)
              .limit(1);
          final snapshot = await participantRef.get();
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          print('Error deleting participant info: $e');
          // Don't fail unregistration if info deletion fails
        }
      }
      
      return success;
    } catch (e) {
      return false;
    }
  }

  // Save participant registration info
  static Future<bool> saveParticipantRegistrationInfo(
    ParticipantRegistrationInfo info,
  ) async {
    try {
      // Use a compound document ID: eventId_userId
      final docId = '${info.eventId}_${info.userId}';
      await _firestore
          .collection('event_participants')
          .doc(docId)
          .set(info.toFirestore());
      return true;
    } catch (e) {
      print('Error saving participant registration info: $e');
      return false;
    }
  }

  // Get participant registration info
  static Future<ParticipantRegistrationInfo?> getParticipantRegistrationInfo(
    String eventId,
    String userId,
  ) async {
    try {
      final docId = '${eventId}_${userId}';
      final doc = await _firestore
          .collection('event_participants')
          .doc(docId)
          .get();
      if (doc.exists && doc.data() != null) {
        return ParticipantRegistrationInfo.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting participant registration info: $e');
      return null;
    }
  }

  // Get all participant registration info for an event
  static Future<List<ParticipantRegistrationInfo>> getEventParticipantInfo(
    String eventId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('event_participants')
          .where('eventId', isEqualTo: eventId)
          .get();
      return snapshot.docs
          .map((doc) => ParticipantRegistrationInfo.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting event participant info: $e');
      return [];
    }
  }

  // Get participant registration info with pagination (for large events)
  static Future<List<ParticipantRegistrationInfo>> getEventParticipantInfoPaginated(
    String eventId, {
    int limit = 500,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('event_participants')
          .where('eventId', isEqualTo: eventId)
          .limit(limit);
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ParticipantRegistrationInfo.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting paginated event participant info: $e');
      return [];
    }
  }

  // Save pending registration (for hand cash payment)
  static Future<bool> savePendingRegistration(
    String eventId,
    String userId,
    ParticipantRegistrationInfo info,
  ) async {
    try {
      final docId = '${eventId}_${userId}';
      
      // Ensure paymentMethod and paymentStatus are set correctly
      final data = info.toFirestore();
      
      // Remove null values and ensure required fields are set
      data.removeWhere((key, value) => value == null);
      
      // Force required fields
      data['paymentMethod'] = 'handCash'; // Force to be handCash
      data['paymentStatus'] = 'pending'; // Force to be pending
      data['eventId'] = eventId; // Ensure eventId is set
      data['userId'] = userId; // Ensure userId is set
      data['registeredAt'] = info.registeredAt.toIso8601String(); // Ensure registeredAt is set
      
      print('=== SAVING PENDING REGISTRATION ===');
      print('docId: $docId');
      print('eventId: $eventId');
      print('userId: $userId');
      print('paymentMethod: ${data['paymentMethod']}');
      print('paymentStatus: ${data['paymentStatus']}');
      print('Full data: $data');
      
      try {
        await _firestore
            .collection('event_participants')
            .doc(docId)
            .set(data);
        print('Document set() completed');
      } catch (setError) {
        print('❌ Error in set() operation: $setError');
        rethrow;
      }
      
      // Verify the document was saved
      try {
        final savedDoc = await _firestore
            .collection('event_participants')
            .doc(docId)
            .get();
        
        if (savedDoc.exists && savedDoc.data() != null) {
          print('✅ Pending registration verified in Firestore');
          print('Saved document data: ${savedDoc.data()}');
          
          // Double-check the paymentMethod and paymentStatus
          final savedData = savedDoc.data()!;
          print('Verification - paymentMethod: ${savedData['paymentMethod']}, paymentStatus: ${savedData['paymentStatus']}');
          
          return true;
        } else {
          print('❌ Pending registration document not found after save');
          print('Document exists: ${savedDoc.exists}, Data: ${savedDoc.data()}');
          return false;
        }
      } catch (verifyError) {
        print('❌ Error verifying saved document: $verifyError');
        // Document might have been saved but verification failed, return true anyway
        return true;
      }
    } catch (e, stackTrace) {
      print('❌ Error saving pending registration: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Get pending registrations for an event (hand cash payments awaiting approval)
  static Future<List<ParticipantRegistrationInfo>> getPendingRegistrations(
    String eventId,
  ) async {
    try {
      print('Getting pending registrations for eventId: $eventId');
      // First, try with composite query
      try {
        final snapshot = await _firestore
            .collection('event_participants')
            .where('eventId', isEqualTo: eventId)
            .where('paymentMethod', isEqualTo: 'handCash')
            .where('paymentStatus', isEqualTo: 'pending')
            .get();
        
        print('Found ${snapshot.docs.length} pending registrations (with composite query)');
        return snapshot.docs
            .map((doc) {
              print('Pending registration doc: ${doc.id}, data: ${doc.data()}');
              return ParticipantRegistrationInfo.fromFirestore(doc.data());
            })
            .toList();
      } catch (e) {
        // If composite query fails (no index), fetch all and filter manually
        print('Composite query failed (may need index): $e');
        print('Falling back to manual filtering...');
        
        final snapshot = await _firestore
            .collection('event_participants')
            .where('eventId', isEqualTo: eventId)
            .get();
        
        print('Found ${snapshot.docs.length} total registrations for this event');
        final pending = <ParticipantRegistrationInfo>[];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final paymentMethod = data['paymentMethod'] as String?;
          final paymentStatus = data['paymentStatus'] as String?;
          
          print('Checking doc ${doc.id}: paymentMethod=$paymentMethod, paymentStatus=$paymentStatus');
          
          if (paymentMethod == 'handCash' && paymentStatus == 'pending') {
            print('Found pending registration: ${doc.id}');
            pending.add(ParticipantRegistrationInfo.fromFirestore(data));
          }
        }
        
        print('Found ${pending.length} pending registrations (manual filtering)');
        return pending;
      }
    } catch (e) {
      print('Error getting pending registrations: $e');
      return [];
    }
  }

  // Approve pending registration (hand cash payment)
  static Future<bool> approvePendingRegistration(
    String eventId,
    String userId,
  ) async {
    try {
      final docId = '${eventId}_${userId}';
      final doc = await _firestore
          .collection('event_participants')
          .doc(docId)
          .get();
      
      if (!doc.exists) return false;
      
      // Update payment status to approved
      await _firestore
          .collection('event_participants')
          .doc(docId)
          .update({'paymentStatus': 'approved'});
      
      // Add user to event participants list
      final result = await registerForEvent(eventId, userId);
      return result.isSuccess;
    } catch (e) {
      print('Error approving pending registration: $e');
      return false;
    }
  }

  // Reject pending registration (hand cash payment)
  static Future<bool> rejectPendingRegistration(
    String eventId,
    String userId,
  ) async {
    try {
      final docId = '${eventId}_${userId}';
      final doc = await _firestore
          .collection('event_participants')
          .doc(docId)
          .get();
      
      if (!doc.exists) return false;
      
      // Update payment status to rejected
      await _firestore
          .collection('event_participants')
          .doc(docId)
          .update({'paymentStatus': 'rejected'});
      
      return true;
    } catch (e) {
      print('Error rejecting pending registration: $e');
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