import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_details_screen.dart';
import 'welcome_screen.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../widgets/event_card.dart';
import '../widgets/category_card.dart';
import 'edit_profile_screen.dart';

class ParticipantDashboard extends StatefulWidget {
  final String? userId;
  
  const ParticipantDashboard({super.key, this.userId});

  @override
  State<ParticipantDashboard> createState() => _ParticipantDashboardState();
}

class _ParticipantDashboardState extends State<ParticipantDashboard> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  
  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  List<Event> _myEvents = [];
  User? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadData();
  }

  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<List<Event>>? _myEventsSubscription;

  @override
  void dispose() {
    _searchController.dispose();
    _eventsSubscription?.cancel();
    _myEventsSubscription?.cancel();
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
      
      // Determine user ID for events - prioritize widget.userId since it's from auth
      String userId;
      if (widget.userId != null) {
        userId = widget.userId!;
      } else if (user != null) {
        userId = user.id;
      } else {
        userId = 'guest_participant';
      }
      
      print('Setting up streams for userId: $userId');
      
      // Use real-time stream for all events
      _eventsSubscription?.cancel();
      _eventsSubscription = FirebaseEventService.getAllEventsStream().listen(
        (events) {
          if (mounted) {
            print('All events stream updated: ${events.length} events');
            setState(() {
              _allEvents = events;
              _filteredEvents = _selectedCategory.isEmpty 
                  ? events 
                  : events.where((e) => e.category == _selectedCategory).toList();
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
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchEvents(String query) async {
    if (query.isEmpty) {
      setState(() => _filteredEvents = _allEvents);
      return;
    }
    
    final results = await FirebaseEventService.searchEvents(query);
    setState(() => _filteredEvents = results);
  }

  Future<void> _filterByCategory(String category) async {
    setState(() => _selectedCategory = category);
    
    if (category.isEmpty) {
      setState(() => _filteredEvents = _allEvents);
    } else {
      final results = await FirebaseEventService.getEventsByCategory(category);
      setState(() => _filteredEvents = results);
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
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

    final success = await FirebaseEventService.registerForEvent(event.id, userId);
    print('Registration result: $success');
    
    if (success) {
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
        const SnackBar(
          content: Text('Registration failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventBridge'),
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
          _buildSearchScreen(),
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
            icon: Icon(Icons.search),
            label: 'Search',
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _searchEvents,
                decoration: const InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Categories
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Events
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory.isEmpty ? 'All Events' : '$_selectedCategory Events',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _selectedIndex = 1); // Switch to search tab
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Event Cards
            if (_filteredEvents.isEmpty)
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
              )
            else
              ..._filteredEvents.map((event) {
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
                    onRegister: () => _registerForEvent(event),
                    onFavorite: () => _toggleFavorite(event),
                    isRegistered: isRegistered,
                    imageUrl: event.imageUrl,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchEvents,
              decoration: const InputDecoration(
                hintText: 'Search events by name, category, or keyword...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Search Results (${_filteredEvents.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredEvents.isEmpty
                ? const Center(
                    child: Text(
                      'No events found. Try searching with different keywords.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
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
                          onRegister: () => _registerForEvent(event),
                          onFavorite: () => _toggleFavorite(event),
                          isRegistered: isRegistered,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventsScreen() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Registered Events (${_myEvents.length})',
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
                        'No registered events yet.\nBrowse events to register!',
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
                            _getStatusText(event.status),
                            _getStatusColor(event.status),
                            onTap: () => _navigateToEventDetails(event),
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
            _currentUser?.name ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _currentUser?.email ?? (_currentUser?.universityId != null ? 'ID: ${_currentUser!.universityId}' : 'Guest User'),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (_currentUser?.universityId != null && _currentUser?.email != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ID: ${_currentUser!.universityId}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
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
          _buildProfileOption('Notifications', Icons.notifications, () {}),
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
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () {},
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

  Widget _buildMyEventCard(
    String title,
    String dateTime,
    String location,
    String status,
    Color statusColor, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            ],
          ),
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

  void _toggleFavorite(Event event) {
    // TODO: Implement favorite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Favorite functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
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
