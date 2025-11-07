# Deleting Firebase Authentication Accounts

## Problem
When you delete a user from the admin panel, only the Firestore document is deleted. The Firebase Authentication account still exists in the Authentication panel.

## Solution Options

### Option 1: Manual Deletion (Quick Fix)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Authentication** > **Users**
4. Find the user by email or UID
5. Click the three dots menu and select **Delete user**

### Option 2: Cloud Function (Recommended for Production)
Set up a Cloud Function that uses Firebase Admin SDK to delete users automatically.

#### Setup Steps:

1. **Initialize Firebase Functions** (if not already done):
   ```bash
   cd your-project-directory
   firebase init functions
   ```
   Choose JavaScript or TypeScript when prompted.

2. **Install dependencies**:
   ```bash
   cd functions
   npm install firebase-admin
   ```

3. **Create the delete user function** in `functions/index.js`:
   ```javascript
   const functions = require('firebase-functions');
   const admin = require('firebase-admin');
   
   admin.initializeApp();
   
   exports.deleteUser = functions.https.onCall(async (data, context) => {
     // Verify the user is authenticated and is an admin
     if (!context.auth) {
       throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
     }
     
     const userId = data.userId;
     if (!userId) {
       throw new functions.https.HttpsError('invalid-argument', 'userId is required');
     }
     
     // Verify the caller is an admin
     const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
     if (!callerDoc.exists || callerDoc.data().type !== 'admin') {
       throw new functions.https.HttpsError('permission-denied', 'Only admins can delete users');
     }
     
     // Prevent self-deletion
     if (context.auth.uid === userId) {
       throw new functions.https.HttpsError('permission-denied', 'Cannot delete yourself');
     }
     
     try {
       // Delete the Firebase Auth user
       await admin.auth().deleteUser(userId);
       return { success: true, message: 'User deleted successfully' };
     } catch (error) {
       console.error('Error deleting user:', error);
       throw new functions.https.HttpsError('internal', 'Failed to delete user', error);
     }
   });
   ```

4. **Deploy the function**:
   ```bash
   firebase deploy --only functions
   ```

5. **Update the Flutter code** to call this function (already implemented in `admin_dashboard.dart`).

### Option 3: Use Firebase Admin SDK in Your Backend
If you have a backend server, you can create an API endpoint that uses Firebase Admin SDK to delete users.

## Current Implementation
The app will:
- ✅ Delete the Firestore user document
- ✅ Delete any pending organizer requests
- ✅ Try to delete Firebase Auth user (only works if it's the current user)
- ⚠️ Show a message if Auth account still exists (needs manual deletion or Cloud Function)

## Note
The client SDK can only delete the currently authenticated user's account. To delete other users' accounts, you must use Firebase Admin SDK (via Cloud Function or backend server).

