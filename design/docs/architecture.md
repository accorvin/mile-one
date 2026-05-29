← [Back to Index](README.md)

# Mile One — Architecture, Project Structure & Tech Stack

## 1. Architecture Overview

### Pattern: Services + Observable State + Snapshot DTOs

```
┌─────────────────────────────────────────────────┐
│                   SwiftUI Views                  │
│  (Onboarding, Dashboard, Run, Routes, History)   │
└──────────────────────┬──────────────────────────┘
                       │ observes @Observable ViewModels
┌──────────────────────▼──────────────────────────┐
│         ViewModels (@MainActor, @Observable)      │
│  Hold Snapshot structs for the view layer         │
│  e.g. RunViewModel, DashboardViewModel            │
└──────────────────────┬──────────────────────────┘
                       │ calls / subscribes
┌──────────────────────▼──────────────────────────┐
│           RunEngine (@MainActor, @Observable)     │
│  Orchestrates intervals, coordinates services    │
└──┬──────────┬──────────┬────────────────────────┘
   │          │          │
   ▼          ▼          ▼
┌──────┐ ┌────────┐ ┌────────┐
│Locati│ │Health  │ │Audio   │
│onSvc │ │KitSvc  │ │Coach   │
└──────┘ └────────┘ └────────┘

┌─────────────────────────────────────────────────┐
│         DataStore (@ModelActor)                   │
│  All SwiftData reads/writes; returns Snapshots   │
└──────────────────────┬──────────────────────────┘
              ┌────────▼────────┐
              │   SwiftData     │
              │ ModelContainer  │
              │ + CloudKit sync │
              └─────────────────┘
```

> **No separate CloudSyncService.** SwiftData's built-in CloudKit integration handles sync automatically when the `ModelContainer` is configured with a CloudKit-backed `ModelConfiguration`. There is no custom sync service.

---

### Key Design Decisions

1. **Monotonic timing via `DispatchSourceTimer`, not wall-clock `Date()`**: `RunEngine` uses a monotonic `DispatchSourceTimer` for interval timing. GPS provides *location data* (distance, coordinates, speed), not timing. Wall-clock `Date()` drifts relative to GPS timestamps and shifts during daylight-saving or NTP corrections. The `DispatchSourceTimer` fires on a monotonic clock (`CLOCK_MONOTONIC`) and is not affected by system clock changes. A 1-second `RunLoop.main`-mode timer is used ONLY for UI refresh — never for interval logic.

2. **Background execution via CoreLocation**: The `location` background mode keeps the app alive. GPS callbacks drive distance calculations. No reliance on `RunLoop.main` timers firing in background.

3. **Protocol abstractions for all iOS framework services**: Every service has a protocol (`LocationProviding`, `HealthStoreProviding`, `AudioCoaching`) so tests use mocks, not real hardware.

