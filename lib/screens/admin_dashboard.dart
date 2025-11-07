import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_notification_service.dart';
import 'welcome_screen.dart';
import 'analytics_screen.dart';
import 'event_details_screen.dart';
import 'edit_event_screen.dart';
import 'manage_participants_screen.dart';
import 'notifications_screen.dart';
import '../widgets/event_card.dart';

class AdminDashboard extends StatefulWidget {
  final String? userId;
  
  const AdminDashboard({super.key, this.userId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  User? _currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;
  
  StreamSubscription? _requestsSubscription;
  StreamSubscription<List<Event>>? _eventsSubscription;
  StreamSubscription<List<User>>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  Set<String> _shownNotificationIds = {}; // Track which notifications we've already shown
  
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Event> _allEvents = [];
  List<User> _allUsers = [];
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Refresh state
  bool _isRefreshingRequests = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _eventsSubscription?.cancel();
    _usersSubscription?.cancel();
    _notificationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      User? user;
      if (widget.userId != null) {
        user = await FirebaseUserService.getUserById(widget.userId!);
      } else {
        user = await FirebaseUserService.getCurrentUserWithDetails();
      }
      
      if (user == null || !user.isAdmin) {
        // Not an admin, redirect to welcome screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        }
        return;
      }
      
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
      
      // Load requests immediately first
      final initialRequests = await FirebaseUserService.getPendingOrganizerRequests();
      print('Admin Dashboard: Loaded ${initialRequests.length} initial pending requests');
      if (mounted) {
        setState(() {
          _pendingRequests = initialRequests;
        });
      }
      
      // Then set up stream for real-time updates
      try {
        _requestsSubscription = FirebaseUserService.getPendingOrganizerRequestsStream().listen(
          (requests) {
            print('Admin Dashboard: Stream update - Received ${requests.length} pending requests');
            if (mounted) {
              setState(() {
                _pendingRequests = requests;
              });
            }
          },
          onError: (error) {
            print('Error in organizer requests stream: $error');
            print('Trying fallback stream...');
            // Try fallback stream without orderBy
            _requestsSubscription?.cancel();
            _requestsSubscription = FirebaseUserService.getPendingOrganizerRequestsStreamFallback().listen(
              (requests) {
                print('Admin Dashboard: Fallback stream - Received ${requests.length} pending requests');
                if (mounted) {
                  setState(() {
                    _pendingRequests = requests;
                  });
                }
              },
              onError: (fallbackError) {
                print('Error in fallback stream: $fallbackError');
                // Periodically refresh using non-stream method
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted) {
                    FirebaseUserService.getPendingOrganizerRequests().then((requests) {
                      if (mounted) {
                        setState(() {
                          _pendingRequests = requests;
                        });
                      }
                    });
                  }
                });
              },
              cancelOnError: false,
            );
          },
          cancelOnError: false,
        );
      } catch (e) {
        print('Error setting up organizer requests stream: $e');
        // Use fallback stream
        _requestsSubscription = FirebaseUserService.getPendingOrganizerRequestsStreamFallback().listen(
          (requests) {
            if (mounted) {
              setState(() {
                _pendingRequests = requests;
              });
            }
          },
          onError: (error) {
            print('Error in fallback stream: $error');
          },
          cancelOnError: false,
        );
      }
      
      // Listen to all events
      _eventsSubscription = FirebaseEventService.getAllEventsStream().listen(
        (events) {
          if (mounted) {
            setState(() {
              _allEvents = events;
            });
          }
        },
        onError: (error) {
          print('Error listening to events: $error');
        },
      );
      
      // Load all users
      _loadAllUsers();
      
      // Set up listener for notifications
      _setupNotificationListener();
    } catch (e) {
      print('Error loading admin data: $e');
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

  Future<void> _approveRequest(String requestId) async {
    if (_currentUser == null) return;
    
    final success = await FirebaseUserService.approveOrganizerRequest(
      requestId,
      _currentUser!.id,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Organizer request approved successfully!' 
              : 'Failed to approve request. Please try again.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    if (_currentUser == null) return;
    
    final success = await FirebaseUserService.rejectOrganizerRequest(
      requestId,
      _currentUser!.id,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Organizer request rejected.' 
              : 'Failed to reject request. Please try again.'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshRequests() async {
    if (_isRefreshingRequests) return;
    
    setState(() {
      _isRefreshingRequests = true;
    });
    
    try {
      // Load requests immediately
      final requests = await FirebaseUserService.getPendingOrganizerRequests();
      print('Refreshed: Loaded ${requests.length} pending requests');
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isRefreshingRequests = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Requests refreshed (${requests.length} pending)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error refreshing requests: $e');
      if (mounted) {
        setState(() {
          _isRefreshingRequests = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh requests: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final users = await FirebaseUserService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
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
    
    if (confirm == true) {
      final success = await FirebaseEventService.deleteEvent(event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Event deleted successfully' : 'Failed to delete event'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete admin users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user "${user.name}"? This action cannot be undone.'),
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
    
    if (confirm == true) {
      try {
        // Delete the Firestore user document
        await FirebaseFirestore.instance.collection('users').doc(user.id).delete();
        
        // Also delete any pending organizer requests for this user
        try {
          final requestsSnapshot = await FirebaseFirestore.instance
              .collection('organizer_requests')
              .where('userId', isEqualTo: user.id)
              .where('status', isEqualTo: 'pending')
              .get();
          
          for (var doc in requestsSnapshot.docs) {
            await doc.reference.delete();
          }
        } catch (e) {
          print('Error deleting organizer requests: $e');
          // Continue even if this fails
        }
        
        // Try to delete Firebase Auth user (only works if it's the current user)
        // For other users, they need to be deleted from Firebase Console or via Cloud Function
        bool authDeleted = false;
        try {
          authDeleted = await FirebaseUserService.deleteAuthUser(user.id);
        } catch (e) {
          print('Could not delete Firebase Auth user: $e');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAllUsers();
        }
      } catch (e) {
        print('Error deleting user: $e');
        if (mounted) {
          String errorMessage = 'Failed to delete user';
          if (e.toString().contains('PERMISSION_DENIED') || 
              e.toString().contains('permission-denied')) {
            errorMessage = 'Permission denied. Please check Firestore security rules.';
          } else {
            errorMessage = 'Failed to delete user: ${e.toString()}';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseUserService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(userId: _currentUser?.id ?? widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRequestsScreen(),
          _buildEventsScreen(),
          _buildUsersScreen(),
          _buildAnalyticsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 2) {
            _loadAllUsers(); // Refresh users when switching to users tab
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            activeIcon: Icon(Icons.person_add),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build Requests Screen
  Widget _buildRequestsScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshRequests();
      },
      color: Colors.blue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 48, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_currentUser?.name ?? 'Admin'}!',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Pending Requests Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Organizer Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text('${_pendingRequests.length}'),
                  backgroundColor: Colors.blue,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_pendingRequests.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No pending requests',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All organizer requests have been reviewed.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._pendingRequests.map((request) {
                final requestedAt = request['requestedAt'] as String?;
                final date = requestedAt != null 
                    ? DateTime.tryParse(requestedAt) 
                    : null;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                request['name'] as String? ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.email, request['email'] as String? ?? ''),
                        _buildInfoRow(Icons.badge, request['universityId'] as String? ?? ''),
                        if (date != null)
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Requested: ${DateFormat('MMM d, y • h:mm a').format(date)}',
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _rejectRequest(request['id'] as String),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _approveRequest(request['id'] as String),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
  
  // Build Events Screen
  Widget _buildEventsScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: _allEvents.isEmpty
          ? const Center(
              child: Text(
                'No events found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _allEvents.length,
              itemBuilder: (context, index) {
                final event = _allEvents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(event.category),
                      child: Icon(
                        _getCategoryIcon(event.category),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${DateFormat('MMM d, y').format(event.date)} • ${event.time}'),
                        Text('${event.participants.length}/${event.maxParticipants} participants'),
                        Text('Category: ${event.category}'),
                      ],
                    ),
                    trailing: PopupMenuButton(
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
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'manage',
                          child: Row(
                            children: [
                              Icon(Icons.people, size: 20),
                              SizedBox(width: 8),
                              Text('Manage Participants'),
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
                      onSelected: (value) {
                        if (value == 'view') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsScreen(
                                event: event,
                                userId: _currentUser?.id,
                              ),
                            ),
                          );
                        } else if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditEventScreen(event: event),
                            ),
                          ).then((_) => _loadData());
                        } else if (value == 'manage') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageParticipantsScreen(event: event),
                            ),
                          );
                        } else if (value == 'delete') {
                          _deleteEvent(event);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
  
  // Build Users Screen
  Widget _buildUsersScreen() {
    // Filter users based on search query
    final filteredUsers = _searchQuery.isEmpty
        ? _allUsers
        : _allUsers.where((user) {
            final query = _searchQuery.toLowerCase();
            return user.name.toLowerCase().contains(query) ||
                   user.email.toLowerCase().contains(query) ||
                   user.universityId.toLowerCase().contains(query) ||
                   user.type.name.toLowerCase().contains(query);
          }).toList();
    
    // Separate filtered users by type
    final adminUsers = filteredUsers.where((u) => u.isAdmin).toList();
    final organizerUsers = filteredUsers.where((u) => u.type == UserType.organizer).toList();
    final participantUsers = filteredUsers.where((u) => u.type == UserType.participant).toList();
    
    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by name, email, or ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        
        // Users List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadAllUsers();
            },
            child: _allUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          // Search Results Summary
                          if (_searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                'Found ${filteredUsers.length} user${filteredUsers.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          
                          // Admins Section
                          if (adminUsers.isNotEmpty) ...[
                            _buildUserSectionHeader('Admins', adminUsers.length, Colors.red),
                            const SizedBox(height: 8),
                            ...adminUsers.map((user) => _buildUserCard(user)),
                            const SizedBox(height: 24),
                          ],
                          
                          // Organizers Section
                          if (organizerUsers.isNotEmpty) ...[
                            _buildUserSectionHeader('Organizers', organizerUsers.length, Colors.blue),
                            const SizedBox(height: 8),
                            ...organizerUsers.map((user) => _buildUserCard(user)),
                            const SizedBox(height: 24),
                          ],
                          
                          // Participants Section
                          if (participantUsers.isNotEmpty) ...[
                            _buildUserSectionHeader('Participants', participantUsers.length, Colors.green),
                            const SizedBox(height: 8),
                            ...participantUsers.map((user) => _buildUserCard(user)),
                          ],
                        ],
                      ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserSectionHeader(String title, int count, Color color) {
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
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text('$count'),
          backgroundColor: color.withOpacity(0.2),
          labelStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildUserCard(User user) {
    final isParticipant = user.type == UserType.participant;
    final isOrganizer = user.type == UserType.organizer;
    final isAdmin = user.isAdmin;
    
    // Different border colors and styles for different user types
    Color borderColor;
    Color cardColor;
    double borderWidth;
    
    if (isAdmin) {
      borderColor = Colors.red;
      cardColor = Colors.red.shade50;
      borderWidth = 2.0;
    } else if (isOrganizer) {
      borderColor = Colors.blue;
      cardColor = Colors.blue.shade50;
      borderWidth = 2.0;
    } else {
      borderColor = Colors.green;
      cardColor = Colors.green.shade50;
      borderWidth = 1.5;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAdmin || isOrganizer ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      color: cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _getUserTypeColor(user.type),
          child: Icon(
            _getUserTypeIcon(user.type),
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isAdmin ? Colors.red.shade900 : 
                         isOrganizer ? Colors.blue.shade900 : 
                         Colors.green.shade900,
                ),
              ),
            ),
            _buildUserTypeBadge(user.type),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.email, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'ID: ${user.universityId}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: user.isAdmin
            ? const SizedBox.shrink()
            : PopupMenuButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[700]),
                itemBuilder: (context) => [
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
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteUser(user);
                  }
                },
              ),
      ),
    );
  }
  
  Widget _buildUserTypeBadge(UserType type) {
    String label;
    Color backgroundColor;
    Color textColor;
    
    switch (type) {
      case UserType.admin:
        label = 'ADMIN';
        backgroundColor = Colors.red;
        textColor = Colors.white;
        break;
      case UserType.organizer:
        label = 'ORGANIZER';
        backgroundColor = Colors.blue;
        textColor = Colors.white;
        break;
      case UserType.participant:
        label = 'PARTICIPANT';
        backgroundColor = Colors.green;
        textColor = Colors.white;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  // Build Analytics Screen
  Widget _buildAnalyticsScreen() {
    return AnalyticsScreen(events: _allEvents);
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
        return Colors.grey;
    }
  }
  
  IconData _getUserTypeIcon(UserType type) {
    switch (type) {
      case UserType.admin:
        return Icons.admin_panel_settings;
      case UserType.organizer:
        return Icons.event;
      case UserType.participant:
        return Icons.person;
    }
  }
  
  Color _getUserTypeColor(UserType type) {
    switch (type) {
      case UserType.admin:
        return Colors.red;
      case UserType.organizer:
        return Colors.blue;
      case UserType.participant:
        return Colors.green;
    }
  }
}

