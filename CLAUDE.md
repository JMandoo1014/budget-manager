# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (connect a device or simulator first)
flutter run

# Run on a specific device
flutter run -d <device-id>          # e.g. -d ios, -d android, -d chrome
flutter devices                     # list available devices

# Build
flutter build apk                   # Android APK
flutter build ios                   # iOS (requires macOS + Xcode)

# Test
flutter test                        # run all tests
flutter test test/widget_test.dart  # run a single test file

# Lint / static analysis
flutter analyze

# Upgrade dependencies
flutter pub upgrade
```

## Project State

This project is a bare Flutter scaffold (`lib/main.dart` is the default counter demo). The budget manager features have not yet been implemented. The app entry point is `lib/main.dart` → `MyApp` → `MyHomePage`.

## Tech Stack

- **Flutter** (Dart SDK ^3.11.0) with Material Design
- **flutter_lints** for static analysis (configured in `analysis_options.yaml`)
- No state management library, routing package, or persistence layer added yet

## Conventions

- Lint rules from `package:flutter_lints/flutter.yaml` are active. Run `flutter analyze` before committing.
- Target platforms: iOS and Android (both configured under `ios/` and `android/`).
