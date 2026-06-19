# flutter_application

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build Android Package (APK)

Run these commands from the project root:

```powershell
cd c:\codebase\flutter-app\flutter_application
flutter clean
flutter pub get
```

Build a release APK:

```powershell
flutter build apk --release
```

Output location:

- `build/app/outputs/flutter-apk/app-release.apk`

Build split APKs by ABI (optional):

```powershell
flutter build apk --split-per-abi
```

Output location:

- `build/app/outputs/flutter-apk/`

Build Android App Bundle for Play Store (recommended for publishing):

```powershell
flutter build appbundle --release
```

Output location:

- `build/app/outputs/bundle/release/app-release.aab`
