import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_details_screen.dart';
import 'welcome_screen.dart';
import 'create_event_screen.dart';
import 'edit_event_screen.dart';
import 'manage_participants_screen.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import 'edit_profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadData();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      User? user;
      
      // If userId is provided, fetch user details
      if (widget.userId != null) {
        user = await FirebaseUserService.getUserById(widget.userId!);
      } else {
        user = await FirebaseUserService.getCurrentUserWithDetails();
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
      _eventsSubscription?.cancel();
      _eventsSubscription = FirebaseEventService.getEventsByOrganizerStream(organizerId).listen(
        (events) {
          if (mounted) {
            print('Organizer events stream updated: ${events.length} events');
            setState(() => _myEvents = events);
          }
        },
        onError: (error) {
          print('Error in organizer events stream: $error');
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
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventBridge - Organizer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
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
    );
  }

  Widget _buildHomeScreen() {
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
    
    // Get recent events (last 5, sorted by date descending)
    final recentEvents = List<Event>.from(_myEvents)
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayEvents = recentEvents.take(5).toList();

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
            // Recent Events
            const Text(
              'Recent Events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (displayEvents.isEmpty)
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
              )
            else
              ...displayEvents.map((event) => Padding(
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

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Padding(
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
            const SizedBox(height: 16),
            Expanded(
              child: _myEvents.isEmpty
                  ? const Center(
                      child: Text(
                        'No events created yet.\nCreate your first event!',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _myEvents.length,
                      itemBuilder: (context, index) {
                        final event = _myEvents[index];
                        return Padding(
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
                        );
                      },
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
          _buildProfileOption('Event Analytics', Icons.analytics, () {}),
          _buildProfileOption('Participant Management', Icons.people, () {}),
          _buildProfileOption('Settings', Icons.settings, () {}),
          _buildProfileOption('Help & Support', Icons.help, () {}),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
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
