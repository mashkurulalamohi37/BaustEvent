import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/event.dart';
import '../models/user.dart';
import '../models/participant_registration_info.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/qr_service.dart';
import '../services/theme_service.dart';

class ManageParticipantsScreen extends StatefulWidget {
  final Event event;

  const ManageParticipantsScreen({super.key, required this.event});

  @override
  State<ManageParticipantsScreen> createState() => _ManageParticipantsScreenState();
}

class _ManageParticipantsScreenState extends State<ManageParticipantsScreen> {
  List<User> _participants = [];
  Map<String, ParticipantRegistrationInfo> _participantInfo = {};
  List<ParticipantRegistrationInfo> _pendingRegistrations = [];
  Map<String, User> _pendingUsers = {};
  bool _isLoading = true;
  bool _isScanning = false;
  MobileScannerController? _scannerController;
  Set<String> _expandedParticipants = {};
  StreamSubscription<QuerySnapshot>? _pendingRegistrationsSubscription;
  
  // Filter options
  String? _selectedHall;
  String? _selectedGender;
  String? _selectedBatch;
  String? _selectedFood;
  String? _selectedTshirtSize;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _setupPendingRegistrationsListener();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _pendingRegistrationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    
    try {
      final participantIds = widget.event.participants;
      
      // Optimize: Only load participant users, not all users
      // For large events (1000+), use batch loading
      final List<User> participants;
      if (participantIds.length > 1000) {
        // Load users in batches for large events (Firestore whereIn limit is 10)
        participants = await FirebaseUserService.getUsersByIds(participantIds);
      } else {
        // For smaller events, check if loading all users is faster
        final allUsers = await FirebaseUserService.getAllUsers();
        participants = allUsers.where((user) => participantIds.contains(user.id)).toList();
      }
      
      // Load participant registration info
      final participantInfoList = await FirebaseEventService.getEventParticipantInfo(
        widget.event.id,
      );
      final participantInfoMap = <String, ParticipantRegistrationInfo>{};
      for (var info in participantInfoList) {
        participantInfoMap[info.userId] = info;
      }
      
      // Load pending registrations (hand cash payments awaiting approval)
      final pendingList = await FirebaseEventService.getPendingRegistrations(widget.event.id);
      
      // Load pending users efficiently using batch loading
      final pendingUserIds = pendingList.map((info) => info.userId).toList();
      final pendingUsersList = pendingUserIds.isNotEmpty
          ? await FirebaseUserService.getUsersByIds(pendingUserIds)
          : <User>[];
      final pendingUsersMap = <String, User>{};
      
      for (var pendingInfo in pendingList) {
        final user = pendingUsersList.firstWhere(
          (u) => u.id == pendingInfo.userId,
          orElse: () => User(
            id: pendingInfo.userId,
            email: 'Unknown',
            name: 'Unknown User',
            universityId: '',
            type: UserType.participant,
            createdAt: DateTime.now(),
          ),
        );
        pendingUsersMap[pendingInfo.userId] = user;
      }
      
      setState(() {
        _participants = participants;
        _participantInfo = participantInfoMap;
        _pendingRegistrations = pendingList;
        _pendingUsers = pendingUsersMap;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load participants'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setupPendingRegistrationsListener() {
    try {
      _pendingRegistrationsSubscription?.cancel();
      
      // Listen to all event_participants documents for this event
      _pendingRegistrationsSubscription = FirebaseFirestore.instance
          .collection('event_participants')
          .where('eventId', isEqualTo: widget.event.id)
          .snapshots()
          .listen((snapshot) {
        
        // Filter for pending hand cash registrations
        final pendingList = <ParticipantRegistrationInfo>[];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final paymentMethod = data['paymentMethod'] as String?;
          final paymentStatus = data['paymentStatus'] as String?;
          
          if (paymentMethod == 'handCash' && paymentStatus == 'pending') {
            try {
              pendingList.add(ParticipantRegistrationInfo.fromFirestore(data));
            } catch (e) {
              print('Error parsing pending registration ${doc.id}: $e');
            }
          }
        }
        
        if (mounted) {
          // Reload users to match pending registrations (optimized for large lists)
          final pendingUserIds = pendingList.map((info) => info.userId).toList();
          if (pendingUserIds.isNotEmpty) {
            FirebaseUserService.getUsersByIds(pendingUserIds).then((pendingUsersList) {
              final pendingUsersMap = <String, User>{};
              for (var pendingInfo in pendingList) {
                final user = pendingUsersList.firstWhere(
                  (u) => u.id == pendingInfo.userId,
                  orElse: () => User(
                    id: pendingInfo.userId,
                    email: 'Unknown',
                    name: 'Unknown User',
                    universityId: '',
                    type: UserType.participant,
                    createdAt: DateTime.now(),
                  ),
                );
                pendingUsersMap[pendingInfo.userId] = user;
              }
              
              setState(() {
                _pendingRegistrations = pendingList;
                _pendingUsers = pendingUsersMap;
              });
            }).catchError((e) {
              print('Error loading users for pending registrations: $e');
            });
          } else {
            setState(() {
              _pendingRegistrations = pendingList;
              _pendingUsers = {};
            });
          }
        }
      }, onError: (error) {
        print('Error in pending registrations stream: $error');
      });
    } catch (e) {
      print('Error setting up pending registrations listener: $e');
    }
  }
  
  Map<String, Map<String, List<User>>> _groupByBatchAndSection() {
    final filteredParticipants = _getFilteredParticipants();
    final grouped = <String, Map<String, List<User>>>{};
    
    for (var participant in filteredParticipants) {
      final info = _participantInfo[participant.id];
      // Check if batch exists and is not empty
      String batch = 'Not Specified';
      if (info?.batch != null) {
        final batchValue = info!.batch!.trim();
        if (batchValue.isNotEmpty) {
          batch = batchValue;
        }
      }
      
      // Check if section exists and is not empty
      String section = 'Not Specified';
      if (info?.section != null) {
        final sectionValue = info!.section!.trim();
        if (sectionValue.isNotEmpty) {
          section = sectionValue;
        }
      }
      
      // Debug: print actual values
      print('Grouping participant ${participant.name}: batch="$batch", section="$section"');
      print('  - Info batch: ${info?.batch}, section: ${info?.section}');
      
      if (!grouped.containsKey(batch)) {
        grouped[batch] = <String, List<User>>{};
      }
      if (!grouped[batch]!.containsKey(section)) {
        grouped[batch]![section] = <User>[];
      }
      grouped[batch]![section]!.add(participant);
    }
    
    return grouped;
  }
  
  List<User> _getFilteredParticipants() {
    return _participants.where((participant) {
      final info = _participantInfo[participant.id];
      
      // Filter by Hall
      if (_selectedHall != null && _selectedHall!.isNotEmpty) {
        final participantHall = info?.hall?.trim() ?? '';
        final selectedHall = _selectedHall!.trim();
        if (participantHall.isEmpty || participantHall != selectedHall) {
          return false;
        }
      }
      
      // Filter by Gender
      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        final participantGender = info?.gender?.trim() ?? '';
        final selectedGender = _selectedGender!.trim();
        if (participantGender.isEmpty || participantGender != selectedGender) {
          return false;
        }
      }
      
      // Filter by Batch
      if (_selectedBatch != null && _selectedBatch!.isNotEmpty) {
        final participantBatch = info?.batch?.trim() ?? '';
        final selectedBatch = _selectedBatch!.trim();
        if (participantBatch.isEmpty || participantBatch != selectedBatch) {
          return false;
        }
      }
      
      // Filter by Food
      if (_selectedFood != null && _selectedFood!.isNotEmpty) {
        final participantFood = info?.foodPreference?.trim() ?? '';
        final selectedFood = _selectedFood!.trim();
        if (participantFood.isEmpty || participantFood != selectedFood) {
          return false;
        }
      }
      
      // Filter by T-shirt Size
      if (_selectedTshirtSize != null && _selectedTshirtSize!.isNotEmpty) {
        final participantSize = info?.tshirtSize?.trim() ?? '';
        final selectedSize = _selectedTshirtSize!.trim();
        if (participantSize.isEmpty || participantSize != selectedSize) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }
  
  List<String> _getAvailableHalls() {
    final halls = <String>{};
    for (var info in _participantInfo.values) {
      if (info.hall != null && info.hall!.isNotEmpty) {
        halls.add(info.hall!);
      }
    }
    return halls.toList()..sort();
  }
  
  List<String> _getAvailableGenders() {
    final genders = <String>{};
    for (var info in _participantInfo.values) {
      if (info.gender != null && info.gender!.isNotEmpty) {
        genders.add(info.gender!);
      }
    }
    return genders.toList()..sort();
  }
  
  List<String> _getAvailableBatches() {
    final batches = <String>{};
    for (var info in _participantInfo.values) {
      if (info.batch != null && info.batch!.trim().isNotEmpty) {
        batches.add(info.batch!.trim());
      }
    }
    return batches.toList()..sort();
  }
  
  List<String> _getAvailableFoods() {
    final foods = <String>{};
    for (var info in _participantInfo.values) {
      if (info.foodPreference != null && info.foodPreference!.isNotEmpty) {
        foods.add(info.foodPreference!);
      }
    }
    return foods.toList()..sort();
  }
  
  List<String> _getAvailableTshirtSizes() {
    final sizes = <String>{};
    for (var info in _participantInfo.values) {
      if (info.tshirtSize != null && info.tshirtSize!.trim().isNotEmpty) {
        sizes.add(info.tshirtSize!.trim());
      }
    }
    return sizes.toList()..sort();
  }

  Future<void> _removeParticipant(User participant) async {
    final success = await FirebaseEventService.unregisterFromEvent(widget.event.id, participant.id);
    if (success) {
      await _loadParticipants();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${participant.name} removed from event'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove participant'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQRScanner() {
    setState(() => _isScanning = true);
    _scannerController = MobileScannerController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            controller: _scannerController!,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processQRCode(barcode.rawValue!);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = false);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() => _isScanning = false);
    
    final qrInfo = QRService.parseQRData(qrData);
    
    if (!QRService.isValidQRData(qrInfo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!QRService.isEventRegistrationQR(qrInfo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR code is not for event registration'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final eventId = qrInfo!['eventId'];
    final userId = qrInfo['userId'];

    if (eventId != widget.event.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This QR code is for a different event'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fetch user and registration info
    try {
      final user = await FirebaseUserService.getUserById(userId);
      if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User not found'),
            backgroundColor: Colors.red,
        ),
      );
      return;
    }

      final registrationInfo = await FirebaseEventService.getParticipantRegistrationInfo(
        eventId,
        userId,
      );

      // Show participant profile
      _showParticipantProfile(user, registrationInfo);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading participant profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showParticipantProfile(User user, ParticipantRegistrationInfo? info) {
    final themeService = ThemeService.instance ?? ThemeService();
    final isDark = themeService.isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Participant Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // User Info Card
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF1976D2),
                              child: Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[300] : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (user.universityId.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${user.universityId}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[300] : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Registration Status
                    Container(
                      decoration: BoxDecoration(
                        color: widget.event.participants.contains(user.id)
                            ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
                            : (isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              widget.event.participants.contains(user.id)
                                  ? Icons.check_circle
                                  : Icons.pending,
                              color: widget.event.participants.contains(user.id)
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.event.participants.contains(user.id)
                                    ? 'Registered'
                                    : 'Not Registered',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: widget.event.participants.contains(user.id)
                                      ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                                      : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Registration Details - Always show, even if info is null
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registration Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (info != null) ...[
                              _buildDetailRow(Icons.school, 'Level', info.level != null ? 'Level ${info.level!}' : 'Not specified', isDark),
                              _buildDetailRow(Icons.calendar_view_month, 'Term', info.term != null ? 'Term ${info.term}' : 'Not specified', isDark),
                              _buildDetailRow(Icons.groups, 'Batch', info.batch ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.class_, 'Section', info.section ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.checkroom, 'T-shirt Size', info.tshirtSize ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.restaurant, 'Food Preference', info.foodPreference ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.home, 'Hall', info.hall ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.person, 'Gender', info.gender ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.phone, 'Personal Number', info.personalNumber ?? 'Not specified', isDark),
                              _buildDetailRow(Icons.phone_android, 'Guardian Number', info.guardianNumber ?? 'Not specified', isDark),
                              if (info.registeredAt != null)
                                _buildDetailRow(
                                  Icons.access_time,
                                  'Registered At',
                                  _formatDate(info.registeredAt),
                                  isDark,
                                ),
                              if (info.paymentMethod != null) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.payment,
                                  'Payment Method',
                                  info.paymentMethod == 'handCash' ? 'Hand Cash' : 'bKash',
                                  isDark,
                                ),
                                if (info.paymentStatus != null)
                                  _buildDetailRow(
                                    Icons.info,
                                    'Payment Status',
                                    info.paymentStatus!.toUpperCase(),
                                    isDark,
                                  ),
                              ],
                            ] else ...[
                              _buildDetailRow(Icons.school, 'Level', 'Not specified', isDark),
                              _buildDetailRow(Icons.calendar_view_month, 'Term', 'Not specified', isDark),
                              _buildDetailRow(Icons.groups, 'Batch', 'Not specified', isDark),
                              _buildDetailRow(Icons.class_, 'Section', 'Not specified', isDark),
                              _buildDetailRow(Icons.checkroom, 'T-shirt Size', 'Not specified', isDark),
                              _buildDetailRow(Icons.restaurant, 'Food Preference', 'Not specified', isDark),
                              _buildDetailRow(Icons.home, 'Hall', 'Not specified', isDark),
                              _buildDetailRow(Icons.person, 'Gender', 'Not specified', isDark),
                              _buildDetailRow(Icons.phone, 'Personal Number', 'Not specified', isDark),
                              _buildDetailRow(Icons.phone_android, 'Guardian Number', 'Not specified', isDark),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    if (!widget.event.participants.contains(user.id)) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
    if (_participants.length >= widget.event.maxParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This event has reached its participant limit.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

                          final result = await FirebaseEventService.registerForEvent(
                            widget.event.id,
                            user.id,
                          );
    if (result.isSuccess) {
                            Navigator.pop(context);
      await _loadParticipants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User registered successfully!'),
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
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Register User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mapRegistrationStatusToMessage(RegistrationStatus status) {
    switch (status) {
      case RegistrationStatus.alreadyRegistered:
        return 'User is already registered for this event.';
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
        return 'Failed to register user.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService.instance ?? ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isDark = themeService.isDarkMode;
        return Scaffold(
          appBar: AppBar(
            title: Text('Manage Participants (${_participants.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadParticipants,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _showQRScanner,
                tooltip: 'Scan QR Code',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                  length: 2,
                  child: Column(
                  children: [
                    // Event Info Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                            Text(
                              'Total Participants: ${_participants.length}/${widget.event.maxParticipants}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                                ),
                                if (_pendingRegistrations.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.orange.shade700 : Colors.orange.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pending_actions,
                                          size: 16,
                                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_pendingRegistrations.length} Pending',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _participants.length / widget.event.maxParticipants,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _participants.length >= widget.event.maxParticipants
                                    ? Colors.red
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                
                  // Filter Section (Hidden by default, can be toggled)
                  if (_showFilters)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 20,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedHall != null || _selectedGender != null || 
                                  _selectedBatch != null || _selectedFood != null || _selectedTshirtSize != null)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedHall = null;
                                      _selectedGender = null;
                                      _selectedBatch = null;
                                      _selectedFood = null;
                                      _selectedTshirtSize = null;
                                    });
                                  },
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              final isSmallScreen = screenWidth < 400;
                              final isMediumScreen = screenWidth >= 400 && screenWidth < 600;
                              final containerPadding = 32.0; // 16px on each side
                              final spacing = 8.0;
                              final availableWidth = screenWidth - containerPadding;
                              
                              // Calculate item width based on screen size
                              // Use fewer columns to prevent overflow
                              double itemWidth;
                              int columns;
                              if (isSmallScreen) {
                                // 2 columns on small screens
                                columns = 2;
                                itemWidth = (availableWidth - spacing) / columns;
                              } else if (isMediumScreen) {
                                // 3 columns on medium screens
                                columns = 3;
                                itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;
                              } else {
                                // 4 columns on large screens to prevent overflow
                                columns = 4;
                                itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;
                                // Ensure minimum width
                                if (itemWidth < 100) {
                                  columns = 3;
                                  itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;
                                }
                              }
                              
                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                alignment: WrapAlignment.start,
                                children: [
                                  // Hall Filter
                                  SizedBox(
                                    width: itemWidth,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedHall,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Hall',
                                        prefixIcon: const Icon(Icons.home, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All Halls'),
                                        ),
                                        ..._getAvailableHalls().map((hall) => DropdownMenuItem(
                                          value: hall,
                                          child: Text(
                                            hall.length > 20 ? '${hall.substring(0, 20)}...' : hall,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedHall = value;
                                        });
                                      },
                                    ),
                                  ),
                                  // Gender Filter
                                  SizedBox(
                                    width: itemWidth,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedGender,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Gender',
                                        prefixIcon: const Icon(Icons.person, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All'),
                                        ),
                                        ..._getAvailableGenders().map((gender) => DropdownMenuItem(
                                          value: gender,
                                          child: Text(gender),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedGender = value;
                                        });
                                      },
                                    ),
                                  ),
                                  // Batch Filter
                                  SizedBox(
                                    width: itemWidth,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedBatch,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Batch',
                                        prefixIcon: const Icon(Icons.groups, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All'),
                                        ),
                                        ..._getAvailableBatches().map((batch) => DropdownMenuItem(
                                          value: batch,
                                          child: Text(batch),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedBatch = value;
                                        });
                                      },
                                    ),
                                  ),
                                  // Food Filter
                                  SizedBox(
                                    width: itemWidth,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedFood,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Food',
                                        prefixIcon: const Icon(Icons.restaurant, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All'),
                                        ),
                                        ..._getAvailableFoods().map((food) => DropdownMenuItem(
                                          value: food,
                                          child: Text(food),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedFood = value;
                                        });
                                      },
                                    ),
                                  ),
                                  // T-shirt Size Filter
                                  SizedBox(
                                    width: itemWidth,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedTshirtSize,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'T-shirt Size',
                                        prefixIcon: const Icon(Icons.checkroom, size: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('All'),
                                        ),
                                        ..._getAvailableTshirtSizes().map((size) => DropdownMenuItem(
                                          value: size,
                                          child: Text(size),
                                        )),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedTshirtSize = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                
                  // Filter Toggle Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showFilters = !_showFilters;
                            });
                          },
                          icon: Icon(
                            _showFilters ? Icons.filter_list_off : Icons.filter_list,
                            color: isDark ? Colors.white : Colors.blue,
                          ),
                          label: Text(
                            _showFilters ? 'Hide Filters' : 'Show Filters',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.blue,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                  // Tab Bar
                  TabBar(
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Participants\n(${_participants.length})',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pending_actions, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Pending\n(${_pendingRegistrations.length})',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Tab Content
                Expanded(
                    child: TabBarView(
                      children: [
                        _participants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: isDark ? Colors.grey[400] : Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No participants yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDark ? Colors.grey[300] : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scan QR codes to register participants',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildGroupedParticipantsList(isDark),
                        _buildPendingApprovalsList(isDark),
                      ],
                    ),
                ),
              ],
              ),
            ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showQRScanner,
            child: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Code',
          ),
        );
      },
    );
  }

  Widget _buildGroupedParticipantsList(bool isDark) {
    final grouped = _groupByBatchAndSection();
    final batchKeys = grouped.keys.toList()..sort();
    
    if (batchKeys.isEmpty) {
      final filteredParticipants = _getFilteredParticipants();
      return ListView.builder(
        itemCount: filteredParticipants.length,
        itemBuilder: (context, index) {
          final participant = filteredParticipants[index];
          return _buildParticipantCard(participant, isDark);
        },
      );
    }
    
    return ListView.builder(
      itemCount: batchKeys.length,
      itemBuilder: (context, batchIndex) {
        final batch = batchKeys[batchIndex];
        final sections = grouped[batch]!;
        final sectionKeys = sections.keys.toList()..sort();
        
        int batchTotal = 0;
        for (var section in sections.values) {
          batchTotal += section.length;
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: batch == 'Not Specified'
                    ? (isDark ? Colors.grey[900] : Colors.grey.shade100)
                    : (isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: batch == 'Not Specified'
                      ? (isDark ? Colors.grey[700]! : Colors.grey.shade300)
                      : (isDark ? Colors.blue.shade700 : Colors.blue.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    batch == 'Not Specified' ? 'Batch: Not Specified' : 'Batch: $batch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: batch == 'Not Specified'
                          ? (isDark ? Colors.grey[300] : Colors.grey.shade700)
                          : (isDark ? Colors.blue.shade300 : Colors.blue.shade900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: batch == 'Not Specified'
                          ? (isDark ? Colors.grey[700] : Colors.grey.shade600)
                          : Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$batchTotal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sections within batch
            ...sectionKeys.map((section) {
              final sectionParticipants = sections[section]!;
              final sectionCount = sectionParticipants.length;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          section == 'Not Specified' ? 'Section: Not Specified' : 'Section $section',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$sectionCount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Participants in section
                  ...sectionParticipants.map((participant) => _buildParticipantCard(participant, isDark)),
                ],
              );
            }),
            
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
  
  Widget _buildParticipantCard(User participant, bool isDark) {
    final info = _participantInfo[participant.id];
    final hasInfo = info != null && (
      info.level != null ||
      info.term != null ||
      info.batch != null ||
      info.section != null ||
      info.tshirtSize != null ||
      info.foodPreference != null ||
      info.hall != null ||
      info.gender != null ||
      info.personalNumber != null ||
      info.guardianNumber != null
    );
    final isExpanded = _expandedParticipants.contains(participant.id);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
        padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      // Tappable participant name row
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: hasInfo ? () {
                            setState(() {
                              if (isExpanded) {
                                _expandedParticipants.remove(participant.id);
                              } else {
                                _expandedParticipants.add(participant.id);
                              }
                            });
                          } : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1976D2),
                  child: Text(
                    participant.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                                      Row(
                                        children: [
                                            Expanded(
                                            child: Text(
                        participant.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                                            ),
                                          ),
                                          if (hasInfo)
                                            Icon(
                                              isExpanded ? Icons.expand_less : Icons.expand_more,
                                              color: isDark ? Colors.grey[300] : Colors.grey.shade600,
                                              size: 20,
                                            ),
                                        ],
                      ),
                      Text(
                        participant.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[300] : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'remove',
                      child: const Row(
                        children: [
                          Icon(Icons.remove_circle, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'remove') {
                      _showRemoveConfirmation(participant);
                    }
                  },
                ),
              ],
            ),
          ),
          // Expanded details section - shown when name is tapped
          if (isExpanded && info != null) ...[
              Divider(
                height: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Registration Details', isDark, [
                    _buildDetailRow(Icons.school, 'Level', info.level != null ? 'Level ${info.level!}' : 'Not specified', isDark),
                    if (info.term != null)
                      _buildDetailRow(Icons.calendar_view_month, 'Term', 'Term ${info.term!}', isDark),
                    if (info.batch != null)
                      _buildDetailRow(Icons.groups, 'Batch', info.batch!, isDark),
                    if (info.section != null)
                      _buildDetailRow(Icons.class_, 'Section', 'Section ${info.section!}', isDark),
                    if (info.tshirtSize != null)
                      _buildDetailRow(Icons.checkroom, 'T-shirt Size', info.tshirtSize!, isDark),
                    if (info.foodPreference != null)
                      _buildDetailRow(Icons.restaurant, 'Food Preference', info.foodPreference!, isDark),
                    _buildDetailRow(Icons.home, 'Hall', info.hall ?? 'Not specified', isDark),
                    _buildDetailRow(Icons.person, 'Gender', info.gender ?? 'Not specified', isDark),
                    _buildDetailRow(Icons.phone, 'Personal Number', info.personalNumber ?? 'Not specified', isDark),
                    _buildDetailRow(Icons.phone_android, 'Guardian Number', info.guardianNumber ?? 'Not specified', isDark),
                  ]),
                  if (info.registeredAt != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time,
                      'Registered At',
                      _formatDate(info.registeredAt),
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  

  Widget _buildDetailSection(String title, bool isDark, List<Widget> details) {
    if (details.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
    
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPendingApprovalsList(bool isDark) {
    if (_pendingRegistrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: isDark ? Colors.grey[400] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No pending approvals',
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.grey[300] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All hand cash payments have been processed',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _pendingRegistrations.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final pendingInfo = _pendingRegistrations[index];
        final user = _pendingUsers[pendingInfo.userId];
        if (user == null) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.shade300,
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[300] : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.orange.shade800 : Colors.orange.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                ),
                const SizedBox(height: 12),
                if (pendingInfo.level != null ||
                    pendingInfo.term != null ||
                    pendingInfo.batch != null ||
                    pendingInfo.section != null ||
                    pendingInfo.tshirtSize != null ||
                    pendingInfo.foodPreference != null ||
                    pendingInfo.hall != null ||
                    pendingInfo.gender != null ||
                    pendingInfo.personalNumber != null ||
                    pendingInfo.guardianNumber != null) ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (pendingInfo.level != null)
                        _buildInfoChip(Icons.school, 'Level', pendingInfo.level!, isDark),
                      if (pendingInfo.term != null)
                        _buildInfoChip(Icons.calendar_view_month, 'Term', pendingInfo.term!, isDark),
                      if (pendingInfo.batch != null)
                        _buildInfoChip(Icons.groups, 'Batch', pendingInfo.batch!, isDark),
                      if (pendingInfo.section != null)
                        _buildInfoChip(Icons.class_, 'Section', pendingInfo.section!, isDark),
                      if (pendingInfo.tshirtSize != null)
                        _buildInfoChip(Icons.checkroom, 'T-shirt', pendingInfo.tshirtSize!, isDark),
                      if (pendingInfo.foodPreference != null)
                        _buildInfoChip(Icons.restaurant, 'Food', pendingInfo.foodPreference!, isDark),
                      if (pendingInfo.hall != null)
                        _buildInfoChip(Icons.home, 'Hall', pendingInfo.hall!, isDark),
                      if (pendingInfo.gender != null)
                        _buildInfoChip(Icons.person, 'Gender', pendingInfo.gender!, isDark),
                      if (pendingInfo.personalNumber != null)
                        _buildInfoChip(Icons.phone, 'Number', pendingInfo.personalNumber!, isDark),
                      if (pendingInfo.guardianNumber != null)
                        _buildInfoChip(Icons.phone_android, 'Guardian', pendingInfo.guardianNumber!, isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectPendingRegistration(user, pendingInfo),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approvePendingRegistration(user, pendingInfo),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.blue.shade300 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePendingRegistration(User user, ParticipantRegistrationInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text('Approve ${user.name}\'s hand cash payment registration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final success = await FirebaseEventService.approvePendingRegistration(
      widget.event.id,
      user.id,
    );
    
    if (success) {
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name}\'s registration approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve registration'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPendingRegistration(User user, ParticipantRegistrationInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Text('Reject ${user.name}\'s hand cash payment registration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final success = await FirebaseEventService.rejectPendingRegistration(
      widget.event.id,
      user.id,
    );
    
    if (success) {
      await _loadParticipants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name}\'s registration rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject registration'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRemoveConfirmation(User participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Are you sure you want to remove ${participant.name} from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeParticipant(participant);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
