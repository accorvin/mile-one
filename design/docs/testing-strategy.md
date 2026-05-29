← [Back to Index](README.md)

# Mile One — Testing Strategy

*Comprehensive testing approach: automated tests catch logic bugs, on-device smoke tests catch iOS integration issues.*

---

## Testing Pyramid

```
      /\
     /  \  On-Device Smoke Tests (manual, pre-release)
    /    \
   /──────\  UI Tests — XCUITest (critical flows only)
  /        \
 /──────────\  Integration Tests — Swift Testing (service pipelines)
/            \
/──────────────\  Unit Tests — Swift Testing (models, services, utils)
```

| Layer | Framework | Count (est.) | Runs On | Speed |
|-------|-----------|-------------|---------|-------|
| Unit | Swift Testing | ~71 | Simulator | ms each |
| Integration | Swift Testing | ~15–20 | Simulator | < 1s each |
| UI | XCUITest (`XCTestCase`) | ~10–15 | Simulator | 5–15s each |
| Accessibility | XCUITest audit API | 4–6 | Simulator | 5s each |
| On-Device | Manual checklist | 7 items | Physical iPhone | ~45 min |

---

## 1. Unit Tests (existing plan — ~71 tests)

Already defined across 14 test files. Key best practices to follow:

### Use Swift Testing idioms

```swift
import Testing

@Suite("Session Plan Validation")
struct SessionPlanTests {
    
    // Parameterized: one test covers all 9 weeks instead of 9 separate tests
    @Test("Each week matches NHS C25K spec", arguments: 1...9)
    func weekMatchesSpec(week: Int) {
        let sessions = SessionPlan.sessions(for: week)
        #expect(sessions.count == 3, "Week \(week) should have 3 sessions")
        
        for session in sessions {
            let first = session.intervals.first
            let last = session.intervals.last
            #expect(first?.type == .walk, "Session \(session.id) should start with warm-up walk")
            #expect(last?.type == .walk, "Session \(session.id) should end with cool-down walk")
            #expect(first?.durationSeconds == 300, "Warm-up should be 5 minutes")
            #expect(last?.durationSeconds == 300, "Cool-down should be 5 minutes")
        }
    }
    
    // Use #require for preconditions that should fail fast
    @Test("Session lookup returns valid session")
    func sessionLookup() throws {
        let session = try #require(SessionPlan.session(week: 1, day: 1),
                                    "Week 1 Day 1 must exist")
        #expect(session.intervals.count > 2)
    }
}
```

### Mocking strategy

Every iOS framework service has a protocol. Tests inject mocks, never real hardware:

| Service | Protocol | Mock |
|---------|----------|------|
| CoreLocation | `LocationProviding` | `MockLocationProvider` |
| HealthKit | `HealthStoreProviding` | `MockHealthStore` |
| AVSpeechSynthesizer | `AudioCoaching` | `MockAudioCoach` |
| SwiftData | (direct `DataStore`) | In-memory `ModelContainer` |

### Test isolation rules

- Each test creates its own dependencies — no shared mutable state
- `DataStore` tests use in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`
- No network calls in unit tests, ever
- All tests run in parallel (Swift Testing default)

---

## 2. Integration Tests (NEW — separate test target)

**Purpose:** Verify that services work together correctly. Unit tests prove individual components; integration tests prove the wiring.

### Test target setup

Add a second test target: `MileOneIntegrationTests`. This keeps integration tests (which are slightly slower) separate from fast unit tests, so you can run units alone during development.

### Planned integration tests

```
Tests/
└── MileOneIntegrationTests/
    ├── RunPipelineTests.swift       — RunEngine + DataStore + MockLocation
    ├── PostRunPipelineTests.swift   — PostRunOrchestrator full flow
    ├── DataStorePersistenceTests.swift — CRUD round-trips on real in-memory SwiftData
    ├── LocationDistanceTests.swift  — GPX trace replay → distance accumulation
    └── CalorieIntegrationTests.swift — Full run → calorie calculation with actual durations
