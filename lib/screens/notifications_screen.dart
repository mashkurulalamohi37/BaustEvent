import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_event_service.dart';
import 'event_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baust_event/screens/polls_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String? userId;
  
  const NotificationsScreen({super.key, this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Set<String> _localReadIds = {};
  final String _localReadIdsKey = 'local_read_notification_ids';

  @override
  void initState() {
    super.initState();
    _loadLocalReadState();
  }

  // Load locally read notification IDs (for broadcast notifications like polls)
  Future<void> _loadLocalReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = widget.userId != null ? '${_localReadIdsKey}_${widget.userId}' : _localReadIdsKey;
      final storedIds = prefs.getStringList(key) ?? [];
      setState(() {
        _localReadIds = storedIds.toSet();
      });
    } catch (e) {
      debugPrint('Error loading local read state: $e');
    }
    _loadNotifications();
  }

  Future<void> _saveLocalReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = widget.userId != null ? '${_localReadIdsKey}_${widget.userId}' : _localReadIdsKey;
      await prefs.setStringList(key, _localReadIds.toList());
    } catch (e) {
      debugPrint('Error saving local read state: $e');
    }
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _loadNotifications() {
    setState(() => _isLoading = true);
    
    try {
      final notificationsCol = _firestore.collection('notifications');
      
      // Try with orderBy first
      try {
        _notificationsSubscription = notificationsCol
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .listen(_processSnapshot, onError: (error) {
           debugPrint('Error in notifications stream: $error');
          _loadNotificationsFallback();
        });
      } catch (e) {
        debugPrint('Error setting up notifications stream: $e');
        _loadNotificationsFallback();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _processSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;
    
    final notifications = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        ...data,
      };
    }).where((n) {
      // Filter notifications: Show only those for this user OR broadcast (no userId)
      final nUserId = n['userId'] as String?;
      return nUserId == null || nUserId == widget.userId;
    }).toList();

    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  void _loadNotificationsFallback() {
    try {
      final notificationsCol = _firestore.collection('notifications');
      _notificationsSubscription?.cancel();
      _notificationsSubscription = notificationsCol
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        
        final notifications = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).where((n) {
          final nUserId = n['userId'] as String?;
          return nUserId == null || nUserId == widget.userId;
        }).toList();
        
        // Sort manually by createdAt
        notifications.sort((a, b) {
          final aTime = a['createdAt'] as String? ?? '';
          final bTime = b['createdAt'] as String? ?? '';
          return bTime.compareTo(aTime);
        });
        
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }, onError: (error) {
        debugPrint('Error in fallback notifications stream: $error');
        if (mounted) setState(() => _isLoading = false);
      });
    } catch (e) {
      debugPrint('Error in fallback: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId, bool isBroadcast) async {
    try {
      if (isBroadcast) {
        // For broadcast notifications (Polls), mark as read locally
        setState(() {
          _localReadIds.add(notificationId);
        });
        await _saveLocalReadState();
      } else {
        // For personal notifications, update Firestore
        await _firestore.collection('notifications').doc(notificationId).update({
          'read': true,
        });
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      bool firestoreUpdates = false;
      bool localUpdates = false;

      for (var notification in _notifications) {
        final id = notification['id'];
        final isBroadcast = notification['userId'] == null;
        final isRead = notification['read'] == true || _localReadIds.contains(id);

        if (!isRead) {
          if (isBroadcast) {
            _localReadIds.add(id);
            localUpdates = true;
          } else {
            final docRef = _firestore.collection('notifications').doc(id);
            batch.update(docRef, {'read': true});
            firestoreUpdates = true;
          }
        }
      }

      if (firestoreUpdates) await batch.commit();
      if (localUpdates) await _saveLocalReadState();
      
      if (mounted) {
        setState(() {}); // Refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _navigateToEvent(String eventId) async {
    try {
      final events = await FirebaseEventService.getAllEvents();
      try {
        final event = events.firstWhere((e) => e.id == eventId);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(
                event: event,
                userId: widget.userId,
              ),
            ),
          );
        }
      } catch (e) {
        // Event not found locally, might need fetching active status
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Event details not found')),
           );
         }
      }
    } catch (e) {
      debugPrint('Error navigating to event: $e');
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'new_event':
        return Icons.event;
      case 'event_reminder':
        return Icons.alarm;
      case 'event_update':
        return Icons.update;
      case 'event_registration':
        return Icons.check_circle;
      case 'poll':
        return Icons.poll;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'new_event':
        return Colors.blue;
      case 'event_reminder':
        return Colors.orange;
      case 'event_update':
        return Colors.purple;
      case 'event_registration':
        return Colors.green;
      case 'poll':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) {
       final isBroadcast = n['userId'] == null;
       return !(n['read'] == true || (isBroadcast && _localReadIds.contains(n['id'])));
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.blue, size: 20),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    _loadNotifications();
                  },
                  child: ListView.builder(
                    cacheExtent: 500,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isBroadcast = notification['userId'] == null;
                      final isRead = notification['read'] == true || 
                                   (isBroadcast && _localReadIds.contains(notification['id']));
                                   
                      final type = notification['type'] as String?;
                      final createdAt = notification['createdAt'] as String?;
                      final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
                      
                      final isDark = Theme.of(context).brightness == Brightness.dark;


                      // Define colors based on states
                      final bgColor = isRead 
                          ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA)) // Light Grey for Read
                          : (isDark ? const Color(0xFF1A2733) : const Color(0xFFEDF7FF)); // Light Blue for Unread
                      
                      final borderColor = isRead
                          ? (isDark ? Colors.white10 : Colors.grey.shade300) // Visible Grey border for Read
                          : (isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200); // Blue border for Unread

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // More side spacing
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: 1.5), // Thicker border
                          boxShadow: [
                            if (!isRead) // Only unread gets a shadow glow
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (!isRead) {
                                await _markAsRead(notification['id'], isBroadcast);
                              }
                              if (!context.mounted) return;
                              
                              if (type == 'poll') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PollsScreen()),
                                );
                              } else if (['new_event', 'event_update', 'event_reminder'].contains(type)) {
                                final eventId = notification['eventId'] as String?;
                                if (eventId != null) {
                                  _navigateToEvent(eventId);
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon - Always colorful
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(type).withValues(alpha: 0.15), // Always colored bg
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(type),
                                      color: _getNotificationColor(type), // Always colored icon
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Title + Time
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _getNotificationTitle(notification),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold, // Always bold title
                                                  fontSize: 16,
                                                  color: isDark 
                                                      ? Colors.white 
                                                      : (isRead ? const Color(0xFF2D3436) : const Color(0xFF0056D2)),
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                            if (date != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  DateFormat('MMM d').format(date),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Body Text
                                        Text(
                                          _getNotificationBody(notification),
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[400] : Colors.grey[800], // Darker text
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        
                                        // Time detail
                                        if (date != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('h:mm a').format(date),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  
                                  // Unread Dot
                                  if (!isRead)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 2),
                                      child: Icon(Icons.circle, color: Colors.blue[700], size: 12),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
     final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see notifications here when there are updates',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
  }

  String _getNotificationTitle(Map<String, dynamic> notification) {
    // If explicit title is present, use it
    if (notification['title'] != null && notification['title'].toString().isNotEmpty) {
      return notification['title'];
    }
    
    final type = notification['type'] as String?;
    switch (type) {
      case 'new_event':
        return 'New Event Available!';
      case 'event_reminder':
        return 'Event Reminder';
      case 'event_update':
        return 'Event Update';
      case 'event_registration':
        return 'Registration Confirmed';
      case 'poll':
        return 'New Flash Poll';
      default:
        return 'Notification';
    }
  }

  String _getNotificationBody(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    switch (type) {
      case 'new_event':
        final eventTitle = notification['eventTitle'] as String? ?? 'New Event';
        final category = notification['category'] as String? ?? '';
        return '$eventTitle - $category';
      case 'event_reminder':
        final eventTitle = notification['eventTitle'] as String? ?? 'Event';
        return '$eventTitle is happening soon!';
      case 'event_update':
        return notification['updateMessage'] as String? ?? 'Event has been updated';
      case 'event_registration':
        final eventTitle = notification['eventTitle'] as String? ?? 'Event';
        return 'You have successfully registered for $eventTitle';
      case 'poll':
        return notification['body'] as String? ?? 'Tap to vote in the new poll!';
      default:
        return notification['body'] as String? ?? 'You have a new notification';
    }
  }
}

