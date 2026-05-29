← [Back to Index](README.md)

# Mile One — Phase 2: Run Engine + GPS + Background Execution

### Phase 2: Run Engine + GPS + Background Execution

**Goal**: The core run engine drives intervals using GPS-timestamp-based timing, GPS provides location updates and background execution, and the engine correctly sequences through all intervals with crash recovery.

#### Design Decisions (fixes from review 2)

- **`@MainActor` RunEngine**: RunEngine is `@MainActor @Observable` so all SwiftUI observation and property mutation happens on the main actor. No cross-thread crashes in Swift 6 strict concurrency.
- **`DispatchSourceTimer` instead of `Timer.scheduledTimer`**: The display timer uses `DispatchSourceTimer` on the main queue so it fires during all RunLoop modes (including `.tracking` during map scrolling). Fixes review 2 issue 3c.
- **GPS-timestamp-based advancement**: `advanceToNextInterval()` uses the GPS location timestamp, not `Date()`, to determine interval elapsed time. Fixes review 2 issue 1a.
- **Single advancement code path**: Only `handleLocationUpdate` advances intervals. The display timer refreshes UI state only — no interval advancement. Fixes review 2 issue 1b (double-advance race).
- **Timer invalidation on deinit**: `deinit` cancels `displayTimer`. Fixes review 2 issue 9e (retain cycle).
- **Pause/resume timer management**: `pause()` cancels the display timer. `resume()` creates a fresh one. No timer leak on pause/resume cycles.

#### Tests FIRST

**File: `Tests/MileOneTests/Mocks/MockLocationProvider.swift`**

```swift
@testable import MileOne
import CoreLocation

final class MockLocationProvider: LocationProviding, @unchecked Sendable {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationError: ((Error) -> Void)?
    
    private(set) var startUpdatingCalled = false
    private(set) var stopUpdatingCalled = false
    private(set) var requestWhenInUseCalled = false
    private(set) var requestAlwaysCalled = false
    
    func requestWhenInUseAuthorization() {
        requestWhenInUseCalled = true
    }
    
    func requestAlwaysAuthorization() {
        requestAlwaysCalled = true
    }
    
    func startUpdatingLocation() {
        startUpdatingCalled = true
    }
    
    func stopUpdatingLocation() {
        stopUpdatingCalled = true
        startUpdatingCalled = false
    }
    
    /// Simulate a GPS update at a given time
    func simulateLocation(
        lat: Double = 35.7796,
        lng: Double = -78.6382,
        timestamp: Date = Date(),
        accuracy: Double = 10
    ) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            altitude: 100,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        onLocationUpdate?(location)
    }
}
```

**File: `MileOne/Services/Protocols/TimeProviding.swift`**

```swift
/// Injectable time source for testable wall-clock operations.
/// RunEngine uses this instead of Date() directly.
protocol TimeProviding {
    func now() -> Date
}

struct SystemTimeProvider: TimeProviding {
    func now() -> Date { Date() }
}
```

**File: `Tests/MileOneTests/Mocks/MockTimeProvider.swift`**

```swift
@testable import MileOne

final class MockTimeProvider: TimeProviding, @unchecked Sendable {
    var currentTime: Date = Date()
    func now() -> Date { currentTime }
}
```

**File: `Tests/MileOneTests/Mocks/MockAudioCoach.swift`**

```swift
@testable import MileOne

final class MockAudioCoach: AudioCoaching, @unchecked Sendable {
    private(set) var spokenTexts: [String] = []
    private(set) var configuredSession = false
    private(set) var stopped = false
    
    func configureAudioSession() throws {
        configuredSession = true
    }
    
    func speak(_ text: String) {
        spokenTexts.append(text)
    }
    
    func stop() {
        stopped = true
    }
    
    func deactivateSession() {
        // Mock: no-op
    }
    
    func cancelPending() {
        // Mock: clear any queued-but-unspoken cues
    }
}
```

**File: `Tests/MileOneTests/Services/RunEngineTests.swift`**

