# Mile One — Claude Context

## What This Is

A native iOS C25K running coach app. 9 weeks, 3 sessions/week, 27 total sessions. The user follows structured walk/run intervals with GPS tracking, audio coaching, route planning, and HealthKit integration.

## Tech Stack

- **Swift 6** with strict concurrency (`StrictConcurrency` experimental feature enabled)
- **SwiftUI** — all views
- **SwiftData + CloudKit** — persistence
- **CoreLocation** (background) — GPS
- **HealthKit** — biometrics + workout sync
- **AVSpeechSynthesizer** — audio coach
- **MapKit** — route display + planning
- **iOS 17+ minimum** — use APIs available on iOS 17; no backporting hacks

## Project Layout

```
Sources/MileOne/
  App/            — App entry point
  Models/         — SwiftData models (UserProfile, CompletedRun, GPSPoint, SavedRoute)
    Snapshots/    — Sendable value-type snapshots for crossing actor boundaries
  Services/       — Business logic (DataStore, RunEngine, RunCheckpoint, NotificationService, etc.)
    Protocols/    — Protocol definitions (DataStoreProviding, LocationProviding, etc.)
  ViewModels/     — @Observable @MainActor classes (one per screen)
  Views/          — SwiftUI views
  Utilities/      — PaceFormatter, DateHelpers, CalorieCalculator, etc.

Tests/MileOneTests/
  Integration/    — End-to-end flows using real DataStore + in-memory ModelContainer
  Mocks/          — MockDataStore, MockLocationProvider, MockTimeProvider, etc.
  Services/       — Unit tests for RunEngine, RunCheckpoint, NotificationService, etc.
  ViewModels/     — Unit tests for each ViewModel (uses MockDataStore)
  Utilities/      — Unit tests for pure utility functions
```

## Architecture Rules

- **Strict actor isolation everywhere.** No `@unchecked Sendable` without a comment explaining why.
- **ViewModels are `@MainActor @Observable`.** Never use `ObservableObject`/`@Published`.
- **SwiftData models never cross actor boundaries raw.** Always convert to a `*Snapshot` (Sendable value type) before returning from an actor context.
- **Protocol-first services.** Every service the app depends on has a `*Providing` or `*Coaching` protocol in `Services/Protocols/`. Mocks live in `Tests/MileOneTests/Mocks/`.
- **UserDefaults injection.** Any code that touches UserDefaults (e.g. `RunCheckpoint`) must accept an injectable `UserDefaults` store for testability. Default to `.standard`.

## Running Tests

```bash
swift test
```

Tests run on macOS (the package declares `.macOS(.v14)` for this reason). Xcode is not required for tests. All 195 tests should pass. If you add new tests, run `swift test` before finishing and make sure the count goes up, not sideways.

## Key Domain Concepts

- **SessionDefinition** — a single C25K session (week + dayInWeek + array of Intervals)
- **Interval** — a single timed block: `.warmUp`, `.run`, `.walk`, or `.coolDown`
- **RunEngine** — the core timer. Driven by GPS timestamps (not wall-clock timers) for interval advancement. Supports pause/resume, skip, and checkpoint persistence every 60s.
- **RunCheckpoint** — crash recovery. Saved to UserDefaults during a run; cleared on clean completion. `isValid` expires after 2 hours.
- **PostRunOrchestrator** — saves a completed run to SwiftData + HealthKit atomically.
- **DataStore** — single source of truth for UserProfile and run history. All mutation goes through here.
- **UserProfileSnapshot** — Sendable copy of UserProfile with all fields; used in ViewModels and tests.

## Week / Graduation Logic

- `currentWeek` is 1–9. `completedSessionsThisWeek` is 0–3.
- `advanceWeek()` bumps the week and resets session count. At week 9 with 3 sessions, it sets `hasGraduated = true` instead of advancing further.
- `canAdvanceWeek` is true when `completedSessionsThisWeek >= 3 && !hasGraduated`.

## Testing Conventions

- Use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest.
- Tests that touch SwiftData use an **in-memory ModelContainer**:
  ```swift
  ModelConfiguration(isStoredInMemoryOnly: true)
  ModelContainer(for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self, configurations: config)
  ```
- Tests that touch UserDefaults use a **named suite** (not `.standard`), cleared at the top of each test.
- `MockDataStore` is an `actor`. Mutate its properties only via its setter methods (e.g. `setShouldThrowOnFetch(true)`) — not direct property access from `@MainActor` test bodies.
- `@MainActor` ViewModels under test: annotate the test struct with `@MainActor` or use `await MainActor.run { }`.
- Avoid `Task.sleep` / `Date()` in tests. Inject time via `MockTimeProvider` and advance `time.currentTime` manually.

## What NOT to Do

- Don't use `UserDefaults.standard` directly in production code without an injectable override — it breaks tests.
- Don't put SwiftData model instances in `@State` or pass them across actor boundaries — use Snapshots.
- Don't add `import XCTest` to new test files — this codebase uses Swift Testing exclusively.
- Don't skip `swift test` before wrapping up a task.
- Don't edit the master weekly update Google Doc via Docs API (unrelated, but: don't).
