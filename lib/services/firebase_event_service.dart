import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class FirebaseEventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _firestore.collection('events');

  // Queries
  static Future<List<Event>> getAllEvents() async {
    final snap = await _eventsCol.orderBy('date', descending: false).get();
    return snap.docs.map((d) => EventFirestore.fromFirestore(d)).toList();
  }

  static Stream<List<Event>> getAllEventsStream() {
    return _eventsCol
        .orderBy('date', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => EventFirestore.fromFirestore(d)).toList());
  }

  static Future<List<Event>> getEventsByOrganizer(String organizerId) async {
    final snap = await _eventsCol
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('date', descending: false)
        .get();
    return snap.docs.map((d) => EventFirestore.fromFirestore(d)).toList();
  }

  static Stream<List<Event>> getEventsByOrganizerStream(String organizerId) {
    return _eventsCol
        .where('organizerId', isEqualTo: organizerId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => EventFirestore.fromFirestore(d)).toList());
  }

  static Future<List<Event>> getUserEvents(String userId) async {
    final snap = await _eventsCol.where('participants', arrayContains: userId).get();
    return snap.docs.map((d) => EventFirestore.fromFirestore(d)).toList();
  }

  static Stream<List<Event>> getUserEventsStream(String userId) {
    return _eventsCol
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => EventFirestore.fromFirestore(d)).toList());
  }

  static Future<List<Event>> searchEvents(String query) async {
    // Simple search over title/category; Firestore requires indexing for complex queries
    final snap = await _eventsCol.get();
    final q = query.toLowerCase();
    return snap.docs
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
    return snap.docs.map((d) => EventFirestore.fromFirestore(d)).toList();
  }

  // Mutations
  static Future<bool> createEvent(Event event) async {
    try {
      await _eventsCol.doc(event.id).set(event.toFirestore());
      return true;
    } catch (e) {
      return false;
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
      await _eventsCol.doc(eventId).delete();
      return true;
    } catch (e) {
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