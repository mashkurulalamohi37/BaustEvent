import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/theme_service.dart';

class AnalyticsScreen extends StatelessWidget {
  final List<Event> events;
  final bool showTopBar;

  const AnalyticsScreen({super.key, required this.events, this.showTopBar = true});

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final totalEvents = events.length;
    final completedEvents = events.where((e) => 
      e.status == EventStatus.completed || 
      (DateTime(e.date.year, e.date.month, e.date.day).isBefore(today))
    ).toList();
    
    final upcomingEvents = events.where((e) {
      final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
      return eventDate.isAfter(today);
    }).toList();
    
    final ongoingEvents = events.where((e) {
      final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList();
    
    // Calculate success metrics
    final totalParticipants = events.fold<int>(0, (sum, e) => sum + e.participants.length);
    final avgParticipants = totalEvents > 0 ? (totalParticipants / totalEvents).round() : 0;
    
    // Success rate: Events with >= 50% participation or completed status
    final successfulEvents = completedEvents.where((e) {
      final participationRate = e.maxParticipants > 0 
          ? (e.participants.length / e.maxParticipants) * 100 
          : 0;
      return participationRate >= 50 || e.status == EventStatus.completed;
    }).length;
    
    final successRate = totalEvents > 0 
        ? ((successfulEvents / totalEvents) * 100).round() 
        : 0;
    
    // Category distribution
    final categoryCounts = <String, int>{};
    for (var event in events) {
      categoryCounts[event.category] = (categoryCounts[event.category] ?? 0) + 1;
    }
    
    // Monthly event distribution (last 6 months)
    final monthlyData = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM yyyy').format(month);
      monthlyData[monthKey] = 0;
    }
    
    for (var event in events) {
      final monthKey = DateFormat('MMM yyyy').format(event.date);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
      }
    }
    

