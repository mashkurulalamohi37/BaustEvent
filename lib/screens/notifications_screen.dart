import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_event_service.dart';
import 'event_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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
            .listen((snapshot) {
          if (mounted) {
            setState(() {
              _notifications = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  ...data,
                };
              }).toList();
              _isLoading = false;
            });
          }
        }, onError: (error) {
          print('Error in notifications stream: $error');
          // Fallback to query without orderBy
          _loadNotificationsFallback();
        });
      } catch (e) {
        print('Error setting up notifications stream: $e');
        _loadNotificationsFallback();
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  void _loadNotificationsFallback() {
    try {
      final notificationsCol = _firestore.collection('notifications');
      _notificationsSubscription?.cancel();
      _notificationsSubscription = notificationsCol
          .limit(50)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              ...data,
            };
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
        }
      }, onError: (error) {
        print('Error in fallback notifications stream: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      print('Error in fallback: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      for (var notification in _notifications) {
        if (notification['read'] != true) {
          final docRef = _firestore.collection('notifications').doc(notification['id']);
          batch.update(docRef, {'read': true});
        }
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEvent(String eventId) async {
    try {
      final events = await FirebaseEventService.getAllEvents();
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
      print('Error navigating to event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((n) => n['read'] != true))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll see notifications here when there are updates',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _loadNotifications();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isRead = notification['read'] == true;
                      final type = notification['type'] as String?;
                      final createdAt = notification['createdAt'] as String?;
                      final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isRead ? 1 : 3,
                        color: isRead ? Colors.white : Colors.blue.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getNotificationColor(type),
                            child: Icon(
                              _getNotificationIcon(type),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            _getNotificationTitle(notification),
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(_getNotificationBody(notification)),
                              if (date != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, y • h:mm a').format(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isRead
                              ? null
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          onTap: () async {
                            if (!isRead) {
                              await _markAsRead(notification['id']);
                            }
                            
                            // Navigate based on notification type
                            if (type == 'new_event' || type == 'event_update' || type == 'event_reminder') {
                              final eventId = notification['eventId'] as String?;
                              if (eventId != null) {
                                _navigateToEvent(eventId);
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _getNotificationTitle(Map<String, dynamic> notification) {
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
      default:
        return notification['body'] as String? ?? 'You have a new notification';
    }
  }
}

