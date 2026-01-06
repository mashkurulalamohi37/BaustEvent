import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poll.dart';
import '../services/firebase_poll_service.dart';

class PollCard extends StatefulWidget {
  final Poll poll;
  final VoidCallback? onVoted;
  final VoidCallback? onDelete;

  const PollCard({
    Key? key,
    required this.poll,
    this.onVoted,
    this.onDelete,
  }) : super(key: key);

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  String? _userVote;
  bool _isLoading = false;
  bool _hasVoted = false;
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  Map<String, Map<String, String>> _voterData = {}; // Cache voter names and IDs
  String? _expandedOptionId; // Track which option is expanded to show voters

  @override
  void initState() {
    super.initState();
    _checkUserVote();
    _startCountdown();
    _loadVoterData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timeRemaining = widget.poll.timeRemaining;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining = widget.poll.timeRemaining;
          if (_timeRemaining <= Duration.zero) {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _checkUserVote() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final voted = await FirebasePollService.hasUserVoted(
      widget.poll.id,
      currentUser.uid,
    );
    
    final userVote = await FirebasePollService.getUserVote(
      widget.poll.id,
      currentUser.uid,
    );

    if (mounted) {
      setState(() {
        _hasVoted = voted;
        _userVote = userVote;
      });
    }
  }
  
  Future<void> _loadVoterData() async {
    if (widget.poll.isAnonymous) return;
    
    final Set<String> allVoterIds = {};
    for (final option in widget.poll.options) {
      allVoterIds.addAll(option.voterIds);
    }
    
    if (allVoterIds.isEmpty) return;
    
    try {
      final firestore = FirebaseFirestore.instance;
      final Map<String, Map<String, String>> voterData = {};
      
      // Fetch user data for all voters (batch query for efficiency)
      for (final voterId in allVoterIds) {
        if (voterData.containsKey(voterId)) continue;
        
        try {
          final userDoc = await firestore.collection('users').doc(voterId).get();
          if (userDoc.exists) {
            final data = userDoc.data();
            voterData[voterId] = {
              'name': data?['name'] ?? 'Unknown',
              'universityId': data?['universityId'] ?? voterId.substring(0, 8),
            };
          } else {
            voterData[voterId] = {
              'name': 'Unknown User',
              'universityId': voterId.substring(0, 8),
            };
          }
        } catch (e) {
          print('Error fetching voter $voterId: $e');
          voterData[voterId] = {
            'name': 'Unknown',
            'universityId': voterId.substring(0, 8),
          };
        }
      }
      
      if (mounted) {
        setState(() {
          _voterData = voterData;
        });
      }
    } catch (e) {
      print('Error loading voter data: $e');
    }
  }

  Future<void> _vote(String optionId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final result = await FirebasePollService.vote(
      widget.poll.id,
      currentUser.uid,
      optionId,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result == VoteResult.success) {
        setState(() {
          _hasVoted = true;
          _userVote = optionId;
        });
        widget.onVoted?.call();
        _showMessage('Vote recorded!', Colors.green);
      } else {
        String message = 'Failed to vote';
        switch (result) {
          case VoteResult.alreadyVoted:
            message = 'You have already voted';
            break;
          case VoteResult.pollClosed:
            message = 'This poll is closed';
            break;
          case VoteResult.pollNotFound:
            message = 'Poll not found';
            break;
          default:
            message = 'Failed to vote. Please try again.';
        }
        _showMessage(message, Colors.red);
      }
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  Future<void> _closePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Poll Early?'),
        content: const Text(
          'This will close the poll immediately and show final results. This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: const Text('Close Poll'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await FirebasePollService.closePoll(widget.poll.id);
        widget.onVoted?.call(); // Refresh the poll list
        if (mounted) {
          _showMessage('Poll closed successfully', Colors.green);
        }
      } catch (e) {
        if (mounted) {
          _showMessage('Failed to close poll', Colors.red);
        }
      }
    }
  }
  
