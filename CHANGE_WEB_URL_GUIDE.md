# 🌐 Change Your Web App URL

## Current URL
Your app is currently at: `https://walkie-7a9dc.web.app`

---

## Option 1: Add Custom Domain (Best Option) 🌟

Use your own domain like `eventbridge.com` or `app.eventbridge.com`

### Steps:

1. **Buy a domain** (if you don't have one):
   - Namecheap: ~$10/year
   - Google Domains: ~$12/year
   - GoDaddy: ~$15/year

2. **Add to Firebase:**
   ```
   Go to: https://console.firebase.google.com/project/walkie-7a9dc/hosting
   Click: "Add custom domain"
   Enter: your-domain.com
   ```

3. **Update DNS records:**
   - Firebase will show you DNS records to add
   - Go to your domain registrar
   - Add the A and TXT records

4. **Wait for SSL:**
   - Firebase automatically provisions SSL
   - Usually takes 24-48 hours

### Result:
✅ Professional URL: `https://eventbridge.com`  
✅ Free SSL certificate  
✅ Automatic renewal  
✅ Keep Firebase hosting benefits  

---

## Option 2: Create New Firebase Hosting Site

Change from `walkie-7a9dc.web.app` to a custom Firebase subdomain.

### Steps:

1. **Create new site:**
   ```powershell
   firebase hosting:sites:create eventbridge-app
   ```

2. **Update firebase.json:**
   ```json
   {
     "hosting": {
       "site": "eventbridge-app",
       "public": "build/web",
       ...
     }
   }
   ```

3. **Deploy:**
   ```powershell
   firebase deploy --only hosting
   ```

### Result:
✅ New URL: `https://eventbridge-app.web.app`  
⚠️ Still shows `.web.app` domain  

---

## Option 3: Use Different Hosting (Alternative)

Deploy to a different service with a better default URL.

### Vercel:
```powershell
flutter build web --release
cd build/web
vercel
```
**Result:** `https://eventbridge.vercel.app`

### Netlify:
1. Go to netlify.com
2. Drag `build/web` folder
3. Change site name in settings

**Result:** `https://eventbridge.netlify.app`

---

## 📊 Comparison

| Option | URL Example | Cost | Setup Time | Recommended |
|--------|-------------|------|------------|-------------|
| **Custom Domain** | `eventbridge.com` | ~$10/year | 1-2 days | ⭐⭐⭐⭐⭐ |
| **New Firebase Site** | `eventbridge-app.web.app` | Free | 5 min | ⭐⭐⭐ |
| **Vercel** | `eventbridge.vercel.app` | Free | 5 min | ⭐⭐⭐⭐ |
| **Netlify** | `eventbridge.netlify.app` | Free | 5 min | ⭐⭐⭐⭐ |

---

## 🎯 My Recommendation

### For Professional Use:
**Get a custom domain** - It looks more professional and builds trust.

**Good domain names:**
- `eventbridge.com` (if available)
- `baustevents.com`
- `bausteventbridge.com`
- `myeventbridge.com`

### For Quick Change:
**Use Vercel or Netlify** - Better default URLs than Firebase.

---

## 🚀 Quick Setup: Custom Domain on Firebase

### 1. Buy Domain (Namecheap - Cheapest)

1. Go to: https://www.namecheap.com
2. Search for your desired domain
3. Purchase (usually $8-12/year)

### 2. Add to Firebase

```powershell
# Go to Firebase Console
# https://console.firebase.google.com/project/walkie-7a9dc/hosting

# Click "Add custom domain"
# Enter your domain
```

### 3. Update DNS

Firebase will show you records like:
```
Type: A
Name: @
Value: 151.101.1.195

Type: A
Name: @
Value: 151.101.65.195
```

Add these to your domain's DNS settings in Namecheap.

### 4. Wait

- DNS propagation: 1-24 hours
- SSL certificate: Automatic
- Done!

---

## 🔧 Quick Setup: New Firebase Site

```powershell
# Create new site
firebase hosting:sites:create eventbridge-app

# This will give you: https://eventbridge-app.web.app
```

Then update `.github/workflows/firebase-deploy.yml`:

```yaml
- name: Deploy to Firebase Hosting
  uses: FirebaseExtended/action-hosting-deploy@v0
  with:
    repoToken: '${{ secrets.GITHUB_TOKEN }}'
    firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
    channelId: live
    projectId: walkie-7a9dc
    target: eventbridge-app  # Add this line
```

Push to GitHub and it will deploy to the new URL!

---

## 🔧 Quick Setup: Switch to Vercel

```powershell
# Install Vercel CLI
npm install -g vercel

# Build
flutter build web --release

# Deploy
cd build/web
vercel --prod

# Follow prompts to set project name
# Result: https://your-project-name.vercel.app
```

---

## 💡 Pro Tips

1. **Custom domain is best** - Worth the $10/year
2. **Vercel/Netlify** - Better free URLs than Firebase
3. **Keep it short** - Easier for users to remember
4. **Use HTTPS** - All options provide free SSL

---

## ❓ Which Should You Choose?

### Choose Custom Domain if:
- ✅ You want a professional URL
- ✅ You're okay spending $10/year
- ✅ You want to build brand trust

### Choose New Firebase Site if:
- ✅ You want to stay on Firebase
- ✅ You want it free
- ✅ You can wait 5 minutes

### Choose Vercel/Netlify if:
- ✅ You want a better free URL
- ✅ You want it now
- ✅ You're okay switching hosting

---

## 🎯 Next Steps

**Tell me which option you prefer:**

1. **Custom domain** - I'll guide you through buying and setting it up
2. **New Firebase site** - I'll help you create and deploy
3. **Vercel/Netlify** - I'll help you switch hosting

**What would you like to do?**
