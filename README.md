# LajfApp

A personal organisation app that brings budgeting, daily planning, university deadlines and groceries into one place. Built with Flutter and Dart, with an Android app and local data storage.

I built LajfApp to organise my own day-to-day life. It connects related workflows: a food expense can become an entry in the groceries inventory, and buying an item from the shopping list can open a prefilled budget transaction.

## Features

- **Today dashboard:** a daily overview with shortcuts to budget, planner and university tasks.
- **Budget:** income and expenses, custom spending categories, monthly recurring expenses, balance carryover, and monthly and yearly spending summaries with charts.
- **Planner and university tasks:** separate task lists, one-time and repeating tasks, configurable reminder offsets, postponement, completion history and calendar views.
- **Groceries:** a home inventory grouped by storage category, quantities, purchase and expiry dates, comments, and a separate shopping list.
- **Gym planner:** planned and completed training days in a calendar.
- **Android reminders:** timezone-aware local notifications for tasks and deadlines.
- **Card vault prototype:** a separate screen for card names, PINs and comments, stored through the platform secure-storage plugin.
- **Dark interface:** Material 3 styling across the app.

## Built with

| Area | Implementation |
| --- | --- |
| Interface | Flutter, Dart and Material 3 |
| State and updates | `StatefulWidget`, `ChangeNotifier` and `AnimatedBuilder` |
| Local persistence | JSON files via `dart:io` and `path_provider` |
| Reminders | `flutter_local_notifications`, `timezone` and `flutter_timezone` |
| Vault storage | `flutter_secure_storage`; `cryptography` for PBKDF2 password verification |
| Android integration | Kotlin platform channel for the private screen |
| Tests | `flutter_test` unit and widget tests |

The core data is stored on the device. There is no account system, backend service or cloud synchronisation in the current implementation.

## Run locally

### Requirements

- Flutter with Dart **3.13.3 or a compatible later 3.x version**, matching `pubspec.yaml`. The local SDK used for this project is Flutter **3.47.3** with Dart **3.13.3**.
- An Android SDK installation with Android API **36**, JDK **17**, and a connected Android device or emulator.
- Flutter available on your `PATH`.

From the project directory:

```sh
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with the ID reported by `flutter devices`. Grant notification permission when prompted. Reminder timing also depends on the device's exact-alarm permission and background restrictions.

Android is the platform currently included in this repository. The app is not configured as a web, desktop or iOS target.

## Development checks

```sh
flutter analyze
flutter test
```

The existing tests cover local storage, budget carryover, recurring expenses, repeating task history, groceries, shopping-list flows and selected phone-sized interface interactions.

To build an APK for local testing:

```sh
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Project structure

```text
lib/
  main.dart           App theme, navigation, dashboard and module integration
  life_data.dart      Budget, task and gym models, persistence and recurrence
  budget.dart         Transactions, categories and spending summaries
  planner.dart        Tasks, university reminders, calendars and gym planner
  groceries.dart      Home inventory, shopping list and local storage
  notifications.dart Android notification scheduling
  vault.dart          Card-vault interface and secure-storage integration
android/              Android project and native integration
assets/               App icon source
test/                 Unit and widget tests
tool/                 Icon generation utility
```

## Current scope

LajfApp is a personal project. Budget, planner and grocery data are stored as local JSON files, without app-level encryption or cloud backup.

The card vault is a prototype, not a production password manager. Tap the Budget tab five times within 1.5 seconds to open it. On a fresh installation, choose and confirm a password of at least 12 characters. There is no bundled password or password recovery. A random 32-byte salt and a PBKDF2-HMAC-SHA256 verifier (600,000 iterations) are stored in platform secure storage, separately from the card entries. Derivation runs off the UI thread. The password is an access gate; it does not encrypt the cards independently of platform secure storage. Three failed attempts trigger a 30-second delay within the current app session, and backgrounding closes the private screen.

Existing card entries from the older fixed-password version are preserved and blocked from first-run password setup. Migrate them using the original app before using this version; an automatic migration/reset flow is not implemented. No real financial data or personal credentials belong in this repository or its screenshots.

The release build configuration currently uses debug signing. A distribution build needs its own application ID and release-signing setup.

## Author

**Miloš Žižić** · [GitHub](https://github.com/Milos12-XD)
