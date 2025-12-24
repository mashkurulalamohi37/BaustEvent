import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/event_expense.dart';

class ExpensePieChart extends StatelessWidget {
  final Map<ExpenseCategory, double> categoryBreakdown;
  final double totalExpenses;

  const ExpensePieChart({
    super.key,
    required this.categoryBreakdown,
    required this.totalExpenses,
  });

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.venue:
        return Colors.purple;
      case ExpenseCategory.catering:
        return Colors.orange;
      case ExpenseCategory.equipment:
        return Colors.blue;
      case ExpenseCategory.marketing:
        return Colors.pink;
      case ExpenseCategory.transportation:
        return Colors.teal;
      case ExpenseCategory.staff:
        return Colors.indigo;
      case ExpenseCategory.decorations:
        return Colors.amber;
      case ExpenseCategory.prizes:
        return Colors.green;
      case ExpenseCategory.printing:
        return Colors.cyan;
      case ExpenseCategory.other:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (categoryBreakdown.isEmpty || totalExpenses == 0) {
      return const SizedBox.shrink();
    }

    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Pie Chart
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: sortedCategories.map((entry) {
                          final category = entry.key;
                          final amount = entry.value;
                          final percentage = (amount / totalExpenses * 100);
                          final color = _getCategoryColor(category);

                          return PieChartSectionData(
                            color: color,
                            value: amount,
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedCategories.map((entry) {
                          final category = entry.key;
                          final color = _getCategoryColor(category);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    category.displayName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
