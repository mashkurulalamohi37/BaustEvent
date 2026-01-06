import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/poll.dart';
import '../services/firebase_poll_service.dart';

class CreatePollScreen extends StatefulWidget {
  final String? eventId; // Optional: Associate poll with an event

  const CreatePollScreen({Key? key, this.eventId}) : super(key: key);

  @override
  State<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  
  bool _isAnonymous = false;
  bool _allowMultipleVotes = false;
  int _selectedHours = 2; // Default: 2 hours
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start with 2 options
    _addOption();
    _addOption();
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError('You must be logged in to create a poll');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final expiresAt = now.add(Duration(hours: _selectedHours));

      // Create poll options
      final options = _optionControllers
          .where((controller) => controller.text.trim().isNotEmpty)
          .map((controller) => PollOption(
                id: const Uuid().v4(),
                text: controller.text.trim(),
              ))
          .toList();

      if (options.length < 2) {
        _showError('Please provide at least 2 options');
        setState(() => _isLoading = false);
        return;
      }

      final poll = Poll(
        id: const Uuid().v4(),
        question: _questionController.text.trim(),
        options: options,
        creatorId: currentUser.uid,
        eventId: widget.eventId,
        createdAt: now,
        expiresAt: expiresAt,
        allowMultipleVotes: _allowMultipleVotes,
        isAnonymous: _isAnonymous,
      );

      final success = await FirebasePollService.createPoll(poll);

      if (success) {
        if (mounted) {
          Navigator.pop(context, poll);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poll created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _showError('Failed to create poll. Please try again.');
      }
    } catch (e) {
      _showError('Error creating poll: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Flash Poll'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Question Input
                    _buildQuestionInput(),
                    const SizedBox(height: 24),

                    // Options
                    _buildOptionsSection(),
                    const SizedBox(height: 24),

                    // Timer Selection
                    _buildTimerSection(),
                    const SizedBox(height: 24),

                    // Settings
                    _buildSettingsSection(),
                    const SizedBox(height: 32),

                    // Create Button
                    _buildCreateButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.poll,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flash Poll',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get quick decisions from your group',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _questionController,
          decoration: InputDecoration(
            hintText: 'e.g., Which color should the club t-shirt be?',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a question';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Add Option'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _optionControllers.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(Icons.check_circle_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an option';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_optionControllers.length > 2) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeOption(index),
                      icon: const Icon(Icons.remove_circle),
                      color: Colors.red,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voting Duration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Poll closes in $_selectedHours ${_selectedHours == 1 ? 'hour' : 'hours'}',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _selectedHours.toDouble(),
                min: 1,
                max: 24,
                divisions: 23,
                label: '$_selectedHours hours',
                onChanged: (value) {
                  setState(() {
                    _selectedHours = value.toInt();
                  });
                },
              ),
              Text(
                'Quick decisions work best!',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.grey.shade50,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Anonymous Voting'),
                subtitle: const Text('Hide who voted for what'),
                value: _isAnonymous,
                onChanged: (value) {
                  setState(() => _isAnonymous = value);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Allow Vote Changes'),
                subtitle: const Text('Let users change their vote'),
                value: _allowMultipleVotes,
                onChanged: (value) {
                  setState(() => _allowMultipleVotes = value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createPoll,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Create Poll',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
