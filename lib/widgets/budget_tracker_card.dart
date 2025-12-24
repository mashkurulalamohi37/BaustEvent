import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetTrackerCard extends StatelessWidget {
  final double? totalBudget;
  final double totalSpent;
  final VoidCallback? onSetBudget;
  final bool isDark;
  final Color primaryColor;

  const BudgetTrackerCard({
    super.key,
    this.totalBudget,
    required this.totalSpent,
    this.onSetBudget,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // We NO LONGER call Theme.of(context) here to avoid the assertion error
    final hasBudget = totalBudget != null && totalBudget! > 0;
    
    final budgetValue = totalBudget ?? 0;
    final remaining = budgetValue - totalSpent;
    final percentageUsed = budgetValue > 0 ? (totalSpent / budgetValue * 100).clamp(0, 100) : 0.0;
    final isOverBudget = totalSpent > budgetValue;
    
    Color statusColor = Colors.green;
    if (isOverBudget) {
      statusColor = Colors.red;
    } else if (percentageUsed > 80) {
      statusColor = Colors.orange;
    }

    final greyColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Card(
      elevation: 2,
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasBudget ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined, 
                      color: hasBudget ? statusColor : Colors.orange, 
                      size: 24
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hasBudget ? 'Budget Tracker' : 'No Budget Set', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onSetBudget,
                  child: Text(
                    hasBudget ? 'Edit' : 'Set', 
                    style: TextStyle(
                      color: primaryColor, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ],
            ),
            
            if (hasBudget) ...[
              const SizedBox(height: 12),
              // Simple Progress Bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (percentageUsed / 100).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfo('Total', '৳${NumberFormat('#,##0').format(budgetValue)}', greyColor, isDark),
                  _buildInfo('Spent', '৳${NumberFormat('#,##0').format(totalSpent)}', statusColor, isDark, isBold: true),
                  _buildInfo(isOverBudget ? 'Over' : 'Left', '৳${NumberFormat('#,##0').format(remaining.abs())}', statusColor, isDark, isBold: true),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Set a budget to track your event expenses and stay on target.',
                style: TextStyle(fontSize: 12, color: greyColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String amount, Color amountColor, bool isDark, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        Text(
          amount, 
          style: TextStyle(
            fontSize: 13, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            color: amountColor
          )
        ),
      ],
    );
  }
}
