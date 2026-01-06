import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poll.dart';
import '../models/user.dart' as app_user;
import '../models/user.dart';  // For UserType enum
import '../services/firebase_poll_service.dart';
import '../services/firebase_user_service.dart';
import '../widgets/poll_card.dart';
import 'create_poll_screen.dart';

class PollsScreen extends StatefulWidget {
  final String? eventId; // Optional: Show polls for a specific event

  const PollsScreen({Key? key, this.eventId}) : super(key: key);

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Poll> _activePolls = [];
  List<Poll> _closedPolls = [];
  bool _isLoading = true;
  app_user.User? _currentUser;
  bool _canCreatePolls = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPolls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPolls() async {
    setState(() => _isLoading = true);

    try {
      // Load user to check permissions
      final user = await FirebaseUserService.getCurrentUserWithDetails();
      
      // Check if user can create polls (organizers or admins)
      final canCreate = user != null && (
        user.type == UserType.organizer || 
        user.isAdmin
      );
      
      print('📊 Poll permissions check:');
      print('  User: ${user?.name}');
      print('  Type: ${user?.type.name}');
      print('  IsOrganizer: ${user?.isOrganizer}');
      print('  IsAdmin: ${user?.isAdmin}');
      print('  CanCreate: $canCreate');
      
      List<Poll> polls;
      if (widget.eventId != null) {
        polls = await FirebasePollService.getPollsByEvent(widget.eventId!);
      } else {
        polls = await FirebasePollService.getAllPolls();
      }

      final active = polls.where((poll) => poll.isActive).toList();
      final closed = polls.where((poll) => !poll.isActive).toList();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _canCreatePolls = canCreate;
          _activePolls = active;
          _closedPolls = closed;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading polls: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePoll(Poll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: const Text(
          'Are you sure you want to delete this poll? This action cannot be undone.',
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

    if (confirmed != true) return;

    final success = await FirebasePollService.deletePoll(poll.id);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPolls();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete poll'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToCreatePoll() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePollScreen(eventId: widget.eventId),
      ),
    );

    if (result != null) {
      _loadPolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.eventId != null ? 'Event Polls' : 'Flash Polls',
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, size: 16),
                  const SizedBox(width: 8),
                  Text('Active (${_activePolls.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 8),
                  Text('Closed (${_closedPolls.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPollList(_activePolls, true),
                _buildPollList(_closedPolls, false),
              ],
            ),
      floatingActionButton: _canCreatePolls
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreatePoll,
              icon: const Icon(Icons.add),
              label: const Text('New Poll'),
              backgroundColor: Colors.blue.shade600,
            )
          : null,
    );
  }

  Widget _buildPollList(List<Poll> polls, bool isActive) {
    if (polls.isEmpty) {
      return _buildEmptyState(isActive);
    }

    return RefreshIndicator(
      onRefresh: _loadPolls,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: polls.length,
        itemBuilder: (context, index) {
          final poll = polls[index];
          final currentUser = FirebaseAuth.instance.currentUser;
          final isCreator = currentUser?.uid == poll.creatorId;
          // Only allow delete for organizers/admins who created the poll
          final canDelete = _canCreatePolls && isCreator;

          return PollCard(
            poll: poll,
            onVoted: _loadPolls,
            onDelete: canDelete ? () => _deletePoll(poll) : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.poll : Icons.history,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isActive ? 'No Active Polls' : 'No Closed Polls',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Create a poll to get quick decisions from your group!'
                  : 'Closed polls will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (isActive && _canCreatePolls) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToCreatePoll,
                icon: const Icon(Icons.add),
                label: const Text('Create Your First Poll'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
