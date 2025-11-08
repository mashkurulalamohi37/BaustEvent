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

class EditEventScreen extends StatefulWidget {
  final Event event;

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = 'Seminars';
  EventStatus _selectedStatus = EventStatus.published;
  bool _isLoading = false;
  User? _currentUser;
  XFile? _selectedImage;
  String? _currentImageUrl;
  DateTime? _registrationCloseDate;
  final TextEditingController _registrationCloseController = TextEditingController();

  final List<String> _categories = [
    'Seminars',
    'Workshops',
    'Cultural',
    'Competitions',
    'Conferences',
    'Rag Day',
    'Picnic',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _loadUser();
  }

  void _loadEvent() {
    final event = widget.event;
    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _locationController.text = event.location;
    _timeController.text = event.time;
    _maxParticipantsController.text = event.maxParticipants.toString();
    _selectedDate = event.date;
    _selectedCategory = event.category;
    _selectedStatus = event.status;
    _currentImageUrl = event.imageUrl;
    _selectedTime = _parseTimeOfDay(event.time);
    _registrationCloseDate = event.registrationCloseDate;
    if (_registrationCloseDate != null) {
      _registrationCloseController.text =
          DateFormat('MMM d, y • h:mm a').format(_registrationCloseDate!.toLocal());
    } else {
      _registrationCloseController.clear();
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
        setState(() {
          _selectedImage = picked;
          _currentImageUrl = null; // Clear old URL when new image is selected
        });
      }
    }
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
    _registrationCloseController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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
      setState(() {
        _selectedTime = time;
        _timeController.text = time.format(context);
      });
    }
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    try {
      final dt = DateFormat.jm().parse(value);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectRegistrationCloseDateTime() async {
    final initialDate = _registrationCloseDate ?? _selectedDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(DateTime.now()) ? DateTime.now() : initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) {
      return;
    }

    final initialTime = _registrationCloseDate != null
        ? TimeOfDay(hour: _registrationCloseDate!.hour, minute: _registrationCloseDate!.minute)
        : (_selectedTime ?? _parseTimeOfDay(_timeController.text)) ??
            TimeOfDay.now();

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null) {
      return;
    }

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final now = DateTime.now();

    if (selected.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration close time must be in the future.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final effectiveTime = _selectedTime ?? _parseTimeOfDay(_timeController.text);
    if (_selectedDate != null && effectiveTime != null) {
      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        effectiveTime.hour,
        effectiveTime.minute,
      );
      if (selected.isAfter(eventDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration must close before the event starts.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _registrationCloseDate = selected;
      _registrationCloseController.text =
          DateFormat('MMM d, y • h:mm a').format(selected);
    });
  }

  Future<void> _updateEvent() async {
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

    final effectiveTime = _selectedTime ?? _parseTimeOfDay(_timeController.text);
    if (effectiveTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid event time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_registrationCloseDate != null) {
      final now = DateTime.now();
      if (_registrationCloseDate!.isBefore(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration close time must be in the future.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        effectiveTime.hour,
        effectiveTime.minute,
      );

      if (_registrationCloseDate!.isAfter(eventDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration must close before the event starts.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      
      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await FirebaseStorageService.uploadEventImage(widget.event.id, _selectedImage!);
      }

      final updatedEvent = widget.event.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        date: _selectedDate!,
        time: _timeController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory,
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 100,
        status: _selectedStatus,
        imageUrl: imageUrl,
        registrationCloseDate: _registrationCloseDate,
        registrationCloseDateSet: true,
      );

      final success = await FirebaseEventService.updateEvent(updatedEvent);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update event. Please try again.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateEvent,
            child: Text(
              'Save',
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
                      : _currentImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _currentImageUrl!,
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
              
              CustomTextField(
                controller: _registrationCloseController,
                label: 'Registration closes at (optional)',
                hint: 'Tap to set closing time',
                icon: Icons.lock_clock,
                readOnly: true,
                onTap: _selectRegistrationCloseDateTime,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _registrationCloseDate == null
                      ? null
                      : () {
                          setState(() {
                            _registrationCloseDate = null;
                            _registrationCloseController.clear();
                          });
                        },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear registration lock'),
                ),
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
              
              // Status Dropdown
              DropdownButtonFormField<EventStatus>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: const Icon(Icons.flag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                  ),
                ),
                items: EventStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(_getStatusText(status)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
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
              
              // Update Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Update Event',
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

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Tap to add/edit event image', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
