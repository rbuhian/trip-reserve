# Firebase & FCM Setup Guide

This document describes the manual steps required to enable Firebase Cloud Messaging (FCM) push notifications in Trip Reserve.

## Prerequisites

- Firebase account at https://console.firebase.google.com

- **Firebase CLI** — required by FlutterFire CLI. Install via npm:
  ```
  npm install -g firebase-tools
  ```
  If you don't have Node.js/npm, download it first from https://nodejs.org (LTS version).

  After installing, log in:
  ```
  firebase login
  ```

- **FlutterFire CLI** — install with:
  ```
  dart pub global activate flutterfire_cli
  ```
  After installing, if `flutterfire` is not recognized, add the Dart pub global bin to your PATH:
  - Windows: `C:\Users\<YourUsername>\AppData\Local\Pub\Cache\bin`
  - Restart your terminal after adding it

  Or run it directly without PATH changes:
  ```
  dart pub global run flutterfire_cli:flutterfire configure
  ```

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project** → name it `trip-reserve`
3. Disable Google Analytics (optional)
4. Click **Create project**

## Step 2: Add Android App

1. In Firebase console, click **Add app** → Android
2. Package name: `com.example.trip_reserve`  
   _(or your actual package name from `android/app/build.gradle.kts`)_
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

## Step 3: Add iOS App

1. In Firebase console, click **Add app** → Apple
2. Bundle ID: find it in `ios/Runner.xcodeproj` → General tab
3. Download `GoogleService-Info.plist`
4. Place it at: `ios/Runner/GoogleService-Info.plist`

## Step 4: Enable Cloud Messaging

1. In Firebase console → **Cloud Messaging**
2. It is enabled by default for new projects

## Step 5: Generate firebase_options.dart

Run FlutterFire CLI to generate the options file (replaces the stub):

```bash
flutterfire configure --project=your-firebase-project-id
```

This generates `lib/firebase_options.dart` with your project credentials.

## Step 6: Install dependencies

```bash
flutter pub get
```

## Step 7: Verify

Run the app. On login, the FCM token will be saved to the `device_tokens` table in Supabase. Check Supabase Table Editor to confirm.

## Android Additional Setup

For Android 13+ (API 33+), notification permission is requested at runtime by `FCMService` automatically.

FCM background messages work via the `firebaseMessagingBackgroundHandler` top-level function registered in `FCMService`.

## iOS Additional Setup

In Xcode:
1. Select Runner target → **Signing & Capabilities**
2. Click **+** → add **Push Notifications**
3. Click **+** → add **Background Modes** → check **Remote notifications**

## Notes

- The stub `lib/firebase_options.dart` makes the app compile before Firebase is configured.
  Firebase initialization errors are caught and logged — the app works normally without FCM.
- `FCMService.instance.initialize()` is called in `main.dart` only when Firebase initializes successfully.
- `FCMService.instance.deleteToken()` should be called on user logout to clean up tokens.
