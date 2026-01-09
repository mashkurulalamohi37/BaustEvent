@echo off
echo Building EventBridge Web (v1.2)...
call flutter build web --release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)

echo.
echo Deploying to Firebase Hosting...
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo Deployment failed!
    pause
    exit /b %errorlevel%
)

echo.
echo SUCCESS! PWA Updated to v1.2
pause
