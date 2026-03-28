# Closet Buddy

Final Year Project repository with:

- `backend/` Django API + AI model integration
- `frontend/` Flutter client

## Repository Layout

- `backend/ai_models` model-related logic
- `backend/api` backend API app
- `frontend/lib/app` app bootstrap/composition
- `frontend/lib/core` DI + config infrastructure
- `frontend/lib/features` feature-first barrel modules
- `frontend/lib/services` API/data services
- `frontend/lib/widgets` reusable widgets
- `frontend/lib/theme` design tokens and themes

## Frontend Quick Start

```bash
cd frontend
flutter pub get
flutter run
```

## Quality Checks (Frontend)

```bash
cd frontend
dart analyze lib
flutter test
flutter test test/theme/theme_color_guardrails_test.dart
```
