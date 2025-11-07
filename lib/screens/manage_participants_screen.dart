import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/qr_service.dart';

class ManageParticipantsScreen extends StatefulWidget {
  final Event event;

  const ManageParticipantsScreen({super.key, required this.event});

  @override
  State<ManageParticipantsScreen> createState() => _ManageParticipantsScreenState();
}

class _ManageParticipantsScreenState extends State<ManageParticipantsScreen> {
  List<User> _participants = [];
  bool _isLoading = true;
  bool _isScanning = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);
    
    try {
      final List<User> allUsers = await FirebaseUserService.getAllUsers();
      final participantIds = widget.event.participants;
      final participants = allUsers.where((user) => participantIds.contains(user.id)).toList();
      
      setState(() {
        _participants = participants;
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

    // Check if user is already registered
    if (widget.event.participants.contains(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User is already registered for this event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Register user for event
    final success = await FirebaseEventService.registerForEvent(eventId, userId);
    if (success) {
      await _loadParticipants();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to register user'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Participants (${_participants.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showQRScanner,
            tooltip: 'Scan QR Code',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Event Info Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Participants: ${_participants.length}/${widget.event.maxParticipants}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _participants.length / widget.event.maxParticipants,
                          backgroundColor: Colors.grey[300],
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
                
                // Participants List
                Expanded(
                  child: _participants.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No participants yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Scan QR codes to register participants',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _participants.length,
                          itemBuilder: (context, index) {
                            final participant = _participants[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1976D2),
                                  child: Text(
                                    participant.name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(participant.name),
                                subtitle: Text(participant.email),
                                trailing: PopupMenuButton(
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
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQRScanner,
        child: const Icon(Icons.qr_code_scanner),
        tooltip: 'Scan QR Code',
      ),
    );
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
