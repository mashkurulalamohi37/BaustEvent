# Item Distribution Tracking System

## Overview
The Item Distribution Tracking System allows event organizers to manage and track the distribution of items (t-shirts, kits, merchandise, etc.) to participants at collection points. The system provides real-time tracking organized by batch and section.

## Features

### 1. **Item Management**
- Create distribution items for events (e.g.,"Event T-Shirt Size L", "Welcome Kit")
- Set total quantities for each item
- Track distributed vs. remaining quantities
- Real-time progress tracking

### 2. **Collection Point Interface**
- Select item to distribute
- Filter participants by:
  - Batch (15, 16, 17, 18, 19, 20, 21, 22)
  - Section (A, B, C, D)
- View participant list with distribution status
- Mark items as "Collected" with one tap
- Visual indicators (green checkmark for collected)

### 3. **Distribution Tracking**
- Real-time tracking of who received what
- Timestamp for each distribution
- Track distributor (who handed out the item)
- Prevent duplicate distributions
- Undo feature for mistakes

### 4. **Analytics & Reports**
- Distribution summary by batch and section
- Progress bars for each item
- Batch-wise breakdown
- Section-wise breakdown within batches
- Export capabilities (via existing Excel export service)

## Data Models

### EventItem
```dart
{
  id: String,
  eventId: String,
  name: String,              // "Event T-Shirt XL"
  description: String,       // "Blue cotton t-shirt"
  imageUrl: String?,
  totalQuantity: int,        // 100
  distributedQuantity: int,  // 45
  createdAt: DateTime,
  createdBy: String,
}
```

### ItemDistribution
```dart
{
  id: String,
  eventId: String,
  itemId: String,
  participantId: String,
  participantName: String,
  participantEmail: String,
  universityId: String,      // "17101001"
  batch: String,             // "17"
  section: String,           // "A"
  distributedAt: DateTime,
  distributedBy: String,     // Organizer who distributed
  notes: String?,
}
```

## How to Use

### For Organizers:

#### 1. **Add Items for Distribution**
```dart
// Navigate to Item Distribution screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ItemDistributionScreen(
      eventId: eventId,
      currentUserId: userId,
    ),
  ),
);

// Tap "Add Item" button
// Enter:
// - Item name (e.g., "Event T-Shirt")
// - Description (e.g., "Size: XL, Color: Blue")
// - Total quantity (e.g., 100)
```

#### 2. **At Collection Point**
1. Open the event
2. Go to "Item Distribution" screen
3. Select the item to distribute
4. Use filters to view specific batch/section
5. When a participant arrives:
   - Find their name in the list
   - Verify their ID
   - Tap "Mark" button
   - Confirm distribution
6. Participant marked with green checkmark

#### 3. **View Distribution Summary**
- Switch to "Summary" tab
- View batch-wise distribution
- See how many items distributed per section
- Track overall progress

### For Participants:
- Participants can see if they've collected items
- Shows collection timestamp
- Can view their distribution history

## Integration

### Add to Organizer Dashboard:
```dart
// In organizer_dashboard.dart, add menu item:
ListTile(
  leading: Icon(Icons.inventory_2),
  title: Text('Item Distribution'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDistributionScreen(
          eventId: eventId,
          currentUserId: currentUser.id,
        ),
      ),
    );
  },
),
```

### Add to Event Detail Screen:
```dart
// Add button in event detail for quick access
ElevatedButton.icon(
  icon: Icon(Icons.qr_code_scanner),
  label: Text('Distribution Point'),
  onPressed: () => _openDistributionScreen(),
),
```

## Firestore Collections

### `event_items` Collection
- Stores all items for distribution
- Indexed by `eventId`
- Tracks quantity and distribution progress

### `item_distributions` Collection
- Stores distribution records
- Indexed by:
  - `eventId`
  - `itemId`
  - `participantId`
  - `batch` + `section` (composite)
- Enables efficient querying

## Security Rules

- **Organizers & Admins**: Full access to create, read, update, delete
- **Participants**: Can read their own distribution records
- **Validation**: Prevents duplicate distributions
- **Audit Trail**: All distributions tracked with timestamp and distributor

## Future Enhancements

1. **QR Code Scanning**
   - Scan participant ID cards
   - Quick distribution without manual search

2. **Bulk Distribution**
   - Mark entire section as collected
   - Batch operations

3. **Distribution Alerts**
   - Notify participants when items available
   - SMS/Email notifications

4. **Size/Variant Tracking**
   - Track t-shirt sizes
   - Multiple variants per item

5. **Photo Verification**
   - Take photo during distribution
   - Proof of collection

## Example Use Cases

### Use Case 1: Event T-Shirt Distribution
```
Event: "Tech Fest 2024"
Item: "Event T-Shirt - Size L"
Total: 150 shirts

Collection Point Flow:
1. Filter: Batch 17, Section A
2. Show 25 students from 17-A
3. As students arrive:
   - Verify ID: "17101025"
   - Give t-shirt
   - Mark as collected
4. Progress: 25/150 (16.7%)
```

### Use Case 2: Welcome Kit Distribution
```
Event: "Freshman Orientation"
Item: "Welcome Kit"
Total: 200 kits

By Section:
- Batch 22, Section A: 45 distributed
- Batch 22, Section B: 50 distributed
- Batch 22, Section C: 48 distributed
- Remaining: 57 kits
```

## Benefits

✅ **Real-time Tracking**: Know exactly what's distributed
✅ **No Duplicate Distributions**: Prevent giving items twice
✅ **Organized by Batch/Section**: Easy filtering and management
✅ **Audit Trail**: Complete record of all distributions
✅ **Progress Monitoring**: See completion percentage
✅ **Undo Capability**: Fix mistakes easily
✅ **Multiple Collection Points**: Multiple organizers can distribute simultaneously
✅ **Offline Resilience**: Works with poor internet (Firebase sync)

## Deployment

1. **Deploy Firestore Rules**:
```bash
firebase deploy --only firestore:rules
```

2. **Deploy Updated App**:
```bash
flutter build web --release
firebase deploy --only hosting
```

3. **Test the Feature**:
   - Create an event
   - Add a test item
   - Register as participant
   - Test distribution flow

---

**Created by**: EventBridge Team  
**Last Updated**: 2026-01-07  
**Version**: 1.0
