## Quick orientation — gym_tracker_app

This is a small Flutter app (single `lib/main.dart`) that logs workouts to
`SharedPreferences` (key: `workouts`) as a `List<String>` entries like
`"Push-ups: 10 reps, 3 sets"`.

Keep changes focused under `lib/` — platform folders (`android/`, `ios/`,
`web/`, etc.) contain generated or platform-specific build files.

Key files and patterns
- `lib/main.dart` — single-entry Flutter UI. Uses `StatefulWidget` with
  `TextEditingController`s and `_saveWorkout()` which writes to
  `SharedPreferences.getInstance()` → `prefs.setStringList('workouts', ...)`.
- `pubspec.yaml` — standard Flutter deps: `shared_preferences`, `flutter_lints`.
- `test/widget_test.dart` — existing test harness; run with `flutter test`.
- `analysis_options.yaml` — project lint rules (uses `flutter_lints`).

Project-specific guidance for AI agents
- Persistence: follow the current pattern of storing workouts as a `List<String>`
  under the `workouts` key. If you introduce richer models, keep a migration
  note and keep backward-compatibility when reading `prefs.getStringList`.
- UI updates: prefer small, localized widget changes. `WorkoutLogScreen` is the
  main screen and currently manages controllers and validation inline.
- Tests: edit or add tests under `test/`. The repo uses the default
  `flutter_test` setup — run targeted tests with `flutter test test/widget_test.dart`.

Build / run / debug commands (developer environment)
- Fetch deps: `flutter pub get`.
- Run on default device: `flutter run`.
- Run on a specific device: `flutter run -d <device-id>`.
- Run analyzer/lints: `flutter analyze`.
- Run unit/widget tests: `flutter test` or a single file.
- Build APK: `flutter build apk`; iOS/Mac/Windows/Linux follow standard Flutter build commands.

Integration points and cautions
- `shared_preferences` is the only external runtime dependency. Be careful
  when changing storage format (strings → JSON) — include migration code.
- The app is multi-platform (android/ios/web/windows/macos/linux). Avoid
  adding platform-specific APIs unless guarded and documented.

Examples to reference while editing
- To read workouts: `prefs.getStringList('workouts') ?? []` (see `lib/main.dart`).
- To append a workout: read list, `.add(...)`, then `prefs.setStringList('workouts', list)`.

When producing changes
- Keep PRs small and testable. For data-model changes include a quick
  compatibility step (attempt to parse old strings first).
- Run `flutter analyze` and targeted `flutter test` before pushing.

If anything is unclear or you want more depth (data model, CI setup, or
conventions for state management), tell me which area to expand and I will
update this file with concrete examples.
