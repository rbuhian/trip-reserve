# Trip Reserve

A car booking application for trip reservations in the Philippines. Built with Flutter and Supabase.

## Tech Stack

- **Frontend:** Flutter 3.x with Material 3
- **Backend:** Supabase (PostgreSQL + Auth + Realtime)
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Maps:** Google Maps API
- **Payments:** PayMongo/Xendit (planned)

## Prerequisites

- Flutter SDK >= 3.2.0
- Dart SDK >= 3.2.0
- Supabase CLI (for local development)
- Docker (for Supabase local)
- Android Studio / Xcode (for mobile development)
- Google Maps API key

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd trip-reserve
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Generate Code

Run build_runner to generate Freezed models and Riverpod code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Environment Setup

Create a `.env` file in the project root (copy from `.env.example` if available):

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

Update `lib/core/app_config.dart` with your configuration values.

## Supabase Setup

### Option A: Supabase Cloud

1. Create a project at [supabase.com](https://supabase.com)
2. Go to Project Settings > API to get your URL and anon key
3. Run the migrations in order:

```bash
# In Supabase SQL Editor, run these files in order:
supabase/migrations/00001_core_tables.sql
supabase/migrations/00002_supporting_tables.sql
supabase/migrations/00003_rls_policies.sql
supabase/migrations/00004_indexes_triggers.sql
supabase/seed.sql
```

### Option B: Supabase Local (Recommended for Development)

1. Install Supabase CLI:

```bash
# macOS
brew install supabase/tap/supabase

# Windows (scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# npm
npm install -g supabase
```

2. Start Supabase locally:

```bash
supabase init  # if not already initialized
supabase start
```

3. Apply migrations:

```bash
supabase db reset  # Applies all migrations and seed data
```

4. Get local credentials:

```bash
supabase status
```

Use the `API URL` and `anon key` from the output.

## Running the App

### Android

```bash
flutter run -d android
```

### iOS

```bash
flutter run -d ios
```

### Web (for testing)

```bash
flutter run -d chrome
```

### All Devices

```bash
flutter devices  # List available devices
flutter run -d <device_id>
```

## Testing

### Run All Tests

```bash
flutter test
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### Run Specific Test File

```bash
flutter test test/path/to/test_file.dart
```

### Widget Tests

```bash
flutter test test/widgets/
```

### Integration Tests

```bash
flutter test integration_test/
```

## Building for Production

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
flutter build ios --release
```

Then archive and upload via Xcode.

### Web

```bash
flutter build web --release
```

Output: `build/web/`

## Deployment

### Android (Play Store)

1. Configure signing in `android/app/build.gradle`
2. Create `android/key.properties` with your keystore info:
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=<alias>
   storeFile=<path-to-keystore>
   ```
3. Build the app bundle:
   ```bash
   flutter build appbundle --release
   ```
4. Upload to Google Play Console

### iOS (App Store)

1. Configure signing in Xcode
2. Set up App Store Connect
3. Build and archive:
   ```bash
   flutter build ios --release
   ```
4. Open Xcode, archive, and upload to App Store Connect

### Web (Firebase Hosting)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and init
firebase login
firebase init hosting

# Build and deploy
flutter build web --release
firebase deploy --only hosting
```

### Web (Vercel)

```bash
# Build
flutter build web --release

# Deploy (from build/web directory)
cd build/web
vercel
```

## Database Migrations

### Create New Migration

```bash
supabase migration new <migration_name>
```

### Apply Migrations

```bash
# Local
supabase db reset

# Production (via Supabase Dashboard or CLI)
supabase db push
```

### View Migration Status

```bash
supabase migration list
```

## Project Structure

```
lib/
├── core/           # App config, theme, router
├── models/         # Data models (Freezed)
├── providers/      # Riverpod providers
├── repositories/   # Data access layer
├── screens/        # UI screens
│   ├── auth/       # Login, Register
│   ├── customer/   # Customer features
│   ├── driver/     # Driver features
│   └── admin/      # Admin features
├── services/       # Business logic services
└── widgets/        # Reusable widgets

supabase/
├── migrations/     # Database migrations
└── seed.sql        # Seed data

test/
├── unit/           # Unit tests
├── widgets/        # Widget tests
└── integration/    # Integration tests
```

## User Roles

| Role | Description |
|------|-------------|
| `customer` | Books trips, views history, makes payments |
| `driver` | Manages vehicles, accepts bookings, tracks earnings |
| `admin` | Manages users, bookings, pricing, reports |

## Test Accounts

After running seed data:

| Email | Password | Role |
|-------|----------|------|
| customer@test.com | test123 | customer |
| driver@test.com | test123 | driver |
| admin@test.com | test123 | admin |

Note: Create these accounts manually via Supabase Auth or the registration screen.

## Troubleshooting

### Build Issues

```bash
# Clean and rebuild
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Supabase Connection Issues

1. Verify your Supabase URL and anon key
2. Check if RLS policies are correctly applied
3. Verify your network connection
4. Check Supabase project status

### iOS Simulator Issues

```bash
# Reset simulator
xcrun simctl erase all
```

### Android Emulator Issues

```bash
# Cold boot
flutter emulators --launch <emulator_id> --cold-boot
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests: `flutter test`
4. Run analyzer: `flutter analyze`
5. Submit a pull request

## License

Private - All rights reserved
