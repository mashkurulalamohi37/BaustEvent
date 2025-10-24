import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';

class EventService {
  static const String _eventsKey = 'events';
  static const String _userEventsKey = 'user_events';
  
  // Get all events
  static Future<List<Event>> getAllEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getStringList(_eventsKey) ?? [];
    return eventsJson.map((json) => Event.fromJson(jsonDecode(json))).toList();
  }
  
  // Get events by organizer
  static Future<List<Event>> getEventsByOrganizer(String organizerId) async {
    final allEvents = await getAllEvents();
    return allEvents.where((event) => event.organizerId == organizerId).toList();
  }
  
  // Get events by category
  static Future<List<Event>> getEventsByCategory(String category) async {
    final allEvents = await getAllEvents();
    return allEvents.where((event) => event.category == category).toList();
  }
  
  // Search events
  static Future<List<Event>> searchEvents(String query) async {
    final allEvents = await getAllEvents();
    return allEvents.where((event) => 
      event.title.toLowerCase().contains(query.toLowerCase()) ||
      event.description.toLowerCase().contains(query.toLowerCase()) ||
      event.category.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  // Create event
  static Future<bool> createEvent(Event event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await getAllEvents();
      events.add(event);
      
      final eventsJson = events.map((e) => jsonEncode(e.toJson())).toList();
      return await prefs.setStringList(_eventsKey, eventsJson);
    } catch (e) {
      return false;
    }
  }
  
  // Update event
  static Future<bool> updateEvent(Event event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await getAllEvents();
      final index = events.indexWhere((e) => e.id == event.id);
      
      if (index != -1) {
        events[index] = event;
        final eventsJson = events.map((e) => jsonEncode(e.toJson())).toList();
        return await prefs.setStringList(_eventsKey, eventsJson);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Delete event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await getAllEvents();
      events.removeWhere((event) => event.id == eventId);
      
      final eventsJson = events.map((e) => jsonEncode(e.toJson())).toList();
      return await prefs.setStringList(_eventsKey, eventsJson);
    } catch (e) {
      return false;
    }
  }
  
  // Register for event
  static Future<bool> registerForEvent(String eventId, String userId) async {
    try {
      final events = await getAllEvents();
      final eventIndex = events.indexWhere((e) => e.id == eventId);
      
      if (eventIndex != -1) {
        final event = events[eventIndex];
        if (!event.participants.contains(userId) && 
            event.participants.length < event.maxParticipants) {
          final updatedEvent = event.copyWith(
            participants: [...event.participants, userId]
          );
          events[eventIndex] = updatedEvent;
          
          final prefs = await SharedPreferences.getInstance();
          final eventsJson = events.map((e) => jsonEncode(e.toJson())).toList();
          await prefs.setStringList(_eventsKey, eventsJson);
          
          // Add to user's registered events
          await _addUserEvent(userId, eventId);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Unregister from event
  static Future<bool> unregisterFromEvent(String eventId, String userId) async {
    try {
      final events = await getAllEvents();
      final eventIndex = events.indexWhere((e) => e.id == eventId);
      
      if (eventIndex != -1) {
        final event = events[eventIndex];
        final updatedParticipants = List<String>.from(event.participants);
        updatedParticipants.remove(userId);
        
        final updatedEvent = event.copyWith(participants: updatedParticipants);
        events[eventIndex] = updatedEvent;
        
        final prefs = await SharedPreferences.getInstance();
        final eventsJson = events.map((e) => jsonEncode(e.toJson())).toList();
        await prefs.setStringList(_eventsKey, eventsJson);
        
        // Remove from user's registered events
        await _removeUserEvent(userId, eventId);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // Get user's registered events
  static Future<List<Event>> getUserEvents(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEventsJson = prefs.getStringList('${_userEventsKey}_$userId') ?? [];
      final eventIds = userEventsJson.map((id) => id.toString()).toList();
      
      final allEvents = await getAllEvents();
      return allEvents.where((event) => eventIds.contains(event.id)).toList();
    } catch (e) {
      return [];
    }
  }
  
  // Helper methods
  static Future<void> _addUserEvent(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final userEvents = await getUserEventIds(userId);
    userEvents.add(eventId);
    await prefs.setStringList('${_userEventsKey}_$userId', userEvents);
  }
  
  static Future<void> _removeUserEvent(String userId, String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final userEvents = await getUserEventIds(userId);
    userEvents.remove(eventId);
    await prefs.setStringList('${_userEventsKey}_$userId', userEvents);
  }
  
  static Future<List<String>> getUserEventIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('${_userEventsKey}_$userId') ?? [];
  }

  // Remove known demo events authored by demo organizer or having demo participant
  static Future<void> removeDemoEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final events = await getAllEvents();
    final filtered = events.where((e) =>
      e.organizerId != 'organizer_1' &&
      !e.participants.contains('user_1')
    ).toList();
    final eventsJson = filtered.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_eventsKey, eventsJson);

    // Also clear user_events for demo ids
    await prefs.remove('${_userEventsKey}_user_1');
    await prefs.remove('${_userEventsKey}_organizer_1');
  }
}
