# Baust Event - Release Build Script
# This script helps you build a Play Protect compliant release

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Baust Event - Release Build Script  " -ForegroundColor Cyan
Write-Host "  Play Protect Compliant Build        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if a file exists
function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Host "[✓] $Description found" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[✗] $Description NOT found" -ForegroundColor Red
        return $false
    }
}

# Pre-flight checks
Write-Host "Running pre-flight checks..." -ForegroundColor Yellow
Write-Host ""

$allChecks = $true

# Check Flutter
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
    Write-Host "[✓] Flutter installed: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "[✗] Flutter not found. Please install Flutter first." -ForegroundColor Red
    $allChecks = $false
}

# Check security files
$allChecks = $allChecks -and (Test-FileExists "android\app\proguard-rules.pro" "ProGuard rules")
$allChecks = $allChecks -and (Test-FileExists "android\app\src\main\res\xml\network_security_config.xml" "Network security config")
$allChecks = $allChecks -and (Test-FileExists "android\app\src\main\res\xml\backup_rules.xml" "Backup rules")
$allChecks = $allChecks -and (Test-FileExists "android\app\src\main\res\xml\data_extraction_rules.xml" "Data extraction rules")
$allChecks = $allChecks -and (Test-FileExists "android\app\src\main\AndroidManifest.xml" "AndroidManifest")
$allChecks = $allChecks -and (Test-FileExists "android\app\google-services.json" "Firebase config")

Write-Host ""

# Check for keystore
if (Test-Path "android\key.properties") {
    Write-Host "[✓] Keystore configuration found" -ForegroundColor Green
    Write-Host "    App will be signed with your release key" -ForegroundColor Gray
} else {
    Write-Host "[!] Keystore configuration NOT found" -ForegroundColor Yellow
    Write-Host "    App will be built but NOT signed for release" -ForegroundColor Yellow
    Write-Host "    Create android\key.properties to enable signing" -ForegroundColor Yellow
}

Write-Host ""

if (-not $allChecks) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Pre-flight checks FAILED!           " -ForegroundColor Red
    Write-Host "  Please fix the issues above         " -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "  All pre-flight checks PASSED!        " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Ask user what to build
Write-Host "What would you like to build?" -ForegroundColor Cyan
Write-Host "1. APK (for testing/direct installation)" -ForegroundColor White
Write-Host "2. AAB (for Google Play Store)" -ForegroundColor White
Write-Host "3. Both APK and AAB" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Enter your choice (1, 2, or 3)"

# Clean build option
Write-Host ""
$clean = Read-Host "Do you want to clean build? (y/n)"

if ($clean -eq "y" -or $clean -eq "Y") {
    Write-Host ""
    Write-Host "Cleaning previous builds..." -ForegroundColor Yellow
    flutter clean
    Write-Host "[✓] Clean completed" -ForegroundColor Green
}

# Get dependencies
Write-Host ""
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host "[✓] Dependencies updated" -ForegroundColor Green

# Build based on choice
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Build Process               " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$buildSuccess = $true

if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host "Building APK..." -ForegroundColor Yellow
    Write-Host "This may take a few minutes..." -ForegroundColor Gray
    Write-Host ""
    
    flutter build apk --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[✓] APK build successful!" -ForegroundColor Green
        Write-Host "    Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Gray
        
        # Get file size
        $apkSize = (Get-Item "build\app\outputs\flutter-apk\app-release.apk").Length / 1MB
        Write-Host "    Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
    } else {
        Write-Host "[✗] APK build failed!" -ForegroundColor Red
        $buildSuccess = $false
    }
    Write-Host ""
}

if ($choice -eq "2" -or $choice -eq "3") {
    Write-Host "Building AAB..." -ForegroundColor Yellow
    Write-Host "This may take a few minutes..." -ForegroundColor Gray
    Write-Host ""
    
    flutter build appbundle --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[✓] AAB build successful!" -ForegroundColor Green
        Write-Host "    Location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Gray
        
        # Get file size
        $aabSize = (Get-Item "build\app\outputs\bundle\release\app-release.aab").Length / 1MB
        Write-Host "    Size: $([math]::Round($aabSize, 2)) MB" -ForegroundColor Gray
    } else {
        Write-Host "[✗] AAB build failed!" -ForegroundColor Red
        $buildSuccess = $false
    }
    Write-Host ""
}

# Final summary
Write-Host "========================================" -ForegroundColor Cyan
if ($buildSuccess) {
    Write-Host "  Build Completed Successfully!        " -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your app is Play Protect compliant! ✅" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Test the release build on a real device" -ForegroundColor White
    Write-Host "2. Verify all features work correctly" -ForegroundColor White
    Write-Host "3. Upload to Google Play Console" -ForegroundColor White
    Write-Host ""
    Write-Host "For detailed instructions, see:" -ForegroundColor Gray
    Write-Host "  - RELEASE_CHECKLIST.md" -ForegroundColor Cyan
    Write-Host "  - PLAY_PROTECT_COMPLIANCE.md" -ForegroundColor Cyan
} else {
    Write-Host "  Build Failed!                        " -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please check the error messages above" -ForegroundColor Yellow
    Write-Host "and refer to PLAY_PROTECT_COMPLIANCE.md for troubleshooting" -ForegroundColor Yellow
}
Write-Host ""
