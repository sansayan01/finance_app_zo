# Firebase App Distribution — Complete Setup Guide

## Important: What this is and what this isn't

**What Firebase App Distribution does:**
- Lets you (the admin) and a few trusted testers download new APKs before you push them to all customers
- Think of it as a private testing area — not a public app store

**Who needs it:**
- Only you and your team (2-5 people max)
- Your real customers **never** need it — they get updates through the normal in-app update flow

**Who does NOT need to install anything:**
- Your real customers — they just open the app, see "Update Available," tap Download. Done.
- The Firebase App Distribution app on a phone is only for testers

---

## Step-by-step: Set up Firebase App Distribution

### What you need before starting

- ✅ A Google/Gmail account (personal or work)
- ✅ Your Android phone (real device, not emulator)
- ✅ ~30 minutes
- ✅ Your application ID: `com.microflow.pro` (your app's unique name on Google Play)

---

### Step 1: Create a Firebase project (5 minutes)

1. Open your web browser (Chrome is best)
2. Go to **https://console.firebase.google.com**
3. Sign in with your Google account
4. Click the large button: **"Create a project"** or **"Add project"**
5. Enter project name: `MicroFlow Pro`
6. Click **Continue**
7. Google Analytics? → **Toggle it OFF** (you can add it later). Click **Continue**
8. Click **Create project**
9. Wait ~30 seconds. When you see **"Your new project is ready"**, click **Continue**

✅ You now have a Firebase project

---

### Step 2: Register your Android app in Firebase (3 minutes)

1. In your Firebase project, you'll see a dashboard with icons for iOS and Android
2. Click the **Android robot icon** (it says "Add an app")
3. Fill in:
   - **Android package name**: `com.microflow.pro` ← this must match exactly
   - **App nickname** (optional): `MicroFlow Pro`
   - **Debug signing certificate SHA-1** (optional): leave blank, click **Next**
4. You'll be asked to download `google-services.json`:
   - Click **Download google-services.json**
   - Save it to a safe place on your computer (e.g., Desktop). You'll need it later.
   - Click **Next**
5. The next screens show SDK setup instructions — **just click Next → Next → Continue to console**
   - We only need distribution, not the full Firebase SDK, so skip those steps

✅ Your Android app is registered in Firebase

---

### Step 3: Find your Firebase App ID (1 minute)

1. In Firebase console, click the **⚙️ gear icon** (top-left) → **Project settings**
2. Scroll down to the **"Your apps"** section
3. You'll see your Android app listed
4. Look for the line that says **"App ID"** — it will look like:
   ```
   1:1234567890:android:abc123def456
   ```
5. **Copy this entire string** and save it in a text file on your Desktop

> 👉 This is what we'll paste into GitHub as `FIREBASE_APP_ID_ANDROID`

---

### Step 4: Create a Tester Group (2 minutes)

A "tester group" is just a list of emails — people you want to test new releases.

1. In Firebase console left menu, scroll down and find **"App Distribution"**
   - If you don't see it, click **"Release & Monitor"** → **"App Distribution"**
2. First time? Click **"Get started"** or **"Set up App Distribution"**
3. Click the **"Testers & Groups"** tab at the top
4. Click **"Create group"**
5. Enter group name: `qa-internal` (this is important — we'll use this exact name later)
6. Add tester emails:
   - Start with **your own email** (the one you'll test from)
   - Add any colleagues who should test
7. Click **Save**

✅ Your tester group is `qa-internal` — testers will get email notifications when you publish a new APK

---

### Step 5: Generate a Service Account key (3 minutes)

This creates a "key" that lets your GitHub Actions workflow upload APKs to Firebase on your behalf.

1. Go to **https://console.cloud.google.com**
2. At the top, click the **project dropdown** (next to the "Google Cloud" logo)
3. Select **"MicroFlow Pro"** (your Firebase project)
4. In the top search bar, type **"Service Accounts"** and open it
   - Or go directly to: **https://console.cloud.google.com/iam-admin/serviceaccounts**
5. You should see a service account already there (created during Firebase setup), probably named something like `firebase-appdistribution-internal@microflow-pro-xxxxx.iam.gserviceaccount.com`
   - **Click on that service account name**
6. Click the **"Keys"** tab at the top of the page
7. Click **"Add Key"** → **"Create new key"**
8. Select **"JSON"** → click **"Create"**
9. A `.json` file will download to your computer — **this is your secret key**
   - ⚠️ Do NOT share this file. Do NOT upload it to GitHub (that's why we'll encode it in the next step).

✅ You now have a service account JSON key file

---

### Step 6: Convert the JSON file to a text string (1 minute)

GitHub secrets can only accept plain text, not files. So we encode the JSON as a base64 string.

#### Windows (PowerShell):

1. Open the folder where the JSON downloaded (usually `Downloads`)
2. Right-click in the empty space → click **"Open in Terminal"**
3. Run this command (replace the filename with your actual file name):
   ```powershell
   Get-Content firebase-adminsdk-xxxxx-xxxxx.json -Raw | [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_)) | Out-File -Encoding utf8 firebase-base64.txt
   ```
4. Open the new `firebase-base64.txt` file → it will be one very long line of text with no spaces or line breaks
5. Select All (Ctrl+A) → Copy (Ctrl+C)
6. Paste this into a safe text file alongside your App ID

> You now have two pieces of information saved:
> 1. Firebase App ID: `1:1234567890:android:abc123def456`
> 2. Base64-encoded service account key: (the long string)

---

### Step 7: Add the secrets to GitHub (3 minutes)

Now we tell GitHub: "Use these keys when uploading releases."

1. Go to **https://github.com** → open your MicroFlow Pro repository
2. Click the **Settings** tab (at the top, only visible to repo owners/admins)
3. Left sidebar → **Secrets and variables** → **Actions**
4. Click **"New repository secret"** (green button)
5. Add these three secrets — one at a time, clicking "Add secret" after each:

| Name to type exactly | What to paste |
|----------------------|--------------|
| `FIREBASE_TOKEN` | The entire long base64 string from `firebase-base64.txt` |
| `FIREBASE_APP_ID_ANDROID` | The `1:1234567890:android:abc...` string from Step 3 |
| `FIREBASE_TESTER_GROUPS` | The literal text `qa-internal` |

6. After adding all three, you should see them listed on the page as 🔒 secrets

✅ GitHub now knows your Firebase credentials

---

### Step 8: (Optional) Install the Firebase App Distribution app on your phone

**Only needed if you want to be a tester yourself.**

1. On your Android phone, open the Play Store
2. Search for **"Firebase App Distribution"**
3. Install the app (by Google)
4. Open it and sign in with the email you added as a tester in Step 4
5. You'll see "No apps to test" for now — that's normal

**If MicroFlow Pro is already installed on your phone from a previous sideload:**
- Uninstall MicroFlow Pro first
- Firebase App Distribution will install it for you

---

### Step 9: Test the whole setup (5-10 minutes)

Let's do a real test to make sure everything works.

1. On your computer, open your project folder
2. Make sure you're on the `main` branch:
   ```
   git checkout main
   git pull origin main
   ```
3. Create a test tag (replace version if needed):
   ```
   git tag v1.0.7
   git push origin v1.0.7
   ```
4. Go to **GitHub → Actions tab** → you should see the `Production Release` workflow running
5. Wait ~10-15 minutes for the build to complete
6. Look for the job called **"Distribute APK via Firebase App Distribution"**
   - ✅ Green checkmark = success! Check your email and your phone's Firebase App Distribution app
   - ❌ Red X = something went wrong. Click on the job to read the error message.

---

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Firebase job is silently skipped | Make sure all three secrets exist in GitHub. Also make sure you're pushing a `v*` tag. |
| "Permission denied" error in GitHub log | Go back to Step 5 → IAM → find your service account → Add role → **Firebase App Distribution Admin** |
| "Invalid app ID" error | Check `FIREBASE_APP_ID_ANDROID` secret — compare character-by-character with what's in Firebase console |
| Testers didn't get an email | Check spam folder. Or go to Firebase → App Distribution → Testers & Groups → click your group → re-add the tester's email |
| App won't install on phone | Uninstall the old MicroFlow Pro first. Also enable "Install unknown apps" for the Firebase App Distribution app (Android asks this on first install) |

---

## How it works after setup (day-to-day)

**You (admin) publish a new release:**
1. Bump version in `pubspec.yaml`
2. Push a tag: `git tag v1.0.8 && git push origin v1.0.8`
3. GitHub Actions runs automatically
4. APK goes to:
   - **Supabase Storage** → your customers see it via in-app update
   - **Firebase App Distribution** → your testers get an email notification

**Your testers (internal team only):**
- They get an email: "New build available"
- They open the Firebase App Distribution app → tap download → done

**Your real customers:**
- They open MicroFlow Pro → go to Settings → "Check for Updates" → see the update
- No need for them to install any Firebase app

---

## Important reminders

1. **Real customers do NOT need Firebase App Distribution** — they use the in-app update flow
2. **Firebase App Distribution is FREE** — no billing required
3. **Firebase App Distribution has limits**: up to 200 testers per app, 1000 builds per month (more than enough for MicroFlow Pro)
4. **The Firebase App Distribution app is optional** for testers — they can also install APKs directly from the email link
5. **If you don't set up Firebase** — your CI/CD pipeline still works fine, it just won't upload to Firebase (the step is skipped automatically)
6. **Your `FIREBASE_TOKEN` secret is sensitive** — treat it like a password. Never commit it to git. Never share it.

---

## What you need to do (checklist)

- [ ] Create Firebase project (Step 1)
- [ ] Register Android app with package name `com.microflow.pro` (Step 2)
- [ ] Save the Firebase App ID (Step 3)
- [ ] Create tester group `qa-internal` with your email (Step 4)
- [ ] Generate service account JSON key (Step 5)
- [ ] Encode key to base64 (Step 6)
- [ ] Add all three secrets to GitHub (Step 7)
- [ ] Test by tagging a release (Step 9)
- [ ] Confirm email notification received

---

*Guide created for MicroFlow Pro project. Last updated: June 29, 2026*
