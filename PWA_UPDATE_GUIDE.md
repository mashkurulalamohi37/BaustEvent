# PWA Update Guide

## Quick Update Steps

### 1. Build Flutter Web
```bash
flutter build web --release
```

### 2. Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

## Current Fix Applied

I've made two improvements to handle Google Sign-In on web/PWA:

1. **Added null safety checks** in `firebase_user_service.dart` to prevent the null operator error
2. **Suppressed error messages** for authentication token failures (common on web without proper OAuth setup)

## Google Sign-In Configuration for Web

If you want Google Sign-In to work on web, you need to:

1. **Google Cloud Console**:
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Select your project
   - Go to "APIs & Services" > "Credentials"
   - Find your OAuth 2.0 Client ID
   - Add your PWA domain to "Authorized JavaScript origins":
     - `https://walkie-7a9dc.web.app`
     - `https://walkie-7a9dc.firebaseapp.com`
   - Add to "Authorized redirect URIs":
     - `https://walkie-7a9dc.web.app/__/auth/handler`
     - `https://walkie-7a9dc.firebaseapp.com/__/auth/handler`

2. **Firebase Console**:
   - Ensure Google Sign-In is enabled in Authentication providers

## Temporary Workaround

Until Google Sign-In is properly configured for web:
- The error message will no longer appear
- Users can still sign in using email/password
- Google Sign-In will work on Android/iOS apps

## After Deploying

Clear browser cache or do a hard refresh (Ctrl+Shift+R) to see the changes.
