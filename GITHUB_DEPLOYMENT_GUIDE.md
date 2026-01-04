# 🚀 Deploy PWA from GitHub - Complete Guide

## Overview
Deploy your EventBridge PWA automatically from GitHub using GitHub Actions. Every time you push to your repository, it will automatically build and deploy to Firebase Hosting!

---

## ✅ What's Already Set Up

I've created a GitHub Actions workflow (`.github/workflows/firebase-deploy.yml`) that will:
- ✅ Automatically trigger on every push to `main` or `master` branch
- ✅ Build your Flutter web app
- ✅ Deploy to Firebase Hosting
- ✅ Can also be triggered manually from GitHub

---

## 🔧 One-Time Setup (Required)

### Step 1: Get Firebase Service Account Key

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/walkie-7a9dc/settings/serviceaccounts/adminsdk

2. **Generate new private key:**
   - Click on **"Service accounts"** tab
   - Click **"Generate new private key"**
   - Click **"Generate key"**
   - A JSON file will download

3. **Copy the entire JSON content:**
   - Open the downloaded JSON file
   - Copy **ALL** the content (it's a long JSON object)

### Step 2: Add Secret to GitHub

1. **Go to your GitHub repository:**
   - Navigate to: https://github.com/mashkurulalamohi37/BaustEvent

2. **Go to Settings → Secrets and variables → Actions:**
   - Click on **"Settings"** tab
   - Click **"Secrets and variables"** → **"Actions"**
   - Click **"New repository secret"**

3. **Create the secret:**
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** Paste the entire JSON content from Step 1
   - Click **"Add secret"**

---

## 🎯 How to Deploy

### Option 1: Automatic Deployment (Recommended)

Just push your code to GitHub:

```powershell
git add .
git commit -m "Deploy PWA to Firebase"
git push origin main
```

**That's it!** GitHub Actions will automatically:
1. Build your Flutter web app
2. Deploy to Firebase Hosting
3. Your app will be live at: `https://walkie-7a9dc.web.app`

### Option 2: Manual Deployment

1. **Go to GitHub Actions:**
   - Navigate to: https://github.com/mashkurulalamohi37/BaustEvent/actions

2. **Select the workflow:**
   - Click on **"Deploy to Firebase Hosting"**

3. **Run workflow:**
   - Click **"Run workflow"**
   - Select branch: `main`
   - Click **"Run workflow"**

---

## 📊 Monitor Deployment

### View Deployment Status

1. **Go to GitHub Actions:**
   - https://github.com/mashkurulalamohi37/BaustEvent/actions

2. **Click on the latest workflow run:**
   - You'll see real-time progress
   - Green checkmark = Success ✅
   - Red X = Failed ❌

### View Deployment Logs

- Click on any step to see detailed logs
- Useful for debugging if deployment fails

---

## 🔍 What Happens During Deployment

```
1. Checkout code from GitHub
   ↓
2. Install Flutter SDK
   ↓
3. Run: flutter pub get
   ↓
4. Run: flutter build web --release
   ↓
5. Deploy build/web to Firebase Hosting
   ↓
6. ✅ Live at: https://walkie-7a9dc.web.app
```

**Time:** Usually takes 3-5 minutes

---

## 🎨 Workflow File Explained

Located at: `.github/workflows/firebase-deploy.yml`

```yaml
on:
  push:
    branches:
      - main
      - master
  workflow_dispatch:  # Manual trigger option
```

**Triggers:**
- Automatically on push to `main` or `master`
- Manually from GitHub Actions tab

```yaml
- name: Build web
  run: flutter build web --release
```

**Builds your app** for production

```yaml
- name: Deploy to Firebase Hosting
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
```

**Deploys to Firebase** using the secret you added

---

## 🌿 Branch-Based Deployment (Optional)

### Deploy Different Branches to Different Channels

You can deploy different branches to preview channels:

**Update `.github/workflows/firebase-deploy.yml`:**

```yaml
on:
  push:
    branches:
      - main        # Production
      - develop     # Preview channel
  pull_request:     # Preview for PRs
```

**Benefits:**
- `main` branch → Production site
- `develop` branch → Preview site
- Pull requests → Temporary preview URLs

---

## 🐛 Troubleshooting

### Issue: Workflow fails with "Firebase service account error"

**Solution:**
1. Check that `FIREBASE_SERVICE_ACCOUNT` secret is added
2. Verify the JSON is complete (no missing characters)
3. Regenerate the service account key if needed

### Issue: Build fails

**Solution:**
1. Check the error in GitHub Actions logs
2. Make sure your code builds locally: `flutter build web --release`
3. Check Flutter version in workflow matches your local version

### Issue: Deployment succeeds but site not updating

**Solution:**
1. Clear browser cache (Ctrl+Shift+R)
2. Check Firebase Console for deployment history
3. Service worker might be caching old version

### Issue: "Permission denied" error

**Solution:**
1. Verify service account has "Firebase Hosting Admin" role
2. Regenerate service account key
3. Update the secret in GitHub

---

## 🔒 Security Best Practices

### ✅ Do's:
- ✅ Use GitHub Secrets for sensitive data
- ✅ Never commit service account JSON to repository
- ✅ Limit service account permissions to Hosting only
- ✅ Rotate service account keys periodically

### ❌ Don'ts:
- ❌ Don't share service account JSON publicly
- ❌ Don't commit `.env` files with secrets
- ❌ Don't use personal access tokens

---

## 📈 Advanced: Multiple Environments

### Deploy to Staging and Production

**Create two workflows:**

**1. `.github/workflows/deploy-staging.yml`:**
```yaml
name: Deploy to Staging
on:
  push:
    branches: [develop]
jobs:
  deploy:
    # ... same steps ...
    with:
      channelId: staging
```

**2. `.github/workflows/deploy-production.yml`:**
```yaml
name: Deploy to Production
on:
  push:
    branches: [main]
jobs:
  deploy:
    # ... same steps ...
    with:
      channelId: live
```

---

## 🎯 Quick Reference

### Add Secret to GitHub:
1. Go to: **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Name: `FIREBASE_SERVICE_ACCOUNT`
4. Value: Paste service account JSON
5. Click **"Add secret"**

### Deploy:
```powershell
git add .
git commit -m "Update app"
git push origin main
```

### View Deployment:
- GitHub Actions: https://github.com/mashkurulalamohi37/BaustEvent/actions
- Live Site: https://walkie-7a9dc.web.app

---

## 🎉 Benefits of GitHub Deployment

| Feature | Manual Deploy | GitHub Deploy |
|---------|--------------|---------------|
| **Automation** | ❌ Manual | ✅ Automatic |
| **CI/CD** | ❌ No | ✅ Yes |
| **Version Control** | ⚠️ Manual | ✅ Automatic |
| **Rollback** | ⚠️ Difficult | ✅ Easy (revert commit) |
| **Team Collaboration** | ⚠️ Limited | ✅ Full |
| **Deployment History** | ❌ No | ✅ Yes |
| **Preview Deployments** | ❌ No | ✅ Yes |

---

## 📝 Complete Setup Checklist

- [ ] Firebase service account key generated
- [ ] `FIREBASE_SERVICE_ACCOUNT` secret added to GitHub
- [ ] `.github/workflows/firebase-deploy.yml` exists
- [ ] Code pushed to GitHub
- [ ] GitHub Actions workflow triggered
- [ ] Deployment successful (check Actions tab)
- [ ] Site live at `https://walkie-7a9dc.web.app`

---

## 🔗 Useful Links

- **Your GitHub Repo:** https://github.com/mashkurulalamohi37/BaustEvent
- **GitHub Actions:** https://github.com/mashkurulalamohi37/BaustEvent/actions
- **Firebase Console:** https://console.firebase.google.com/project/walkie-7a9dc
- **Service Accounts:** https://console.firebase.google.com/project/walkie-7a9dc/settings/serviceaccounts/adminsdk
- **Live Site:** https://walkie-7a9dc.web.app (after deployment)

---

## 💡 Pro Tips

1. **Use Protected Branches:**
   - Require pull request reviews before merging to `main`
   - Prevents accidental deployments

2. **Add Status Badge:**
   - Show deployment status in your README
   ```markdown
   ![Deploy Status](https://github.com/mashkurulalamohi37/BaustEvent/actions/workflows/firebase-deploy.yml/badge.svg)
   ```

3. **Set Up Notifications:**
   - Get email/Slack notifications on deployment success/failure
   - Configure in GitHub repository settings

4. **Preview Deployments:**
   - Deploy pull requests to preview channels
   - Test changes before merging

5. **Deployment Frequency:**
   - Deploy as often as you want (it's free!)
   - Every push = automatic deployment

---

## 🚀 You're Ready!

### Next Steps:

1. **Get Firebase Service Account Key** (see Step 1 above)
2. **Add Secret to GitHub** (see Step 2 above)
3. **Push your code:**
   ```powershell
   git add .
   git commit -m "Setup GitHub deployment"
   git push origin main
   ```
4. **Watch it deploy** at: https://github.com/mashkurulalamohi37/BaustEvent/actions

**That's it!** Your app will automatically deploy every time you push to GitHub! 🎊

---

**Questions?** Check the troubleshooting section or Firebase/GitHub documentation.
