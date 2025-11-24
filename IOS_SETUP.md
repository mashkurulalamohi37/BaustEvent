# iOS Setup Guide for EventBridge

This guide will help you set up the EventBridge app for iOS development and deployment.

## Prerequisites

1. **macOS** - iOS development requires a Mac computer
2. **Xcode** - Install from Mac App Store (version 14.0 or later recommended)
3. **CocoaPods** - Install using:
   ```bash
   sudo gem install cocoapods
   ```
4. **Flutter SDK** - Ensure Flutter is properly installed and configured

## Step 1: Firebase iOS Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on the iOS icon to add an iOS app
4. Enter your iOS bundle ID (found in `ios/Runner.xcodeproj` or `ios/Runner/Info.plist`)
5. Download `GoogleService-Info.plist`
6. **Important**: Add `GoogleService-Info.plist` to `ios/Runner/` directory
   - Open Xcode
   - Right-click on `Runner` folder
   - Select "Add Files to Runner..."
   - Select `GoogleService-Info.plist`
   - Make sure "Copy items if needed" is checked
   - Ensure "Runner" target is selected

## Step 2: Install CocoaPods Dependencies

1. Navigate to the iOS directory:
   ```bash
   cd ios
   ```

2. Install pods:
   ```bash
   pod install
   ```

3. If you encounter issues, try:
   ```bash
   pod deintegrate
   pod install
   ```

4. Return to project root:
   ```bash
   cd ..
   ```

## Step 3: Configure Xcode Project

1. Open the workspace (not the project):
   ```bash
   open ios/Runner.xcworkspace
   ```
   **Note**: Always open `.xcworkspace`, not `.xcodeproj`

2. **Configure Signing & Capabilities:**
   - Select the `Runner` target
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Enable "Automatically manage signing"
   - Xcode will automatically create a provisioning profile

3. **Add Required Capabilities:**
   - Push Notifications (for Firebase Cloud Messaging)
   - Background Modes → Remote notifications

## Step 4: Configure Info.plist Permissions

The following permissions are already configured in `Info.plist`:
- Camera access (for QR code scanning and photo capture)
- Photo library access (for selecting event images)
- Notification permissions (handled by Firebase)

## Step 5: Build and Run

### Using Flutter CLI:
```bash
flutter run -d ios
```

### Using Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select a simulator or connected device
3. Click the Run button (▶️) or press `Cmd + R`

## Step 6: Enable Push Notifications (Production)

For production builds with push notifications:

1. In Xcode, go to "Signing & Capabilities"
2. Click "+ Capability"
3. Add "Push Notifications"
4. Add "Background Modes" and enable "Remote notifications"

5. In Firebase Console:
   - Go to Project Settings → Cloud Messaging
   - Upload your APNs Authentication Key or Certificate
   - Follow Firebase's guide for APNs setup

## Troubleshooting

### Issue: "No Podfile found"
**Solution**: The Podfile should be in the `ios/` directory. If missing, run:
```bash
cd ios
pod init
```

### Issue: "Firebase not initialized"
**Solution**: 
- Verify `GoogleService-Info.plist` is in `ios/Runner/` and added to Xcode project
- Check that the bundle ID matches in both Xcode and Firebase Console

### Issue: "Pod install fails"
**Solution**:
```bash
cd ios
pod repo update
pod deintegrate
pod install
```

### Issue: "Build fails with signing errors"
**Solution**:
- Ensure you have a valid Apple Developer account
- Configure signing in Xcode (Signing & Capabilities tab)
- Make sure bundle ID is unique

### Issue: "Notifications not working"
**Solution**:
- Verify Push Notifications capability is enabled in Xcode
- Check that APNs certificate/key is uploaded to Firebase Console
- Ensure notification permissions are requested in the app

## Testing on Simulator vs Device

- **Simulator**: Good for UI testing, but push notifications may not work
- **Physical Device**: Required for full testing of notifications and camera features

## Deployment

For App Store deployment:
1. Configure App Store Connect
2. Archive the app in Xcode (Product → Archive)
3. Upload to App Store Connect
4. Submit for review

## Additional Resources

- [Flutter iOS Setup](https://docs.flutter.dev/deployment/ios)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)

