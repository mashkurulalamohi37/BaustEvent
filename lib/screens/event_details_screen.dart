import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/qr_service.dart';
import 'qr_code_screen.dart';
import 'edit_event_screen.dart';
import 'manage_participants_screen.dart';
import 'welcome_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  final bool isOrganizer;
  final String? userId;

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.isOrganizer = false,
    this.userId,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Event _event;
  User? _currentUser;
  bool _isRegistered = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user;
    // If userId is provided, fetch user details
    if (widget.userId != null) {
      user = await FirebaseUserService.getUserById(widget.userId!);
    } else {
      user = await FirebaseUserService.getCurrentUserWithDetails();
    }
    
    setState(() {
      _currentUser = user;
      if (user != null) {
        _isRegistered = _event.participants.contains(user.id);
      } else {
        _isRegistered = false;
      }
    });
  }

  // Check if current user is a guest
  bool _isGuestUser() {
    // If no userId was passed, user is likely a guest
    if (widget.userId == null && _currentUser == null) {
      return true;
    }
    // If current user exists and is a guest user
    if (_currentUser != null) {
      return _currentUser!.email == 'guest@eventbridge.com' || 
             _currentUser!.id.startsWith('guest_');
    }
    return false;
  }

  Future<void> _toggleRegistration() async {
    // Prevent guest users from registering
    if (!_isRegistered && _isGuestUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in or sign up to register for events.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Login',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const WelcomeScreen(),
                ),
                (route) => false,
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Ensure we have a valid logged-in user
    if (_currentUser == null) {
      if (widget.userId != null) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to register for events.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Use widget.userId if available, otherwise use currentUser.id
    String userId;
    if (widget.userId != null) {
      userId = widget.userId!;
    } else {
      userId = _currentUser!.id;
    }
    
    // Double-check registration status before proceeding
    if (!_isRegistered && _event.participants.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already registered for this event.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      // Refresh event data
      final updatedEvent = await FirebaseEventService.getAllEvents()
          .then((events) => events.firstWhere((e) => e.id == _event.id));
      setState(() {
        _event = updatedEvent;
        _isRegistered = true;
      });
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      bool success;
      if (_isRegistered) {
        success = await FirebaseEventService.unregisterFromEvent(_event.id, userId);
      } else {
        // Additional check in service will prevent duplicate registration
        success = await FirebaseEventService.registerForEvent(_event.id, userId);
      }

      if (success) {
        // Refresh event data
        final updatedEvent = await FirebaseEventService.getAllEvents()
            .then((events) => events.firstWhere((e) => e.id == _event.id));
        
        setState(() {
          _event = updatedEvent;
          _isRegistered = !_isRegistered;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRegistered 
                ? 'Successfully registered for event!' 
                : 'Successfully unregistered from event!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update registration. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showQRCode() async {
    // Ensure we have a valid logged-in user (guests can't show QR code)
    if (_currentUser == null || _isGuestUser()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to view your QR code.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = _currentUser!.id;

    final qrData = QRService.generateEventQRData(_event.id, userId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCodeScreen(
          data: qrData,
          title: 'Event Registration QR Code',
          subtitle: 'Show this QR code at the event for check-in',
        ),
      ),
    );
  }

  Future<void> _deleteEvent() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
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

    setState(() => _isLoading = true);

    try {
      print('Deleting event: ${_event.id}');
      final success = await FirebaseEventService.deleteEvent(_event.id);
      print('Delete result: $success');
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } else {
        if (mounted) {
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
      print('Exception during delete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markEventAsDone() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Event as Done'),
        content: const Text(
          'Are you sure you want to mark this event as completed?',
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

    setState(() => _isLoading = true);

    try {
      print('Marking event as completed: ${_event.id}');
      final success = await FirebaseEventService.markEventAsCompleted(_event.id);
      print('Mark as done result: $success');
      if (success) {
        // Refresh event data
        try {
          final updatedEvent = await FirebaseEventService.getAllEvents()
              .then((events) => events.firstWhere((e) => e.id == _event.id));
          
          if (mounted) {
            setState(() {
              _event = updatedEvent;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Event marked as completed!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          print('Error refreshing event after status update: $e');
          // Still show success since the update worked
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Event marked as completed!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
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
      print('Exception during mark as done: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        actions: [
          if (_isRegistered && !widget.isOrganizer)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _showQRCode,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image Placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _event.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                      ),
                    )
                  : _buildImagePlaceholder(),
            ),
            const SizedBox(height: 16),
            
            // Event Title
            Text(
              _event.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Event Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Event Details
            _buildDetailRow(Icons.calendar_today, 'Date', 
                DateFormat('EEEE, MMMM d, y').format(_event.date)),
            _buildDetailRow(Icons.access_time, 'Time', _event.time),
            _buildDetailRow(Icons.location_on, 'Location', _event.location),
            _buildDetailRow(Icons.category, 'Category', _event.category),
            _buildDetailRow(Icons.people, 'Participants', 
                '${_event.participants.length}/${_event.maxParticipants}'),
            
            const SizedBox(height: 16),
            
            // Description
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _event.description,
              style: const TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            if (!widget.isOrganizer) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _toggleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRegistered ? Colors.red : const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isRegistered ? 'Unregister' : 'Register',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ] else ...[
              // Organizer actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditEventScreen(event: _event),
                          ),
                        ).then((_) => _loadUserData());
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Edit Event'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageParticipantsScreen(event: _event),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Manage'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Mark as Done button (only if not already completed)
                  if (_event.status != EventStatus.completed)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _markEventAsDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, color: Colors.white),
                        label: const Text(
                          'Mark as Done',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (_event.status != EventStatus.completed) const SizedBox(width: 12),
                  // Delete button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _deleteEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Delete Event',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event, size: 60, color: Colors.grey),
          SizedBox(height: 8),
          Text('No Image Available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_event.status) {
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

  String _getStatusText() {
    switch (_event.status) {
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
}