```swift
import Testing
import CoreLocation
@testable import MileOne

@MainActor
struct RunEngineTests {
    
    // Helper: simple 4-interval session (5s warmup, 10s run, 10s walk, 5s cooldown)
    private func makeTestSession() -> SessionDefinition {
        SessionDefinition(
            id: "TEST",
            week: 1,
            dayInWeek: 1,
            intervals: [
                Interval(type: .warmUp, durationSeconds: 5),
                Interval(type: .run, durationSeconds: 10),
                Interval(type: .walk, durationSeconds: 10),
                Interval(type: .coolDown, durationSeconds: 5),
            ]
        )
    }
    
    @Test func startSetsInitialState() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        
        #expect(engine.isRunning == true)
        #expect(engine.isPaused == false)
        #expect(engine.currentIntervalIndex == 0)
        #expect(engine.currentInterval?.type == .warmUp)
        #expect(location.startUpdatingCalled == true)
        #expect(audio.configuredSession == true)
        #expect(audio.spokenTexts.count >= 1) // opening cue
    }
    
    @Test func intervalAdvancesOnGPSTimestamp() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        let startTime = Date()
        try engine.start()
        
        // Current interval is warmUp (5s). Simulate GPS update 6s later using GPS timestamp.
        let sixSecondsLater = startTime.addingTimeInterval(6)
        location.simulateLocation(timestamp: sixSecondsLater)
        
        // Should have advanced to the run interval via GPS timestamp, not Date()
        #expect(engine.currentIntervalIndex == 1)
        #expect(engine.currentInterval?.type == .run)
    }
    
    @Test func displayTimerDoesNotAdvanceIntervals() throws {
        // Verifies fix for review 2 issue 1b — only GPS path advances intervals
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        #expect(engine.currentIntervalIndex == 0)
        
        // Trigger display refresh (simulating the display timer callback)
        engine.refreshDisplay()
        
        // Display refresh must NOT advance the interval
        #expect(engine.currentIntervalIndex == 0, "refreshDisplay must not call advanceToNextInterval")
    }
    
    @Test func pauseAndResumeWork() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        engine.pause()
        
        #expect(engine.isPaused == true)
        #expect(location.stopUpdatingCalled == true)
        
        engine.resume()
        #expect(engine.isPaused == false)
        #expect(location.startUpdatingCalled == true)
    }
    
    @Test func pauseResumeDoesNotLeakTimers() throws {
        // Verifies that pause cancels the timer and resume creates exactly one new timer
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        
        // Pause/resume 5 times
        for _ in 0..<5 {
            engine.pause()
            engine.resume()
        }
        
        // Engine should still function correctly — only one active timer
        #expect(engine.isRunning == true)
        #expect(engine.isPaused == false)
        #expect(engine.activeTimerCount == 1, "Multiple pause/resume cycles must not accumulate timers")
    }
    
    @Test func pauseTimeNotCountedInElapsed() throws {
        // RunEngine accepts an injectable TimeProvider (defaults to SystemTimeProvider)
        // so tests can control wall-clock time deterministically.
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let mockTime = MockTimeProvider()
        let session = SessionDefinition(
            id: "TEST",
            week: 1,
            dayInWeek: 1,
            intervals: [
                Interval(type: .warmUp, durationSeconds: 300),
                Interval(type: .run, durationSeconds: 60),
                Interval(type: .coolDown, durationSeconds: 300),
            ]
        )
        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: location,
            audioCoach: audio,
            timeProvider: mockTime
        )
        
        let t0 = Date()
        mockTime.currentTime = t0
        try engine.start()
        
        // Simulate 10 seconds of running
        mockTime.currentTime = t0.addingTimeInterval(10)
        location.simulateLocation(timestamp: mockTime.currentTime)
        #expect(engine.totalElapsed >= 9 && engine.totalElapsed <= 11)
        
        // Pause at t0+10
        engine.pause()
        
        // Advance mock clock 60 seconds while paused (to t0+70)
        mockTime.currentTime = t0.addingTimeInterval(70)
        
        // Resume at t0+70 — engine records 60s of pause duration
        engine.resume()
        
        // Simulate GPS 5 seconds after resume (t0+75)
        mockTime.currentTime = t0.addingTimeInterval(75)
        location.simulateLocation(timestamp: mockTime.currentTime)
        
        // Active time = 10s (before pause) + 5s (after resume) = 15s
        // NOT 75s (total wall clock)
        #expect(engine.totalElapsed >= 14 && engine.totalElapsed <= 16,
                "Pause time must not be counted. Expected ~15s, got \(engine.totalElapsed)")
    }
    
    @Test func skipIntervalAdvancesToNext() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        #expect(engine.currentInterval?.type == .warmUp)
        
        engine.skipInterval()
        #expect(engine.currentInterval?.type == .run)
        
        engine.skipInterval()
        #expect(engine.currentInterval?.type == .walk)
    }
    
    @Test func runCompletesAfterAllIntervals() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        var didComplete = false
        engine.onRunComplete = { _, _, _ in
            didComplete = true
        }
        
        try engine.start()
        
        engine.skipInterval() // warmUp → run
        engine.skipInterval() // run → walk
        engine.skipInterval() // walk → coolDown
        engine.skipInterval() // coolDown → complete
        
        #expect(engine.isComplete == true)
        #expect(engine.isRunning == false)
        #expect(didComplete == true)
        #expect(location.stopUpdatingCalled == true)
    }
    
    @Test func doubleCompletionPrevented() throws {
        // Skipping past the last interval should not fire onRunComplete twice
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        var completionCount = 0
        engine.onRunComplete = { _, _, _ in
            completionCount += 1
        }
        
        try engine.start()
        // Skip all intervals
        for _ in 0..<4 { engine.skipInterval() }
        
        // Try to skip again after completion
        engine.skipInterval()
        engine.skipInterval()
        
        #expect(completionCount == 1, "onRunComplete must fire exactly once")
    }
    
    @Test func distanceAccumulatesFromGPS() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        
        let now = Date()
        location.simulateLocation(lat: 35.7796, lng: -78.6382, timestamp: now)
        location.simulateLocation(lat: 35.7806, lng: -78.6382, timestamp: now.addingTimeInterval(1))
        
        #expect(engine.totalDistance > 100)
        #expect(engine.totalDistance < 150)
    }
    
    @Test func gpsDeadZoneAdvancesIntervals() throws {
        // Intervals should advance even without GPS updates, using the display timer's
        // timestamp. When GPS resumes, timestamps should pick up correctly.
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        let t0 = Date()
        try engine.start()
        
        // Send one GPS fix then nothing for 6s — interval should still advance
        location.simulateLocation(timestamp: t0)
        
        // Simulate display timer firing at t0+6 (no GPS, timer provides fallback timestamp)
        engine.refreshDisplayWithTimestamp(t0.addingTimeInterval(6))
        
        #expect(engine.currentIntervalIndex == 1,
                "Interval must advance using fallback timestamp when GPS is unavailable")
    }
    
    @Test func endRunStopsEverything() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        engine.endRun()
        
        #expect(engine.isRunning == false)
        #expect(engine.isComplete == true)
        #expect(location.stopUpdatingCalled == true)
    }
    
    @Test func audioCueOnIntervalTransition() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        let initialCueCount = audio.spokenTexts.count
        
        engine.skipInterval() // warmUp → run
        #expect(audio.spokenTexts.count > initialCueCount)
        #expect(audio.spokenTexts.last == "Time to run!")
        
        engine.skipInterval() // run → walk
        #expect(audio.spokenTexts.last == "Take a walk break.")
    }
    
    @Test func coolDownCueIsSpecific() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        engine.skipInterval() // warmUp → run
        engine.skipInterval() // run → walk
        engine.skipInterval() // walk → coolDown
        
        #expect(audio.spokenTexts.last == "Great work! Begin your cool-down walk.")
    }
    
    @Test func realWeek1SessionSequence() throws {
        guard let session = SessionPlanLibrary.session(week: 1, day: 1) else {
            Issue.record("W1D1 not found"); return
        }
        
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        #expect(engine.currentInterval?.type == .warmUp)
        #expect(engine.currentInterval?.durationSeconds == 300)
        
        engine.skipInterval()
        #expect(engine.currentInterval?.type == .run)
        #expect(engine.currentInterval?.durationSeconds == 60)
        
        engine.skipInterval()
        #expect(engine.currentInterval?.type == .walk)
        #expect(engine.currentInterval?.durationSeconds == 90)
    }
    
    @Test func timerInvalidatedOnDeinit() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        var engine: RunEngine? = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine?.start()
        #expect(engine?.isRunning == true)
        
        // Deallocate engine — timer must be invalidated in deinit
        weak var weakEngine = engine
        engine = nil
        
        #expect(weakEngine == nil, "RunEngine should be deallocated — no retain cycle from timer")
    }
    
    // --- Crash Recovery ---
    
    @Test func checkpointSavesRunState() throws {
        let location = MockLocationProvider()
        let audio = MockAudioCoach()
        let engine = RunEngine(
            sessionDefinition: makeTestSession(),
            locationProvider: location,
            audioCoach: audio
        )
        
        try engine.start()
        engine.skipInterval() // advance to run
        
        let checkpoint = engine.createCheckpoint()
        #expect(checkpoint.currentIntervalIndex == 1)
        #expect(checkpoint.sessionId == "TEST")
        #expect(checkpoint.isValid == true)
    }
    
    @Test func incompleteRunDetectedOnLaunch() {
        // If a checkpoint exists from a previous session, detect it
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 2,
            totalElapsed: 180,
            totalDistance: 500,
            timestamp: Date().addingTimeInterval(-300) // 5 min ago
        )
        
        // Checkpoint older than 2 hours is stale — discard
        let staleCheckpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 2,
            totalElapsed: 180,
            totalDistance: 500,
            timestamp: Date().addingTimeInterval(-7200)
        )
        
        #expect(checkpoint.isValid == true, "Recent checkpoint should be valid")
        #expect(staleCheckpoint.isValid == false, "Checkpoint > 2 hours old is stale")
    }
}
```

