import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

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
    final snap = await _eventsCol
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('date', descending: false)
        .get();
    // Filter out deleted documents
    return snap.docs
        .where((d) => d.exists)
        .map((d) => EventFirestore.fromFirestore(d))
        .toList();
  }

  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    return _eventsCol
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('date', descending: false)
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
    final snap = await _eventsCol
        .where('category', isEqualTo: category)
        .orderBy('date', descending: false)
        .get();
    // Filter out deleted documents
    return snap.docs
        .where((d) => d.exists)
        .map((d) => EventFirestore.fromFirestore(d))
        .toList();
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

  static Future<bool> registerForEvent(String eventId, String userId) async {
    try {
      final ref = _eventsCol.doc(eventId);
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        final event = EventFirestore.fromFirestore(snap);
        if (event.participants.contains(userId)) return true;
        if (event.participants.length >= event.maxParticipants) return false;
        final updated = List<String>.from(event.participants)..add(userId);
        tx.update(ref, {'participants': updated});
        return true;
      });
    } catch (e) {
      return false;
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
}