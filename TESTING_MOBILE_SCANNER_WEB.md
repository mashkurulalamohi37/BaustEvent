# Testing Mobile Scanner on Web

## Quick Test Guide

### 1. Run the Web App Locally
```bash
flutter run -d chrome --web-renderer html
```

**Note**: Use `--web-renderer html` for better camera compatibility. The default CanvasKit renderer may have issues with camera access in some browsers.

### 2. Grant Camera Permissions
When you navigate to the QR scanner:
1. Your browser will prompt for camera access
2. Click "Allow" to grant permission
3. The camera feed should appear in the scanner dialog

### 3. Test QR Code Scanning
You can test with:
- A physical QR code
- A QR code displayed on another device
- A QR code from the app itself (generate one first)

### 4. Browser Compatibility

#### ✅ Fully Supported
- **Chrome/Edge** (Desktop & Mobile) - Best support
- **Firefox** (Desktop & Mobile) - Good support
- **Safari** (Desktop & Mobile) - Good support (iOS 11+)

#### ⚠️ Requirements
- **HTTPS required** (or localhost for development)
- **Camera permissions** must be granted
- **Modern browser** (released in last 2-3 years)

### 5. Common Issues & Solutions

#### Issue: "Camera not found" or "Permission denied"
**Solutions**:
- Check if camera is being used by another application
- Ensure HTTPS is enabled (or using localhost)
- Check browser camera permissions in settings
- Try a different browser

#### Issue: Scanner not appearing
**Solutions**:
- Check browser console for errors (F12)
- Ensure `mobile_scanner` package is properly installed
- Rebuild the app: `flutter clean && flutter pub get && flutter build web`

#### Issue: QR codes not being detected
**Solutions**:
- Ensure good lighting
- Hold QR code steady and at proper distance
- Try a different QR code to rule out code quality issues
- Check if the QR code format is supported

### 6. Development vs Production

#### Development (localhost)
```bash
# Run with hot reload
flutter run -d chrome --web-renderer html

# Or run with web server
flutter run -d web-server --web-port=8080
```

#### Production Build
```bash
# Build optimized web version
flutter build web --release --web-renderer html

# The output will be in build/web/
```

### 7. Deployment Checklist

- [ ] Build with `--web-renderer html` for better camera support
- [ ] Ensure hosting uses HTTPS
- [ ] Test camera permissions on deployed site
- [ ] Test on multiple browsers (Chrome, Firefox, Safari)
- [ ] Test on both desktop and mobile browsers
- [ ] Verify QR code detection works correctly

### 8. Firebase Hosting Deployment

If using Firebase Hosting:
```bash
# Build the web app
flutter build web --release --web-renderer html

# Deploy to Firebase
firebase deploy --only hosting
```

### 9. GitHub Pages Deployment

If using GitHub Pages:
```bash
# Build the web app
flutter build web --release --web-renderer html --base-href /your-repo-name/

# Copy build/web contents to your GitHub Pages branch
```

## Testing Checklist

- [ ] Scanner opens when clicking scan button
- [ ] Camera feed is visible
- [ ] QR codes are detected and processed
- [ ] Valid QR codes trigger appropriate actions
- [ ] Invalid QR codes show error messages
- [ ] Scanner closes properly after scanning
- [ ] Works on mobile browsers
- [ ] Works on desktop browsers
- [ ] HTTPS deployment works correctly

---
**Last Updated**: 2026-01-04
**Status**: Ready for testing
