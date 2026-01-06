import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poll.dart';
import 'firebase_notification_service.dart';

class FirebasePollService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _pollsCol =>
      _firestore.collection('polls');

  // Create a new poll
  static Future<bool> createPoll(Poll poll) async {
    try {
      print('=== CREATING POLL IN FIRESTORE ===');
      print('Poll ID: ${poll.id}');
      print('Question: ${poll.question}');
      print('Options: ${poll.options.map((o) => o.text).join(", ")}');
      print('Expires at: ${poll.expiresAt}');

      final pollData = poll.toFirestore();
      print('Poll data to save: $pollData');

      await _pollsCol.doc(poll.id).set(pollData);
      print('Poll created successfully');

      // Verify the document was created
      final doc = await _pollsCol.doc(poll.id).get();
      if (doc.exists) {
        print('Poll document verified in Firestore');

        // Send notification about new poll
        try {
          await _notifyNewPoll(poll);
        } catch (e) {
          print('Error sending new poll notification: $e');
        }

        return true;
      } else {
        print('WARNING: Poll document not found after creation');
        throw Exception('Poll document was not created in Firestore');
      }
    } catch (e, stackTrace) {
      print('=== ERROR CREATING POLL IN FIRESTORE ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Firestore error: ${e.toString()}');
    }
  }

  // Get all active polls
  static Future<List<Poll>> getAllPolls() async {
    try {
      final snap = await _pollsCol
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .where((d) => d.exists)
          .map((d) => PollFirestore.fromFirestore(d))
          .toList();
    } catch (e) {
      print('Error fetching all polls: $e');
      // Try without orderBy if index doesn't exist
      try {
        final snap = await _pollsCol.get();
        final polls = snap.docs
            .where((d) => d.exists)
            .map((d) => PollFirestore.fromFirestore(d))
            .toList();
        polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return polls;
      } catch (e2) {
        print('Error fetching polls (fallback): $e2');
        return [];
      }
    }
  }

  // Get active polls stream
  static Stream<List<Poll>> getAllPollsStream() {
    return _pollsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) {
      final polls = <Poll>[];
      for (var doc in s.docs) {
        if (!doc.exists) continue;
        final data = doc.data();
        if (data == null || data.isEmpty) continue;
        try {
          polls.add(PollFirestore.fromFirestore(doc));
        } catch (e) {
          print('Error parsing poll document ${doc.id}: $e');
        }
      }
      return polls;
    }).handleError((error) {
      print('Error in getAllPollsStream: $error');
      return <Poll>[];
    });
  }

  // Get polls by creator
  static Future<List<Poll>> getPollsByCreator(String creatorId) async {
    try {
      final snap = await _pollsCol
          .where('creatorId', isEqualTo: creatorId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .where((d) => d.exists)
          .map((d) => PollFirestore.fromFirestore(d))
          .toList();
    } catch (e) {
      print('Error fetching creator polls: $e');
      // Fallback without orderBy
      try {
        final snap = await _pollsCol
            .where('creatorId', isEqualTo: creatorId)
            .get();
        final polls = snap.docs
            .where((d) => d.exists)
            .map((d) => PollFirestore.fromFirestore(d))
            .toList();
        polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return polls;
      } catch (e2) {
        print('Error fetching creator polls (fallback): $e2');
        return [];
      }
    }
  }

  // Get polls by event
  static Future<List<Poll>> getPollsByEvent(String eventId) async {
    try {
      final snap = await _pollsCol
          .where('eventId', isEqualTo: eventId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .where((d) => d.exists)
          .map((d) => PollFirestore.fromFirestore(d))
          .toList();
    } catch (e) {
      print('Error fetching event polls: $e');
      // Fallback without orderBy
      try {
        final snap = await _pollsCol
            .where('eventId', isEqualTo: eventId)
            .get();
        final polls = snap.docs
            .where((d) => d.exists)
            .map((d) => PollFirestore.fromFirestore(d))
            .toList();
        polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return polls;
      } catch (e2) {
        print('Error fetching event polls (fallback): $e2');
        return [];
      }
    }
  }

  // Get a single poll
  static Future<Poll?> getPoll(String pollId) async {
    try {
      final doc = await _pollsCol.doc(pollId).get();
      if (doc.exists && doc.data() != null) {
        return PollFirestore.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching poll: $e');
      return null;
    }
  }

  // Vote on a poll
  static Future<VoteResult> vote(
    String pollId,
    String userId,
    String optionId,
  ) async {
    try {
      final ref = _pollsCol.doc(pollId);
      final result = await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          return VoteResult.pollNotFound;
        }

        final poll = PollFirestore.fromFirestore(snap);

        // Check if poll is still active
        if (!poll.isActive) {
          return VoteResult.pollClosed;
        }

        // Check if user already voted
        final hasVoted = poll.options.any((o) => o.voterIds.contains(userId));
        if (hasVoted && !poll.allowMultipleVotes) {
          return VoteResult.alreadyVoted;
        }

        // Find the option to vote for
        final optionIndex = poll.options.indexWhere((o) => o.id == optionId);
        if (optionIndex == -1) {
          return VoteResult.optionNotFound;
        }

        // Update the poll options
        final updatedOptions = List<PollOption>.from(poll.options);

        // If not anonymous, add voter ID
        if (!poll.isAnonymous) {
          // Remove user from other options if changing vote
          for (var i = 0; i < updatedOptions.length; i++) {
            final voterIds = List<String>.from(updatedOptions[i].voterIds);
            if (voterIds.remove(userId)) {
              updatedOptions[i] = updatedOptions[i].copyWith(
                votes: updatedOptions[i].votes - 1,
                voterIds: voterIds,
              );
            }
          }

          // Add vote to selected option
          final selectedOption = updatedOptions[optionIndex];
          final newVoterIds = List<String>.from(selectedOption.voterIds)
            ..add(userId);
          updatedOptions[optionIndex] = selectedOption.copyWith(
            votes: selectedOption.votes + 1,
            voterIds: newVoterIds,
          );
        } else {
          // For anonymous polls, just increment vote count
          final selectedOption = updatedOptions[optionIndex];
          updatedOptions[optionIndex] = selectedOption.copyWith(
            votes: selectedOption.votes + 1,
          );
        }

        // Update Firestore
        tx.update(ref, {
          'options': updatedOptions.map((o) => o.toJson()).toList(),
        });

        return VoteResult.success;
      });

      return result;
    } catch (e) {
      print('Error voting on poll: $e');
      return VoteResult.error;
    }
  }

  // Check if user has voted
  static Future<bool> hasUserVoted(String pollId, String userId) async {
    try {
      final poll = await getPoll(pollId);
      if (poll == null) return false;
      return poll.options.any((o) => o.voterIds.contains(userId));
    } catch (e) {
      print('Error checking vote status: $e');
      return false;
    }
  }

  // Get user's vote (which option they voted for)
  static Future<String?> getUserVote(String pollId, String userId) async {
    try {
      final poll = await getPoll(pollId);
      if (poll == null) return null;
      
      for (var option in poll.options) {
        if (option.voterIds.contains(userId)) {
          return option.id;
        }
      }
      return null;
    } catch (e) {
      print('Error getting user vote: $e');
      return null;
    }
  }

  // Close a poll
  static Future<bool> closePoll(String pollId) async {
    try {
      await _pollsCol.doc(pollId).update({'status': 'closed'});
      return true;
    } catch (e) {
      print('Error closing poll: $e');
      return false;
    }
  }

  // Delete a poll
  static Future<bool> deletePoll(String pollId) async {
    try {
      await _pollsCol.doc(pollId).delete();
      return true;
    } catch (e) {
      print('Error deleting poll: $e');
      return false;
    }
  }

  // Update poll
  static Future<bool> updatePoll(Poll poll) async {
    try {
      await _pollsCol.doc(poll.id).update(poll.toFirestore());
      return true;
    } catch (e) {
      print('Error updating poll: $e');
      return false;
    }
  }

  // Send notification about new poll
  static Future<void> _notifyNewPoll(Poll poll) async {
    try {
      print('📊 Creating poll notification...');
      
      // Store notification in Firestore - listeners will show it to users
      final notificationsCol = _firestore.collection('notifications');
      
      String title;
      String body;
      String eventTitle = 'Flash Poll';
      String? eventId;
      
      if (poll.eventId != null) {
        try {
          final event = await _firestore
              .collection('events')
              .doc(poll.eventId)
              .get();
          
          if (event.exists) {
            final eventData = event.data();
            eventTitle = eventData?['title'] as String? ?? 'Event';
            eventId = poll.eventId;
            
            title = '📊 New Poll: $eventTitle';
            body = poll.question;
          } else {
            title = '📊 New Poll Available';
            body = poll.question;
          }
        } catch (e) {
          print('Error getting event for poll notification: $e');
          title = '📊 New Poll Available';
          body = poll.question;
        }
      } else {
        // General poll notification
        title = '📊 New Poll Available';
        body = poll.question;
      }
      
      // Create notification for ALL users
      final notificationData = {
        'type': 'poll',
        'pollId': poll.id,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'title': title,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
        'category': 'Poll', // Add category for filtering
      };
      
      print('Notification data: $notificationData');
      
      await notificationsCol.add(notificationData);
      
      print('✅ Poll notification stored in Firestore successfully');
    } catch (e, stackTrace) {
      print('❌ Error sending poll notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Get active polls (not expired)
  static Future<List<Poll>> getActivePolls() async {
    try {
      final polls = await getAllPolls();
      return polls.where((poll) => poll.isActive).toList();
    } catch (e) {
      print('Error fetching active polls: $e');
      return [];
    }
  }

  // Get expired polls
  static Future<List<Poll>> getExpiredPolls() async {
    try {
      final polls = await getAllPolls();
      return polls.where((poll) => poll.isExpired).toList();
    } catch (e) {
      print('Error fetching expired polls: $e');
      return [];
    }
  }
}

enum VoteResult {
  success,
  alreadyVoted,
  pollClosed,
  pollNotFound,
  optionNotFound,
  error,
}
