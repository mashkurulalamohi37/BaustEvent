import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/theme_service.dart';

enum EventFilterType {
  all,
  upcoming,
  ongoing,
  past,
  completed,
}

class AnalyticsScreen extends StatefulWidget {
  final List<Event> events;
  final bool showTopBar;

  const AnalyticsScreen({super.key, required this.events, this.showTopBar = true});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  EventFilterType _selectedFilter = EventFilterType.upcoming;

  @override
  Widget build(BuildContext context) {
    // Calculate statistics
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final totalEvents = widget.events.length;
    final completedEvents = widget.events.where((e) => 
      e.status == EventStatus.completed || 
      (DateTime(e.date.year, e.date.month, e.date.day).isBefore(today))
    ).toList();
    
    final upcomingEvents = widget.events.where((e) {
      final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
      return eventDate.isAfter(today);
    }).toList();
    
    final ongoingEvents = widget.events.where((e) {
      final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
      return eventDate.isAtSameMomentAs(today);
    }).toList();
    
    // Filter events based on selection, but always include ongoing events
    List<Event> filteredEvents;
    switch (_selectedFilter) {
      case EventFilterType.all:
        filteredEvents = widget.events;
        break;
      case EventFilterType.upcoming:
        filteredEvents = [...upcomingEvents, ...ongoingEvents];
        break;
      case EventFilterType.ongoing:
        filteredEvents = ongoingEvents;
        break;
      case EventFilterType.past:
        filteredEvents = [...completedEvents, ...ongoingEvents];
        break;
      case EventFilterType.completed:
        filteredEvents = [...completedEvents.where((e) => e.status == EventStatus.completed).toList(), ...ongoingEvents];
        break;
    }
    
    // Remove duplicates (in case ongoing events are included multiple times)
    filteredEvents = filteredEvents.toSet().toList();
    
    // Calculate success metrics
    final totalParticipants = widget.events.fold<int>(0, (sum, e) => sum + e.participants.length);
    final avgParticipants = totalEvents > 0 ? (totalParticipants / totalEvents).round() : 0;
    
    // Success rate: Based on registered participants vs max participants for each event
    // Calculate average participation rate across all events
    double totalParticipationRate = 0;
    int eventsWithMaxParticipants = 0;
    int successfulEvents = 0; // Events with >= 50% participation
    
    for (var event in widget.events) {
      if (event.maxParticipants > 0) {
        final participationRate = (event.participants.length / event.maxParticipants) * 100;
        totalParticipationRate += participationRate;
        eventsWithMaxParticipants++;
        
        // Count as successful if >= 50% registered
        if (participationRate >= 50) {
          successfulEvents++;
        }
      }
    }
    
    // Calculate overall success rate as average participation rate
    final successRate = eventsWithMaxParticipants > 0
        ? (totalParticipationRate / eventsWithMaxParticipants).round()
        : 0;
    
    // Category distribution
    final categoryCounts = <String, int>{};
    for (var event in widget.events) {
      categoryCounts[event.category] = (categoryCounts[event.category] ?? 0) + 1;
    }
    
    // Monthly event distribution (last 6 months)
    final monthlyData = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM yyyy').format(month);
      monthlyData[monthKey] = 0;
    }
    
    for (var event in widget.events) {
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
            widget.events,
            monthlyData,
            categoryCounts,
            filteredEvents,
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
          widget.events,
          monthlyData,
          categoryCounts,
          filteredEvents,
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
    List<Event> filteredEvents,
  ) {
        // Check if we're in admin dashboard (which forces light mode via Theme widget)
        // Admin dashboard wraps with ThemeService.lightTheme, so if parent is light AND
        // we're embedded (showTopBar is false), we're in admin dashboard
        // Otherwise, always use ThemeService value to respect user's theme choice
        final parentThemeIsLight = Theme.of(context).brightness == Brightness.light;
        // Only force light mode if we're embedded (no top bar) AND parent is light (admin dashboard)
        // Otherwise, use ThemeService value (respects user's dark/light mode choice)
        final actualIsDark = (!widget.showTopBar && parentThemeIsLight) ? false : isDarkFromService;
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
              if (widget.showTopBar)
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
            
            // Per-Event Success Rate - Elegant Design
            Container(
              decoration: BoxDecoration(
                color: actualIsDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: actualIsDark 
                      ? Colors.grey[800]!.withOpacity(0.3)
                      : Colors.grey[200]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(actualIsDark ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: Colors.green[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Event Success Rate',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: actualIsDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: actualIsDark 
                                ? Colors.grey[800] 
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: actualIsDark 
                                  ? Colors.grey[700]! 
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<EventFilterType>(
                              value: _selectedFilter,
                              icon: Icon(
                                Icons.filter_list,
                                size: 18,
                                color: actualIsDark ? Colors.white : Colors.black87,
                              ),
                              isDense: true,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: actualIsDark ? Colors.white : Colors.black87,
                              ),
                              dropdownColor: actualIsDark 
                                  ? Colors.grey[900] 
                                  : Colors.white,
                              items: [
                                DropdownMenuItem(
                                  value: EventFilterType.all,
                                  child: Row(
                                    children: [
                                      Icon(Icons.event, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      const Text('All Events'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: EventFilterType.upcoming,
                                  child: Row(
                                    children: [
                                      Icon(Icons.upcoming, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      const Text('Upcoming'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: EventFilterType.ongoing,
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_available, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      const Text('Ongoing'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: EventFilterType.past,
                                  child: Row(
                                    children: [
                                      Icon(Icons.history, size: 16, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      const Text('Past'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: EventFilterType.completed,
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      const Text('Completed'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (EventFilterType? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedFilter = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ongoingEvents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ongoing events are always shown',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    filteredEvents.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No events to display',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: actualIsDark 
                                      ? Colors.grey[400] 
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredEvents.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final event = filteredEvents[index];
                              final isOngoing = ongoingEvents.contains(event);
                              final registeredCount = event.participants.length;
                              final maxCount = event.maxParticipants;
                              final eventSuccessRate = maxCount > 0
                                  ? ((registeredCount / maxCount) * 100).round()
                                  : 0;
                              
                              return _buildEventSuccessCard(
                                actualIsDark,
                                event,
                                registeredCount,
                                maxCount,
                                eventSuccessRate,
                                isOngoing,
                              );
                            },
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

  Widget _buildElegantLegendItem(bool actualIsDark, Color color, String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: actualIsDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value event${value != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: actualIsDark 
                        ? Colors.grey[400] 
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSuccessCard(
    bool actualIsDark,
    Event event,
    int registeredCount,
    int maxCount,
    int successRate,
    bool isOngoing,
  ) {
    final isHighSuccess = successRate >= 70;
    final isMediumSuccess = successRate >= 50;
    final successColor = isHighSuccess
        ? const Color(0xFF10B981) // Green
        : isMediumSuccess
            ? Colors.orange
            : Colors.red[400]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: actualIsDark 
            ? Colors.grey[900]!.withOpacity(0.5)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: successColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isOngoing)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.radio_button_checked,
                              size: 12,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ongoing',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: actualIsDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$successRate%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: actualIsDark 
                            ? Colors.grey[400] 
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$registeredCount / $maxCount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: actualIsDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: maxCount > 0 ? registeredCount / maxCount : 0,
                    backgroundColor: actualIsDark 
                        ? Colors.grey[800]! 
                        : Colors.grey[200]!,
                    valueColor: AlwaysStoppedAnimation<Color>(successColor),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

