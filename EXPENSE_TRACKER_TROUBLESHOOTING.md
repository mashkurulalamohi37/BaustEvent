# Expense Tracker Troubleshooting Guide

## Issue: "Failed to add expense"

### ✅ **FIXED!** Firestore Security Rules

The Firestore security rules have been **successfully deployed** to allow expense tracking.

### What Was Done:

1. **Added Expense Tracker Rules** to `firestore.rules`
   - Organizers can create/read/update/delete expenses for their events
   - Admins can manage all expenses
   - Proper authentication and authorization checks

2. **Deployed Rules to Firebase**
   - Rules are now active in your Firebase project
   - Command used: `firebase deploy --only firestore:rules`

3. **Enhanced Error Logging**
   - Added detailed console logs to help diagnose issues
   - Better error messages in the UI

### How to Test:

1. **Restart Your App**
   - Close the app completely
   - Reopen it to ensure fresh connection to Firebase

2. **Try Adding an Expense**
   - Go to any event you created
   - Click "Expense Tracker"
   - Click the "+" button
   - Fill in the form and submit

3. **Check Console Logs**
   - If it still fails, check the Flutter console for detailed error messages
   - Look for lines starting with "Creating new expense for event:"

### Common Issues and Solutions:

#### 1. **User Not Authenticated**
**Symptom:** Error about authentication
**Solution:** 
- Make sure you're logged in
- Check that `widget.userId` is not empty
- Verify Firebase Auth is working

#### 2. **User Not an Organizer**
**Symptom:** Permission denied error
**Solution:**
- Make sure your user account has `type: 'organizer'` in Firestore
- Or make sure you're an admin with `isAdmin: true`
- Check the `users` collection in Firebase Console

#### 3. **Event Not Found**
**Symptom:** Error about event not existing
**Solution:**
- Verify the event exists in the `events` collection
- Check that `eventId` matches the event document ID
- Ensure the event has an `organizerId` field

#### 4. **Network Issues**
**Symptom:** Timeout or connection errors
**Solution:**
- Check your internet connection
- Verify Firebase is accessible
- Check Firebase Console for service status

### Debugging Steps:

1. **Check Firebase Console**
   - Go to Firebase Console → Firestore Database
   - Look for the `event_expenses` collection
   - Check if any expenses were created

2. **Check User Type**
   ```
   Firebase Console → Firestore → users → [your user ID]
   ```
   - Verify `type` field is `'organizer'` or `'admin'`
   - Or verify `isAdmin` field is `true`

3. **Check Event Ownership**
   ```
   Firebase Console → Firestore → events → [event ID]
   ```
   - Verify `organizerId` matches your user ID

4. **View Console Logs**
   - Run the app with `flutter run`
   - Watch the console for detailed error messages
   - Look for the expense data being logged

### Expected Console Output (Success):

```
Creating new expense for event: [eventId], user: [userId]
Expense data: {id: , eventId: ..., category: other, description: SoundBox, amount: 8000.0, ...}
Expense created with ID: [generated-id]
```

### Expected Console Output (Failure):

```
Creating new expense for event: [eventId], user: [userId]
Expense data: {id: , eventId: ..., category: other, description: SoundBox, amount: 8000.0, ...}
Error saving expense: [error message]
Expense created with ID: null
```

### Firestore Rules Validation:

The deployed rules ensure:
- ✅ Only authenticated users can access expenses
- ✅ Only organizers can create expenses for their events
- ✅ Only admins can create expenses for any event
- ✅ Users can only edit/delete their own expenses
- ✅ Admins can edit/delete any expense
- ✅ All required fields must be present

### Next Steps:

1. **Restart the app** and try again
2. **Check the console logs** for detailed error information
3. **Verify your user type** in Firebase Console
4. **Test with a simple expense** (small amount, basic description)

### Still Having Issues?

If the problem persists:

1. Share the **console logs** (the output when you try to add an expense)
2. Share your **user ID** and **event ID**
3. Check if you can see the `event_expenses` collection in Firebase Console
4. Verify the Firestore rules were deployed successfully

The rules are now deployed and should work! 🎉
