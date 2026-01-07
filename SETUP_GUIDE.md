# EventBridge Setup Guide: Google Sign-In & PWA

## 1. Google Sign-In Configuration
The "Google Sign-In failed: ApiException: 10" error indicates that your app's **SHA-1 Certificate Fingerprint** is missing from the Firebase Console.

### Step 1: Get your SHA-1 Fingerprint (Android)
1. Open a terminal in your project's `android` folder:
   ```powershell
   cd d:\Baust_Event\android
   ```
2. Run the signing report:
   ```powershell
   ./gradlew signingReport
   ```
   *(If this fails with "JAVA_HOME not set", you may need to run it from Android Studio's terminal or locate your Java path)*

3. Look for the **debug** variant output:
   ```text
   Variant: debug
   Config: debug
   Store: ...\debug.keystore
   Alias: AndroidDebugKey
   MD5: ...
   SHA1: DA:39:A3:EE:5E:6B:4B:0D:32:55:BF:EF:95:60:18:90:AF:D8:07:09  <-- COPY THIS
   SHA-256: ...
   ```

### Step 2: Add to Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Open **Project Settings** (Gear icon).
3. Scroll down to **Your apps** and select the **Android** app.
4. Click **Add fingerprint**.
5. Paste the **SHA-1** you copied.
6. Click **Save**.

**Note:** For the **Release** version (Play Store/APK), you must also add the SHA-1 from your *Release Keystore* using the same process.

### Step 3: Web / PWA Configuration
For Google Sign-In to work on the Web (PWA):
1. Go to the [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
2. Select your project.
3. Find the **OAuth 2.0 Client ID** named "Web client (auto created by...)" or similar.
4. Under **Authorized JavaScript origins**, add your PWA domain:
   - `https://your-project-id.web.app`
   - `https://your-project-id.firebaseapp.com`
   - `http://localhost:port` (for local testing)
5. Save changes.

## 2. PWA Deployment
Your project is configured for PWA.

### Build & Deploy
1. **Build** the web release:
   ```bash
   flutter build web --release --web-renderer html
   ```
   *(Using HTML renderer is often more compatible for broad device support, or use default `auto`)*

2. **Deploy** to Firebase Hosting:
   ```bash
   firebase deploy
   ```

## 3. Important Notes
- **Support Email**: Ensure you have set a **Support Email** in Firebase Console -> Project Settings -> General. Google Sign-In may fail (Error 12500) if this is missing.
- **Testing**: Changes to fingerprints may take a few minutes to propagate.
