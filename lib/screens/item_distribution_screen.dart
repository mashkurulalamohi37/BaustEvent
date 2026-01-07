import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/event_item.dart';
import '../models/user.dart' as app_user;
import '../services/firebase_item_distribution_service.dart';
import '../services/firebase_event_service.dart';
import '../services/theme_service.dart';

class ItemDistributionScreen extends StatefulWidget {
  final String eventId;
  final String currentUserId;

  const ItemDistributionScreen({
    super.key,
    required this.eventId,
    required this.currentUserId,
  });

  @override
  State<ItemDistributionScreen> createState() => _ItemDistributionScreenState();
}

class _ItemDistributionScreenState extends State<ItemDistributionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EventItem> _items = [];
  EventItem? _selectedItem;
  Event? _event;
  bool _isLoading = true;
  
  // Filters
  bool _showFilters = false;
  Set<String> _expandedParticipants = {};
  
  // Filter selections
  String? _selectedHall;
  String? _selectedGender;
  String? _selectedFood;
  String? _selectedTshirtSize;
  String _selectedBatch = 'All';
  String _selectedSection = 'All';
  List<String> _batches = ['All'];
  List<String> _sections = ['All'];
  
  // Cache for performance
  List<app_user.User>? _cachedParticipants;
  Set<String>? _cachedDistributedIds;
  Map<String, Map<String, dynamic>>? _cachedRegistrations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final event = await FirebaseEventService.getEventById(widget.eventId);
      var items = await FirebaseItemDistributionService.getEventItems(widget.eventId);
      
      // DEDUPLICATE ITEMS VISUALLY
      final uniqueItems = <EventItem>[];
      final seenNames = <String>{};
      
      for (var item in items) {
        final lowerName = item.name.toLowerCase();
        if (!seenNames.contains(lowerName)) {
          seenNames.add(lowerName);
          uniqueItems.add(item);
        }
      }
      items = uniqueItems;
      
      // Prefetch registration details
      final regSnapshot = await FirebaseFirestore.instance
          .collection('event_participants') // Correct collection name
          .where('eventId', isEqualTo: widget.eventId)
          .get();
          
      _cachedRegistrations = {};
      for (var doc in regSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        if (userId != null) {
          _cachedRegistrations![userId] = data;
        }
      }

      // Prefetch participants (Load ALL once)
      _cachedParticipants = await FirebaseEventService.getRegisteredParticipants(widget.eventId);
      
      // Initialize selected item and fetch distribution status
      if (_selectedItem == null && items.isNotEmpty) {
        _selectedItem = items.first;
      }
      
      if (_selectedItem != null) {
        _cachedDistributedIds = await FirebaseItemDistributionService.getDistributedParticipantIds(
          itemId: _selectedItem!.id,
        );
      } else {
        _cachedDistributedIds = {};
      }
      
      _buildFilterLists();
      
      setState(() {
        _event = event;
        _items = items;
        _isLoading = false;
      });
      
      // Auto-create items based on event configuration if no items exist
      if (_event != null && items.isEmpty) {
        await _autoCreateItemsFromEvent();
      } else if (_event != null && items.isNotEmpty) {
        // Update existing items if they have wrong totalQuantity
        final correctCount = _event!.participants.length;
        bool needsUpdate = false;
        
        for (var item in items) {
          if (item.totalQuantity != correctCount) {
            needsUpdate = true;
            await FirebaseItemDistributionService.updateItemQuantity(
              item.id, 
              correctCount,
            );
          }
        }
        
        if (needsUpdate) {
          await _loadData(); // Reload with updated quantities
          return;
        }
        
        if (_selectedItem == null) {
          _selectedItem = items.first;
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _autoCreateItemsFromEvent() async {
    if (_event == null) return;
    
    // Get actual registered participant count
    final participantCount = _event!.participants.length;
    
    final itemsToCreate = <EventItem>[];
    
    // Check if Food item already exists
    final hasFoodItem = _items.any((item) => item.name.toLowerCase() == 'food');
    
    // Check event configuration and create relevant items only if they don't exist
    if (_event!.requireFood && !hasFoodItem) {
      itemsToCreate.add(EventItem(
        id: '',
        eventId: widget.eventId,
        name: 'Food',
        description: 'Event meal/refreshment',
        totalQuantity: participantCount, // Use actual participant count
        createdAt: DateTime.now(),
        createdBy: widget.currentUserId,
      ));
    }
    
    // Check if T-Shirt item already exists
    final hasTShirtItem = _items.any((item) => item.name.toLowerCase().contains('shirt'));
    
    if (_event!.requireTshirtSize && !hasTShirtItem) {
      itemsToCreate.add(EventItem(
        id: '',
        eventId: widget.eventId,
        name: 'T-Shirt',
        description: 'Event t-shirt',
        totalQuantity: participantCount, // Use actual participant count
        createdAt: DateTime.now(),
        createdBy: widget.currentUserId,
      ));
    }
    
    // Only save and reload if there are new items to create
    if (itemsToCreate.isEmpty) {
      print('No new items to create - items already exist');
      return;
    }
    
    // Save all NEW items to Firestore
    for (var item in itemsToCreate) {
      try {
        await FirebaseItemDistributionService.createEventItem(item);
        print('Created new item: ${item.name}');
      } catch (e) {
        print('Error creating auto item: $e');
      }
    }
    
    // Reload items only if we created new ones
    await _loadData();
  }

  void _buildFilterLists() {
    if (_cachedRegistrations == null || _cachedRegistrations!.isEmpty) {
      return;
    }

    final Set<String> batchSet = {};
    final Set<String> sectionSet = {};

    for (var regData in _cachedRegistrations!.values) {
      // Extract batch
      String? batch = regData['batch']?.toString();
      if (batch != null && batch.isNotEmpty && batch != 'Unknown') {
        batchSet.add(batch);
      }

      // Extract section
      String? section = regData['section']?.toString();
      if (section != null && section.isNotEmpty && section != 'Unknown') {
        // Normalize section
        if (section.startsWith('Section ')) {
          section = section.replaceAll('Section ', '');
        }
        sectionSet.add(section);
      }
    }

    // Sort and add to lists
    final sortedBatches = batchSet.toList()..sort();
    final sortedSections = sectionSet.toList()..sort();

    setState(() {
      _batches = ['All', ...sortedBatches];
      _sections = ['All', ...sortedSections];
    });

    print('Dynamic filters built: Batches=${_batches.length}, Sections=${_sections.length}');
  }


  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeService.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Item Distribution'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _loadData(),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            labelPadding: const EdgeInsets.symmetric(vertical: 4),
            tabs: const [
              Tab(icon: Icon(Icons.checklist, size: 20), text: 'Distribution'),
              Tab(icon: Icon(Icons.analytics, size: 20), text: 'Summary'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                   Column(
                    children: [
                      // Item Selector & Stats Card
                      _buildItemStatsCard(),
                      
                      // Filter Toggle
                      _buildFilterToggle(),
                      
                      // Filter Section (Collapsible)
                      if (_showFilters) _buildFilterSection(),
                      
                      // Requirement Stats (New)
                      _buildRequirementStats(),
                      
                      // Grouped List
                      Expanded(child: _buildGroupedParticipantsList()),
                    ],
                   ),
                  _buildSummaryTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildItemStatsCard() {
    if (_items.isEmpty) {
      return const Center(child: Text('No items available'));
    }

    // Dynamic Stats Calculation
    int currentDist = 0;
    int total = 0;
    double progress = 0.0;
    int remaining = 0;

    if (_selectedItem != null) {
      currentDist = _cachedDistributedIds?.length ?? _selectedItem!.distributedQuantity;
      total = _selectedItem!.totalQuantity;
      remaining = (total - currentDist).clamp(0, total);
      progress = total > 0 ? (currentDist / total) : 0.0;
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Item:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<EventItem>(
            value: _selectedItem,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            items: _items.map((item) {
              // Dynamic count for selected item
              int dQty = item.distributedQuantity;
              if (item.id == _selectedItem?.id && _cachedDistributedIds != null) {
                  dQty = _cachedDistributedIds!.length;
              }
              return DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.name} ($dQty/${item.totalQuantity})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                 _selectedItem = value;
                 // Reload distribution status for new item
                 if (value != null) {
                    _isLoading = true;
                 }
              });
              if (value != null) {
                FirebaseItemDistributionService.getDistributedParticipantIds(itemId: value.id).then((ids) {
                  setState(() {
                    _cachedDistributedIds = ids;
                    _isLoading = false;
                  });
                });
              }
            },
          ),
          if (_selectedItem != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? Colors.green
                    : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$remaining remaining',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
          ),
            if (_selectedHall != null || _selectedGender != null || 
                _selectedBatch != 'All' || _selectedSection != 'All' ||
                _selectedFood != null || _selectedTshirtSize != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedHall = null;
                    _selectedGender = null;
                    _selectedBatch = 'All';
                    _selectedSection = 'All';
                    _selectedFood = null;
                    _selectedTshirtSize = null;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
              ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
           // Batch
           SizedBox(
             width: 150,
             child: DropdownButtonFormField<String>(
               value: _selectedBatch,
               isExpanded: true,
               decoration: const InputDecoration(labelText: 'Batch', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
               items: _batches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
               onChanged: (v) => setState(() => _selectedBatch = v ?? 'All'),
             ),
           ),
           // Section
           SizedBox(
             width: 150,
             child: DropdownButtonFormField<String>(
               value: _selectedSection,
               isExpanded: true,
               decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
               items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
               onChanged: (v) => setState(() => _selectedSection = v ?? 'All'),
             ),
           ),
           // Hall
           SizedBox(
             width: 150,
             child: DropdownButtonFormField<String>(
               value: _selectedHall,
               isExpanded: true,
               decoration: const InputDecoration(labelText: 'Hall', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
               items: [
                 const DropdownMenuItem(value: null, child: Text('All Halls')),
                 ..._getAvailableHalls().map((h) => DropdownMenuItem(value: h, child: Text(h))),
               ],
               onChanged: (v) => setState(() => _selectedHall = v),
             ),
           ),
           // Gender
           SizedBox(
             width: 150,
             child: DropdownButtonFormField<String>(
               value: _selectedGender,
               isExpanded: true,
               decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
               items: [
                 const DropdownMenuItem(value: null, child: Text('All Genders')),
                 ..._getAvailableGenders().map((g) => DropdownMenuItem(value: g, child: Text(g))),
               ],
               onChanged: (v) => setState(() => _selectedGender = v),
             ),
           ),
           // Food
           SizedBox(
             width: 150,
             child: DropdownButtonFormField<String>(
               value: _selectedFood,
               isExpanded: true,
               decoration: const InputDecoration(labelText: 'Food', border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)),
               items: [
                 const DropdownMenuItem(value: null, child: Text('All Food')),
                 ..._getAvailableFoods().map((f) => DropdownMenuItem(value: f, child: Text(f))),
               ],
               onChanged: (v) => setState(() => _selectedFood = v),
             ),
           ),
        ],
      ),
    );
  }

  // --- Helpers ---

  List<String> _getAvailableHalls() {
    if (_cachedRegistrations == null) return [];
    return _cachedRegistrations!.values
        .map((r) => r['hall'] as String?)
        .where((h) => h != null && h.isNotEmpty)
        .map((h) => h!)
        .toSet()
        .toList()..sort();
  }

  List<String> _getAvailableGenders() {
    if (_cachedRegistrations == null) return [];
    return _cachedRegistrations!.values
        .map((r) => r['gender'] as String?)
        .where((g) => g != null && g.isNotEmpty)
        .map((g) => g!)
        .toSet()
        .toList()..sort();
  }
  
  List<String> _getAvailableFoods() {
    if (_cachedRegistrations == null) return [];
    return _cachedRegistrations!.values
        .map((r) => r['foodPreference'] as String?)
        .where((f) => f != null && f.isNotEmpty)
        .map((f) => f!)
        .toSet()
        .toList()..sort();
  }

  List<Map<String, dynamic>> _getProcessedParticipants() {
    if (_cachedParticipants == null) return [];
    final results = <Map<String, dynamic>>[];
    
    for (var participant in _cachedParticipants!) {
      final regInfo = _cachedRegistrations?[participant.id];
      String batch = 'Unknown';
      String section = 'Unknown';
      String? hall;
      String? gender;
      String? food;
      String? tshirt;
      String? phone;

      if (regInfo != null) {
          batch = regInfo['batch']?.toString() ?? 'Unknown';
          section = regInfo['section']?.toString() ?? 'Unknown';
          if (section.startsWith('Section ')) section = section.replaceAll('Section ', '');
          hall = regInfo['hall']?.toString();
          gender = regInfo['gender']?.toString();
          food = regInfo['foodPreference']?.toString();
          tshirt = regInfo['tshirtSize']?.toString();
          phone = regInfo['personalNumber']?.toString();
      }
      
      // Filter Logic (Sync)
      if (_selectedBatch != 'All' && batch != _selectedBatch) continue;
      if (_selectedSection != 'All' && section != _selectedSection) continue;
      if (_selectedHall != null && hall != _selectedHall) continue;
      if (_selectedGender != null && gender != _selectedGender) continue;
      if (_selectedFood != null && food != _selectedFood) continue;

      results.add({
        'id': participant.id,
        'userId': participant.id,
        'name': participant.name,
        'universityId': participant.universityId,
        'email': participant.email,
        'batch': batch,
        'section': section,
        'hall': hall,
        'gender': gender,
        'foodPreference': food,
        'tshirtSize': tshirt,
        'personalNumber': phone,
        'hasReceived': _cachedDistributedIds?.contains(participant.id) ?? false,
      });
    }
    return results;
  }

  Map<String, Map<String, List<Map<String, dynamic>>>> _groupByBatchAndSection() {
    final participants = _getProcessedParticipants();
    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
    
    for (var p in participants) {
      final batch = p['batch'];
      final section = p['section'];
      if (!grouped.containsKey(batch)) grouped[batch] = {};
      if (!grouped[batch]!.containsKey(section)) grouped[batch]![section] = [];
      grouped[batch]![section]!.add(p);
    }
    return grouped;
  }

  Widget _buildRequirementStats() {
    if (_selectedItem == null) return const SizedBox.shrink();
    
    final name = _selectedItem!.name.toLowerCase();
    final isFood = name.contains('food') || name.contains('lunch') || name.contains('dinner');
    final isTshirt = name.contains('t-shirt') || name.contains('tshirt') || name.contains('jersey');
    
    if (!isFood && !isTshirt) return const SizedBox.shrink();

    final participants = _getProcessedParticipants();
    if (participants.isEmpty) return const SizedBox.shrink();

    final counts = <String, int>{};
    for (var p in participants) {
      String key;
      if (isFood) {
        key = p['foodPreference']?.toString() ?? 'None';
      } else {
        key = p['tshirtSize']?.toString() ?? 'Unknown';
      }
      if (key.trim().isEmpty || key == 'null') key = 'Unknown';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    
    // Sort keys
    final sortedKeys = counts.keys.toList()..sort();

    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFood ? 'Food Requirements (Filtered):' : 'Size Requirements (Filtered):',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedKeys.map((key) {
               final count = counts[key];
               return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.blue.shade100),
                 ),
                 child: Text('$key: $count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
               );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedParticipantsList() {
    final grouped = _groupByBatchAndSection();
    final batches = grouped.keys.toList()..sort();
    
    if (batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No participants found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: batches.length,
      itemBuilder: (context, i) {
        final batch = batches[i];
        final sections = grouped[batch]!;
        final sortedSections = sections.keys.toList()..sort();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add spacing between batches
            if (i > 0) const SizedBox(height: 16),
            if (i > 0) Divider(thickness: 2, color: Colors.grey.shade300, height: 1),
            if (i > 0) const SizedBox(height: 16),
            
            // Batch Header with Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  left: BorderSide(color: Colors.blue.shade700, width: 4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Batch $batch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue.shade900,
                    ),
                   ),
                   ElevatedButton.icon(
                     onPressed: () {
                        // Gather all participants in this batch
                        final allInBatch = <Map<String, dynamic>>[];
                        for (var s in sections.values) {
                           allInBatch.addAll(s);
                        }
                        _markListAsDistributed(allInBatch);
                     },
                     icon: const Icon(Icons.check_circle, size: 18),
                     label: const Text('Mark Batch'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blue.shade700,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(8),
                       ),
                     ),
                   ),
                ],
              ),
            ),
            ...sortedSections.map((section) {
               final sectionPs = sections[section]!;
               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Section Header with Button
                   Container(
                     margin: const EdgeInsets.only(top: 8),
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       border: Border(
                         left: BorderSide(color: Colors.grey.shade400, width: 3),
                       ),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           'Section $section',
                           style: TextStyle(
                             fontWeight: FontWeight.w600,
                             fontSize: 14,
                             color: Colors.grey.shade700,
                           ),
                         ),
                         ElevatedButton.icon(
                           onPressed: () => _markListAsDistributed(sectionPs),
                           icon: const Icon(Icons.done_all, size: 16),
                           label: const Text('Mark Section'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.grey.shade600,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(6),
                             ),
                           ),
                         ),
                       ],
                     ),
                   ),
                   ...sectionPs.map((p) => _buildParticipantCard(p)),
                 ],
               );
            }),
          ],
        );
      },
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> p) {
    bool expanded = _expandedParticipants.contains(p['id']);
    bool hasReceived = p['hasReceived'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0,1))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
               setState(() {
                 if (expanded) _expandedParticipants.remove(p['id']);
                 else _expandedParticipants.add(p['id']);
               });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                   CircleAvatar(
                     backgroundColor: hasReceived ? Colors.green : Colors.blue,
                     child: Text(
                       (p['name'] as String)[0].toUpperCase(),
                       style: const TextStyle(color: Colors.white),
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           p['name'], 
                           style: TextStyle(
                             fontWeight: FontWeight.bold, 
                             decoration: hasReceived ? TextDecoration.lineThrough : null,
                             color: hasReceived ? Colors.grey : Colors.black87
                           )
                         ),
                         Text('ID: ${p['universityId']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                       ],
                     ),
                   ),
                   Checkbox(
                     value: hasReceived,
                     onChanged: (val) {
                       if (val == true) _markAsDistributed(p);
                       else _unmarkAsDistributed(p);
                     },
                   ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  if (p['tshirtSize'] != null) _detailRow(Icons.checkroom, 'Size', p['tshirtSize']),
                  if (p['foodPreference'] != null) _detailRow(Icons.restaurant, 'Food', p['foodPreference']),
                  if (p['hall'] != null) _detailRow(Icons.home, 'Hall', p['hall']),
                  if (p['personalNumber'] != null) _detailRow(Icons.phone, 'Phone', p['personalNumber']),
                  if (p['email'] != null) _detailRow(Icons.email, 'Email', p['email']),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }


  Future<void> _markAsDistributed(Map<String, dynamic> participant) async {
    if (_selectedItem == null) return;

    // Optimistic Update
    setState(() {
      _cachedDistributedIds?.add(participant['id']);
    });

    try {
      await FirebaseItemDistributionService.distributeItem(
        eventId: widget.eventId,
        itemId: _selectedItem!.id,
        participantId: participant['id'] as String,
        participantName: participant['name'] as String,
        participantEmail: participant['email'] as String,
        universityId: participant['universityId'] as String,
        batch: participant['batch'] as String,
        section: participant['section'] as String,
        distributedBy: widget.currentUserId,
      );
      // Success - no reload needed, UI is already correct
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _cachedDistributedIds?.remove(participant['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unmarkAsDistributed(Map<String, dynamic> participant) async {
    if (_selectedItem == null) return;

    // Optimistic Update
    setState(() {
      _cachedDistributedIds?.remove(participant['id']);
    });

    try {
      await FirebaseItemDistributionService.undistributeItem(
        itemId: _selectedItem!.id,
        participantId: participant['userId'] as String,
      );
    } catch (e) {
      // Revert if failed
      if (mounted) {
        setState(() {
          _cachedDistributedIds?.add(participant['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markListAsDistributed(List<Map<String, dynamic>> participants) async {
    if (_selectedItem == null) return;
    
    // Filter those who need marking
    final toMark = participants.where((p) => _cachedDistributedIds?.contains(p['id']) == false).toList();
    if (toMark.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All selected are already marked!')));
      return;
    }

    // Confirmation for bulk
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Bulk Mark'),
        content: Text('Mark ${toMark.length} participants as distributed? This will process in the background.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic Update for ALL
    setState(() {
      for (var p in toMark) {
        _cachedDistributedIds?.add(p['id']);
      }
    });
    
    // Background Processing
    int errorCount = 0;
    for (var p in toMark) {
      try {
         await FirebaseItemDistributionService.distributeItem(
          eventId: widget.eventId,
          itemId: _selectedItem!.id,
          participantId: p['id'] as String,
          participantName: p['name'] as String,
          participantEmail: p['email'] as String,
          universityId: p['universityId'] as String,
          batch: p['batch'] as String,
          section: p['section'] as String,
          distributedBy: widget.currentUserId,
        );
      } catch (e) {
        errorCount++;
        print('Error marking ${p['id']}: $e');
        // Revert individual failure? Too complex for loop. Just let it be inconsistent or reload later.
        // Ideally we revert this specific ID.
        if (mounted) {
             setState(() => _cachedDistributedIds?.remove(p['id']));
        }
      }
    }

    if (errorCount > 0 && mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Completed with $errorCount errors.')));
    }
  }


  // _markAllFiltered removed as it relied on deleted methods and is not used in the new UI.

  Widget _buildSummaryTab() {
    if (_selectedItem == null) {
      return const Center(child: Text('Please select an item'));
    }
    if (_cachedParticipants == null || _cachedRegistrations == null) {
       return const Center(child: CircularProgressIndicator());
    }

    // Calculate Summary Locally
    final summary = <String, Map<String, int>>{};
    int totalDistributed = 0;

    for (var p in _cachedParticipants!) {
        // Must be in cachedDistributedIds
        if (_cachedDistributedIds?.contains(p.id) != true) continue;

        totalDistributed++;
        
        final reg = _cachedRegistrations?[p.id];
        final batch = reg?['batch']?.toString() ?? 'Unknown';
        var section = reg?['section']?.toString() ?? 'Unknown';
        if (section.startsWith('Section ')) section = section.replaceAll('Section ', '');

        summary.putIfAbsent(batch, () => {});
        summary[batch]![section] = (summary[batch]![section] ?? 0) + 1;
    }
    
    if (summary.isEmpty) {
        return const Center(child: Text('No items distributed yet'));
    }

    final batches = summary.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Total Distributed: $totalDistributed', 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              final sections = summary[batch]!;
              final totalForBatch = sections.values.fold<int>(0, (sum, count) => sum + count);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.school, color: Colors.blue),
                  title: Text('Batch $batch', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$totalForBatch items distributed'),
                  children: sections.entries.map((entry) {
                    return ListTile(
                      title: Text('Section ${entry.key}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${entry.value}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g., Event T-Shirt',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Blue XL size',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Total Quantity',
                  hintText: 'e.g., 100',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || quantityController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              try {
                final item = EventItem(
                  id: '',
                  eventId: widget.eventId,
                  name: nameController.text,
                  description: descController.text,
                  totalQuantity: int.parse(quantityController.text),
                  createdAt: DateTime.now(),
                  createdBy: widget.currentUserId,
                );

                await FirebaseItemDistributionService.createEventItem(item);
                
                Navigator.pop(context);
                _loadData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
