# Debugging Organizer Requests

## How to Check if Requests are Being Created

### Step 1: Check Firestore Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database**
4. Look for the `organizer_requests` collection
5. Check if there are any documents with `status: "pending"`

### Step 2: Check App Logs

When a user signs up as organizer, you should see these logs:
```
Creating organizer request for user: [userId]
=== CREATING ORGANIZER REQUEST ===
UserId: [userId]
Email: [email]
Name: [name]
Request data: {...}
Organizer request created successfully with ID: [requestId]
===================================
```

### Step 3: Check Admin Dashboard Logs

When admin opens the dashboard, you should see:
```
Admin Dashboard: Loaded X initial pending requests
Organizer requests stream: Got X documents
Admin Dashboard: Stream update - Received X pending requests
```

## Common Issues

### Issue 1: Requests Not Being Created

**Symptoms:**
- No documents in `organizer_requests` collection
- No logs about creating organizer request

**Solution:**
- Check if user is actually selecting "Organizer" during signup
- Check if `createOrganizerRequest` is being called
- Check Firestore rules allow creating requests

### Issue 2: Requests Created But Not Showing

**Symptoms:**
- Documents exist in Firestore
- Admin dashboard shows "No pending requests"

**Possible Causes:**
1. **Missing Firestore Index**
   - The query uses `where('status', isEqualTo: 'pending').orderBy('requestedAt')`
   - This requires a composite index
   - The code now has a fallback that works without index

2. **Firestore Rules Blocking Read**
   - Check that admin user has `type: "admin"` in their user document
   - Check Firestore rules allow admin to read `organizer_requests`

3. **Status Field Mismatch**
   - Check that requests have `status: "pending"` (lowercase)
   - Not "Pending" or "PENDING"

### Issue 3: Stream Errors

**Symptoms:**
- Logs show "Error in organizer requests stream"
- Requests show initially but don't update

**Solution:**
- The code now has fallback streams
- Check console logs for specific error messages
- The app will use non-stream method if streams fail

## Manual Test

1. **Create a test organizer request:**
   - Sign up a new user
   - Select "Organizer" as user type
   - Check Firestore for the new request

2. **Check as Admin:**
   - Log in as admin (`ohi82@gmail.com` / `ohi@82`)
   - Go to Admin Dashboard → Requests tab
   - Should see the pending request

3. **Check Firestore Rules:**
   - Make sure admin can read `organizer_requests`
   - Make sure users can create requests

## Firestore Index (Optional)

If you want to use the optimized query with `orderBy`, create this index:

1. Go to Firestore → Indexes
2. Click "Create Index"
3. Collection: `organizer_requests`
4. Fields:
   - `status` (Ascending)
   - `requestedAt` (Descending)
5. Click "Create"

**Note:** The app will work without this index using the fallback query.

## Verify Admin Account

Make sure your admin account has:
- Firebase Auth user created
- Firestore user document with `type: "admin"` (lowercase)

Check in Firestore:
```json
{
  "email": "ohi82@gmail.com",
  "name": "Admin",
  "type": "admin",  // Must be lowercase "admin"
  "universityId": "ADMIN"
}
```

