# Creating Admin Account

## Step 1: Create Admin User in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Authentication** → **Users** tab
4. Click **Add user**
5. Enter:
   - Email: `ohi82@gmail.com`
   - Password: `ohi@82`
6. Click **Add user**

## Step 2: Create Admin User Document in Firestore

1. Go to **Firestore Database** in Firebase Console
2. Navigate to `users` collection
3. Find the user document with the email `ohi82@gmail.com` (or create a new document with the user's UID)
4. Set the following fields:
   ```json
   {
     "email": "ohi82@gmail.com",
     "name": "Admin",
     "universityId": "ADMIN",
     "type": "admin",
     "createdAt": "2025-01-01T00:00:00.000Z"
   }
   ```

## Step 3: Verify Admin Access

1. Log out of the app (if logged in)
2. Log in with:
   - Email: `ohi82@gmail.com`
   - Password: `ohi@82`
3. You should see the **Admin Dashboard** with pending organizer requests

## Alternative: Create Admin via Code (One-time script)

You can also create the admin account programmatically. Add this to your app temporarily:

```dart
// Run this once to create admin account
Future<void> createAdminAccount() async {
  try {
    // Create auth user
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'ohi82@gmail.com',
      password: 'ohi@82',
    );
    
    // Create user document
    await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
      'email': 'ohi82@gmail.com',
      'name': 'Admin',
      'universityId': 'ADMIN',
      'type': 'admin',
      'createdAt': DateTime.now().toIso8601String(),
    });
    
    print('Admin account created successfully!');
  } catch (e) {
    print('Error creating admin: $e');
  }
}
```

## Important Notes

- ⚠️ **Change the password** after first login for security
- 🔒 Keep admin credentials secure
- 👥 Only create admin accounts for trusted users
- 📝 Admin can approve/reject organizer requests
- 🚫 Regular users cannot sign up as admin - only through Firestore

## Admin Capabilities

- ✅ View all pending organizer requests
- ✅ Approve organizer requests
- ✅ Reject organizer requests
- ✅ View all users
- ✅ Manage the system

