# Closet Buddy Frontend

Flutter client for Closet Buddy.

## Run

```bash
flutter pub get
flutter run
```

Optional API host override:

```bash
flutter run --dart-define=API_HOST=http://127.0.0.1:8000
```

## Quality Checks

```bash
dart analyze lib
flutter test
flutter test test/theme/theme_color_guardrails_test.dart
```

## Project Structure

- `lib/app` app shell + auth gate
- `lib/core` cross-cutting infrastructure (DI/service registry)
- `lib/features` domain modules (`<domain>/screens` + barrel exports)
- `lib/services` API/data layer
- `lib/widgets` reusable UI components
- `lib/theme` theme + tokens + color system
- `lib/utils` pure utility helpers

## Architecture Guide

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for layer rules and extension
guidelines.
