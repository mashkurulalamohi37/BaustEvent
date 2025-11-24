import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/event.dart';
import '../models/user.dart';
import '../models/participant_registration_info.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/qr_service.dart';
import '../services/bkash_payment_service.dart';
import 'qr_code_screen.dart';
import 'edit_event_screen.dart';
import 'manage_participants_screen.dart';
import 'welcome_screen.dart';
import 'participant_registration_form_screen.dart';

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
  bool _isPending = false; // Track pending hand cash registration
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _eventSubscription;
  StreamSubscription<QuerySnapshot>? _pendingRegistrationsSubscription;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadUserData().then((_) {
      // Setup listeners after user data is loaded
      _setupEventListener();
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pendingRegistrationsSubscription?.cancel();
    super.dispose();
  }

  void _setupEventListener() {
    // Listen to event changes in real-time to detect when user becomes registered
    _eventSubscription?.cancel();
    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(_event.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        try {
          final updatedEvent = EventFirestore.fromFirestore(snapshot);
          setState(() {
            _event = updatedEvent;
            // Update registration status
            if (_currentUser != null) {
              _isRegistered = _event.participants.contains(_currentUser!.id);
              // If now registered, clear pending status
              if (_isRegistered) {
                _isPending = false;
              }
            }
          });
          print('Event updated: participants=${_event.participants.length}, isRegistered=$_isRegistered');
        } catch (e) {
          print('Error parsing event update: $e');
        }
      }
    }, onError: (error) {
      print('Error in event listener: $error');
    });
    
    // Listen to pending registrations to detect when user submits a hand cash request
    _pendingRegistrationsSubscription?.cancel();
    if (_currentUser != null) {
      _pendingRegistrationsSubscription = FirebaseFirestore.instance
          .collection('event_participants')
          .where('eventId', isEqualTo: _event.id)
          .where('userId', isEqualTo: _currentUser!.id)
          .snapshots()
          .listen((snapshot) {
        if (mounted && _currentUser != null) {
          // Check if user has a pending registration
          bool hasPending = false;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final paymentMethod = data['paymentMethod'] as String?;
            final paymentStatus = data['paymentStatus'] as String?;
            
            if (paymentMethod == 'handCash' && paymentStatus == 'pending') {
              hasPending = true;
              break;
            }
          }
          
          setState(() {
            // Only show pending if not registered
            _isPending = !_isRegistered && hasPending;
          });
          
          print('Pending registration status updated: isPending=$_isPending, isRegistered=$_isRegistered');
        }
      }, onError: (error) {
        print('Error in pending registrations listener: $error');
      });
    }
  }

  Future<void> _loadUserData() async {
    User? user;
    // If userId is provided, fetch user details
    if (widget.userId != null) {
      user = await FirebaseUserService.getUserById(widget.userId!);
    } else {
      user = await FirebaseUserService.getCurrentUserWithDetails();
    }
    
    // Refresh event data to get latest participants list
    try {
      final updatedEvent = await FirebaseEventService.getAllEvents()
          .then((events) => events.firstWhere((e) => e.id == _event.id, orElse: () => _event));
      setState(() {
        _event = updatedEvent;
      });
    } catch (e) {
      print('Error refreshing event data: $e');
    }
    
    if (user == null) {
      setState(() {
        _currentUser = null;
        _isRegistered = false;
        _isPending = false;
      });
      return;
    }
    
    // Check registration status
    final isRegistered = user != null && _event.participants.contains(user.id);
    
    // Check if user has pending hand cash registration (only if not already registered)
    bool isPending = false;
    if (!isRegistered && user != null) {
      try {
        print('Checking for pending registrations for userId: ${user.id}, eventId: ${_event.id}');
        final pendingRegistrations = await FirebaseEventService.getPendingRegistrations(_event.id);
        print('Found ${pendingRegistrations.length} total pending registrations');
        for (var info in pendingRegistrations) {
          print('  - Pending registration: userId=${info.userId}, paymentMethod=${info.paymentMethod}, paymentStatus=${info.paymentStatus}');
        }
        isPending = pendingRegistrations.any((info) => info.userId == user!.id);
        print('User has pending registration: $isPending');
      } catch (e) {
        print('Error checking pending registrations: $e');
      }
    }
    
    setState(() {
      _currentUser = user;
      _isRegistered = isRegistered;
      // Only show pending if not registered
      _isPending = !isRegistered && isPending;
    });
    
    print('Registration status updated: isRegistered=$_isRegistered, isPending=$_isPending');
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

  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.green),
              title: const Text('bKash'),
              subtitle: const Text('Pay online instantly'),
              onTap: () => Navigator.pop(context, 'bkash'),
            ),
            ListTile(
              leading: const Icon(Icons.money, color: Colors.orange),
              title: const Text('Hand Cash'),
              subtitle: const Text('Pay at event (requires approval)'),
              onTap: () => Navigator.pop(context, 'handCash'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _processPayment(String userId) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'User information not available',
      };
    }

    final transactionId = const Uuid().v4();
    final amount = _event.paymentAmount!;

    return await BKashPaymentService.processPayment(
      context: context,
      transactionId: transactionId,
      amount: amount,
      eventId: _event.id,
      eventTitle: _event.title,
      customerName: _currentUser!.name,
      customerPhone: _currentUser!.universityId, // Using universityId as phone, adjust as needed
    );
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

    // Prevent admins from registering for events
    if (_currentUser!.isAdmin && !_isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admins cannot register for events. Admins can only manage and view events.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => _isLoading = false);
      return;
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
    
    // Check if event date has passed - participants cannot register for past events
    if (_event.isEventDatePassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRegistered
                ? 'Cannot modify registration for a past event.'
                : 'Cannot register for a past event.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (_event.isRegistrationClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRegistered
                ? 'Registration changes are locked for this event.'
                : 'Registration is closed for this event.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (!_isRegistered && _event.participants.length >= _event.maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event has reached its participant limit.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      RegistrationResult result;
      if (_isRegistered) {
        final success = await FirebaseEventService.unregisterFromEvent(_event.id, userId);
        result = success
            ? const RegistrationResult(RegistrationStatus.success)
            : const RegistrationResult(
                RegistrationStatus.error,
                message: 'Failed to update registration. Please try again.',
              );
      } else {
        // Check if participant information is required
        final hasRequiredFields = _event.requireLevel ||
            _event.requireTerm ||
            _event.requireBatch ||
            _event.requireSection ||
            _event.requireTshirtSize ||
            _event.requireFood ||
            _event.requireHall ||
            _event.requireGender ||
            _event.requirePersonalNumber ||
            _event.requireGuardianNumber;
        
        ParticipantRegistrationInfo? registrationInfo;
        if (hasRequiredFields) {
          // Check if info already exists
          final existingInfo = await FirebaseEventService.getParticipantRegistrationInfo(
            _event.id,
            userId,
          );
          
          // Show form to collect/update participant info
          registrationInfo = await Navigator.push<ParticipantRegistrationInfo>(
            context,
            MaterialPageRoute(
              builder: (context) => ParticipantRegistrationFormScreen(
                event: _event,
                userId: userId,
                existingInfo: existingInfo,
              ),
            ),
          );
          
          if (registrationInfo == null) {
            setState(() => _isLoading = false);
            // User cancelled the form
            return;
          }
          
          // Save participant registration info
          await FirebaseEventService.saveParticipantRegistrationInfo(registrationInfo);
        }
        
        // Check if payment is required
        if (_event.paymentRequired && _event.paymentAmount != null && _event.paymentAmount! > 0) {
          // Show payment method selection if hand cash is allowed
          String? selectedPaymentMethod;
          if (_event.requireHandCash) {
            selectedPaymentMethod = await _showPaymentMethodDialog();
            if (selectedPaymentMethod == null) {
              setState(() => _isLoading = false);
              return; // User cancelled
            }
          } else {
            selectedPaymentMethod = 'bkash';
          }
          
          // Update registration info with payment method
          if (registrationInfo != null) {
            registrationInfo = registrationInfo!.copyWith(
              paymentMethod: selectedPaymentMethod,
              paymentStatus: selectedPaymentMethod == 'handCash' ? 'pending' : 'completed',
            );
          } else if (_event.paymentRequired) {
            // Create registration info if payment is required but no other fields are required
            registrationInfo = ParticipantRegistrationInfo(
              eventId: _event.id,
              userId: userId,
              paymentMethod: selectedPaymentMethod,
              paymentStatus: selectedPaymentMethod == 'handCash' ? 'pending' : 'completed',
              registeredAt: DateTime.now(),
            );
          }
          
          if (selectedPaymentMethod == 'bkash') {
            // Save registration info for bKash
            if (registrationInfo != null) {
              await FirebaseEventService.saveParticipantRegistrationInfo(registrationInfo!);
            }
            
            // Process bKash payment
            final paymentResult = await _processPayment(userId);
            
            if (!paymentResult['success']) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(paymentResult['message'] ?? 'Payment failed. Registration cancelled.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }
          } else if (selectedPaymentMethod == 'handCash') {
            // For hand cash, registration is pending approval
            // Ensure registrationInfo exists
            registrationInfo = (registrationInfo ?? ParticipantRegistrationInfo(
              eventId: _event.id,
              userId: userId,
              registeredAt: DateTime.now(),
            )).copyWith(
              paymentMethod: 'handCash',
              paymentStatus: 'pending',
            );
            
            // Save pending registration (not added to participants list yet)
            print('Saving hand cash pending registration for userId: $userId, eventId: ${_event.id}');
            final saved = await FirebaseEventService.savePendingRegistration(_event.id, userId, registrationInfo!);
            
            if (saved) {
              print('Pending registration saved successfully');
              setState(() {
                _isLoading = false;
                _isPending = true; // Immediately set pending status
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Registration submitted. Waiting for organizer approval.'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
              
              // Refresh user data to update registration status and show pending
              await _loadUserData();
            } else {
              print('Failed to save pending registration');
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to submit registration. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          }
        }
        
        // Additional check in service will prevent duplicate registration
        result = await FirebaseEventService.registerForEvent(_event.id, userId);
      }

      if (result.isSuccess) {
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
          SnackBar(
            content: Text(result.message ?? _mapRegistrationStatusToMessage(result.status)),
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
        return 'Failed to update registration. Please try again.';
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
    final bool isOrganizerOrAdmin = widget.isOrganizer || (_currentUser?.isAdmin ?? false);
    final bool eventDatePassed = _event.isEventDatePassed;
    final bool registrationClosed = _event.isRegistrationClosed || eventDatePassed;
    final DateTime? registrationCloseDate = _event.registrationCloseDate;

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
            if (_event.paymentRequired && _event.paymentAmount != null)
              _buildDetailRow(
                Icons.payment,
                'Registration Fee',
                '${_event.paymentAmount!.toStringAsFixed(2)} TK',
              ),
            if (registrationCloseDate != null)
              _buildDetailRow(
                Icons.lock_clock,
                registrationClosed ? 'Registration closed' : 'Registration closes',
                DateFormat('MMM d, y • h:mm a').format(registrationCloseDate.toLocal()),
              ),
            
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
            if (isOrganizerOrAdmin) ...[
              // Organizer/Admin actions
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
            ] else ...[
              // Participant actions
              if (_event.paymentRequired && _event.paymentAmount != null && !_isRegistered)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment Required: ${_event.paymentAmount!.toStringAsFixed(2)} TK',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || registrationClosed || _isPending) ? null : _toggleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: registrationClosed
                        ? Colors.grey
                        : _isPending
                            ? Colors.orange
                            : (_isRegistered ? Colors.red : const Color(0xFF1976D2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          registrationClosed
                              ? (eventDatePassed 
                                  ? (_isRegistered ? 'Event Passed' : 'Event Date Passed')
                                  : (_isRegistered ? 'Registration Locked' : 'Registration Closed'))
                              : _isPending
                                  ? 'Pending Approval'
                                  : (_isRegistered 
                                      ? 'Unregister' 
                                      : (_event.paymentRequired && _event.paymentAmount != null
                                          ? 'Pay & Register'
                                          : 'Register')),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              if (registrationClosed)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    eventDatePassed
                        ? 'This event has already passed.'
                        : (registrationCloseDate != null
                            ? 'Registration closed on ${DateFormat('MMM d, y • h:mm a').format(registrationCloseDate.toLocal())}.'
                            : 'Registration is closed for this event.'),
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
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