  Future<void> _handleVoteOption(String optionId) async {
    if (_hasVoted && widget.poll.allowMultipleVotes && _userVote != optionId) {
      // Can vote on different options if multiple votes allowed
      await _vote(optionId);
    } else if (_hasVoted && _userVote == optionId) {
      // Trying to vote on same option - ignore
      _showMessage('You have already voted for this option', Colors.orange);
    } else if (_hasVoted && _userVote != optionId) {
      // Want to change vote - ask for confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change Vote?'),
          content: const Text('Do you want to change your vote to this option?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
              ),
              child: const Text('Change Vote'),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        await _vote(optionId);
      }
    } else {
      // First time voting
      await _vote(optionId);
    }
  }

  String _formatTimeRemaining() {
    if (_timeRemaining <= Duration.zero) return 'Closed';
    
    final hours = _timeRemaining.inHours;
    final minutes = _timeRemaining.inMinutes.remainder(60);
    final seconds = _timeRemaining.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s remaining';
    } else {
      return '${seconds}s remaining';
    }
  }

  Color _getTimerColor() {
    final totalMinutes = _timeRemaining.inMinutes;
    if (totalMinutes <= 5) return Colors.red;
    if (totalMinutes <= 30) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == widget.poll.creatorId;
    final showResults = _hasVoted || !widget.poll.isActive || isCreator;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(isCreator),
          
          // Question
          _buildQuestion(),

          // Timer
          if (widget.poll.isActive) _buildTimer(),

          // Options
          _buildOptions(showResults),

          // Stats
          if (showResults) _buildStats(),

          // Footer
          if (!widget.poll.isActive) _buildClosedBadge(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isCreator) {
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.poll,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'FLASH POLL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (isCreator && widget.poll.isActive)
            IconButton(
              icon: const Icon(Icons.lock_clock, color: Colors.white),
              onPressed: _closePoll,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Close Poll Early',
            ),
          if (isCreator && widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: widget.onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.poll.question,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildTimer() {
    final color = _getTimerColor();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            _formatTimeRemaining(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(bool showResults) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: widget.poll.options.map((option) {
          final percentage = option.getPercentage(widget.poll.totalVotes);
          final isSelected = _userVote == option.id;
          
          if (showResults) {
            return _buildResultOption(option, percentage, isSelected);
          } else {
            return _buildVoteOption(option);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildVoteOption(PollOption option) {
    final isAlreadyVoted = _userVote == option.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isLoading || !widget.poll.isActive
            ? null
            : () => _handleVoteOption(option.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.radio_button_unchecked,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultOption(PollOption option, double percentage, bool isSelected) {
    final isWinning = widget.poll.totalVotes > 0 &&
        option.votes == widget.poll.options
            .map((o) => o.votes)
            .reduce((a, b) => a > b ? a : b);
    final isExpanded = _expandedOptionId == option.id;
    final hasVoters = !widget.poll.isAnonymous && option.voterIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: hasVoters 
            ? () {
                setState(() {
                  _expandedOptionId = isExpanded ? null : option.id;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.blue.shade300
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isWinning ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isWinning ? Colors.blue.shade700 : Colors.grey.shade700,
                    ),
                  ),
                  if (hasVoters) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.poll.totalVotes > 0 ? percentage / 100 : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isWinning ? Colors.blue.shade600 : Colors.grey.shade400,
                  ),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${option.votes} ${option.votes == 1 ? 'vote' : 'votes'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (hasVoters && !isExpanded)
                    Text(
                      'Tap to see voters',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            // Show voters if not anonymous and there are votes
            if (!widget.poll.isAnonymous && option.voterIds.isNotEmpty && isExpanded) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: option.voterIds.take(10).map((voterId) {
                  final voterInfo = _voterData[voterId];
                  final displayName = voterInfo?['name'] ?? 'Loading...';
                  final universityId = voterInfo?['universityId'] ?? '';
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.blue.shade100 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.blue.shade300 
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 12,
                          color: isSelected 
                              ? Colors.blue.shade700 
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                    ? Colors.blue.shade700 
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (universityId.isNotEmpty)
                              Text(
                                'ID: $universityId',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected 
                                      ? Colors.blue.shade600 
                                      : Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (option.voterIds.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${option.voterIds.length - 10} more',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                '${widget.poll.totalVotes} total ${widget.poll.totalVotes == 1 ? 'vote' : 'votes'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          if (widget.poll.isAnonymous)
            Row(
              children: [
                Icon(Icons.visibility_off, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Anonymous',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildClosedBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            'Poll Closed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