#### Implementation

1. Implement `LocationService` (real CoreLocation wrapper)
   - Protocol includes both `requestWhenInUseAuthorization()` and `requestAlwaysAuthorization()`
   - Set `allowsBackgroundLocationUpdates = true` only AFTER receiving at least `.authorizedWhenInUse`
   - Implement `didFailWithError` delegate method — propagate GPS failures to RunEngine

2. Implement `RunEngine` as `@MainActor @Observable`:
   - **GPS-timestamp interval timing**: `advanceToNextInterval()` uses the location's `.timestamp`, not `Date()`
   - **Single advancement path**: Only `handleLocationUpdate` calls `advanceToNextInterval()`. `refreshDisplay()` updates UI state only.
   - **Fallback for GPS dead zones**: `refreshDisplayWithTimestamp(_:)` uses `Date()` as fallback when GPS hasn't updated in >3 seconds, allowing intervals to advance without GPS
   - **`DispatchSourceTimer`** for display updates (fires in all RunLoop modes)
   - **Pause/resume**: `pause()` cancels the display timer. `resume()` creates exactly one new timer. No timer accumulation.
   - **`deinit`** cancels the display timer to break retain cycles
   - **Guard against double-completion**: `advanceToNextInterval()` returns early if `isComplete == true`
   - **Crash recovery checkpoint**: Save run state (interval index, elapsed, distance) to UserDefaults every 60 seconds. On launch, check for incomplete runs.

