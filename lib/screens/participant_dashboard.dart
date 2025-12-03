import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_details_screen.dart';
import 'welcome_screen.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/participant_registration_info.dart';
import '../models/meal_settings.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/firebase_settings_service.dart';
import '../widgets/event_card.dart';
import '../widgets/category_card.dart';
import '../utils/debouncer.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'participant_registration_form_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import '../services/theme_service.dart';

class ParticipantDashboard extends StatefulWidget {
  final String? userId;
  
  const ParticipantDashboard({super.key, this.userId});

  @override
  State<ParticipantDashboard> createState() => _ParticipantDashboardState();
}

class _ParticipantDashboardState extends State<ParticipantDashboard> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  late final Debouncer _searchDebouncer;
  
  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  List<Event> _myEvents = [];
  List<Event> _upcomingEvents = [];
  List<Event> _ongoingEvents = [];
  List<Event> _pastEvents = [];
  User? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = '';
  bool _hasPendingOrganizerRequest = false;
  bool _showPastOnly = false;
  MealSettings? _mealSettings;

  @override
  void initState() {
    super.initState();
    _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 500));
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadData();
  }

  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<List<Event>>? _myEventsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<MealSettings>? _mealSettingsSubscription;
  final Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown
  bool _notificationInitialLoadComplete = false;
  SharedPreferences? _notificationPrefs;
  DateTime? _lastNotificationSeenAt;
  String? _activeNotificationUserId;
  static const String _notificationPrefsKeyPrefix = 'participant_last_notification_seen_';

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    _eventsSubscription?.cancel();
    _myEventsSubscription?.cancel();
    _notificationSubscription?.cancel();
    _mealSettingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Initialize FCM token and subscribe to notifications
    try {
      final token = await FirebaseNotificationService.getToken();
      if (token != null) {
        // Get user first to save token
        User? tempUser;
        if (widget.userId != null) {
          tempUser = await FirebaseUserService.getUserById(widget.userId!);
        } else {
          tempUser = await FirebaseUserService.getCurrentUserWithDetails();
        }
        if (tempUser != null) {
          await FirebaseNotificationService.saveFCMToken(tempUser.id, token);
          await FirebaseNotificationService.subscribeToTopic('new_events');
        }
      }
    } catch (e) {
      print('Error setting up notifications: $e');
    }
    
    try {
      User? user;
      
      // If userId is provided, fetch user details
      if (widget.userId != null) {
        user = await FirebaseUserService.getUserById(widget.userId!);
      } else {
        user = await FirebaseUserService.getCurrentUserWithDetails();
      }
      
      // Determine user ID for events - prioritize widget.userId since it's from auth
      final userId = _resolveUserId(user);
      await _ensureNotificationPrefsLoaded(userId);
      
      print('Setting up streams for userId: $userId');
      
      // Use real-time stream for all events
      _eventsSubscription?.cancel();
      _eventsSubscription = FirebaseEventService.getAllEventsStream().listen(
        (events) {
          if (mounted) {
            print('All events stream updated: ${events.length} events');
            setState(() {
              _allEvents = events;
              // Apply category filter if one is selected
              final filtered = _selectedCategory.isEmpty 
                  ? events 
                  : events.where((e) => e.category == _selectedCategory).toList();
              _filteredEvents = filtered;
              _categorizeEvents(filtered);
            });
          }
        },
        onError: (error) {
          print('Error in all events stream: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading events: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // Use real-time stream for user's registered events
      _myEventsSubscription?.cancel();
      _myEventsSubscription = FirebaseEventService.getUserEventsStream(userId).listen(
        (myEvents) {
          if (mounted) {
            print('My events stream updated: ${myEvents.length} events for userId: $userId');
            print('Event IDs: ${myEvents.map((e) => e.id).toList()}');
            setState(() {
              _myEvents = myEvents;
            });
          }
        },
        onError: (error) {
          print('Error in my events stream: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading your events: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
      
      // Check if user has pending organizer request
      bool hasPendingRequest = false;
      if (user != null) {
        hasPendingRequest = await FirebaseUserService.hasPendingOrganizerRequest(user.id);
      }
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
        _hasPendingOrganizerRequest = hasPendingRequest;
      });
      // Load meal settings initially
      try {
        final initialMealSettings = await FirebaseSettingsService.getMealSettings();
        if (mounted) {
          setState(() {
            _mealSettings = initialMealSettings;
          });
        }
      } catch (e) {
        print('Error loading initial meal settings: $e');
      }
      
      _setupMealSettingsListener();
      
      // Set up listener for new event notifications
      _setupNotificationListener(userId);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _resolveUserId(User? user) {
    if (widget.userId != null) {
      return widget.userId!;
    }
    if (user != null) {
      return user.id;
    }
    return 'guest_participant';
  }

  Future<void> _ensureNotificationPrefsLoaded(String userId) async {
    _notificationPrefs ??= await SharedPreferences.getInstance();
    _activeNotificationUserId = userId;
    final stored = _notificationPrefs!.getString('$_notificationPrefsKeyPrefix$userId');
    if (stored != null) {
      _lastNotificationSeenAt = DateTime.tryParse(stored);
    }
  }

  Future<void> _updateLastNotificationSeen(DateTime? createdAt) async {
    final userId = _activeNotificationUserId;
    if (userId == null) return;
    final timestamp = createdAt ?? DateTime.now();
    if (_lastNotificationSeenAt == null || timestamp.isAfter(_lastNotificationSeenAt!)) {
      _lastNotificationSeenAt = timestamp;
      _notificationPrefs ??= await SharedPreferences.getInstance();
      await _notificationPrefs!.setString(
        '$_notificationPrefsKeyPrefix$userId',
        _lastNotificationSeenAt!.toIso8601String(),
      );
    }
  }
  
  // Set up listener for notifications from Firestore
  void _setupNotificationListener(String userId) {
    try {
      print('Setting up notification listener for participant...');
      final notificationsCol = FirebaseFirestore.instance.collection('notifications');
      _notificationSubscription?.cancel();
      _notificationInitialLoadComplete = false;
      
      _notificationSubscription = notificationsCol
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        print('Notification listener triggered: ${snapshot.docs.length} unread notifications');
        
        if (!_notificationInitialLoadComplete) {
          for (var doc in snapshot.docs) {
            _shownNotificationIds.add(doc.id);
          }
          _notificationInitialLoadComplete = true;
          print('Notification listener bootstrap complete - existing notifications skipped');
          return;
        }
        
        if (!mounted) {
          print('Widget not mounted, skipping notification processing');
          return;
        }
        
        final newNotifications = snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .map((change) => change.doc)
            .where((doc) => !_shownNotificationIds.contains(doc.id))
            .toList();
        
        if (newNotifications.isEmpty) {
          print('No new notification changes detected');
          return;
        }
        
        for (var doc in newNotifications) {
          final notificationId = doc.id;
            final data = doc.data();
          if (data == null) {
            print('Notification $notificationId has no data, skipping');
            continue;
          }
            
              final createdAtStr = data['createdAt'] as String?;
          final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
          if (_lastNotificationSeenAt != null &&
              createdAt != null &&
              !createdAt.isAfter(_lastNotificationSeenAt!)) {
            print('Notification $notificationId is older than last seen, skipping');
                  _shownNotificationIds.add(notificationId);
                  continue;
            }
            
            final type = data['type'] as String?;
            final eventTitle = data['eventTitle'] as String? ?? 'Event';
            final eventId = data['eventId'] as String? ?? '';
            final category = data['category'] as String? ?? '';
            
            print('Processing notification: type=$type, eventTitle=$eventTitle, eventId=$eventId');
            
            String title;
            String body;
            
            switch (type) {
              case 'new_event':
                title = 'New Event Available!';
                body = '$eventTitle - $category';
                break;
              case 'event_reminder':
                title = 'Event Reminder';
                body = '$eventTitle is happening soon!';
                break;
              case 'event_update':
                title = 'Event Update: $eventTitle';
                body = data['updateMessage'] as String? ?? 'Event has been updated';
                break;
              case 'event_registration':
                title = 'Registration Confirmed';
                body = 'You have successfully registered for $eventTitle';
                break;
              default:
                title = 'EventBridge';
                body = data['body'] as String? ?? 'You have a new notification';
            }
            
            print('Showing system notification: $title - $body');
            
            FirebaseNotificationService.showLocalNotification(
              title: title,
              body: body,
              payload: 'event:$eventId',
            );
            
            _shownNotificationIds.add(notificationId);
            print('Notification marked as shown: $notificationId');
          _updateLastNotificationSeen(createdAt);
            
              _refreshData();
        }
      }, onError: (error) {
        print('Error in notification listener: $error');
        _setupNotificationListenerFallback(userId);
      });
      print('Notification listener set up successfully');
    } catch (e, stackTrace) {
      print('Error setting up notification listener: $e');
      print('Stack trace: $stackTrace');
      _setupNotificationListenerFallback(userId);
    }
  }
  
  void _setupNotificationListenerFallback(String userId) {
    try {
      print('Setting up fallback notification listener (without orderBy)...');
      final notificationsCol = FirebaseFirestore.instance.collection('notifications');
      _notificationSubscription?.cancel();
      _notificationInitialLoadComplete = false;
      
      _notificationSubscription = notificationsCol
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        print('Fallback notification listener triggered: ${snapshot.docs.length} unread notifications');
        
        if (!_notificationInitialLoadComplete) {
          for (var doc in snapshot.docs) {
            _shownNotificationIds.add(doc.id);
          }
          _notificationInitialLoadComplete = true;
          print('Fallback listener bootstrap complete - existing notifications skipped');
          return;
        }
        
        if (!mounted) {
          print('Widget not mounted, skipping fallback notification processing');
          return;
        }
        
        final newNotifications = snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .map((change) => change.doc)
            .where((doc) => !_shownNotificationIds.contains(doc.id))
            .toList();
        
        if (newNotifications.isEmpty) {
          print('No new fallback notification changes detected');
          return;
        }
        
        for (var doc in newNotifications) {
          final notificationId = doc.id;
            final data = doc.data();
          if (data == null) {
            print('Fallback notification $notificationId has no data, skipping');
            continue;
          }
            
              final createdAtStr = data['createdAt'] as String?;
          final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
          if (_lastNotificationSeenAt != null &&
              createdAt != null &&
              !createdAt.isAfter(_lastNotificationSeenAt!)) {
                  _shownNotificationIds.add(notificationId);
                  continue;
            }
            
            final type = data['type'] as String?;
            final eventTitle = data['eventTitle'] as String? ?? 'Event';
            final eventId = data['eventId'] as String? ?? '';
            final category = data['category'] as String? ?? '';
            
            String title;
            String body;
            
            switch (type) {
              case 'new_event':
                title = 'New Event Available!';
                body = '$eventTitle - $category';
                break;
              case 'event_reminder':
                title = 'Event Reminder';
                body = '$eventTitle is happening soon!';
                break;
              case 'event_update':
                title = 'Event Update: $eventTitle';
                body = data['updateMessage'] as String? ?? 'Event has been updated';
                break;
              case 'event_registration':
                title = 'Registration Confirmed';
                body = 'You have successfully registered for $eventTitle';
                break;
              default:
                title = 'EventBridge';
                body = data['body'] as String? ?? 'You have a new notification';
            }
            
            print('Showing system notification (fallback): $title - $body');
            
            FirebaseNotificationService.showLocalNotification(
              title: title,
              body: body,
              payload: 'event:$eventId',
            );
            
            _shownNotificationIds.add(notificationId);
          _updateLastNotificationSeen(createdAt);
              _refreshData();
        }
      }, onError: (error) {
        print('Error in notification listener (fallback): $error');
      });
      print('Fallback notification listener set up successfully');
    } catch (e2, stackTrace) {
      print('Error in fallback notification listener: $e2');
      print('Stack trace: $stackTrace');
    }
  }

  void _setupMealSettingsListener() {
    _mealSettingsSubscription?.cancel();
    _mealSettingsSubscription = FirebaseSettingsService.mealSettingsStream().listen(
      (settings) {
        if (mounted) {
          setState(() {
            _mealSettings = settings;
          });
        }
      },
      onError: (error) => print('Error listening to meal settings: $error'),
    );
  }

  Future<void> _searchEvents(String query) async {
    if (query.isEmpty) {
      // Reset to show all events with category filter applied
      final filtered = _selectedCategory.isEmpty 
          ? _allEvents 
          : _allEvents.where((e) => e.category == _selectedCategory).toList();
      setState(() {
      _showPastOnly = false;
        _filteredEvents = filtered;
        _categorizeEvents(filtered);
      });
      return;
    }
    
    // Perform search
    final results = await FirebaseEventService.searchEvents(query);
    
    // Apply category filter if one is selected
    final filteredResults = _selectedCategory.isEmpty 
        ? results 
        : results.where((e) => e.category == _selectedCategory).toList();
    
    setState(() {
    _showPastOnly = false;
      _filteredEvents = filteredResults;
      // Also categorize search results
      _categorizeEvents(filteredResults);
    });
  }

  Future<void> _filterByCategory(String category) async {
    setState(() => _selectedCategory = category);
    
    // Filter events based on category
    List<Event> eventsToCategorize;
    if (category.isEmpty) {
      eventsToCategorize = _allEvents;
    setState(() {
      _showPastOnly = false;
      _filteredEvents = _allEvents;
    });
    } else {
      // Filter from all events by category (client-side filtering is faster)
      eventsToCategorize = _allEvents.where((e) => e.category == category).toList();
    setState(() {
      _showPastOnly = false;
      _filteredEvents = eventsToCategorize;
    });
    }
    
    // Re-categorize the filtered events
    _categorizeEvents(eventsToCategorize);
  }

  void _categorizeEvents(List<Event> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    _upcomingEvents = events.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAfter(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    _ongoingEvents = events.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    _pastEvents = events.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isBefore(today);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort past events descending (most recent first)
  }

  Future<void> _refreshData() async {
    await _loadData();
    // Also check for pending organizer request status
    if (_currentUser != null) {
      final hasPending = await FirebaseUserService.hasPendingOrganizerRequest(_currentUser!.id);
      if (mounted) {
        setState(() {
          _hasPendingOrganizerRequest = hasPending;
        });
      }
    }
  }

  // Check if current user is a guest
  bool _isGuestUser() {
    // If no userId was passed from auth screen, user is a guest
    if (widget.userId == null) {
      return true;
    }
    // If current user exists and is a guest user
    if (_currentUser != null) {
      return _currentUser!.email == 'guest@eventbridge.com' || 
             _currentUser!.id.startsWith('guest_');
    }
    return false;
  }

  Future<void> _registerForEvent(Event event) async {
    // Prevent guest users from registering
    if (_isGuestUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in or sign up to register for events.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WelcomeScreen(),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    // Ensure we have a valid logged-in user
    if (_currentUser == null && widget.userId != null) {
      // Try to load user
      final user = await FirebaseUserService.getUserById(widget.userId!);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to register for events.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentUser = user);
    }

    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to register for events.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent admins from registering for events
    if (_currentUser!.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admins cannot register for events. Admins can only manage and view events.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Use widget.userId if available, otherwise use currentUser.id
    String userId;
    if (widget.userId != null) {
      userId = widget.userId!;
    } else {
      userId = _currentUser!.id;
    }
    
    print('Registering for event: ${event.id} with userId: $userId');
    
    final alreadyRegistered = event.participants.contains(userId);
    if (alreadyRegistered) {
      print('User already registered for this event');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already registered for this event.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      _navigateToEventDetails(event);
      return;
    }

    // Check if event date has passed - participants cannot register for past events
    if (event.isEventDatePassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot register for a past event.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (event.isRegistrationClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is closed for this event.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (event.participants.length >= event.maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event has reached its participant limit.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if participant information is required
    final hasRequiredFields = event.requireLevel ||
        event.requireTerm ||
        event.requireBatch ||
        event.requireSection ||
        event.requireTshirtSize ||
        event.requireFood ||
        event.requireHall ||
        event.requireGender ||
        event.requirePersonalNumber ||
        event.requireGuardianNumber;
    
    ParticipantRegistrationInfo? registrationInfo;
    if (hasRequiredFields) {
      // Check if info already exists
      final existingInfo = await FirebaseEventService.getParticipantRegistrationInfo(
        event.id,
        userId,
      );
      
      // Show form to collect/update participant info
      registrationInfo = await Navigator.push<ParticipantRegistrationInfo>(
        context,
        MaterialPageRoute(
          builder: (context) => ParticipantRegistrationFormScreen(
            event: event,
            userId: userId,
            existingInfo: existingInfo,
          ),
        ),
      );
      
      if (registrationInfo == null) {
        // User cancelled the form
        return;
      }
      
      // Save participant registration info
      await FirebaseEventService.saveParticipantRegistrationInfo(registrationInfo);
    }

    final result = await FirebaseEventService.registerForEvent(event.id, userId);
    print('Registration result: ${result.status} message: ${result.message}');
    
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // The stream should automatically update _myEvents, but we can also manually refresh
      // Wait a moment for Firestore to propagate the change
      await Future.delayed(const Duration(milliseconds: 500));
      // Navigate to event details - the stream will update the list automatically
      final updated = _allEvents.where((e) => e.id == event.id).firstOrNull ?? event;
      _navigateToEventDetails(updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? _mapRegistrationStatusToMessage(result.status)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  String _mapRegistrationStatusToMessage(RegistrationStatus status) {
    switch (status) {
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
        return 'Registration failed. Please try again.';
    }
  }

  Widget _buildMealStatusBanner() {
    final settings = _mealSettings;
    if (settings == null) {
      return const SizedBox.shrink();
    }
    
    final isEnabled = settings.isMealEnabled;
    final isAvailable = settings.isMealCurrentlyAvailable;
    final closeTime = settings.closeTime;
    final timeRemaining = settings.timeUntilClose;

    Color background;
    Color accent;
    IconData icon;
    String title;
    String subtitle;

    if (!isEnabled) {
      background = Colors.red.shade50;
      accent = Colors.red.shade400;
      icon = Icons.no_meals;
      title = 'Meal service is turned off';
      subtitle = 'Meal service is disabled for today.';
    } else if (isAvailable) {
      background = Colors.green.shade50;
      accent = Colors.green.shade600;
      icon = Icons.restaurant;
      title = 'Meal service is OPEN';
      subtitle = closeTime == null
          ? 'Enjoy your meal. Closing time not set.'
          : 'Closes at ${DateFormat('h:mm a').format(closeTime)}';
    } else {
      background = Colors.orange.shade50;
      accent = Colors.orange.shade700;
      icon = Icons.restaurant_menu;
      title = 'Meal service is CLOSED';
      subtitle = closeTime == null
          ? 'Meal service closed for today.'
          : 'Closed after ${DateFormat('h:mm a').format(closeTime)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: accent.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                if (isAvailable && timeRemaining != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Closes in ${_formatDuration(timeRemaining)}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return '$minutes min';
    }
    return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Show confirmation dialog before exiting
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true && mounted) {
          // Exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('EventBridge'),
          actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(userId: widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userId: _currentUser?.id ?? widget.userId,
                  ),
                ),
              );
              if (updated == true) {
                _refreshData();
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          _buildSearchScreen(),
          _buildMyEventsScreen(),
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: Colors.grey[600],
          selectedFontSize: 13,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          elevation: 8,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 26),
              activeIcon: Icon(Icons.home, size: 26),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search, size: 26),
              activeIcon: Icon(Icons.search, size: 26),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_outlined, size: 26),
              activeIcon: Icon(Icons.event, size: 26),
              label: 'My Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 26),
              activeIcon: Icon(Icons.person, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if there's an active search query
    final hasSearchQuery = _searchController.text.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Builder(
              builder: (context) {
                final themeService = ThemeService.instance ?? ThemeService();
                final isDark = themeService.isDarkMode;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: Colors.grey[700]!, width: 1) : null,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchEvents,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      suffixIcon: hasSearchQuery
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchEvents('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Pending Organizer Request Banner
            if (_hasPendingOrganizerRequest)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: Colors.blue.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Organizer Request Pending',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your request to become an organizer is being reviewed by an admin. You will be notified once approved.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 8),
            
            if (_mealSettings != null) ...[
              _buildMealStatusBanner(),
              const SizedBox(height: 16),
            ],
            
            // Show search results if searching
            if (hasSearchQuery) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Results (${_filteredEvents.length})',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _searchEvents('');
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_filteredEvents.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No events found. Try different keywords.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else
                ..._filteredEvents.map((event) {
                  String? userId;
                  if (widget.userId != null) {
                    userId = widget.userId;
                  } else if (_currentUser != null) {
                    userId = _currentUser!.id;
                  }
                  final isRegistered = userId != null && event.participants.contains(userId);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EventCard(
                      title: event.title,
                      description: event.description,
                      date: DateFormat('MMM d, y').format(event.date),
                      time: event.time,
                      location: event.location,
                      icon: _getCategoryIcon(event.category),
                      color: _getCategoryColor(event.category),
                      onTap: () => _navigateToEventDetails(event),
                      onRegister: () => _registerForEvent(event),
                      isRegistered: isRegistered,
                      imageUrl: event.imageUrl,
                      registrationClosed: event.isRegistrationClosed || event.isEventDatePassed,
                      hostName: event.hostName,
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
            
            // Only show categories and categorized events if not searching
            if (!hasSearchQuery) ...[
              // Categories
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  CategoryCard(
                    title: 'All',
                    icon: Icons.apps,
                    color: _selectedCategory.isEmpty ? const Color(0xFF1976D2) : Colors.grey,
                    onTap: () => _filterByCategory(''),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Seminars',
                    icon: Icons.school,
                    color: _selectedCategory == 'Seminars' ? const Color(0xFF1976D2) : Colors.blue,
                    onTap: () => _filterByCategory('Seminars'),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Workshops',
                    icon: Icons.build,
                    color: _selectedCategory == 'Workshops' ? const Color(0xFF1976D2) : Colors.green,
                    onTap: () => _filterByCategory('Workshops'),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Cultural',
                    icon: Icons.palette,
                    color: _selectedCategory == 'Cultural' ? const Color(0xFF1976D2) : Colors.orange,
                    onTap: () => _filterByCategory('Cultural'),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Competitions',
                    icon: Icons.emoji_events,
                    color: _selectedCategory == 'Competitions' ? const Color(0xFF1976D2) : Colors.purple,
                    onTap: () => _filterByCategory('Competitions'),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Rag Day',
                    icon: Icons.celebration,
                    color: _selectedCategory == 'Rag Day' ? const Color(0xFF1976D2) : Colors.pink,
                    onTap: () => _filterByCategory('Rag Day'),
                  ),
                  const SizedBox(width: 12),
                  CategoryCard(
                    title: 'Picnic',
                    icon: Icons.park,
                    color: _selectedCategory == 'Picnic' ? const Color(0xFF1976D2) : Colors.teal,
                    onTap: () => _filterByCategory('Picnic'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming Events Section
            if (_upcomingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${_upcomingEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._upcomingEvents.take(5).map((event) {
                String? userId;
                if (widget.userId != null) {
                  userId = widget.userId;
                } else if (_currentUser != null) {
                  userId = _currentUser!.id;
                }
                final isRegistered = userId != null && event.participants.contains(userId);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventCard(
                    title: event.title,
                    description: event.description,
                    date: DateFormat('MMM d, y').format(event.date),
                    time: event.time,
                    location: event.location,
                    icon: _getCategoryIcon(event.category),
                    color: _getCategoryColor(event.category),
                    onTap: () => _navigateToEventDetails(event),
                    onRegister: null,
                    isRegistered: isRegistered,
                    imageUrl: event.imageUrl,
                    hostName: event.hostName,
                  ),
                );
              }),
              if (_upcomingEvents.length > 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _selectedIndex = 1); // Switch to search tab
                    },
                    child: const Text('View All Upcoming Events'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            
            // Ongoing Events Section
            if (_ongoingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ongoing Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${_ongoingEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._ongoingEvents.take(5).map((event) {
                String? userId;
                if (widget.userId != null) {
                  userId = widget.userId;
                } else if (_currentUser != null) {
                  userId = _currentUser!.id;
                }
                final isRegistered = userId != null && event.participants.contains(userId);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventCard(
                    title: event.title,
                    description: event.description,
                    date: DateFormat('MMM d, y').format(event.date),
                    time: event.time,
                    location: event.location,
                    icon: _getCategoryIcon(event.category),
                    color: _getCategoryColor(event.category),
                    onTap: () => _navigateToEventDetails(event),
                    onRegister: () => _registerForEvent(event),
                    isRegistered: isRegistered,
                    imageUrl: event.imageUrl,
                    registrationClosed: event.isRegistrationClosed || event.isEventDatePassed,
                    hostName: event.hostName,
                  ),
                );
              }),
              if (_ongoingEvents.length > 5)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _selectedIndex = 1); // Switch to search tab
                    },
                    child: const Text('View All Ongoing Events'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
            
            // Past Events Section
            if (_pastEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Past Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${_pastEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._pastEvents.take(3).map((event) {
                String? userId;
                if (widget.userId != null) {
                  userId = widget.userId;
                } else if (_currentUser != null) {
                  userId = _currentUser!.id;
                }
                final isRegistered = userId != null && event.participants.contains(userId);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventCard(
                    title: event.title,
                    description: event.description,
                    date: DateFormat('MMM d, y').format(event.date),
                    time: event.time,
                    location: event.location,
                    icon: _getCategoryIcon(event.category),
                    color: _getCategoryColor(event.category),
                    onTap: () => _navigateToEventDetails(event),
                    onRegister: null,
                    isRegistered: isRegistered,
                    imageUrl: event.imageUrl,
                    registrationClosed: event.isRegistrationClosed,
                    hostName: event.hostName,
                  ),
                );
              }),
              if (_pastEvents.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _selectedCategory = '';
                        _filteredEvents = _allEvents;
                        _showPastOnly = true;
                        _selectedIndex = 1; // Switch to search tab
                      });
                    },
                    child: const Text('View All Past Events'),
                  ),
                ),
            ],
            ],
            
            // Show message if no events (only when not searching)
            if (!hasSearchQuery && _upcomingEvents.isEmpty && _ongoingEvents.isEmpty && _pastEvents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No events found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchScreen() {
    // Check if there's an active search query
    final hasSearchQuery = _searchController.text.isNotEmpty;
    final hasCategoryFilter = _selectedCategory.isNotEmpty;
    List<Event> displayEvents;
    if (_showPastOnly) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      displayEvents = _allEvents
          .where((event) {
            final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
            return eventDate.isBefore(today);
          })
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } else if (hasSearchQuery || hasCategoryFilter) {
      displayEvents = _filteredEvents;
    } else {
      displayEvents = _allEvents;
    }
    
    final headerText = _showPastOnly
        ? 'Past Events (${displayEvents.length})'
        : hasSearchQuery
            ? 'Search Results (${displayEvents.length})'
            : hasCategoryFilter
                ? '${_selectedCategory[0].toUpperCase()}${_selectedCategory.substring(1)} Events (${displayEvents.length})'
                : 'All Events (${displayEvents.length})';
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Builder(
              builder: (context) {
                final themeService = ThemeService.instance ?? ThemeService();
                final isDark = themeService.isDarkMode;
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: isDark ? Border.all(color: Colors.grey[700]!, width: 1) : null,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _searchDebouncer.call(() {
                        _searchEvents(value);
                      });
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search events by name, category, or keyword...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  headerText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                );
              },
            ),
            if (_showPastOnly)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPastOnly = false;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Show All Events'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: displayEvents.isEmpty
                  ? Center(
                      child: Text(
                        hasSearchQuery
                            ? 'No events found. Try searching with different keywords.'
                            : 'No events available.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      cacheExtent: 500, // Cache more items for smoother scrolling
                      itemCount: displayEvents.length,
                      itemBuilder: (context, index) {
                        final event = displayEvents[index];
                        // Check if user is registered for this event
                        String? userId;
                        if (widget.userId != null) {
                          userId = widget.userId;
                        } else if (_currentUser != null) {
                          userId = _currentUser!.id;
                        }
                        final isRegistered = userId != null && event.participants.contains(userId);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EventCard(
                            title: event.title,
                            description: event.description,
                            date: DateFormat('MMM d, y').format(event.date),
                            time: event.time,
                            location: event.location,
                            icon: _getCategoryIcon(event.category),
                            color: _getCategoryColor(event.category),
                            onTap: () => _navigateToEventDetails(event),
                            onRegister: _showPastOnly ? null : () => _registerForEvent(event),
                            isRegistered: isRegistered,
                            imageUrl: event.imageUrl,
                            registrationClosed: event.isRegistrationClosed || event.isEventDatePassed,
                            hostName: event.hostName,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyEventsScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Categorize my events
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final myUpcomingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAfter(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final myOngoingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final myPastEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isBefore(today);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Registered Events',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_myEvents.length} ${_myEvents.length == 1 ? 'event' : 'events'} registered',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // Upcoming Events
            if (myUpcomingEvents.isNotEmpty) ...[
              _buildSectionHeader('Upcoming', myUpcomingEvents.length, Colors.blue),
              const SizedBox(height: 16),
              ...myUpcomingEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  onTap: () => _navigateToEventDetails(event),
                ),
              )),
              const SizedBox(height: 28),
            ],
            
            // Ongoing Events
            if (myOngoingEvents.isNotEmpty) ...[
              _buildSectionHeader('Ongoing', myOngoingEvents.length, Colors.green),
              const SizedBox(height: 16),
              ...myOngoingEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  onTap: () => _navigateToEventDetails(event),
                ),
              )),
              const SizedBox(height: 28),
            ],
            
            // Past Events
            if (myPastEvents.isNotEmpty) ...[
              _buildSectionHeader('Past', myPastEvents.length, Colors.grey[600]!),
              const SizedBox(height: 16),
              ...myPastEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  onTap: () => _navigateToEventDetails(event),
                ),
              )),
            ],
            
            // Empty state
            if (_myEvents.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 60),
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Registered Events',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Browse events and register to see them here',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Profile Picture with border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1976D2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1976D2).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                    backgroundImage: _currentUser?.profileImageUrl != null
                        ? NetworkImage(_currentUser!.profileImageUrl!)
                        : null,
                    child: _currentUser?.profileImageUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFF1976D2),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _currentUser?.name ?? 'User',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (_currentUser?.email != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email_outlined, 
                        size: 16, 
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentUser!.email!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                if (_currentUser?.universityId != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined, 
                        size: 16, 
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ID: ${_currentUser!.universityId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Profile Options Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildProfileOption(
                  'Edit Profile',
                  Icons.edit_outlined,
                  const Color(0xFF1976D2),
                  () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(
                          userId: _currentUser?.id ?? widget.userId,
                        ),
                      ),
                    );
                    if (updated == true) {
                      _refreshData();
                    }
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  'Notifications',
                  Icons.notifications_outlined,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationsScreen(userId: widget.userId),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  'Settings',
                  Icons.settings_outlined,
                  Colors.grey[700]!,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),
                _buildProfileOption(
                  'Help & Support',
                  Icons.help_outline,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  // Sign out from Firebase Auth
                  await FirebaseUserService.signOut();
                  // Clear user state
                  setState(() => _currentUser = null);
                  // Navigate to welcome screen
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: Colors.grey[300],
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(
    String title,
    String description,
    String date,
    String time,
    String location,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$date • $time',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyEventCard(
    String title,
    String dateTime,
    String location,
    String status,
    Color statusColor, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.access_time, 
                      size: 16, 
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateTime,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.location_on, 
                      size: 16, 
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption(String title, IconData icon, Color iconColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }


  // Helper methods
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'seminars':
        return Icons.school;
      case 'workshops':
        return Icons.build;
      case 'cultural':
        return Icons.palette;
      case 'competitions':
        return Icons.emoji_events;
      case 'rag day':
        return Icons.celebration;
      case 'picnic':
        return Icons.park;
      default:
        return Icons.event;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'seminars':
        return Colors.blue;
      case 'workshops':
        return Colors.green;
      case 'cultural':
        return Colors.orange;
      case 'competitions':
        return Colors.purple;
      case 'rag day':
        return Colors.pink;
      case 'picnic':
        return Colors.teal;
      default:
        return const Color(0xFF1976D2);
    }
  }

  void _navigateToEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
          event: event,
          isOrganizer: false,
          userId: widget.userId,
        ),
      ),
    ).then((_) => _refreshData());
  }


  String _getStatusText(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return 'Draft';
      case EventStatus.published:
        return 'Published';
      case EventStatus.active:
        return 'Active';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.draft:
        return Colors.grey;
      case EventStatus.published:
        return Colors.blue;
      case EventStatus.active:
        return Colors.green;
      case EventStatus.completed:
        return Colors.orange;
      case EventStatus.cancelled:
        return Colors.red;
    }
  }
}
