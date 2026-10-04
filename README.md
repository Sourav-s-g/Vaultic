# Vaultic

Vaultic is a Flutter personal-finance app with a separate Next.js web application in `web-app/`. The Flutter application and its root `web/` platform target remain separate from the Vercel deployment.

## Vaultic Web

The web application uses Next.js App Router, strict TypeScript, Supabase SSR clients, TanStack Query, and Tailwind CSS. Its Vercel root is `web-app/`. Email/password authentication and recovery are implemented; finance data features are delivered in later phases.

Run the web application from its own directory:

```sh
cd web-app
npm ci
npm run dev
```

Copy `web-app/.env.example` to an untracked local environment file and provide the Supabase URL and public anon key before using Supabase-backed features. Never add service-role credentials or a production origin to source control. For Vercel setup and password-reset redirect configuration, follow [docs/DEPLOY.md](docs/DEPLOY.md).

The web CI workflow runs in `web-app/`; its available quality checks are `npm run lint`, `npm run typecheck`, and `npm run build`. `/api/health` returns a status-only response for deployment checks.

---

Vaultic is a Flutter application scaffold. This README is a comprehensive, ready-to-use guide to help you develop, run, test, build, and ship the app. It includes recommended workflows, configuration tips, troubleshooting, and sections you can customize for your project's needs.

> NOTE: Replace placeholder sections (marked with **TODO**) with project-specific details (screenshots, feature list, API keys, design decisions).

---

## Table of contents

