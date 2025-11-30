import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      
      // Set up listener for notifications
      _setupNotificationListener();
    } catch (e, stackTrace) {
      print('❌ Error in _loadData: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }
  
  // Set up listener for notifications from Firestore
  void _setupNotificationListener() {
    try {
      final notificationsCol = FirebaseFirestore.instance.collection('notifications');
      _notificationSubscription?.cancel();
      
      // Listen to all unread notifications
      _notificationSubscription = notificationsCol
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty && mounted) {
          for (var doc in snapshot.docs) {
            final notificationId = doc.id;
            if (_shownNotificationIds.contains(notificationId)) continue;
            
            final data = doc.data();
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
            
            // Show system notification in phone notification panel
            FirebaseNotificationService.showLocalNotification(
              title: title,
              body: body,
              payload: 'event:$eventId',
            );
            
            _shownNotificationIds.add(notificationId);
          }
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
          _buildProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'My Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHomeScreen() {
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Participants', 
                    totalParticipants.toString(), 
                    Icons.people, 
                    Colors.green,
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending', 
                    pendingEvents.toString(), 
                    Icons.pending, 
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Analytics Quick Access
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnalyticsScreen(events: _myEvents),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          color: Colors.purple,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'View Analytics',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'See event success rates and statistics',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming Events
            if (upcomingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${upcomingEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  ),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Ongoing Events
            if (ongoingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ongoing Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${ongoingEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  ),
                ),
              )),
              const SizedBox(height: 24),
            ],
            
            // Past Events
            if (pastEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Past Events',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${pastEvents.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  ),
                ),
              )),
            ],
            
            // Empty state
            if (_myEvents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No events created yet.\nCreate your first event!',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateEventScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            size: 80,
            color: Colors.grey,
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
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventsScreen() {
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Upcoming Events
            if (upcomingEvents.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${upcomingEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
                  const Text(
                    'Ongoing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${ongoingEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
                  const Text(
                    'Past',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${pastEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
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
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'No events created yet.\nCreate your first event!',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF1976D2),
            backgroundImage: _currentUser?.profileImageUrl != null
                ? NetworkImage(_currentUser!.profileImageUrl!)
                : null,
            child: _currentUser?.profileImageUrl == null
                ? const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser?.name ?? 'Organizer',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _currentUser?.email ?? 'Event Organizer',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          _buildProfileOption('Edit Profile', Icons.edit, () async {
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
          }),
          _buildProfileOption('Event Analytics', Icons.analytics, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnalyticsScreen(events: _myEvents),
              ),
            );
          }),
          _buildProfileOption('Participant Management', Icons.people, () {}),
          _buildProfileOption('Settings', Icons.settings, () {}),
          _buildProfileOption('Help & Support', Icons.help, () {}),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateTime,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  participants,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
    Color statusColor, {
    VoidCallback? onEdit,
    VoidCallback? onManage,
    VoidCallback? onDelete,
    VoidCallback? onMarkDone,
    VoidCallback? onViewDetails,
  }) {
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Menu button for additional actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
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
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 20),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (status != 'Completed')
                      const PopupMenuItem(
                        value: 'done',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Mark as Done'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateTime,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  participants,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
                        borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildProfileOption(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
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