4. **SwiftData `@ModelActor` for thread safety + Snapshot Pattern**: All database reads/writes go through a dedicated `@ModelActor` (`DataStore`). DataStore returns plain-struct snapshots (DTOs), never `@Model` objects. Views and ViewModels never touch `@Model` directly. See [Snapshot Pattern](#snapshot-pattern) below.

5. **GPS data in separate model**: `GPSPoint` is its own `@Model` with a relationship to `CompletedRun`, not a Data blob. Keeps CloudKit records under the 1MB limit and enables lazy loading.

6. **RunEngine is `@MainActor`**: `RunEngine` is annotated `@MainActor` so all property mutations (from CLLocationManager callbacks, timers, etc.) are dispatched to the main actor. This satisfies Swift 6 strict concurrency and prevents data races with SwiftUI observation.

7. **Dependency injection via SwiftUI `.environment()`**: All services are created in `MileOneApp.swift` and passed down via SwiftUI environment. See [Dependency Injection](#dependency-injection) below.

---

### Snapshot Pattern

DataStore returns **plain-struct DTOs** (snapshots), not `@Model` objects. This prevents cross-actor isolation violations (Swift 6 strict concurrency) and decouples views from the persistence layer.

**Flow:**

```
@Model (SwiftData)
    → DataStore actor (reads @Model, maps to snapshot)
        → Snapshot struct (plain, Sendable)
            → ViewModel (@MainActor, @Observable)
                → SwiftUI View
```

**Example snapshot structs** (canonical definitions in `services.md`):

```swift
// Snapshots are plain Sendable structs — safe to pass across actor boundaries.
// See services.md for the full canonical definitions.

struct UserProfileSnapshot: Sendable {
    let heightCm: Double
    let weightKg: Double
    let birthYear: Int
    let biologicalSex: BiologicalSex
    let currentWeek: Int
    let completedSessionsThisWeek: Int
    let hasCompletedOnboarding: Bool
    let hasGraduated: Bool
    let startingWeek: Int
    let usesMetric: Bool
    let runDays: [Int]
    let reminderHour: Int
    let reminderMinute: Int
    let remindersEnabled: Bool
}

struct CompletedRunSnapshot: Sendable, Identifiable {
    let id: UUID
    let weekNumber: Int
    let sessionNumber: Int
    let date: Date
    let distanceMeters: Double
    let durationSeconds: Double
    let calories: Double
    let averagePaceSecondsPerKm: Double?
    let averageHeartRate: Double?
    let effortRating: EffortRating?
    let isFreeRun: Bool
}

struct GPSPointSnapshot: Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double
    let horizontalAccuracy: Double
}
```

**DataStore returns snapshots** (see `services.md` for canonical `DataStoreProviding` protocol):

```swift
@ModelActor
actor DataStore: DataStoreProviding {
    func fetchUserProfile() throws -> UserProfileSnapshot? {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try modelContext.fetch(descriptor).first else { return nil }
        return UserProfileSnapshot(
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthYear: profile.birthYear,
            biologicalSex: profile.biologicalSex,
            // ... map all fields (see services.md for complete implementation)
        )
    }

    func fetchCompletedRuns(weekNumber: Int?, limit: Int?) throws -> [CompletedRunSnapshot] {
        var descriptor = FetchDescriptor<CompletedRun>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let weekNumber {
            descriptor.predicate = #Predicate { $0.weekNumber == weekNumber }
        }
        return try modelContext.fetch(descriptor).map { run in
            CompletedRunSnapshot(
                id: run.id,
                weekNumber: run.weekNumber,
                sessionNumber: run.sessionNumber,
                // ... map all fields (see services.md for complete implementation)
            )
        }
    }
}
```

**ViewModel consumes snapshots:**

```swift
@MainActor @Observable
final class DashboardViewModel {
    private let dataStore: DataStoreProviding
    var profile: UserProfileSnapshot?
    var recentRuns: [CompletedRunSnapshot] = []

    func load() async throws {
        profile = try await dataStore.fetchUserProfile()
        if let week = profile?.currentWeek {
            recentRuns = try await dataStore.fetchCompletedRuns(weekNumber: week, limit: nil)
        }
    }
}
```

---

### RunViewModel Role

`RunViewModel` wraps `RunEngine` and holds snapshot state for `RunView`. **`RunView` observes `RunViewModel`, not `RunEngine` directly.**

```swift
@MainActor @Observable
final class RunViewModel {
    private let engine: RunEngine
    private let dataStore: DataStoreProviding

    // Snapshot state for the view
    var currentIntervalName: String = ""
    var elapsedTime: TimeInterval = 0
    var totalDistance: Double = 0
    var currentPace: String = "--:--"
    var isPaused: Bool = false
    var isComplete: Bool = false
    var intervalProgress: Double = 0

    init(engine: RunEngine, dataStore: DataStoreProviding) {
        self.engine = engine
        self.dataStore = dataStore
    }

    func start() { engine.start() }
    func pause() { engine.pause() }
    func resume() { engine.resume() }
    func skip() { engine.skipInterval() }
}
```

`RunView` only reads `RunViewModel` properties — it never imports or references `RunEngine`.

---

### AppState

`AppState.swift` holds global navigation and session state:

```swift
@MainActor @Observable
final class AppState {
    // Navigation
    var hasCompletedOnboarding: Bool = false
    var selectedTab: AppTab = .dashboard

    // Active session
    var isRunActive: Bool = false
    var activeSessionWeek: Int?
    var activeSessionDay: Int?

    // Authentication / profile
    var isCloudSyncEnabled: Bool = false
    var userProfileLoaded: Bool = false
}

enum AppTab: Hashable {
    case dashboard, routePlanner, history, settings
}
```

`AppState` is created in `MileOneApp.swift` and passed via `.environment()`. `ContentView` reads it for top-level routing (onboarding vs main app).

---

### Dependency Injection

All services are created in `MileOneApp.swift` and injected via SwiftUI `.environment()`:

```swift
@main
struct MileOneApp: App {
    let container: ModelContainer

    // Services — created once, injected via environment
    @State private var appState = AppState()
    @State private var locationService = LocationService()
    @State private var healthKitService = HealthKitService()
    @State private var audioCoachService = AudioCoachService()

    init() {
        container = Self.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(locationService)
                .environment(healthKitService)
                .environment(audioCoachService)
        }
        .modelContainer(container)
    }
}
```

Views pull services from the environment:

```swift
struct PreRunView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(HealthKitService.self) private var healthKitService
    @Environment(AppState.self) private var appState
    // ...
}
```

The `DataStore` is created from the `ModelContainer`'s `ModelContext` — views that need it create a `DataStore` from the container or receive one via environment.

---

### ModelContainer Configuration

```swift
extension MileOneApp {
    /// Production: CloudKit-backed persistent store
    static func makeModelContainer() -> ModelContainer {
        let config = ModelConfiguration(
            "MileOne",
            schema: Schema([UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self]),
            cloudKitDatabase: .private("iCloud.com.mileone.app")
        )
        return try! ModelContainer(for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
                                    configurations: config)
    }

    /// Previews: in-memory, no CloudKit
    static func makePreviewContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
                                    configurations: config)
    }
}

// Tests: in-memory, no CloudKit
// Used in test setUp():
//   let config = ModelConfiguration(isStoredInMemoryOnly: true)
//   let container = try ModelContainer(for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
//                                       configurations: config)
//   let dataStore = DataStore(modelContainer: container)
```

| Context     | Store            | CloudKit          |
|-------------|------------------|-------------------|
| Production  | Persistent (SQLite) | `.private(...)` |
| Previews    | In-memory        | None              |
| Tests       | In-memory        | None              |

---

## 2. Project Structure

```
MileOne/
├── MileOne.entitlements               # HealthKit, CloudKit, background modes
├── App/
│   ├── MileOneApp.swift              # @main, ModelContainer setup, DI
│   ├── AppState.swift                # @Observable — navigation, session, auth state
│   └── Constants.swift               # App-wide constants
├── Models/
│   ├── UserProfile.swift             # @Model — biometrics, progress
│   ├── CompletedRun.swift            # @Model — run records
│   ├── GPSPoint.swift                # @Model — individual GPS points
│   ├── SavedRoute.swift              # @Model — planned routes
│   ├── Snapshots/
│   │   ├── UserProfileSnapshot.swift   # Sendable DTO
│   │   ├── CompletedRunSnapshot.swift  # Sendable DTO
│   │   ├── GPSPointSnapshot.swift      # Sendable DTO
│   │   ├── GPSPointData.swift          # Plain value struct for cross-actor GPS data
│   │   └── SavedRouteSnapshot.swift    # Sendable DTO
│   ├── SessionPlan.swift             # Static struct — 27 session definitions
│   ├── Interval.swift                # Struct — interval definition
│   └── Enums.swift                   # EffortRating, IntervalType, DrawMode, etc.
├── Services/
│   ├── Protocols/
│   │   ├── LocationProviding.swift
│   │   ├── HealthStoreProviding.swift
│   │   └── AudioCoaching.swift
│   ├── LocationService.swift
│   ├── HealthKitService.swift
│   ├── AudioCoachService.swift
│   ├── RouteService.swift            # MKDirections wrapper with queuing
│   └── DataStore.swift               # @ModelActor — returns Snapshot structs
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingFlow.swift      # NavigationStack coordinator
│   │   ├── WelcomeView.swift
│   │   ├── BiometricsView.swift
│   │   ├── ActivityLevelView.swift
│   │   ├── ScheduleView.swift
│   │   ├── LocationPermissionView.swift
│   │   └── HealthKitPermissionView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── WeeklyRingView.swift
│   │   ├── NextSessionCard.swift
│   │   ├── LapsedUserCard.swift
│   │   └── DashboardViewModel.swift
│   ├── Run/
│   │   ├── PreRunView.swift          # Route selection, session preview
│   │   ├── RunView.swift             # Timer + map tabbed container (observes RunViewModel)
│   │   ├── TimerView.swift           # Primary in-run view
│   │   ├── RunMapView.swift          # Secondary map view
│   │   ├── PostRunView.swift         # Summary + effort check-in
│   │   ├── RunEngine.swift           # @MainActor @Observable — core run orchestrator
│   │   └── RunViewModel.swift        # @MainActor @Observable — wraps RunEngine, holds view snapshots
│   ├── RoutePlanner/
│   │   ├── RoutePlannerView.swift
│   │   ├── RouteListView.swift
│   │   ├── RouteDetailView.swift
│   │   └── RoutePlannerViewModel.swift
│   ├── History/
│   │   ├── HistoryView.swift         # Calendar + list
│   │   ├── RunDetailView.swift       # Full summary + map replay
│   │   └── HistoryViewModel.swift
│   ├── Graduation/
│   │   └── GraduationView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Utilities/
│   ├── CalorieCalculator.swift
│   ├── PaceFormatter.swift
│   └── DateHelpers.swift
└── Tests/
    ├── MileOneTests/
    │   ├── Models/
    │   │   ├── SessionPlanTests.swift
    │   │   └── CalorieCalculatorTests.swift
    │   ├── Services/
    │   │   ├── RunEngineTests.swift
    │   │   ├── LocationServiceTests.swift
    │   │   ├── HealthKitServiceTests.swift
    │   │   ├── AudioCoachServiceTests.swift
    │   │   ├── RouteServiceTests.swift
    │   │   └── DataStoreTests.swift
    │   ├── ViewModels/
    │   │   ├── DashboardViewModelTests.swift
    │   │   ├── RoutePlannerViewModelTests.swift
    │   │   └── HistoryViewModelTests.swift
    │   └── Mocks/
    │       ├── MockLocationProvider.swift
    │       ├── MockHealthStore.swift
    │       ├── MockAudioCoach.swift
    │       └── MockDataStore.swift
    └── MileOneUITests/
        ├── OnboardingUITests.swift
        ├── DashboardUITests.swift
        ├── RunFlowUITests.swift
        └── RoutePlannerUITests.swift
```

### Entitlements File (`MileOne.entitlements`)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- HealthKit -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>

    <!-- CloudKit -->
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.mileone.app</string>
    </array>

    <!-- Background Modes -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>location</string>
    </array>
</dict>
</plist>
```

---

## 3. Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Language | Swift | 6.0+ |
| UI | SwiftUI | iOS 17+ |
| Maps | MapKit | iOS 17+ (MapContentBuilder API) |
| Health | HealthKit | iOS 17+ |
| Storage | SwiftData | iOS 17+ |
| Cloud Sync | CloudKit (via SwiftData) | iOS 17+ |
| Audio | AVFoundation + AVSpeechSynthesizer | iOS 17+ |
| Location | CoreLocation | iOS 17+ |
| Testing | Swift Testing (`@Test`, `#expect`) | Xcode 16+ |
| Min Deployment | iOS 17.0 | — |

> **Test framework**: Swift Testing is the canonical test framework. Use `@Test`, `@Suite`, `#expect`, and `#require` exclusively. Do not use XCTest (`XCTestCase`, `XCTAssert*`) for unit tests. UI tests use Xcode's UI testing framework which still requires `XCTestCase`, but unit/integration tests use Swift Testing only.

---