```

#### RunPipelineTests

Tests the core runtime loop with real (in-memory) SwiftData but mocked location/audio:

```swift
@Suite("Run Pipeline Integration")
struct RunPipelineTests {
    
    @Test("Complete W1D1 session saves to DataStore")
    func completeSession() async throws {
        let dataStore = try DataStore(inMemory: true)
        let mockLocation = MockLocationProvider()
        let mockAudio = MockAudioCoach()
        let engine = RunEngine(dataStore: dataStore, 
                               locationService: mockLocation,
                               audioCoach: mockAudio)
        
        // Start session
        await engine.startSession(week: 1, day: 1)
        
        // Simulate running through all intervals (fast-forward)
        await engine.fastForwardToCompletion()
        
        // Verify run was saved
        let runs = try await dataStore.fetchAllRuns()
        #expect(runs.count == 1)
        #expect(runs.first?.sessionWeek == 1)
        #expect(runs.first?.sessionDay == 1)
    }
}
```

#### LocationDistanceTests — GPX Trace Replay

Replay a real GPS trace through `MockLocationProvider` and verify distance accumulation, accuracy filtering, and the 90-second grace period:

```swift
@Suite("GPS Distance Accumulation")
struct LocationDistanceTests {
    
    @Test("Distance accumulates from GPX trace with accuracy filtering")
    func gpxTraceDistance() async throws {
        // Load a GPX file with known distance (~1 mile loop)
        let points = GPXParser.parse(filename: "test-1mile-loop")
        let mockLocation = MockLocationProvider(simulatedPoints: points)
        let locationService = LocationService(provider: mockLocation)
        
        await locationService.startTracking()
        await mockLocation.replayAllPoints(intervalSeconds: 1.0)
        
        let distance = locationService.totalDistanceMeters
        // 1 mile ≈ 1609m, allow 10% tolerance for GPS noise
        #expect(distance > 1400 && distance < 1800,
                "Expected ~1 mile, got \(distance)m")
    }
    
    @Test("Points with accuracy > 30m are filtered out after grace period")
    func accuracyFiltering() async throws {
        let goodPoint = MockGPSPoint(lat: 35.73, lon: -78.85, accuracy: 10)
        let badPoint = MockGPSPoint(lat: 35.74, lon: -78.86, accuracy: 50)
        
        let mockLocation = MockLocationProvider(simulatedPoints: [goodPoint, badPoint])
        let locationService = LocationService(provider: mockLocation)
        
        // Advance past 90-second grace period
        await locationService.startTracking()
        await locationService.advanceClock(seconds: 100)
        await mockLocation.replayAllPoints(intervalSeconds: 1.0)
        
        // Bad point should be filtered — distance should not jump
        #expect(locationService.totalDistanceMeters < 100,
                "Bad accuracy point should be filtered")
    }
}
```

### GPX test fixtures

Add a `TestFixtures/` directory with GPX files for location tests:

```
Tests/
└── TestFixtures/
    ├── test-1mile-loop.gpx      — ~1 mile loop, good accuracy
    ├── test-noisy-gps.gpx       — Mix of good and poor accuracy points
    └── test-stationary.gpx      — Standing still (should accumulate ~0 distance)
```

Create GPX files from real runs or generate them. A simple 1-mile rectangular loop:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="MileOneTests">
  <trk><name>Test 1-Mile Loop</name><trkseg>
    <trkpt lat="35.7300" lon="-78.8500"><time>2026-01-01T12:00:00Z</time></trkpt>
    <trkpt lat="35.7340" lon="-78.8500"><time>2026-01-01T12:02:00Z</time></trkpt>
    <trkpt lat="35.7340" lon="-78.8460"><time>2026-01-01T12:04:00Z</time></trkpt>
    <trkpt lat="35.7300" lon="-78.8460"><time>2026-01-01T12:06:00Z</time></trkpt>
    <trkpt lat="35.7300" lon="-78.8500"><time>2026-01-01T12:08:00Z</time></trkpt>
  </trkseg></trk>
</gpx>
```

