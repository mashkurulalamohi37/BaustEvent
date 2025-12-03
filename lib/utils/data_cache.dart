import '../models/user.dart';
import '../models/event.dart';

/// Simple in-memory cache for frequently accessed data
/// Helps reduce database queries and improve performance
class DataCache {
  static final DataCache _instance = DataCache._internal();
  factory DataCache() => _instance;
  DataCache._internal();

  // Cache for users (key: userId, value: User)
  final Map<String, User> _userCache = {};
  DateTime? _userCacheTimestamp;
  static const _cacheExpiryMinutes = 5;

  // Cache for user lists
  List<User>? _allUsersCache;
  DateTime? _allUsersCacheTimestamp;

  // Cache for events (key: eventId, value: Event)
  final Map<String, Event> _eventCache = {};
  DateTime? _eventCacheTimestamp;

  // Cache for event lists
  List<Event>? _allEventsCache;
  DateTime? _allEventsCacheTimestamp;

  /// Get user from cache
  User? getUser(String userId) {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    return null;
  }

  /// Store user in cache
  void cacheUser(User user) {
    _userCache[user.id] = user;
    _userCacheTimestamp = DateTime.now();
  }

  /// Store multiple users in cache
  void cacheUsers(List<User> users) {
    for (var user in users) {
      _userCache[user.id] = user;
    }
    _userCacheTimestamp = DateTime.now();
  }

  /// Get all users from cache
  List<User>? getAllUsers() {
    if (_allUsersCache != null && _allUsersCacheTimestamp != null) {
      final age = DateTime.now().difference(_allUsersCacheTimestamp!);
      if (age.inMinutes < _cacheExpiryMinutes) {
        return _allUsersCache;
      }
    }
    return null;
  }

  /// Cache all users
  void cacheAllUsers(List<User> users) {
    _allUsersCache = users;
    _allUsersCacheTimestamp = DateTime.now();
    // Also update individual user cache
    cacheUsers(users);
  }

  /// Clear user cache
  void clearUserCache() {
    _userCache.clear();
    _allUsersCache = null;
    _userCacheTimestamp = null;
    _allUsersCacheTimestamp = null;
  }

  /// Clear expired cache entries
  void clearExpiredCache() {
    if (_userCacheTimestamp != null) {
      final age = DateTime.now().difference(_userCacheTimestamp!);
      if (age.inMinutes >= _cacheExpiryMinutes) {
        _userCache.clear();
        _userCacheTimestamp = null;
      }
    }

    if (_allUsersCacheTimestamp != null) {
      final age = DateTime.now().difference(_allUsersCacheTimestamp!);
      if (age.inMinutes >= _cacheExpiryMinutes) {
        _allUsersCache = null;
        _allUsersCacheTimestamp = null;
      }
    }
  }

  /// Get event from cache
  Event? getEvent(String eventId) {
    if (_eventCache.containsKey(eventId)) {
      return _eventCache[eventId];
    }
    return null;
  }

  /// Store event in cache
  void cacheEvent(Event event) {
    _eventCache[event.id] = event;
    _eventCacheTimestamp = DateTime.now();
  }

  /// Store multiple events in cache
  void cacheEvents(List<Event> events) {
    for (var event in events) {
      _eventCache[event.id] = event;
    }
    _eventCacheTimestamp = DateTime.now();
  }

  /// Get all events from cache
  List<Event>? getAllEvents() {
    if (_allEventsCache != null && _allEventsCacheTimestamp != null) {
      final age = DateTime.now().difference(_allEventsCacheTimestamp!);
      if (age.inMinutes < _cacheExpiryMinutes) {
        return _allEventsCache;
      }
    }
    return null;
  }

  /// Cache all events
  void cacheAllEvents(List<Event> events) {
    _allEventsCache = events;
    _allEventsCacheTimestamp = DateTime.now();
    // Also update individual event cache
    cacheEvents(events);
  }

  /// Clear event cache
  void clearEventCache() {
    _eventCache.clear();
    _allEventsCache = null;
    _eventCacheTimestamp = null;
    _allEventsCacheTimestamp = null;
  }

  /// Get cache size (for debugging)
  int getCacheSize() {
    return _userCache.length + _eventCache.length;
  }
}