3. Configure `Info.plist`:
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `UIBackgroundModes`: `location`

4. Test background behavior on device (simulator doesn't properly test background GPS)

5. Run all RunEngine tests — all must pass

**Crash recovery design**:
```swift
struct RunCheckpoint: Codable {
    let sessionId: String
    let currentIntervalIndex: Int
    let totalElapsed: TimeInterval
    let totalDistance: Double
    let timestamp: Date
    
    var isValid: Bool {
        // Stale after 2 hours
        abs(timestamp.timeIntervalSinceNow) < 7200
    }
}

// In RunEngine:
private var checkpointTimer: DispatchSourceTimer?

func startCheckpointTimer() {
    let timer = DispatchSource.makeTimerSource(queue: .main)
    timer.schedule(deadline: .now() + 60, repeating: 60)
    timer.setEventHandler { [weak self] in
        self?.saveCheckpoint()
    }
    timer.resume()
    checkpointTimer = timer
}

func saveCheckpoint() {
    let checkpoint = createCheckpoint()
    if let data = try? JSONEncoder().encode(checkpoint) {
        UserDefaults.standard.set(data, forKey: "runCheckpoint")
    }
}

func clearCheckpoint() {
    UserDefaults.standard.removeObject(forKey: "runCheckpoint")
}

// On app launch (in AppState or similar):
static func detectIncompleteRun() -> RunCheckpoint? {
    guard let data = UserDefaults.standard.data(forKey: "runCheckpoint"),
          let checkpoint = try? JSONDecoder().decode(RunCheckpoint.self, from: data),
          checkpoint.isValid else {
        return nil
    }
    return checkpoint
}
```

---