---

## 3. UI Tests (XCUITest)

UI tests verify critical user flows end-to-end. Keep them focused — they're slow.

### Accessibility identifiers

Every interactive element MUST have an `accessibilityIdentifier`. This is more reliable than matching labels (which change with localization):

```swift
// In views:
Button("Pause") { ... }
    .accessibilityIdentifier("pauseRunButton")

Text(formattedTime)
    .accessibilityIdentifier("runCountdownTimer")

// In tests:
let pauseButton = app.buttons["pauseRunButton"]
#expect(pauseButton.exists)
pauseButton.tap()
```

### Launch arguments for test state

Skip onboarding and pre-populate test data using launch arguments:

```swift
// In test:
let app = XCUIApplication()
app.launchArguments = ["--uitesting", "--skip-onboarding"]
app.launchEnvironment = ["TEST_USER_WEIGHT": "70", "TEST_USER_SEX": "male"]
app.launch()

// In app (AppDelegate or @main):
#if DEBUG
if CommandLine.arguments.contains("--uitesting") {
    // Use in-memory store, skip animations, pre-populate data
}
if CommandLine.arguments.contains("--skip-onboarding") {
    // Set hasCompletedOnboarding = true
}
#endif
```

### Planned UI test flows

| File | Tests | What it covers |
|------|-------|----------------|
| `OnboardingUITests` | 2–3 | Complete onboarding, back navigation, iCloud toggle |
| `DashboardUITests` | 2–3 | Dashboard loads, next session card, start run button |
| `RunFlowUITests` | 4–5 | Start run → countdown → pause → resume → complete, interval transitions visible |
| `RoutePlannerUITests` | 2–3 | Create route, save route, load saved route |

### Simulated location for UI tests

Attach a GPX file to the UI test scheme so the simulator feeds fake GPS data during run flow tests:

1. Add `test-run-route.gpx` to project
2. Edit Scheme → Test → Options → Allow Location Simulation → select GPX file
3. The run flow UI test can verify the map shows a path and distance updates

---

## 4. Accessibility Audit Tests (NEW)

Leverage Xcode's built-in `performAccessibilityAudit()` (available since Xcode 15). One test per screen catches:
- Missing accessibility labels
- Insufficient color contrast
- Clipped text
- Dynamic Type support failures
- Hit region too small (< 44pt)

```swift
// In MileOneUITests/AccessibilityAuditTests.swift

import XCTest

final class AccessibilityAuditTests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }
    
    func testDashboardAccessibility() throws {
        // Navigate to dashboard (should be default after onboarding)
        try app.performAccessibilityAudit()
    }
    
    func testInRunScreenAccessibility() throws {
        // Start a run to get to the in-run screen
        app.buttons["startRunButton"].tap()
        // Wait for countdown to finish
        sleep(4)
        try app.performAccessibilityAudit()
    }
    
    func testPostRunScreenAccessibility() throws {
        // Use a launch argument to jump directly to post-run with fake data
        app.launchArguments.append("--show-post-run")
        app.launch()
        try app.performAccessibilityAudit()
    }
    
    func testSettingsAccessibility() throws {
        app.buttons["settingsButton"].tap()
        try app.performAccessibilityAudit()
    }
}
```

---

## 5. Xcode Test Plan (NEW)

Create `MileOne.xctestplan` to run UI tests across multiple device sizes and catch layout issues:

### Configurations

| Config Name | Device | Purpose |
|-------------|--------|---------|
| iPhone SE | iPhone SE (3rd gen) | Smallest supported screen — catches overflow, truncation |
| iPhone 15 Pro Max | iPhone 15 Pro Max | Largest screen — catches spacing, alignment |
| Dark Mode | iPhone 15 | Verify dark theme rendering |
| Dynamic Type XXL | iPhone 15 | Verify text scales without clipping |

