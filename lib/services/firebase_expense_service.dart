import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_expense.dart';

class FirebaseExpenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'event_expenses';

  // Add a new expense
  static Future<String?> addExpense(EventExpense expense) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(expense.toFirestore());
      print('Expense added successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error adding expense: $e');
      return null;
    }
  }

  // Update an existing expense
  static Future<bool> updateExpense(EventExpense expense) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(expense.id)
          .update(expense.toFirestore());
      print('Expense updated successfully: ${expense.id}');
      return true;
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  // Delete an expense
  static Future<bool> deleteExpense(String expenseId) async {
    try {
      await _firestore.collection(_collectionName).doc(expenseId).delete();
      print('Expense deleted successfully: $expenseId');
      return true;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }

  // Get all expenses for a specific event
  static Future<List<EventExpense>> getExpensesByEvent(String eventId) async {
    try {
      print('🔍 Fetching expenses for eventId: $eventId');
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('eventId', isEqualTo: eventId)
          .orderBy('date', descending: true)
          .get();

      print('📊 Query returned ${querySnapshot.docs.length} documents');
      
      final expenses = querySnapshot.docs
          .map((doc) {
            print('  - Document ID: ${doc.id}, data: ${doc.data()}');
            return EventExpense.fromFirestore(doc);
          })
          .toList();
      
      print('✅ Successfully parsed ${expenses.length} expenses');
      return expenses;
    } catch (e) {
      print('❌ Error getting expenses by event: $e');
      return [];
    }
  }

  // Get expenses stream for real-time updates
  static Stream<List<EventExpense>> getExpensesByEventStream(String eventId) {
    try {
      return _firestore
          .collection(_collectionName)
          .where('eventId', isEqualTo: eventId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => EventExpense.fromFirestore(doc))
              .toList());
    } catch (e) {
      print('Error getting expenses stream: $e');
      return Stream.value([]);
    }
  }

  // Get total expenses for an event
  static Future<double> getTotalExpensesByEvent(String eventId) async {
    try {
      final expenses = await getExpensesByEvent(eventId);
      return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      print('Error calculating total expenses: $e');
      return 0.0;
    }
  }

  // Get expenses grouped by category
  static Future<Map<ExpenseCategory, double>> getExpensesByCategory(String eventId) async {
    try {
      final expenses = await getExpensesByEvent(eventId);
      final Map<ExpenseCategory, double> categoryTotals = {};

      for (var expense in expenses) {
        categoryTotals[expense.category] = 
            (categoryTotals[expense.category] ?? 0.0) + expense.amount;
      }

      return categoryTotals;
    } catch (e) {
      print('Error getting expenses by category: $e');
      return {};
    }
  }

  // Get all expenses (admin only)
  static Future<List<EventExpense>> getAllExpenses({int? limit}) async {
    try {
      Query query = _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => EventExpense.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all expenses: $e');
      return [];
    }
  }

  // Get expenses by organizer (all expenses for events created by this organizer)
  static Future<List<EventExpense>> getExpensesByOrganizer(String organizerId, List<String> eventIds) async {
    try {
      if (eventIds.isEmpty) return [];

      // Firestore 'in' query supports up to 10 items
      final List<EventExpense> allExpenses = [];
      
      // Split into chunks of 10
      for (int i = 0; i < eventIds.length; i += 10) {
        final chunk = eventIds.skip(i).take(10).toList();
        final querySnapshot = await _firestore
            .collection(_collectionName)
            .where('eventId', whereIn: chunk)
            .orderBy('date', descending: true)
            .get();

        allExpenses.addAll(
          querySnapshot.docs.map((doc) => EventExpense.fromFirestore(doc)).toList()
        );
      }

      return allExpenses;
    } catch (e) {
      print('Error getting expenses by organizer: $e');
      return [];
    }
  }

  // Get expenses within a date range
  static Future<List<EventExpense>> getExpensesByDateRange(
    String eventId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('eventId', isEqualTo: eventId)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => EventExpense.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting expenses by date range: $e');
      return [];
    }
  }

  // Get expense statistics for an event
  static Future<Map<String, dynamic>> getExpenseStatistics(String eventId) async {
    try {
      final expenses = await getExpensesByEvent(eventId);
      final categoryTotals = await getExpensesByCategory(eventId);

      final total = expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
      final average = expenses.isNotEmpty ? total / expenses.length : 0.0;
      final highest = expenses.isNotEmpty 
          ? expenses.reduce((a, b) => a.amount > b.amount ? a : b).amount 
          : 0.0;
      final lowest = expenses.isNotEmpty 
          ? expenses.reduce((a, b) => a.amount < b.amount ? a : b).amount 
          : 0.0;

      return {
        'total': total,
        'average': average,
        'highest': highest,
        'lowest': lowest,
        'count': expenses.length,
        'byCategory': categoryTotals,
      };
    } catch (e) {
      print('Error getting expense statistics: $e');
      return {
        'total': 0.0,
        'average': 0.0,
        'highest': 0.0,
        'lowest': 0.0,
        'count': 0,
        'byCategory': {},
      };
    }
  }
}
