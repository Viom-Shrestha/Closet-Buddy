# Frontend Architecture

This Flutter app follows a pragmatic layered structure that keeps behavior the
same while making code easier to navigate and maintain.

## Layer Map

- `lib/app/`
  - App composition root.
  - Contains app shell (`ClosetBuddyApp`) and entry gate (`AuthGate`).
- `lib/core/`
  - Cross-cutting infrastructure.
  - Includes dependency wiring (`ServiceRegistry`) and app config (`AppConfig`).
- `lib/features/`
  - Domain-oriented modules.
  - Each domain owns its own screens under `features/<domain>/screens/` plus a
    domain barrel (`features/<domain>/<domain>.dart`).
- `lib/services/`
  - API/data-access layer.
  - One service per domain area (auth, profile, clothing, storage, etc.).
- `lib/widgets/`
  - Reusable UI building blocks.
- `lib/theme/`
  - Design tokens, palettes, and theme configuration.
  - UI should consume tokens from here, not raw color literals.
- `lib/utils/`
  - Pure helpers and utility rules.

## Dependency Rules

- Feature screens/widgets should get services from `ServiceRegistry` instead of creating
  new service instances in-place.
- Services accept constructor injection (`ApiClient?`) to make testing and
  replacement easier.
- Theme/data tokens stay in `lib/theme`; feature screens/widgets should reference
  semantic tokens only.

## Import Strategy

- Use module barrel files where useful:
  - `lib/app/app.dart`
  - `lib/core/core.dart`
  - `lib/features/features.dart`
  - `lib/services/services.dart`
- Keep imports local and readable; avoid circular dependencies.

## Feature-Folder Migration Strategy

- Prefer importing through `lib/features/<domain>/<domain>.dart` for domain APIs
  and `lib/features/features.dart` for top-level convenience.
- Cross-feature UI imports should target `lib/features/<domain>/screens/...`.
- Keep reusable shared UI in `lib/widgets/`.

## Adding New Features

1. Add/extend service in `lib/services/`.
2. Register service dependency in `ServiceRegistry` if needed.
3. Build UI in `lib/features/<domain>/screens/` and reusable parts in
   `lib/widgets/`.
4. Add/extend tokens in `lib/theme/` for any new styling.
5. Add tests in `test/` and run analyzer + guardrail tests.
