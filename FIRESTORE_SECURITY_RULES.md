# Firestore Security Rules Setup Guide

## Current Status: Test Mode ✅

Your Firestore is currently in **test mode**, which means:
- ✅ All read/write access is allowed for 30 days
- ✅ Perfect for development and testing
- ✅ The notification system will work perfectly
- ⚠️ **Not secure for production** - anyone can access your data

## When to Switch to Production Mode

Switch to production mode when:
- You're ready to deploy your app to users
- You want to secure your database
- The 30-day test mode period is ending

## How to Deploy Security Rules

### Option 1: Using Firebase Console (Recommended for beginners)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Copy the contents of `firestore.rules` file
5. Paste into the rules editor
6. Click **Publish**

### Option 2: Using Firebase CLI

1. Install Firebase CLI (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Deploy the rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

## Security Rules Overview

The provided `firestore.rules` file includes:

### Users Collection
- ✅ Users can read/update their own profile
- ✅ Organizers can read all user profiles
- ✅ Users can create their own profile during signup

### Events Collection
- ✅ All authenticated users can read events
- ✅ Only organizers can create events
- ✅ Only event organizers can update/delete their own events

### Notifications Collection
- ✅ All authenticated users can read notifications
- ✅ Only organizers can create notifications
- ✅ Users can mark notifications as read

## Testing Your Rules

After deploying rules, test them:

1. Try creating an event as a participant (should fail)
2. Try creating an event as an organizer (should succeed)
3. Try updating someone else's event (should fail)
4. Try reading events (should succeed for all authenticated users)

## Important Notes

⚠️ **Before deploying to production:**
- Review all security rules carefully
- Test thoroughly with different user roles
- Make sure all your app features work with the new rules
- Consider adding more specific rules for your use case

## Need Help?

If you encounter permission errors after deploying rules:
1. Check Firebase Console → Firestore → Rules for syntax errors
2. Verify user authentication is working
3. Check that user documents have the correct `type` field ('organizer' or 'participant')
4. Review the error messages in your app logs

## Current Test Mode

For now, you can continue using test mode for development. The notification system and all features will work perfectly. Switch to production rules when you're ready to secure your database.