### Setup in Xcode

1. File → New → Test Plan
2. Add `MileOneUITests` target
3. Add configurations with different simulator devices
4. Under each configuration, set system appearance (dark/light) and text size

Unit and integration tests don't need multi-device — they run in any simulator.

---

## 6. On-Device Smoke Test Checklist (NEW)

**When to run:** Before any TestFlight release. Cannot be automated — these verify iOS system integration that simulators can't replicate.

### Pre-deploy prerequisites

- [ ] Apple Developer account active with valid membership
- [ ] CloudKit container `iCloud.com.mileone.app` created in developer portal
- [ ] Provisioning profile generated with HealthKit + CloudKit + Background Location entitlements
- [ ] App signed and deployed to physical iPhone via Xcode

### Smoke tests (est. 45 min total)

| # | Test | Steps | Pass Criteria | Time |
|---|------|-------|--------------|------|
| 1 | **GPS background tracking** | Start a run, lock the phone, walk for 5 minutes | Distance increases while locked; GPS points recorded | 7 min |
| 2 | **Audio while locked** | Start a run, lock the phone, wait for interval transition | Voice cue plays through speaker/AirPods while screen is off | 5 min |
| 3 | **HealthKit write** | Complete a short run, open Apple Health app | Workout appears in Health → Workouts with correct duration/calories | 5 min |
| 4 | **HealthKit route** | Complete a run with GPS, check Health → Workouts → route | Route map shows the path you walked/ran | 5 min |
| 5 | **CloudKit sync** | Complete a run, force-quit app, relaunch | Run history still shows the completed run (SwiftData + CloudKit persisted it) | 3 min |
| 6 | **30-min sustained run** | Start Week 5 Day 3 (20-min continuous run + warm-up/cool-down) | App stays alive for full 30+ minutes without iOS killing it | 35 min |
| 7 | **Phone call interruption** | Start a run, have someone call you, answer for 30 sec, hang up | Run resumes correctly; timer didn't drift; audio cues resume | 3 min |

### Battery benchmark

- Note battery % before and after test #6 (30-min run)
- Acceptable: < 15% drain for 30 minutes of GPS + audio
- If > 20%: investigate GPS accuracy settings, reduce update frequency

---

## 7. Code Coverage

### Targets

| Area | Target | Rationale |
|------|--------|-----------|
| Models (SessionPlan, Interval) | > 95% | Pure logic, easy to test exhaustively |
| Services (RunEngine, DataStore) | > 85% | Core business logic |
| CalorieCalculator | 100% | Small, pure function |
| ViewModels | > 70% | Test data flow, not SwiftUI rendering |
| Views | Not measured | SwiftUI views tested via UI tests, not unit coverage |

### Enable in Xcode

Edit Scheme → Test → Options → ✅ Gather coverage for: `MileOne` target

---

## Updated File Structure

```
Tests/
├── MileOneTests/                    ← Unit tests (Swift Testing)
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
├── MileOneIntegrationTests/         ← NEW: Integration tests (Swift Testing)
│   ├── RunPipelineTests.swift
│   ├── PostRunPipelineTests.swift
│   ├── DataStorePersistenceTests.swift
│   ├── LocationDistanceTests.swift
│   └── CalorieIntegrationTests.swift
├── MileOneUITests/                  ← UI tests (XCUITest)
│   ├── OnboardingUITests.swift
│   ├── DashboardUITests.swift
│   ├── RunFlowUITests.swift
│   ├── RoutePlannerUITests.swift
│   └── AccessibilityAuditTests.swift   ← NEW
├── TestFixtures/                    ← NEW: GPX files for location tests
│   ├── test-1mile-loop.gpx
│   ├── test-noisy-gps.gpx
│   └── test-stationary.gpx
└── MileOne.xctestplan              ← NEW: Multi-device test plan
```
