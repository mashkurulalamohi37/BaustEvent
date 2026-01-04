# Quick Setup for GitHub Deployment

Write-Host "🚀 EventBridge - GitHub Deployment Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if git is initialized
if (-not (Test-Path ".git")) {
    Write-Host "❌ Git repository not found!" -ForegroundColor Red
    Write-Host "Please initialize git first:" -ForegroundColor Yellow
    Write-Host "  git init" -ForegroundColor White
    Write-Host "  git remote add origin https://github.com/mashkurulalamohi37/BaustEvent.git" -ForegroundColor White
    exit 1
}

Write-Host "✅ Git repository found" -ForegroundColor Green
Write-Host ""

# Check if workflow file exists
if (Test-Path ".github/workflows/firebase-deploy.yml") {
    Write-Host "✅ GitHub Actions workflow configured" -ForegroundColor Green
} else {
    Write-Host "❌ Workflow file not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Get Firebase Service Account Key:" -ForegroundColor White
Write-Host "   → Visit: https://console.firebase.google.com/project/walkie-7a9dc/settings/serviceaccounts/adminsdk" -ForegroundColor Cyan
Write-Host "   → Click 'Generate new private key'" -ForegroundColor Cyan
Write-Host "   → Download and copy the JSON content" -ForegroundColor Cyan
Write-Host ""

Write-Host "2. Add Secret to GitHub:" -ForegroundColor White
Write-Host "   → Visit: https://github.com/mashkurulalamohi37/BaustEvent/settings/secrets/actions" -ForegroundColor Cyan
Write-Host "   → Click 'New repository secret'" -ForegroundColor Cyan
Write-Host "   → Name: FIREBASE_SERVICE_ACCOUNT" -ForegroundColor Cyan
Write-Host "   → Value: Paste the JSON content" -ForegroundColor Cyan
Write-Host ""

Write-Host "3. Push to GitHub:" -ForegroundColor White
Write-Host "   git add ." -ForegroundColor Cyan
Write-Host "   git commit -m 'Setup GitHub deployment'" -ForegroundColor Cyan
Write-Host "   git push origin main" -ForegroundColor Cyan
Write-Host ""

Write-Host "4. Monitor Deployment:" -ForegroundColor White
Write-Host "   → Visit: https://github.com/mashkurulalamohi37/BaustEvent/actions" -ForegroundColor Cyan
Write-Host ""

Write-Host "5. View Live Site:" -ForegroundColor White
Write-Host "   → https://walkie-7a9dc.web.app" -ForegroundColor Cyan
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "📚 For detailed instructions, see:" -ForegroundColor Yellow
Write-Host "   GITHUB_DEPLOYMENT_GUIDE.md" -ForegroundColor White
Write-Host ""

# Ask if user wants to commit and push now
Write-Host "Would you like to commit and push the changes now? (Y/N): " -ForegroundColor Yellow -NoNewline
$response = Read-Host

if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host ""
    Write-Host "⚠️  Make sure you've added the FIREBASE_SERVICE_ACCOUNT secret first!" -ForegroundColor Yellow
    Write-Host "Press Enter to continue or Ctrl+C to cancel..." -NoNewline
    Read-Host
    
    Write-Host ""
    Write-Host "📦 Adding files..." -ForegroundColor Cyan
    git add .
    
    Write-Host "💾 Committing changes..." -ForegroundColor Cyan
    git commit -m "Setup GitHub deployment for PWA"
    
    Write-Host "🚀 Pushing to GitHub..." -ForegroundColor Cyan
    git push origin main
    
    Write-Host ""
    Write-Host "✅ Done! Check deployment status at:" -ForegroundColor Green
    Write-Host "   https://github.com/mashkurulalamohi37/BaustEvent/actions" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "👍 No problem! You can push manually when ready." -ForegroundColor Green
    Write-Host "   Run: git add . && git commit -m 'Setup deployment' && git push origin main" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🎉 Setup complete!" -ForegroundColor Green