    // Get or create theme service instance
    final themeService = ThemeService.instance;
    if (themeService == null) {
      // If no instance exists, create one - this should rarely happen
      final newService = ThemeService();
      return ListenableBuilder(
        listenable: newService,
        builder: (context, _) {
          // Force rebuild by reading the value fresh
          final isDark = newService.isDarkMode;
          return _buildContent(
            context,
            isDark,
            totalEvents,
            successRate,
            totalParticipants,
            avgParticipants,
            successfulEvents,
            completedEvents,
            upcomingEvents,
            ongoingEvents,
            events,
            monthlyData,
            categoryCounts,
          );
        },
      );
    }
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        // Force rebuild by reading the value fresh
        final isDark = themeService.isDarkMode;
        return _buildContent(
          context,
          isDark,
          totalEvents,
          successRate,
          totalParticipants,
          avgParticipants,
          successfulEvents,
          completedEvents,
          upcomingEvents,
          ongoingEvents,
          events,
          monthlyData,
          categoryCounts,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDarkFromService,
    int totalEvents,
    int successRate,
    int totalParticipants,
    int avgParticipants,
    int successfulEvents,
    List<Event> completedEvents,
    List<Event> upcomingEvents,
    List<Event> ongoingEvents,
    List<Event> allEvents,
    Map<String, int> monthlyData,
    Map<String, int> categoryCounts,
  ) {
        // Check if we're in admin dashboard (which forces light mode via Theme widget)
        // Admin dashboard wraps with ThemeService.lightTheme, so if parent is light AND
        // we're embedded (showTopBar is false), we're in admin dashboard
        // Otherwise, always use ThemeService value to respect user's theme choice
        final parentThemeIsLight = Theme.of(context).brightness == Brightness.light;
        // Only force light mode if we're embedded (no top bar) AND parent is light (admin dashboard)
        // Otherwise, use ThemeService value (respects user's dark/light mode choice)
        final actualIsDark = (!showTopBar && parentThemeIsLight) ? false : isDarkFromService;
        // Force dark mode colors when dark mode is active
        final cardColor = actualIsDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = actualIsDark ? Colors.white : Colors.black;
        final secondaryTextColor = actualIsDark ? Colors.grey[300] : Colors.grey[700];
        // Force scaffold background color based on theme
        final scaffoldColor = actualIsDark ? const Color(0xFF121212) : Colors.white;
        
        return Container(
          color: scaffoldColor,
          child: Column(
            children: [
              // Top Bar - Only show if showTopBar is true
              if (showTopBar)
                Container(
                  height: kToolbarHeight + MediaQuery.of(context).padding.top,
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  decoration: BoxDecoration(
                    color: actualIsDark ? const Color(0xFF121212) : const Color(0xFF1976D2),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Analytics View',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button width
                    ],
                  ),
                ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Cards - Upper Portion
                      const SizedBox(height: 8),
                Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      actualIsDark,
                      'Total Events',
                      totalEvents.toString(),
                      Icons.event,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      actualIsDark,
                      'Success Rate',
                      '$successRate%',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      actualIsDark,
                      'Total Participants',
                      totalParticipants.toString(),
                      Icons.people,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      actualIsDark,
                      'Avg/Event',
                      avgParticipants.toString(),
                      Icons.bar_chart,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            
            // Success Rate Pie Chart
            Container(
                  decoration: BoxDecoration(
                    color: actualIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Success Rate',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: actualIsDark ? Colors.white : Colors.black,
                          ),
                        ),
                    const SizedBox(height: 20),
                     SizedBox(
                       height: 200,
                       child: Row(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Expanded(
                             flex: 3,
                             child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: successfulEvents.toDouble(),
                                    title: '$successfulEvents\nSuccessful',
                                    color: Colors.green,
                                    radius: 60,
                                    titleStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: actualIsDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: (totalEvents - successfulEvents).toDouble(),
                                    title: '${totalEvents - successfulEvents}\nOthers',
                                    color: Colors.grey,
                                    radius: 60,
                                    titleStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: actualIsDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                           Expanded(
                             flex: 3,
                             child: Padding(
                               padding: const EdgeInsets.only(left: 4.0, right: 4.0),
                               child: Column(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   _buildLegendItem(actualIsDark, Colors.green, 'Success', successfulEvents),
                                   const SizedBox(height: 8),
                                   _buildLegendItem(actualIsDark, Colors.grey, 'Others', totalEvents - successfulEvents),
                                 ],
                               ),
                             ),
                           ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Event Status Distribution
            Container(
                  decoration: BoxDecoration(
                    color: actualIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Events by Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: actualIsDark ? Colors.white : Colors.black,
                          ),
                        ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: totalEvents > 0 ? totalEvents.toDouble() + 1 : 5,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  final labels = ['Upcoming', 'Ongoing', 'Completed', 'Draft'];
                                  if (index >= 0 && index < labels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        labels[index],
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: actualIsDark ? Colors.grey[300] : null,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: actualIsDark ? Colors.grey[300] : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border(
                              bottom: BorderSide(
                                color: actualIsDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                              left: BorderSide(
                                color: actualIsDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: actualIsDark ? Colors.grey[800]! : Colors.grey[200]!,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              );
                            },
                          ),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: upcomingEvents.length.toDouble(),
                                  color: Colors.blue,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: ongoingEvents.length.toDouble(),
                                  color: Colors.green,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 2,
                              barRods: [
                                BarChartRodData(
                                  toY: completedEvents.length.toDouble(),
                                  color: Colors.orange,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 3,
                              barRods: [
                                BarChartRodData(
                                  toY: allEvents.where((e) => e.status == EventStatus.draft).length.toDouble(),
                                  color: Colors.grey,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Monthly Events Trend
            if (monthlyData.values.any((v) => v > 0))
              Container(
                    decoration: BoxDecoration(
                      color: actualIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Events Over Time (Last 6 Months)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: actualIsDark ? Colors.white : Colors.black,
                            ),
                          ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: actualIsDark ? Colors.grey[800]! : Colors.grey[200]!,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    final months = monthlyData.keys.toList();
                                    if (index >= 0 && index < months.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          months[index].split(' ')[0],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: actualIsDark ? Colors.grey[300] : null,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(
                                  color: actualIsDark ? Colors.grey[700]! : Colors.grey[300]!,
                                  width: 1,
                                ),
                                left: BorderSide(
                                  color: actualIsDark ? Colors.grey[700]! : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: monthlyData.values.toList().asMap().entries.map((e) {
                                  return FlSpot(e.key.toDouble(), e.value.toDouble());
                                }).toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                              ),
                            ],
                            minY: 0,
                            maxY: monthlyData.values.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            
            // Category Distribution
            if (categoryCounts.isNotEmpty)
              Container(
                    decoration: BoxDecoration(
                      color: actualIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Events by Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: actualIsDark ? Colors.white : Colors.black,
                            ),
                          ),
                      const SizedBox(height: 20),
                      ...categoryCounts.entries.map((entry) {
                        final percentage = totalEvents > 0 
                            ? ((entry.value / totalEvents) * 100).round() 
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: actualIsDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value} ($percentage%)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: actualIsDark ? Colors.grey[300] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: entry.value / totalEvents,
                                backgroundColor: actualIsDark ? Colors.grey[800] : Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getCategoryColor(entry.key),
                                ),
                                minHeight: 8,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildStatCard(BuildContext context, bool actualIsDark, String title, String value, IconData icon, Color color) {
    // Force dark mode colors when dark mode is active
    final cardColor = actualIsDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleTextColor = actualIsDark ? Colors.grey[300] : Colors.grey[700];
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: titleTextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(bool actualIsDark, Color color, String label, int value) {
    return Row(
      children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 10,
                color: actualIsDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'seminars':
        return Colors.blue;
      case 'workshops':
        return Colors.green;
      case 'cultural':
        return Colors.orange;
      case 'competitions':
        return Colors.purple;
      case 'rag day':
        return Colors.pink;
      case 'picnic':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

