import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/event_expense.dart';
import '../services/firebase_expense_service.dart';
import '../widgets/expense_card.dart';
import '../widgets/expense_summary_card.dart';
import '../widgets/budget_tracker_card.dart';
import 'package:share_plus/share_plus.dart';
import 'add_expense_screen.dart';
import 'expense_graphical_view_screen.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ExpenseTrackerScreen extends StatefulWidget {
  final Event event;
  final String userId;
  final bool isAdmin;

  const ExpenseTrackerScreen({
    super.key,
    required this.event,
    required this.userId,
    this.isAdmin = false,
  });

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  StreamSubscription<List<EventExpense>>? _expensesSubscription;
  StreamSubscription<DocumentSnapshot>? _eventSubscription; // New subscription
  List<EventExpense> _expenses = [];
  bool _isLoading = true;
  double? _currentBudget; // Track budget locally
  
  // Filtering
  ExpenseCategory? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentBudget = widget.event.budget; // Initialize with event budget
    _loadExpenses();
    _setupEventSubscription(); // Start listening to event changes
  }

  void _setupEventSubscription() {
    _eventSubscription = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.event.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('budget')) {
          setState(() {
            _currentBudget = (data['budget'] is int) 
                ? (data['budget'] as int).toDouble() 
                : data['budget'] as double?;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    _eventSubscription?.cancel(); // Cancel subscription
    _searchController.dispose();
    super.dispose();
  }

  void _loadExpenses() {
    setState(() => _isLoading = true);
    
    // Load initial data
    FirebaseExpenseService.getExpensesByEvent(widget.event.id).then((expenses) {
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
        });
      }
    });

    // Set up real-time stream
    _expensesSubscription?.cancel();
    _expensesSubscription = FirebaseExpenseService.getExpensesByEventStream(widget.event.id).listen(
      (expenses) {
        if (mounted) {
          setState(() {
            _expenses = expenses;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        print('Error loading expenses: $error');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  List<EventExpense> get _filteredExpenses {
    var filtered = _expenses;

    // Filter by category
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.category.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (e.notes?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    return filtered;
  }

  Map<ExpenseCategory, double> get _categoryBreakdown {
    final Map<ExpenseCategory, double> breakdown = {};
    for (var expense in _expenses) {
      breakdown[expense.category] = (breakdown[expense.category] ?? 0.0) + expense.amount;
    }
    return breakdown;
  }

  double get _totalExpenses {
    return _expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  void _openGraphicalView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseGraphicalViewScreen(
          expenses: _expenses,
          totalBudget: _currentBudget ?? 0,
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }

    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      
      // Rename default sheet
      String sheetName = 'Expenses';
      excel.rename('Sheet1', sheetName);
      
      Sheet sheetObject = excel[sheetName];

      // Add Headers
      List<String> headers = ['Date', 'Description', 'Category', 'Amount', 'Payment Method', 'Notes'];
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());
      
      // Style headers (optional, basic bolding if supported or just raw data)
      // The excel package basic usage is appending rows.
      
      // Add Data
      for (var expense in _expenses) {
        sheetObject.appendRow([
          TextCellValue(DateFormat('yyyy-MM-dd').format(expense.date)),
          TextCellValue(expense.description),
          TextCellValue(expense.category.displayName),
          DoubleCellValue(expense.amount),
          TextCellValue(expense.paymentMethod.displayName),
          TextCellValue(expense.notes ?? ''),
        ]);
      }

      // Save file
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/expenses_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      final fileBytes = excel.save();
      
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        
        // Share file
        final xFile = XFile(path);
        await Share.shareXFiles([xFile], text: '${widget.event.title} Expenses Export');
      }
      
    } catch (e) {
      print('Error exporting to Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  Future<void> _addExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          eventId: widget.event.id,
          userId: widget.userId,
        ),
      ),
    );

    if (result == true) {
      // Expenses will update automatically via stream
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _editExpense(EventExpense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(
          eventId: widget.event.id,
          userId: widget.userId,
          expense: expense,
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(EventExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.description}"?'),
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

    if (confirm == true) {
      final success = await FirebaseExpenseService.deleteExpense(expense.id);
      if (success && mounted) {
        // Success feedback from UI update is enough
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete expense'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _canEditExpense(EventExpense expense) {
    return widget.isAdmin || expense.createdBy == widget.userId;
  }

  Future<void> _setBudget() async {
    print('🔧 Opening budget dialog...');
    final TextEditingController budgetController = TextEditingController(
      text: _currentBudget?.toStringAsFixed(0) ?? '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Event Budget'),
        content: TextField(
          controller: budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Budget (৳)',
            hintText: 'Enter total budget amount',
            prefixText: '৳ ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(budgetController.text);
              print('💰 Parsed budget amount: $amount');
              Navigator.pop(context, amount);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    budgetController.dispose();

    print('📊 Dialog result: $result');

    if (result != null && result > 0 && mounted) {
      // Update budget in Firestore
      try {
        print('🔄 Updating budget in Firestore for event: ${widget.event.id}');
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event.id)
            .update({'budget': result});
        
        print('✅ Budget updated successfully in Firestore');
        
        if (mounted) {
          print('Budget update feedback: UI will reflect change');
        }
      } catch (e, stackTrace) {
        print('❌ Error updating budget: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update budget: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print('⚠️ Budget update cancelled or invalid amount');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredExpenses = _filteredExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          // Graphical View Button (Replaces filter)
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Graphical View',
            onPressed: _openGraphicalView,
          ),
          // Export Button
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export Excel',
            onPressed: () => _exportToExcel(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadExpenses();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Info
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.event,
                                color: Color(0xFF1976D2),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.event.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(widget.event.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Budget Tracker
                    BudgetTrackerCard(
                      key: const ValueKey('stable_budget_card'),
                      totalBudget: _currentBudget,
                      totalSpent: _totalExpenses,
                      onSetBudget: _setBudget,
                      isDark: isDark,
                      primaryColor: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 10),

                    // Summary Card
                    ExpenseSummaryCard(
                      totalExpenses: _totalExpenses,
                      categoryBreakdown: _categoryBreakdown,
                      expenseCount: _expenses.length,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search expenses...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Active Filters
                    if (_selectedCategory != null) ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(_selectedCategory!.displayName),
                            onDeleted: () {
                              setState(() {
                                _selectedCategory = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Expense List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expenses (${filteredExpenses.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Expense List
                    if (filteredExpenses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _selectedCategory != null
                                    ? 'No expenses found'
                                    : 'No expenses recorded yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty || _selectedCategory != null
                                    ? 'Try adjusting your filters'
                                    : 'Add your first expense to get started',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredExpenses.map((expense) => ExpenseCard(
                        expense: expense,
                        onEdit: _canEditExpense(expense) ? () => _editExpense(expense) : null,
                        onDelete: _canEditExpense(expense) ? () => _deleteExpense(expense) : null,
                        showActions: _canEditExpense(expense),
                        isDark: isDark,
                      )),
                    
                    // Add bottom padding to prevent FAB from covering last item
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    );
  }
}
