import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/event_expense.dart';
import 'package:intl/intl.dart';

class ExpenseGraphicalViewScreen extends StatefulWidget {
  final List<EventExpense> expenses;
  final double totalBudget;

  const ExpenseGraphicalViewScreen({
    super.key,
    required this.expenses,
    this.totalBudget = 0,
  });

  @override
  State<ExpenseGraphicalViewScreen> createState() => _ExpenseGraphicalViewScreenState();
}

class _ExpenseGraphicalViewScreenState extends State<ExpenseGraphicalViewScreen> {
  int _touchedIndex = -1;

  Map<ExpenseCategory, double> get _categoryBreakdown {
    final Map<ExpenseCategory, double> breakdown = {};
    for (var expense in widget.expenses) {
      breakdown[expense.category] = (breakdown[expense.category] ?? 0.0) + expense.amount;
    }
    return breakdown;
  }

  double get _totalExpenses {
    return widget.expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  // Elegant Pastel/Vibrant Palette
  // Standard Material Palette (Matches List View)
  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.venue: return Colors.purple;
      case ExpenseCategory.catering: return Colors.orange;
      case ExpenseCategory.equipment: return Colors.blue;
      case ExpenseCategory.marketing: return Colors.pink;
      case ExpenseCategory.transportation: return Colors.teal;
      case ExpenseCategory.staff: return Colors.indigo;
      case ExpenseCategory.decorations: return Colors.amber;
      case ExpenseCategory.prizes: return Colors.green;
      case ExpenseCategory.printing: return Colors.cyan;
      case ExpenseCategory.other: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.venue: return Icons.curtains_closed_rounded;
      case ExpenseCategory.catering: return Icons.restaurant_menu_rounded;
      case ExpenseCategory.equipment: return Icons.speaker_group_rounded;
      case ExpenseCategory.marketing: return Icons.campaign_rounded;
      case ExpenseCategory.transportation: return Icons.directions_car_filled_rounded;
      case ExpenseCategory.staff: return Icons.badge_rounded;
      case ExpenseCategory.decorations: return Icons.celebration_rounded;
      case ExpenseCategory.prizes: return Icons.emoji_events_rounded;
      case ExpenseCategory.printing: return Icons.print_rounded;
      case ExpenseCategory.other: return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final breakdown = _categoryBreakdown;
    final total = _totalExpenses;
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate center info
    String centerTopText;
    String centerMainText;
    String centerBottomText;
    Color centerColor;

    if (_touchedIndex != -1 && _touchedIndex < sortedEntries.length) {
      final entry = sortedEntries[_touchedIndex];
      centerTopText = 'Spending on';
      centerMainText = entry.key.displayName;
      centerBottomText = '৳${NumberFormat.compact().format(entry.value)}';
      centerColor = _getCategoryColor(entry.key);
    } else {
      centerTopText = 'Total Spent';
      centerMainText = '৳${NumberFormat.compact().format(total)}';
      centerBottomText = 'in ${widget.expenses.length} txns';
      centerColor = isDark ? Colors.white : const Color(0xFF2D3436);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Insights'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            // Elegant Donut Chart
            if (breakdown.isNotEmpty)
              SizedBox(
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 70,
                        sections: List.generate(sortedEntries.length, (i) {
                          final isTouched = i == _touchedIndex;
                          final entry = sortedEntries[i];
                          final percentage = (entry.value / total * 100);
                          final fontSize = isTouched ? 18.0 : 14.0;
                          final radius = isTouched ? 60.0 : 50.0;
                          final color = _getCategoryColor(entry.key);

                          return PieChartSectionData(
                            color: color,
                            value: entry.value,
                            title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
                            radius: radius,
                            titleStyle: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                            ),
                          );
                        }),
                      ),
                    ),
                    // Animated Center Content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          centerTopText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            centerMainText,
                            key: ValueKey(centerMainText),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: centerColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          centerBottomText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 250,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No data to visualize', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Premium Budget Card
            if (widget.totalBudget > 0)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF192B7A), Color(0xFF4C83FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4C83FF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL BUDGET',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '৳${NumberFormat('#,##0').format(widget.totalBudget)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Custom Progress Bar
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          height: 8,
                          width: MediaQuery.of(context).size.width * 
                                ((total / widget.totalBudget).clamp(0.0, 1.0)) * 0.8, // approximate width calc
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTransparentStat('Spent', total),
                        _buildTransparentStat(
                          total > widget.totalBudget ? 'Overrun' : 'Remaining',
                          (widget.totalBudget - total).abs(),
                          isWarning: total > widget.totalBudget,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Clean Category List
            Row(
              children: [
                Text(
                  'Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.expenses.length} Transactions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ...sortedEntries.map((entry) {
              final isTouched = breakdown.keys.toList().indexOf(entry.key) == _touchedIndex;
              final percentage = (entry.value / total * 100);
              final color = _getCategoryColor(entry.key);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isTouched 
                    ? Border.all(color: color, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(entry.key),
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            children: [
                              Container(
                                height: 4,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                height: 4,
                                width: 100 * (percentage / 100).clamp(0.0, 1.0),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '৳${NumberFormat('#,##0').format(entry.value)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(ExpenseCategory category) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getCategoryIcon(category),
        size: 16,
        color: _getCategoryColor(category),
      ),
    );
  }

  Widget _buildTransparentStat(String label, double amount, {bool isWarning = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '৳${NumberFormat.compact().format(amount)}',
          style: TextStyle(
            color: isWarning ? const Color(0xFFFF6B6B) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
