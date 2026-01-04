# UI Fix: "Manage" Button Visibility

## Issue
The "Manage" button text was not clearly visible in the Event Details screen because it had blue text on a blue background, making it nearly impossible to read.

## Location
**File**: `lib/screens/event_details_screen.dart`  
**Line**: ~1010  
**Screen**: Event Details Screen (for organizers/admins)

## Root Cause
The `ElevatedButton` for the "Manage" button was using:
- Background color: `Color(0xFF1976D2)` (blue)
- Text color: Default (which was also blue)

This created a blue-on-blue color scheme with insufficient contrast.

## Solution
Added explicit text styling to ensure white text on blue background:

```dart
style: ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF1976D2),
  foregroundColor: Colors.white,  // ← Added this
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
),
child: const Text(
  'Manage',
  style: TextStyle(color: Colors.white),  // ← Added this
),
```

## Changes Made
1. Added `foregroundColor: Colors.white` to the button style
2. Added explicit `TextStyle(color: Colors.white)` to the Text widget

## Visual Impact
- **Before**: Blue text on blue background (invisible/hard to read)
- **After**: White text on blue background (clear and readable)

## Testing
✅ Build completed successfully  
✅ No compilation errors  
✅ Button text now clearly visible

## Related Buttons
The following buttons in the same screen already had proper text colors:
- ✅ "Edit Event" button (outlined button with blue text)
- ✅ "Expense Tracker" button (green with white text)
- ✅ "Mark as Done" button (orange with white text)
- ✅ "Delete Event" button (red with white text)

Now the "Manage" button matches the same high-contrast pattern.

---
**Date Fixed**: 2026-01-04  
**Issue**: Manage button text not visible  
**Status**: ✅ Resolved