- [Project overview](#project-overview)
- [Screenshots](#screenshots)
- [Features](#features)
- [Tech stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
  - [Clone repository](#clone-repository)
  - [Install dependencies](#install-dependencies)
  - [Configure environment and secrets](#configure-environment-and-secrets)
  - [Run on device / emulator](#run-on-device--emulator)
- [Building & releasing](#building--releasing)
  - [Android release build](#android-release-build)
  - [iOS release build](#ios-release-build)
  - [Web build](#web-build)
  - [Desktop builds](#desktop-builds)
- [Testing](#testing)
- [Linting & formatting](#linting--formatting)
- [CI / CD recommendations](#ci--cd-recommendations)
- [Architecture & code organization](#architecture--code-organization)
- [State management suggestions](#state-management-suggestions)
- [Localization & accessibility](#localization--accessibility)
- [Working with assets](#working-with-assets)
- [Common tasks and commands](#common-tasks-and-commands)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Contributing](#contributing)
- [Security & privacy](#security--privacy)
- [License](#license)
- [Contact / Authors](#contact--authors)

---

## Project overview

Vaultic is a Flutter project scaffold. Use this README as the canonical developer and contributor guide while building the application. Vaultic's purpose and behavior should be documented here and in the in-repo docs.

TODO: Add a short elevator pitch describing what Vaultic does (example: "Vaultic is a secure personal vault for passwords and confidential notes").

## Screenshots

Include screenshots and GIFs here to show the app UI and key flows.

- Desktop / Mobile screenshot - TODO: add images in `assets/docs/` and reference them below:

```markdown
![Home screen](assets/docs/screenshot-home.png)
![Create item](assets/docs/screenshot-create.png)
```

---

## Features

List the app's features. Example:

- Encrypted storage for secrets (local device encryption)
- Create, edit, and delete vault entries
- Biometric unlock (Face ID / Touch ID) and PIN support
- Sync to cloud (optional) — TODO: document provider
- Search and tagging
- Secure export/import

Customize this list to reflect your app's current and planned features.

---

## Tech stack

- Flutter (specify version below)
- Dart
- State management: (Provider / Riverpod / Bloc / GetX) — specify which you use
- Local storage: (sqflite / hive / sembast / flutter_secure_storage) — specify which packages you use
- CI: GitHub Actions (recommended)

---

## Prerequisites

Ensure the following are installed and configured before running Vaultic locally:

- Flutter SDK 3.0.0 or later (run `flutter --version`).
- For Android builds: Android SDK, Android Studio, configured ANDROID_HOME.
- For iOS builds: Xcode (macOS only), CocoaPods (`gem install cocoapods`).
- For Web builds: Chrome or Edge for local testing.
- Optional: Java JDK for Android builds.

Minimum supported versions (example):

- Flutter: >=3.0.0
- Dart: as required by Flutter stable channel

Run `flutter doctor` and resolve any issues before continuing.

---

## Getting started

Follow these steps to get a development environment running.

### Clone repository

```bash
git clone https://github.com/Sourav-s-g/Vaultic.git
cd Vaultic
```

### Install dependencies

From the project root:

```bash
flutter pub get
```

If your project contains native plugins, ensure platform tooling is installed and run:

```bash
flutter pub get
cd ios && pod install && cd ..
```

### Configure environment and secrets

If your app requires environment variables or API keys, keep them out of version control and use a local file or CI secrets.

Example `.env` (do not commit):

```
# .env
API_BASE_URL=https://api.example.com
GOOGLE_MAPS_API_KEY=your_key_here
SENTRY_DSN=your_sentry_dsn
```

Add `.env` to `.gitignore` and load values using a package such as `flutter_dotenv`.

### Run on device / emulator

- Run on mobile emulator or connected device:

```bash
flutter run
```

- Run on a specific device or emulator:

```bash
flutter devices        # list devices
flutter run -d <id>
```

- Run on web (Chrome):

```bash
flutter run -d chrome
```

- Run on Windows/macOS/Linux desktop (if enabled and configured):

```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

---

## Building & releasing

### Android release build

1. Generate a signing key (if you do not already have one):

```bash
keytool -genkey -v -keystore ~/vaultic-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vaultic
```

2. Reference the keystore in `android/key.properties` (do NOT commit this file):

```
storePassword=<store-password>
keyPassword=<key-password>
keyAlias=vaultic
storeFile=/path/to/vaultic-release-key.jks
```

3. Build the release APK / AAB:

```bash
flutter build apk --release
flutter build appbundle --release
```

4. Test the release build on a device before publishing to Play Store.

### iOS release build (macOS required)

1. Open the `ios` workspace in Xcode:

```bash
open ios/Runner.xcworkspace
```

2. Configure signing & capabilities in the Runner target and associated provisioning profiles.

3. Build and archive the app using Xcode to create an IPA for TestFlight / App Store.

Alternatively, use `flutter build ipa --release` (Xcode 14+ and proper signing config required).

### Web build

```bash
flutter build web --release
```

Deploy the `build/web` directory to your static host (Firebase Hosting, Netlify, GitHub Pages, etc.).

### Desktop builds

Follow Flutter desktop build docs for macOS, Windows, and Linux. Example:

```bash
flutter build windows --release
```

---

## Testing

Write and run unit, widget, and integration tests.

- Run unit & widget tests:

```bash
flutter test
```

- Run integration tests (example using `integration_test` package):

```bash
flutter test integration_test
```

- Use `flutter drive` with a compatible driver for older integration tests.

Automate tests in CI for every PR.

---

## Linting & formatting

- Format code:

```bash
flutter format .
```

- Analyze code:

```bash
flutter analyze
```

- Use `analysis_options.yaml` to enforce project lint rules. Example rules: `package:pedantic` or `package:lint` or `package:effective_dart`.

---

## CI / CD recommendations

- Use GitHub Actions to run tests on each PR and build artifacts on merge to `main`/`master`.
- Example workflow steps:
  - Checkout
  - Setup Flutter (use official action)
  - Install dependencies and run `flutter pub get`
  - Run `flutter analyze` and `flutter test`
  - Build artifacts for distribution

- Store keystore files and signing credentials in CI secrets and use them only at build time.

---

## Architecture & code organization

This section should describe how the app is organized and where major concerns live. Example layout (customize to match your code):

```
/lib
  /src
    /app.dart           # App entry / routing
    /models             # Data models
    /services           # API, encryption, storage services
    /providers          # State providers (Riverpod/Provider)
    /screens            # UI screens
    /widgets            # Reusable widgets
    /utils              # Utility helpers
    /l10n               # Localization resources
/assets
  /icons
  /images
  /docs
/ios
/android
```

Describe your main design decisions here (e.g., separation of concerns, services for persistence, dependency injection approach).

---

## State management suggestions

Pick one technique and document it here. Common choices:

- Provider (simple, lightweight)
- Riverpod (recommended for testability and flexibility)
- BLoC (for event-driven complex logic)
- GetX (simple with additional features)

Include examples on how you expect screens/services to interact with app state and how to mock dependencies in tests.

---

## Localization & accessibility

- Use Flutter's `intl` or `flutter_localizations` and ARB files for localization.
- Provide instructions to generate localization delegates and messages if used (e.g., `flutter pub run intl_utils:generate`).
- Test accessibility: ensure widgets are labeled, support large fonts, and are navigable by screen readers.

---

## Working with assets

- Place images, icons, and docs under `/assets` and register them in `pubspec.yaml`.

Example:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/docs/
```

Optimize images for mobile and keep vector assets in SVG (use `flutter_svg` to render).

---

## Common tasks and commands

- Clean build files: `flutter clean`
- Upgrade dependencies: `flutter pub upgrade --major-versions`
- Generate code (if using build_runner): `flutter pub run build_runner build --delete-conflicting-outputs`
- Show dependencies graph: `flutter pub deps`

---

## Troubleshooting & FAQ

Q: `pod install` failing on iOS?
A: Ensure CocoaPods is installed and run `pod repo update` or `arch -x86_64 pod install` on Apple Silicon if needed.

Q: App crashes on launch in release mode?
A: Enable crash reporting (Sentry) or run symbolicated build. Check ProGuard/R8 rules if using obfuscation.

Q: `flutter run` shows multiple devices or emulator not starting?
A: Run `flutter devices` to list devices and pass `-d <deviceId>` to target explicitly.

Include frequently seen issues and platform-specific workarounds here.

---

## Contributing

We welcome contributions. Please follow these steps:

1. Fork the repository.
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit changes with clear messages.
4. Run tests and linters locally.
5. Push and open a Pull Request explaining the change.

Include a `CONTRIBUTING.md` in the repo for long-form contributor guidance and add a `CODE_OF_CONDUCT.md`.

---

## Security & privacy

- Never commit API keys, keystore passwords, or other secrets to the repository.
- Use `flutter_secure_storage` (or platform equivalent) for sensitive values.
- Prefer end-to-end encryption for user data and document how encryption keys are derived, stored, and rotated.

If your app handles PII or sensitive data, include a privacy policy and compliance guidance (GDPR, CCPA) in this repo or documentation.

---

## License

TODO: Add a license for the project. Example: MIT

```
MIT License

Copyright (c) 2026 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
...
```

Replace with a complete license file and include `LICENSE` at repo root.

---

## Contact / Authors

- Maintainer: Sourav-s-g (https://github.com/Sourav-s-g)
- Project lead: TODO: add name and contact info

---

Thank you for using Vaultic. If you'd like, I can:

- Add a short project description and elevator pitch if you tell me what Vaultic does.
- Insert screenshots if you upload image files to `assets/docs/`.
- Add a sample GitHub Actions workflow for CI.
- Scaffold `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`.

