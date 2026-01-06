import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_details_screen.dart';
import 'welcome_screen.dart';
import 'create_event_screen.dart';
import 'edit_event_screen.dart';
import 'manage_participants_screen.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_notification_service.dart';
import 'edit_profile_screen.dart';
import 'analytics_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'polls_screen.dart';
import '../services/theme_service.dart';

class OrganizerDashboard extends StatefulWidget {
  final String? userId;
  
  const OrganizerDashboard({super.key, this.userId});

  @override
  State<OrganizerDashboard> createState() => _OrganizerDashboardState();
}

class _OrganizerDashboardState extends State<OrganizerDashboard> {
  int _selectedIndex = 0;
  
  List<Event> _myEvents = [];
  User? _currentUser;
  bool _isLoading = true;
  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown
  bool _notificationInitialLoadComplete = false;
  SharedPreferences? _notificationPrefs;
  DateTime? _lastNotificationSeenAt;
  String? _activeNotificationUserId;
  static const String _notificationPrefsKeyPrefix = 'organizer_last_notification_seen_';

  @override
  void initState() {
    super.initState();
    print('=== ORGANIZER DASHBOARD INITIALIZED ===');
    print('Widget userId: ${widget.userId}');
    _initializeData();
  }

  Future<void> _initializeData() async {
    print('Initializing organizer dashboard data...');
    await _loadData();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('_loadData() called');
    setState(() => _isLoading = true);
    
    try {
      User? user;
      
      // If userId is provided, fetch user details
      if (widget.userId != null) {
        print('Fetching user by ID: ${widget.userId}');
        user = await FirebaseUserService.getUserById(widget.userId!);
        print('User fetched: ${user?.id}, email: ${user?.email}');
      } else {
        print('Fetching current user');
        user = await FirebaseUserService.getCurrentUserWithDetails();
        print('Current user: ${user?.id}, email: ${user?.email}');
      }
      
      // Determine organizer ID
      String organizerId;
      if (user != null) {
        organizerId = user.id;
      } else if (widget.userId != null) {
        organizerId = widget.userId!;
      } else {
        organizerId = 'guest_organizer';
      }
      
      // Use real-time stream for organizer events
      print('=== LOADING ORGANIZER EVENTS ===');
      print('User ID: ${user?.id}');
      print('Widget userId: ${widget.userId}');
      print('Organizer ID being used: $organizerId');
      print('User email: ${user?.email}');
      print('User name: ${user?.name}');
      
      // Debug: Check all events to see what organizerIds exist
      try {
        print('Fetching ALL events from database...');
        final allEvents = await FirebaseEventService.getAllEvents();
        print('Total events in database: ${allEvents.length}');
        if (allEvents.isNotEmpty) {
          print('Sample organizerIds from all events:');
          final organizerIds = <String>{};
          for (var event in allEvents) {
            organizerIds.add(event.organizerId);
            if (organizerIds.length <= 5) {
              print('  Event "${event.title}": organizerId = "${event.organizerId}"');
            }
          }
          print('All unique organizerIds in database: ${organizerIds.toList()}');
          print('Looking for organizerId: "$organizerId"');
          if (!organizerIds.contains(organizerId)) {
            print('⚠️ WARNING: Your organizerId "$organizerId" does NOT match any events!');
            print('Available organizerIds: ${organizerIds.toList()}');
          }
        } else {
          print('⚠️ No events exist in the database at all!');
        }
      } catch (e) {
        print('Error checking all events: $e');
      }
      
      _eventsSubscription?.cancel();
      
      // Also fetch events immediately to avoid waiting for stream
      try {
        print('Fetching events for organizerId: "$organizerId"');
        final initialEvents = await FirebaseEventService.getEventsByOrganizer(organizerId);
        print('Initial events loaded: ${initialEvents.length} events');
        if (initialEvents.isNotEmpty) {
          print('Event titles: ${initialEvents.map((e) => e.title).toList()}');
        } else {
          print('⚠️ WARNING: No events found for organizerId: "$organizerId"');
          print('This could mean:');
          print('  1. You haven\'t created any events yet');
          print('  2. Events were created with a different organizerId');
          print('  3. Events were deleted');
        }
        if (mounted) {
          setState(() {
            _myEvents = initialEvents;
            _currentUser = user;
            _isLoading = false;
          });
          print('State updated: _myEvents.length = ${_myEvents.length}');
        }
      } catch (e, stackTrace) {
        print('❌ Error loading initial events: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          setState(() {
            _currentUser = user;
            _isLoading = false;
          });
        }
      }
      
