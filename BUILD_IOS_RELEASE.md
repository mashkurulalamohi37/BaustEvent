# iOS Release Build Guide

## Prerequisites
- ✅ macOS computer with Xcode installed
- ✅ Apple Developer account ($99/year) - Required for release builds
- ✅ CocoaPods installed: `sudo gem install cocoapods`

## Step-by-Step Release Build Instructions

### Step 1: Prepare the Project

```bash
# Navigate to project directory
cd /path/to/Baust_Event

# Clean previous builds
flutter clean

# Get all dependencies
flutter pub get

# Install iOS CocoaPods
cd ios
pod install
cd ..
```

### Step 2: Update Version (Optional)

If you want to update the version number, edit `pubspec.yaml`:
```yaml
version: 1.0.0+1
# Format: version_name+build_number
# Example: 1.0.1+2 (version 1.0.1, build 2)
```

### Step 3: Open in Xcode

```bash
open ios/Runner.xcworkspace
```

⚠️ **IMPORTANT**: Always open `.xcworkspace`, NOT `.xcodeproj`

### Step 4: Configure Signing & Capabilities

1. In Xcode, select **Runner** project (left sidebar, blue icon)
2. Select **Runner** target (under TARGETS)
3. Click **Signing & Capabilities** tab
4. Configure:
   - ✅ Check **"Automatically manage signing"**
   - Select your **Team** (Apple Developer account)
   - Verify **Bundle Identifier**: `com.baust.eventmanager`
   - Xcode will automatically create/select provisioning profiles

### Step 5: Build Release Version

**Option A: Using Flutter CLI (Recommended)**

```bash
# Build release iOS app
flutter build ios --release

# Or build IPA directly (for distribution)
flutter build ipa
```

**Option B: Using Xcode**

1. In Xcode, select **Product** → **Scheme** → **Runner**
2. Select **Any iOS Device** or a connected device (not simulator)
3. Go to **Product** → **Archive**
4. Wait for the build to complete
5. Xcode Organizer will open automatically
6. Click **Distribute App** to create IPA

### Step 6: Build Output Locations

**Flutter CLI Build:**
- Release build: `build/ios/iphoneos/Runner.app`
- IPA file: `build/ios/ipa/baust_event.ipa`

**Xcode Archive:**
- Archive location: `~/Library/Developer/Xcode/Archives`
- Can be distributed via Xcode Organizer

## Distribution Methods

### 1. App Store Connect (For App Store Distribution)

```bash
flutter build ipa
```

Then upload to [App Store Connect](https://appstoreconnect.apple.com):
- Use **Transporter** app (from Mac App Store)
- Or use Xcode Organizer → Distribute App → App Store Connect

### 2. TestFlight (Beta Testing)

1. Build IPA: `flutter build ipa`
2. Upload to App Store Connect
3. Go to TestFlight section in App Store Connect
4. Add testers (internal or external)
5. No App Store review needed for beta testing

### 3. Ad Hoc Distribution (Limited Devices)

```bash
flutter build ipa --export-method ad-hoc
```

Requirements:
- Register device UDIDs in Apple Developer Portal
- Maximum 100 devices per year
- Share IPA file directly with registered devices

### 4. Enterprise Distribution (Enterprise Account Only)

```bash
flutter build ipa --export-method enterprise
```

## Build Commands Reference

| Purpose | Command |
|---------|---------|
| **Release Build** | `flutter build ios --release` |
| **Release IPA** | `flutter build ipa` |
| **Ad Hoc IPA** | `flutter build ipa --export-method ad-hoc` |
| **Enterprise IPA** | `flutter build ipa --export-method enterprise` |
| **Debug Build** | `flutter build ios --debug` |
| **Profile Build** | `flutter build ios --profile` |

## Troubleshooting

### Error: "No signing certificate found"
**Solution:**
- Open Xcode → Signing & Capabilities
- Select your Team
- Enable "Automatically manage signing"
- Xcode will create certificates automatically

### Error: "Provisioning profile not found"
**Solution:**
- In Xcode, go to Signing & Capabilities
- Click "Download Manual Profiles" if needed
- Or let Xcode automatically manage it

### Error: "Pod install fails"
**Solution:**
```bash
cd ios
pod deintegrate
pod install --repo-update
cd ..
```

### Error: "Build fails with Swift errors"
**Solution:**
- Clean build folder: In Xcode, Product → Clean Build Folder (⇧⌘K)
- Delete Derived Data: Xcode → Preferences → Locations → Derived Data → Delete
- Rebuild: `flutter clean && flutter pub get && cd ios && pod install && cd ..`

### Error: "Archive button is disabled"
**Solution:**
- Select "Any iOS Device" or a connected physical device (not simulator)
- Simulators cannot create archives

## Release Build Checklist

Before building release version, verify:

- ✅ Version number updated in `pubspec.yaml`
- ✅ Bundle identifier: `com.baust.eventmanager`
- ✅ Signing configured in Xcode
- ✅ GoogleService-Info.plist is present
- ✅ All dependencies installed (`pod install`)
- ✅ No build errors in debug mode
- ✅ Tested on device/simulator

## Quick Release Build Command

```bash
# Complete release build workflow
flutter clean && \
flutter pub get && \
cd ios && \
pod install && \
cd .. && \
flutter build ipa
```

The IPA will be created at: `build/ios/ipa/baust_event.ipa`

## Next Steps After Building

1. **For App Store:**
   - Upload IPA to App Store Connect
   - Fill in app metadata, screenshots, description
   - Submit for App Store review

2. **For TestFlight:**
   - Upload to App Store Connect
   - Add internal/external testers
   - Distribute beta version

3. **For Ad Hoc:**
   - Share IPA file with registered devices
   - Install via iTunes/Finder or TestFlight

---

**Your iOS release build is ready!** 🎉

For questions or issues, refer to the [Flutter iOS Deployment Guide](https://docs.flutter.dev/deployment/ios)

