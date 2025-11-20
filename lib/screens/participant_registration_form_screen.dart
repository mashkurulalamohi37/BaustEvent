import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/participant_registration_info.dart';

class ParticipantRegistrationFormScreen extends StatefulWidget {
  final Event event;
  final String userId;
  final ParticipantRegistrationInfo? existingInfo;

  const ParticipantRegistrationFormScreen({
    super.key,
    required this.event,
    required this.userId,
    this.existingInfo,
  });

  @override
  State<ParticipantRegistrationFormScreen> createState() =>
      _ParticipantRegistrationFormScreenState();
}

class _ParticipantRegistrationFormScreenState
    extends State<ParticipantRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _level;
  String? _term;
  String? _batch;
  String? _section;
  String? _tshirtSize;
  String? _foodPreference;
  String? _hall;
  String? _gender;
  final TextEditingController _personalNumberController = TextEditingController();
  final TextEditingController _guardianNumberController = TextEditingController();

  final List<String> _levels = ['1', '2', '3', '4'];
  final List<String> _terms = ['1', '2'];
  final List<String> _sections = ['A', 'B', 'C', 'D', 'E'];
  final List<String> _tshirtSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _foodPreferences = ['Mutton', 'Beef'];
  final List<String> _halls = ['Zikrul haque hall', 'Abbas Uddin Hall', 'Annex-1(Tara mon Bibi)', 'Annex-2', 'Non-Residential'];
  final List<String> _genders = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    if (widget.existingInfo != null) {
      _level = widget.existingInfo!.level;
      // Only set term if it's a valid option (Term 3 removed)
      _term = _terms.contains(widget.existingInfo!.term) 
          ? widget.existingInfo!.term 
          : null;
      _batch = widget.existingInfo!.batch;
      _section = widget.existingInfo!.section;
      _tshirtSize = widget.existingInfo!.tshirtSize;
      _foodPreference = widget.existingInfo!.foodPreference;
      _hall = widget.existingInfo!.hall;
      _gender = widget.existingInfo!.gender;
      _personalNumberController.text = widget.existingInfo!.personalNumber ?? '';
      _guardianNumberController.text = widget.existingInfo!.guardianNumber ?? '';
    }
  }

  @override
  void dispose() {
    _personalNumberController.dispose();
    _guardianNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final hasRequiredFields = event.requireLevel ||
        event.requireTerm ||
        event.requireBatch ||
        event.requireSection ||
        event.requireTshirtSize ||
        event.requireFood ||
        event.requireHall ||
        event.requireGender ||
        event.requirePersonalNumber ||
        event.requireGuardianNumber;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Information'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please fill in the required information to complete your registration.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              if (event.requireLevel) ...[
                DropdownButtonFormField<String>(
                  value: _level,
                  decoration: InputDecoration(
                    labelText: 'Level *',
                    prefixIcon: const Icon(Icons.school),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _levels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text('Level $level'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _level = value),
                  validator: (value) {
                    if (event.requireLevel && (value == null || value.isEmpty)) {
                      return 'Please select your level';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireTerm) ...[
                DropdownButtonFormField<String>(
                  value: _term,
                  decoration: InputDecoration(
                    labelText: 'Term *',
                    prefixIcon: const Icon(Icons.calendar_view_month),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _terms.map((term) {
                    return DropdownMenuItem(
                      value: term,
                      child: Text('Term $term'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _term = value),
                  validator: (value) {
                    if (event.requireTerm && (value == null || value.isEmpty)) {
                      return 'Please select your term';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireBatch) ...[
                TextFormField(
                  initialValue: _batch,
                  decoration: InputDecoration(
                    labelText: 'Batch *',
                    hintText: 'e.g., 2024',
                    prefixIcon: const Icon(Icons.groups),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _batch = value),
                  validator: (value) {
                    if (event.requireBatch &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter your batch';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireSection) ...[
                DropdownButtonFormField<String>(
                  value: _section,
                  decoration: InputDecoration(
                    labelText: 'Section *',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _sections.map((section) {
                    return DropdownMenuItem(
                      value: section,
                      child: Text('Section $section'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _section = value),
                  validator: (value) {
                    if (event.requireSection &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your section';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireTshirtSize) ...[
                DropdownButtonFormField<String>(
                  value: _tshirtSize,
                  decoration: InputDecoration(
                    labelText: 'T-shirt Size *',
                    prefixIcon: const Icon(Icons.checkroom),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _tshirtSizes.map((size) {
                    return DropdownMenuItem(
                      value: size,
                      child: Text(size),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _tshirtSize = value),
                  validator: (value) {
                    if (event.requireTshirtSize &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your T-shirt size';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireFood) ...[
                DropdownButtonFormField<String>(
                  value: _foodPreference,
                  decoration: InputDecoration(
                    labelText: 'Food Preference *',
                    prefixIcon: const Icon(Icons.restaurant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _foodPreferences.map((food) {
                    return DropdownMenuItem(
                      value: food,
                      child: Text(food),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _foodPreference = value),
                  validator: (value) {
                    if (event.requireFood &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your food preference';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireHall) ...[
                DropdownButtonFormField<String>(
                  value: _hall,
                  decoration: InputDecoration(
                    labelText: 'Hall *',
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _halls.map((hall) {
                    return DropdownMenuItem(
                      value: hall,
                      child: Text(hall),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _hall = value),
                  validator: (value) {
                    if (event.requireHall &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your hall';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireGender) ...[
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _genders.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) {
                    if (event.requireGender &&
                        (value == null || value.isEmpty)) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requirePersonalNumber) ...[
                TextFormField(
                  controller: _personalNumberController,
                  decoration: InputDecoration(
                    labelText: 'Personal Number *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (event.requirePersonalNumber &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter your personal number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              if (event.requireGuardianNumber) ...[
                TextFormField(
                  controller: _guardianNumberController,
                  decoration: InputDecoration(
                    labelText: 'Guardian Number *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (event.requireGuardianNumber &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter guardian number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Information',
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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Get trimmed values for text fields
      final batchValue = _batch != null ? _batch!.trim() : null;
      final personalNumberValue = _personalNumberController.text.trim();
      final guardianNumberValue = _guardianNumberController.text.trim();
      
      final info = ParticipantRegistrationInfo(
        eventId: widget.event.id,
        userId: widget.userId,
        level: widget.event.requireLevel && _level != null && _level!.isNotEmpty ? _level : null,
        term: widget.event.requireTerm && _term != null && _term!.isNotEmpty ? _term : null,
        batch: widget.event.requireBatch && batchValue != null && batchValue.isNotEmpty ? batchValue : null,
        section: widget.event.requireSection && _section != null && _section!.isNotEmpty ? _section : null,
        tshirtSize: widget.event.requireTshirtSize && _tshirtSize != null && _tshirtSize!.isNotEmpty ? _tshirtSize : null,
        foodPreference: widget.event.requireFood && _foodPreference != null && _foodPreference!.isNotEmpty ? _foodPreference : null,
        // Save these fields if they have values, regardless of whether they're required
        hall: _hall != null && _hall!.isNotEmpty ? _hall : null,
        gender: _gender != null && _gender!.isNotEmpty ? _gender : null,
        personalNumber: personalNumberValue.isNotEmpty ? personalNumberValue : null,
        guardianNumber: guardianNumberValue.isNotEmpty ? guardianNumberValue : null,
        registeredAt: widget.existingInfo?.registeredAt ?? DateTime.now(),
      );

      Navigator.pop(context, info);
    }
  }
}

