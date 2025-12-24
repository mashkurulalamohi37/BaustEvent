# Expense Tracker Feature

## Overview

The Expense Tracker system has been successfully added to the BaustEvent application. This feature allows event organizers and admins to track and manage all costs associated with their events.

## Features Implemented

### 1. **Data Model** (`lib/models/event_expense.dart`)
- Complete `EventExpense` model with all necessary fields
- Support for 10 expense categories: Venue, Catering, Equipment, Marketing, Transportation, Staff, Decorations, Prizes, Printing, Other
- Support for 6 payment methods: Cash, bKash, Nagad, Bank Transfer, Card, Other
- Full Firestore serialization support

### 2. **Service Layer** (`lib/services/firebase_expense_service.dart`)
- CRUD operations for expenses
- Real-time expense streams
- Category-based expense grouping
- Expense statistics calculation
- Support for filtering by date range
- Admin functions to view all expenses across events

### 3. **UI Components**

#### Expense Card Widget (`lib/widgets/expense_card.dart`)
- Displays individual expense items
- Category-specific icons and colors
- Shows amount, date, payment method, and notes
- Edit and delete actions for authorized users

#### Expense Summary Card (`lib/widgets/expense_summary_card.dart`)
- Total expenses display
- Category breakdown with visual progress bars
- Percentage distribution
- Quick view of top 5 expense categories

### 4. **Screens**

#### Expense Tracker Screen (`lib/screens/expense_tracker_screen.dart`)
- View all expenses for an event
- Real-time updates via Firestore streams
- Filter by category
- Search functionality
- Expense summary with charts
- Add/Edit/Delete expenses
- Permission-based access control

#### Add/Edit Expense Screen (`lib/screens/add_expense_screen.dart`)
- Form to add new expenses
- Edit existing expenses
- Category and payment method dropdowns
- Date picker
- Amount validation
- Optional notes field
- Optional receipt upload support (structure in place)

### 5. **Integration Points**

#### Event Details Screen
- Added "Expense Tracker" button for organizers and admins
- Green button with wallet icon
- Navigates to expense tracker for the specific event

#### Organizer Dashboard
- Organizers can access expense tracker from event details

#### Admin Dashboard
- Admins can access expense tracker for any event
- Can view and manage all expenses

## How to Use

### For Organizers

1. **Navigate to Your Event**
   - Go to "My Events" tab in the organizer dashboard
   - Select an event

2. **Access Expense Tracker**
   - Click the green "Expense Tracker" button
   - View expense summary and all recorded expenses

3. **Add an Expense**
   - Click the floating "Add Expense" button
   - Fill in the form:
     - Description (required)
     - Category (required)
     - Amount in BDT (required)
     - Date (required)
     - Payment Method (required)
     - Notes (optional)
   - Click "Add Expense"

4. **Edit/Delete Expenses**
   - Click "Edit" on any expense you created
   - Modify the details and save
   - Click "Delete" to remove an expense (with confirmation)

5. **Filter and Search**
   - Use the filter icon to filter by category
   - Use the search bar to find specific expenses
   - Clear filters to see all expenses

### For Admins

1. **Access Any Event**
   - Go to "Events" tab in admin dashboard
   - Click on any event

2. **Manage Expenses**
   - Click "Expense Tracker" button
   - View, edit, or delete any expense
   - Add new expenses if needed

## Permissions

- **Organizers**: Can manage expenses for their own events
- **Admins**: Can manage expenses for all events
- **Participants**: Cannot view or manage expenses

## Database Structure

### Firestore Collection: `event_expenses`

```
event_expenses/
  {expenseId}/
    - eventId: string
    - category: string (enum)
    - description: string
    - amount: number
    - date: timestamp
    - createdBy: string (userId)
    - createdAt: timestamp
    - receiptUrl: string (optional)
    - paymentMethod: string (enum)
    - notes: string (optional)
```

### Required Firestore Indexes

You may need to create these composite indexes in Firebase Console:

1. **Collection**: `event_expenses`
   - Fields: `eventId` (Ascending), `date` (Descending)
   - Query Scope: Collection

2. **Collection**: `event_expenses`
   - Fields: `eventId` (Ascending), `category` (Ascending)
   - Query Scope: Collection

Firebase will prompt you to create these indexes when you first use the filtering features.

## Firestore Security Rules

Add these rules to your `firestore.rules` file:

```javascript
// Expense Tracker Rules
match /event_expenses/{expenseId} {
  // Allow organizers and admins to read expenses for their events
  allow read: if request.auth != null && (
    isAdmin() ||
    isEventOrganizer(resource.data.eventId)
  );
  
  // Allow organizers and admins to create expenses
  allow create: if request.auth != null && (
    isAdmin() ||
    isEventOrganizer(request.resource.data.eventId)
  ) && request.resource.data.createdBy == request.auth.uid;
  
  // Allow users to update their own expenses, or admins to update any
  allow update: if request.auth != null && (
    isAdmin() ||
    resource.data.createdBy == request.auth.uid
  );
  
  // Allow users to delete their own expenses, or admins to delete any
  allow delete: if request.auth != null && (
    isAdmin() ||
    resource.data.createdBy == request.auth.uid
  );
}

// Helper function to check if user is event organizer
function isEventOrganizer(eventId) {
  return exists(/databases/$(database)/documents/events/$(eventId)) &&
         get(/databases/$(database)/documents/events/$(eventId)).data.organizerId == request.auth.uid;
}
```

## Currency

- Default currency: **BDT (Bangladeshi Taka)**
- Symbol: **৳**
- All amounts are stored as double/float values

## Future Enhancements

Potential features for future development:

1. **Budget Management**
   - Set budget limits per event
   - Budget vs actual comparison
   - Alerts when approaching budget limit

2. **Receipt Upload**
   - Upload receipt images
   - View receipts in expense details
   - Receipt gallery

3. **Export Functionality**
   - Export expenses to CSV
   - Export to PDF report
   - Email expense reports

4. **Analytics**
   - Expense trends over time
   - Category-wise spending patterns
   - Comparison across events

5. **Multi-Currency Support**
   - Support for different currencies
   - Currency conversion

6. **Expense Approval Workflow**
   - Require approval for expenses above certain amount
   - Approval notifications

## Testing Checklist

- [x] Create expense model
- [x] Create expense service
- [x] Create expense widgets
- [x] Create expense tracker screen
- [x] Create add/edit expense screen
- [x] Integrate with event details
- [x] Add to organizer dashboard
- [x] Add to admin dashboard
- [ ] Test CRUD operations
- [ ] Test real-time updates
- [ ] Test permissions
- [ ] Test filtering and search
- [ ] Test with multiple events
- [ ] Test on different devices

## Files Created

1. `lib/models/event_expense.dart` - Expense data model
2. `lib/services/firebase_expense_service.dart` - Expense service layer
3. `lib/widgets/expense_card.dart` - Expense card widget
4. `lib/widgets/expense_summary_card.dart` - Summary card widget
5. `lib/screens/expense_tracker_screen.dart` - Main expense tracker screen
6. `lib/screens/add_expense_screen.dart` - Add/edit expense screen

## Files Modified

1. `lib/screens/event_details_screen.dart` - Added expense tracker button
2. (Organizer and Admin dashboards already have access via event details)

## Notes

- The expense tracker is fully integrated and ready to use
- All expenses are stored in Firestore with real-time synchronization
- The UI follows the existing app design patterns
- Permission checks ensure only authorized users can manage expenses
- The system is scalable and can handle multiple events with many expenses
