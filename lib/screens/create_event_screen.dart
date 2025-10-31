import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../services/firebase_event_service.dart';
import '../services/firebase_user_service.dart';
import '../services/firebase_storage_service.dart';
import '../widgets/custom_text_field.dart';

class CreateEventScreen extends StatefulWidget {
  final String? organizerId;
  
  const CreateEventScreen({super.key, this.organizerId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '100');
  
  DateTime? _selectedDate;
  String _selectedCategory = 'Seminars';
  bool _isLoading = false;
  User? _currentUser;
  XFile? _selectedImage;
  String? _imageUrl;

  final List<String> _categories = [
    'Seminars',
    'Workshops',
    'Cultural',
    'Competitions',
    'Conferences',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await FirebaseUserService.getCurrentUserWithDetails();
    setState(() => _currentUser = user);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    
    if (time != null) {
      setState(() => _timeController.text = time.format(context));
    }
  }

  Future<void> _pickImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() => _selectedImage = picked);
      }
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date for the event'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Prevent multiple clicks
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Determine organizer ID: use passed organizerId, or current user, or create guest
      String organizerId;
      
      // Priority 1: Use organizerId passed from parent (dashboard)
      if (widget.organizerId != null) {
        organizerId = widget.organizerId!;
        print('Using organizerId from parent: $organizerId');
      }
      // Priority 2: Use current user if available
      else if (_currentUser != null) {
        organizerId = _currentUser!.id;
        print('Using current user ID: $organizerId');
      }
      // Priority 3: Create guest organizer
      else {
        print('Creating guest organizer user...');
        organizerId = 'guest_organizer';
        final guestUser = User(
          id: 'guest_organizer',
          email: 'guest@eventbridge.com',
          name: 'Guest Organizer',
          universityId: 'GUEST001',
          type: UserType.organizer,
          createdAt: DateTime.now(),
        );
        await FirebaseUserService.createUser(guestUser).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout creating guest user');
          },
        );
        organizerId = guestUser.id;
        print('Guest organizer created: $organizerId');
      }

      // Generate event ID first so we can use it for image upload
      final eventId = const Uuid().v4();
      print('Generated event ID: $eventId');
      String? imageUrl;
      
      // Upload image if selected (use the same event ID) with timeout
      if (_selectedImage != null) {
        print('Uploading event image...');
        try {
          imageUrl = await FirebaseStorageService.uploadEventImage(eventId, _selectedImage!)
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('Image upload timed out');
              return null; // Continue without image
            },
          );
          print('Image upload result: $imageUrl');
        } catch (e) {
          print('Image upload error (continuing anyway): $e');
          imageUrl = null; // Continue without image
        }
      }

      final event = Event(
        id: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate!,
        time: _timeController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory,
        organizerId: organizerId,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 100,
        status: EventStatus.published,
        imageUrl: imageUrl,
      );

      print('Creating event in Firestore: ${event.id}');
      print('Organizer ID: $organizerId');
      
      // Add timeout to Firestore write
      await FirebaseEventService.createEvent(event).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Firestore write timeout. Please check your connection and security rules.');
        },
      );
      
      print('Event created successfully in Firestore');
      
      if (!mounted) {
        setState(() => _isLoading = false);
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Small delay to show success message
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e, stackTrace) {
      print('=== ERROR CREATING EVENT ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('===========================');
      
      if (!mounted) {
        return;
      }
      
      String errorMessage = 'An error occurred while creating the event.';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('permission') || errorString.contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check your Firestore security rules in Firebase Console.';
      } else if (errorString.contains('unavailable')) {
        errorMessage = 'Firestore is unavailable. Please check your internet connection.';
      } else if (errorString.contains('timeout')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      } else {
        errorMessage = 'Error: ${e.toString().replaceFirst('Exception: ', '').replaceFirst('Firestore error: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      print('Finally block - resetting loading state');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createEvent,
            child: Text(
              'Create',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Event Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Event Image
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                          ),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Event Title
              CustomTextField(
                controller: _titleController,
                label: 'Event Title',
                icon: Icons.title,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Date and Time Row
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: TextEditingController(
                        text: _selectedDate != null 
                            ? DateFormat('MMM d, y').format(_selectedDate!)
                            : '',
                      ),
                      label: 'Date',
                      icon: Icons.calendar_today,
                      readOnly: true,
                      onTap: _selectDate,
                      validator: (value) {
                        if (_selectedDate == null) {
                          return 'Please select a date';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _timeController,
                      label: 'Time',
                      icon: Icons.access_time,
                      readOnly: true,
                      onTap: _selectTime,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select time';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location
              CustomTextField(
                controller: _locationController,
                label: 'Location',
                icon: Icons.location_on,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter event location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value!);
                },
              ),
              const SizedBox(height: 16),
              
              // Max Participants
              CustomTextField(
                controller: _maxParticipantsController,
                label: 'Max Participants',
                icon: Icons.people,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter max participants';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Event',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tap to add event image', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
