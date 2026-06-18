# Firebase Setup Guide

To compile and run the app, you need to set up Firebase:

## Step 1: Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click **Create a project** (or select existing)
3. Name it something like "Adorsho Nibash"
4. Disable Google Analytics (optional)

## Step 2: Register Android App

1. In Firebase Console, click the **Android** icon to add an Android app
2. Package name: `com.adorsho_nibash.app`
3. App nickname: Adorsho Nibash (Mazumder)
4. Click **Register app**

## Step 3: Download google-services.json

1. Click **Download google-services.json**
2. Place the file at: `android/app/google-services.json`

## Step 4: Enable Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** provider
3. Create your account (email + password)

## Step 5: Enable Firestore

1. Go to **Cloud Firestore** > **Create database**
2. Choose **Start in test mode** (for development)
3. Select a region close to Bangladesh (e.g., `asia-southeast1`)

## Step 6: Enable Developer Mode (Windows)

Flutter needs symlink support for plugins:

1. Open Windows **Settings** > **Update & Security** > **For developers**
2. Select **Developer mode**
3. Or run in PowerShell as Admin:
   ```powershell
   reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
   ```

## Step 7: Build & Run

```bash
cd adorsho_nibash_app
flutter clean
flutter pub get
flutter run
```

## Troubleshooting

- **Firebase not found**: Ensure `google-services.json` is in `android/app/`
- **Java errors**: JAVA_HOME is set to `D:\jdk-17\jdk-17.0.14+7`
- **Symlink errors**: Enable Developer Mode
