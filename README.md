# MealRescue — Rescue Food. Share Hope.

MealRescue is an Android app for coordinating surplus food donations. Food
providers publish available portions and pickup deadlines; receivers find
listings, request portions, and confirm collection. The app tracks completed
handoffs so users can see the food redistributed through the platform.

## How it works

1. A provider creates and publishes a food listing with its quantity, category,
   preparation time, pickup deadline, address, and optional food photo.
2. A receiver browses listings, checks the food and pickup details, and requests
   a number of portions.
3. The provider accepts or rejects the request. The app updates listing and
   reservation quantities together.
4. The receiver confirms collection, then the provider confirms the handover.
   Completed portions contribute to impact statistics.

## Features

- Email and password registration, sign-in, and password reset.
- Provider and receiver roles, with role-specific dashboards and navigation.
- Create, edit, publish, and withdraw food listings.
- Browse, search, filter, and sort available listings.
- Reserve portions, accept or reject requests, and manage pickup deadlines.
- Two-party pickup completion and donation history.
- Impact summaries based on completed records.
- Report unsafe or misleading listings and review reports in the admin screen.
- Optional push notifications for reservation events through Firebase Cloud
  Functions.
- Optional food photos compressed on the device and stored in the Firestore
  listing document. Firebase Storage is not used for these photos.

## Technology

- Flutter and Dart (Android app; package name `com.mealrescue.app`).
- Firebase Authentication for email and password accounts.
- Cloud Firestore for profiles, donations, reservations, and reports.
- Provider for app state and Firebase Messaging for optional notifications.
- Firebase Cloud Functions in `functions/` for optional reservation notices.

## Requirements

- Flutter SDK with Dart 3.3 or later.
- Android Studio and an Android emulator or device.
- A Firebase project with Email/Password Authentication and Cloud Firestore
  enabled.
- Firebase CLI and FlutterFire CLI for Firebase setup and deployment.
- Node.js 20 for the optional Cloud Functions and demo account seeder.

## Configure and run

1. Install Flutter dependencies:

   ```sh
   flutter pub get
   ```

2. Create or select a Firebase project. In the Firebase console, enable
   **Authentication → Email/Password** and create a **Cloud Firestore**
   database. The Android application ID is `com.mealrescue.app`.

3. Configure this app for your Firebase project. This generates the platform
   options used by `lib/firebase_options.dart`:

   ```sh
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android --android-package-name=com.mealrescue.app
   ```

4. Install and sign in to the Firebase CLI, select the same project, and deploy
   the Firestore rules and indexes:

   ```sh
   npm install -g firebase-tools
   firebase login
   firebase use --add
   firebase deploy --only firestore:rules,firestore:indexes
   ```

   Deploy the rules before using the app. They enforce signed-in access,
   ownership, allowed role and status changes, and quantity bounds.

5. Start the app on a connected Android device or emulator:

   ```sh
   flutter run
   ```

`lib/firebase_options.dart` currently contains Firebase project options. Run
`flutterfire configure` when connecting the app to a different project. Never
commit Firebase service account keys or other private credentials.

## Demo data

Providers can load sample listings from the provider dashboard’s menu. To seed
demo accounts, create a Firebase service account with appropriate Auth and
Firestore access, then run the seeder. Keep the downloaded service account key
outside the repository.

PowerShell:

```powershell
npm install --prefix tool --no-save --package-lock=false firebase-admin
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
$env:DEMO_PASSWORD = "choose-a-demo-password"
node tool/seed_demo_users.js
```

Bash:

```sh
npm install --prefix tool --no-save --package-lock=false firebase-admin
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
export DEMO_PASSWORD="choose-a-demo-password"
node tool/seed_demo_users.js
```

The script creates two provider accounts, two receiver accounts, and one admin
account using the password supplied through `DEMO_PASSWORD`. It does not reset
passwords for accounts that already exist. Admin privileges should only be
assigned to trusted accounts.

## Optional push notifications

The handlers in `functions/index.js` send notices for reservation requests,
status changes, and receiver collection confirmation. Firestore remains the
source of truth; notifications are informational. Deploying Cloud Functions
requires a Firebase project on the Blaze plan.

```sh
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Reservation and quantity rules

Listings track pending, accepted, and completed portions separately. A new
request is limited to the portions that are not already pending, reserved, or
completed. Reservation operations use Firestore transactions so a concurrent
request cannot allocate the same remaining portions twice.

The receiver first confirms collection; the provider then confirms handover.
Impact totals are derived from completed portions rather than manually edited
counters. Listings past their pickup deadline cannot accept new reservations.

## Project layout

```text
lib/
  core/         shared constants, theme, utilities, and widgets
  models/       user, donation, reservation, report, and impact data
  providers/    authentication, listings, reservations, moderation, navigation
  screens/      authentication, dashboards, donations, reservations, impact,
                profile, and admin UI
  services/     Firebase-backed authentication and data operations
functions/     optional Cloud Functions for notifications
tool/           demo account seeder
test/           Dart unit tests
firestore.rules Firestore access and validation rules
```

## Tests and build

Run the Dart/Flutter unit tests with:

```sh
flutter test
```

Build a release APK with:

```sh
flutter build apk --release
```

The Android release configuration uses the debug signing key for evaluation.
Create and configure a release keystore before distributing a production app.

## Safety and production notes

- Food safety depends on providers supplying accurate handling, allergen, and
  pickup information. The app does not independently certify food as safe.
- Firestore rules protect ownership and validate status transitions and
  inventory bounds. For a production deployment, move sensitive inventory
  mutations into trusted backend code and disallow direct client counter edits.
- The included `storage.rules` file is not referenced by the current
  `firebase.json`; the app stores compressed photos in Firestore instead.
- Review Firebase billing, rules, privacy, and account verification before
  using the app with real organizations or personal data.