      // Set up stream for real-time updates
      print('Setting up stream for organizerId: "$organizerId"');
      _eventsSubscription = FirebaseEventService.getEventsByOrganizerStream(organizerId).listen(
        (events) {
          if (mounted) {
            print('📡 Stream updated: ${events.length} events for organizerId: $organizerId');
            if (events.isNotEmpty) {
              print('Event IDs: ${events.map((e) => e.id).toList()}');
            }
            setState(() {
              _myEvents = events;
            });
          }
        },
        onError: (error) {
          print('❌ Error in organizer events stream: $error');
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
      
      // Load notification preferences
      await _ensureNotificationPrefsLoaded(organizerId);
      
      // Set up listener for notifications
      _setupNotificationListener(organizerId);
    } catch (e, stackTrace) {
      print('❌ Error in _loadData: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _ensureNotificationPrefsLoaded(String userId) async {
    _notificationPrefs ??= await SharedPreferences.getInstance();
    _activeNotificationUserId = userId;
    final stored = _notificationPrefs!.getString('$_notificationPrefsKeyPrefix$userId');
    if (stored != null) {
      _lastNotificationSeenAt = DateTime.tryParse(stored);
    } else {
      // First time - mark current time so we don't show old notifications
      _lastNotificationSeenAt = DateTime.now();
      await _notificationPrefs!.setString(
        '$_notificationPrefsKeyPrefix$userId',
        _lastNotificationSeenAt!.toIso8601String(),
      );
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
      print('Setting up organizer notification listener...');
      final notificationsCol = FirebaseFirestore.instance.collection('notifications');
      _notificationSubscription?.cancel();
      _notificationInitialLoadComplete = false;
      
      _notificationSubscription = notificationsCol
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        print('Organizer notification listener triggered: ${snapshot.docs.length} unread notifications');
        
        // Bootstrap - skip all existing notifications on first load
        if (!_notificationInitialLoadComplete) {
          for (var doc in snapshot.docs) {
            _shownNotificationIds.add(doc.id);
          }
          _notificationInitialLoadComplete = true;
          print('Notification bootstrap complete - existing notifications skipped');
          return;
        }
        
        if (!mounted) return;
        
        // Only process newly added notifications
        final newNotifications = snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .map((change) => change.doc)
            .where((doc) => !_shownNotificationIds.contains(doc.id))
            .toList();
        
        if (newNotifications.isEmpty) return;
        
        for (var doc in newNotifications) {
          final notificationId = doc.id;
          final data = doc.data();
          if (data == null) continue;
          
          final createdAtStr = data['createdAt'] as String?;
          final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
          
          // Skip old notifications
          if (_lastNotificationSeenAt != null &&
              createdAt != null &&
              !createdAt.isAfter(_lastNotificationSeenAt!)) {
            _shownNotificationIds.add(notificationId);
            continue;
          }
          
          final type = data['type'] as String?;
          final eventTitle = data['eventTitle'] as String? ?? data['title'] as String? ?? 'Event';
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
            case 'poll':
              title = data['title'] as String? ?? '📊 New Poll';
              body = data['body'] as String? ?? eventTitle;
              break;
            default:
              title = 'EventBridge';
              body = data['body'] as String? ?? 'You have a new notification';
          }
          
          FirebaseNotificationService.showLocalNotification(
            title: title,
            body: body,
            payload: 'event:$eventId',
          );
          
          _shownNotificationIds.add(notificationId);
           _updateLastNotificationSeen(createdAt);
        }
      }, onError: (error) {
        print('Error in notification listener: $error');
      });
    } catch (e) {
      print('Error setting up notification listener: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    print('OrganizerDashboard build() called - isLoading: $_isLoading, events: ${_myEvents.length}');
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
          title: const Text('EventBridge - Organizer'),
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
          _buildCreateEventScreen(),
          _buildMyEventsScreen(),
          _buildAnalyticsScreen(),
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
              icon: Icon(Icons.add_circle_outline, size: 26),
              activeIcon: Icon(Icons.add_circle, size: 26),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_outlined, size: 26),
              activeIcon: Icon(Icons.event, size: 26),
              label: 'My Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined, size: 26),
              activeIcon: Icon(Icons.analytics, size: 26),
              label: 'Analytics',
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
    
    // Calculate real stats from _myEvents
    final totalEvents = _myEvents.length;
    final totalParticipants = _myEvents.fold<int>(
      0,
      (sum, event) => sum + event.participants.length,
    );
    
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final eventsThisMonth = _myEvents.where((event) => 
      event.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
      event.date.isBefore(now.add(const Duration(days: 1)))
    ).length;
    
    final pendingEvents = _myEvents.where((event) => 
      event.status == EventStatus.draft || event.status == EventStatus.published
    ).length;
    
    // Categorize events
    final today = DateTime(now.year, now.month, now.day);
    
    final upcomingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAfter(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final ongoingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final pastEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isBefore(today);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    print('Home screen - Total events: $totalEvents, Upcoming: ${upcomingEvents.length}, Ongoing: ${ongoingEvents.length}, Past: ${pastEvents.length}');

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Events', 
                    totalEvents.toString(), 
                    Icons.event, 
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Participants', 
                    totalParticipants.toString(), 
                    Icons.people, 
                    Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'This Month', 
                    eventsThisMonth.toString(), 
                    Icons.calendar_month, 
                    Colors.orange,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending', 
                    pendingEvents.toString(), 
                    Icons.pending, 
                    Colors.red,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Analytics Quick Access
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedIndex = 3; // Switch to Analytics tab
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.purple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'See event success rates and statistics',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios, 
                        size: 16, 
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Flash Polls Quick Access
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade600,
                    Colors.purple.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PollsScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.poll,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flash Polls',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Get quick decisions from your group',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios, 
                        size: 16, 
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming Events
            if (upcomingEvents.isNotEmpty) ...[
              _buildSectionHeader('Upcoming Events', upcomingEvents.length, isDark),
              const SizedBox(height: 14),
              ...upcomingEvents.take(5).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _viewEventDetails(event),
                  child: _buildEventCard(
                    event.title,
                    '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                    event.location,
                    '${event.participants.length} participants',
                    _getStatusText(event.status),
                    _getStatusColor(event.status),
                    isDark,
                  ),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Ongoing Events
            if (ongoingEvents.isNotEmpty) ...[
              _buildSectionHeader('Ongoing Events', ongoingEvents.length, isDark),
              const SizedBox(height: 14),
              ...ongoingEvents.take(5).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _viewEventDetails(event),
                  child: _buildEventCard(
                    event.title,
                    '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                    event.location,
                    '${event.participants.length} participants',
                    _getStatusText(event.status),
                    _getStatusColor(event.status),
                    isDark,
                  ),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Past Events
            if (pastEvents.isNotEmpty) ...[
              _buildSectionHeader('Past Events', pastEvents.length, isDark),
              const SizedBox(height: 14),
              ...pastEvents.take(3).map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _viewEventDetails(event),
                  child: _buildEventCard(
                    event.title,
                    '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                    event.location,
                    '${event.participants.length} participants',
                    _getStatusText(event.status),
                    _getStatusColor(event.status),
                    isDark,
                  ),
                ),
              )),
            ],
            
            // Empty state
            if (_myEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events created yet',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first event!',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1976D2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateEventScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_circle,
            size: 100,
            color: const Color(0xFF1976D2).withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create New Event',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to create a new event',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              // Get the current organizer ID
              String? organizerId;
              if (_currentUser != null) {
                organizerId = _currentUser!.id;
              } else if (widget.userId != null) {
                organizerId = widget.userId;
              }
              
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateEventScreen(organizerId: organizerId),
                ),
              );
              if (result == true) {
                _refreshData();
              }
            },
            icon: const Icon(Icons.add, size: 24),
            label: const Text(
              'Create Event',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: const Color(0xFF1976D2).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              minimumSize: const Size(180, 56),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventsScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Categorize events
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final upcomingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAfter(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final ongoingEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final pastEvents = _myEvents.where((event) {
      final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate.isBefore(today);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Events (${_myEvents.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming Events
            if (upcomingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${upcomingEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...upcomingEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  '${event.participants.length} participants',
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  isDark,
                  onEdit: () => _editEvent(event),
                  onManage: () => _manageEvent(event),
                  onViewDetails: () => _viewEventDetails(event),
                  onDelete: () => _deleteEvent(event),
                  onMarkDone: () => _markEventAsDone(event),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Ongoing Events
            if (ongoingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ongoing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${ongoingEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...ongoingEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  '${event.participants.length} participants',
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  isDark,
                  onEdit: () => _editEvent(event),
                  onManage: () => _manageEvent(event),
                  onViewDetails: () => _viewEventDetails(event),
                  onDelete: () => _deleteEvent(event),
                  onMarkDone: () => _markEventAsDone(event),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Past Events
            if (pastEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Past',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${pastEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pastEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMyEventCard(
                  event.title,
                  '${DateFormat('MMM d, y').format(event.date)} • ${event.time}',
                  event.location,
                  '${event.participants.length} participants',
                  _getStatusText(event.status),
                  _getStatusColor(event.status),
                  isDark,
                  onEdit: () => _editEvent(event),
                  onManage: () => _manageEvent(event),
                  onViewDetails: () => _viewEventDetails(event),
                  onDelete: () => _deleteEvent(event),
                  onMarkDone: () => _markEventAsDone(event),
                ),
              )),
            ],
            
            // Empty state
            if (_myEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events created yet',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first event!',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsScreen() {
    return AnalyticsScreen(events: _myEvents, showTopBar: false);
  }

  Widget _buildProfileScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
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
                  _currentUser?.name ?? 'Organizer',
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
                        size: 18, 
                        color: isDark ? Colors.grey[200] : Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentUser!.email!,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[100] : Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (_currentUser?.universityId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.badge_outlined, 
                        size: 18, 
                        color: isDark ? Colors.grey[200] : Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${_currentUser!.universityId}',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[100] : Colors.grey[800],
                          fontWeight: FontWeight.w600,
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
                  'Flash Polls',
                  Icons.poll,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PollsScreen(),
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
            height: 56,
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
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
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
              icon: const Icon(Icons.logout_rounded, size: 22, color: Colors.white),
              label: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.red.withOpacity(0.5),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    String title,
    String dateTime,
    String location,
    String participants,
    String status,
    Color statusColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time, 
                  size: 16, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  dateTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people, 
                  size: 16, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  participants,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyEventCard(
    String title,
    String dateTime,
    String location,
    String participants,
    String status,
    Color statusColor,
    bool isDark, {
    VoidCallback? onEdit,
    VoidCallback? onManage,
    VoidCallback? onDelete,
    VoidCallback? onMarkDone,
    VoidCallback? onViewDetails,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Menu button for additional actions
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert, 
                    color: isDark ? Colors.grey[400] : Colors.grey[600], 
                    size: 20,
                  ),
                  color: isDark ? Colors.grey[800] : Colors.white,
                  onSelected: (value) {
                    if (value == 'view' && onViewDetails != null) {
                      onViewDetails();
                    } else if (value == 'done' && onMarkDone != null) {
                      onMarkDone();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility, 
                            size: 20,
                            color: isDark ? Colors.grey[300] : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (status != 'Completed')
                      PopupMenuItem(
                        value: 'done',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Mark as Done',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time, 
                  size: 16, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  dateTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.people, 
                  size: 16, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  participants,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(color: Color(0xFF1976D2)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onManage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Manage',
                      style: TextStyle(color: Colors.white),
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

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  // Helper methods
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

  void _editEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(event: event),
      ),
    ).then((_) => _refreshData());
  }

  void _manageEvent(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageParticipantsScreen(event: event),
      ),
    ).then((_) => _refreshData());
  }

  void _viewEventDetails(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
          event: event,
          isOrganizer: true,
        ),
      ),
    ).then((result) {
      // If event was deleted, refresh the data
      if (result == true) {
        _refreshData();
      } else {
        _refreshData();
      }
    });
  }

  Future<void> _deleteEvent(Event event) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await FirebaseEventService.deleteEvent(event.id);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (success) {
          // Immediately remove from local list as a fallback while stream updates
          setState(() {
            _myEvents = _myEvents.where((e) => e.id != event.id).toList();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Stream should update automatically, but refresh as backup
          _refreshData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete event. Please check your Firestore security rules and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _markEventAsDone(Event event) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Event as Done'),
        content: Text(
          'Are you sure you want to mark "${event.title}" as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark as Done'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await FirebaseEventService.markEventAsCompleted(event.id);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event marked as completed!'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update event status. Please check your Firestore security rules and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
