import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_item.dart';

class FirebaseItemDistributionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static CollectionReference<Map<String, dynamic>> get _itemsCol =>
      _firestore.collection('event_items');
  
  static CollectionReference<Map<String, dynamic>> get _distributionsCol =>
      _firestore.collection('item_distributions');

  // Create a new item for an event
  static Future<String> createEventItem(EventItem item) async {
    try {
      final docRef = await _itemsCol.add(item.toJson());
      return docRef.id;
    } catch (e) {
      print('Error creating event item: $e');
      throw Exception('Failed to create event item');
    }
  }

  // Get all items for an event
  static Future<List<EventItem>> getEventItems(String eventId) async {
    try {
      final snapshot = await _itemsCol
          .where('eventId', isEqualTo: eventId)
          .get();

      final items = snapshot.docs
          .map((doc) => EventItem.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy (avoids index requirement)
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return items;
    } catch (e) {
      print('Error getting event items: $e');
      return [];
    }
  }

  // Update item total quantity
  static Future<bool> updateItemQuantity(String itemId, int newQuantity) async {
    try {
      await _itemsCol.doc(itemId).update({
        'totalQuantity': newQuantity,
      });
      return true;
    } catch (e) {
      print('Error updating item quantity: $e');
      return false;
    }
  }

  // Mark item as distributed to a participant
  static Future<bool> distributeItem({
    required String eventId,
    required String itemId,
    required String participantId,
    required String participantName,
    required String participantEmail,
    required String universityId,
    required String batch,
    required String section,
    required String distributedBy,
    String? notes,
  }) async {
    try {
      // Check if already distributed
      final existingDistribution = await _distributionsCol
          .where('eventId', isEqualTo: eventId)
          .where('itemId', isEqualTo: itemId)
          .where('participantId', isEqualTo: participantId)
          .limit(1)
          .get();

      if (existingDistribution.docs.isNotEmpty) {
        throw Exception('Item already distributed to this participant');
      }

      final distribution = ItemDistribution(
        id: '',
        eventId: eventId,
        itemId: itemId,
        participantId: participantId,
        participantName: participantName,
        participantEmail: participantEmail,
        universityId: universityId,
        batch: batch,
        section: section,
        distributedAt: DateTime.now(),
        distributedBy: distributedBy,
        notes: notes,
      );

      // Add distribution record
      await _distributionsCol.add(distribution.toJson());

      // Update item distributed quantity
      final itemDoc = await _itemsCol.doc(itemId).get();
      if (itemDoc.exists) {
        final currentDistributed = itemDoc.data()?['distributedQuantity'] as int? ?? 0;
        await _itemsCol.doc(itemId).update({
          'distributedQuantity': currentDistributed + 1,
        });
      }

      return true;
    } catch (e) {
      print('Error distributing item: $e');
      return false;
    }
  }

  // Get distribution records for an item
  static Future<List<ItemDistribution>> getItemDistributions(String itemId) async {
    try {
      final snapshot = await _distributionsCol
          .where('itemId', isEqualTo: itemId)
          .orderBy('distributedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ItemDistribution.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting distributions: $e');
      return [];
    }
  }

  // Get distribution records by batch and section
  static Future<List<ItemDistribution>> getDistributionsByBatchSection({
    required String eventId,
    required String itemId,
    required String batch,
    required String section,
  }) async {
    try {
      final snapshot = await _distributionsCol
          .where('eventId', isEqualTo: eventId)
          .where('itemId', isEqualTo: itemId)
          .where('batch', isEqualTo: batch)
          .where('section', isEqualTo: section)
          .orderBy('distributedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ItemDistribution.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting batch/section distributions: $e');
      return [];
    }
  }

  // Check if participant has received the item
  static Future<bool> hasParticipantReceivedItem({
    required String itemId,
    required String participantId,
  }) async {
    try {
      final snapshot = await _distributionsCol
          .where('itemId', isEqualTo: itemId)
          .where('participantId', isEqualTo: participantId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking distribution status: $e');
      return false;
    }
  }

  // Get all participant IDs who have received this item (optimized batch fetch)
  static Future<Set<String>> getDistributedParticipantIds({
    required String itemId,
  }) async {
    try {
      final snapshot = await _distributionsCol
          .where('itemId', isEqualTo: itemId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['participantId'] as String)
          .toSet();
    } catch (e) {
      print('Error getting distributed participant IDs: $e');
      return {};
    }
  }

  // Get distribution summary by batch and section
  static Future<Map<String, Map<String, int>>> getDistributionSummary(
    String eventId,
    String itemId,
  ) async {
    try {
      final snapshot = await _distributionsCol
          .where('eventId', isEqualTo: eventId)
          .where('itemId', isEqualTo: itemId)
          .get();

      final summary = <String, Map<String, int>>{};

      for (var doc in snapshot.docs) {
        final batch = doc.data()['batch'] as String;
        final section = doc.data()['section'] as String;

        if (!summary.containsKey(batch)) {
          summary[batch] = {};
        }

        summary[batch]![section] = (summary[batch]![section] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      print('Error getting distribution summary: $e');
      return {};
    }
  }

  // Undo distribution (in case of mistake)
  static Future<bool> undoDistribution(String distributionId, String itemId) async {
    try {
      await _distributionsCol.doc(distributionId).delete();

      // Decrease distributed quantity
      final itemDoc = await _itemsCol.doc(itemId).get();
      if (itemDoc.exists) {
        final currentDistributed = itemDoc.data()?['distributedQuantity'] as int? ?? 0;
        await _itemsCol.doc(itemId).update({
          'distributedQuantity': currentDistributed > 0 ? currentDistributed - 1 : 0,
        });
      }

      return true;
    } catch (e) {
      print('Error undoing distribution: $e');
      return false;
    }
  }

  // Remove distribution by itemId and participantId (for checkbox uncheck)
  static Future<bool> undistributeItem({
    required String itemId,
    required String participantId,
  }) async {
    try {
      // Find the distribution record
      final snapshot = await _distributionsCol
          .where('itemId', isEqualTo: itemId)
          .where('participantId', isEqualTo: participantId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('No distribution found for this participant');
        return false;
      }

      final distributionId = snapshot.docs.first.id;
      return await undoDistribution(distributionId, itemId);
    } catch (e) {
      print('Error undistributing item: $e');
      return false;
    }
  }
}
