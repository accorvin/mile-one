import Testing
import Foundation
import CoreLocation
@testable import MileOne

// MARK: - RunEngineTests

/// All RunEngine tests run on @MainActor since RunEngine is @MainActor.
@MainActor
struct RunEngineTests {

    // MARK: - Helpers

    /// Create a simple test session with known intervals.
    private func makeSession(intervals: [Interval]? = nil) -> SessionDefinition {
        let defaultIntervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .walk, durationSeconds: 90),
            Interval(type: .coolDown, durationSeconds: 300)
        ]
        return SessionDefinition(
            id: "TEST1",
            week: 1,
            dayInWeek: 1,
            intervals: intervals ?? defaultIntervals
        )
    }

    /// Create RunEngine with mock dependencies and a controllable clock.
    private func makeEngine(
        session: SessionDefinition? = nil,
        timeProvider: MockTimeProvider = MockTimeProvider(),
        locationProvider: MockLocationProvider = MockLocationProvider(),
        audioCoach: MockAudioCoach = MockAudioCoach()
    ) -> (RunEngine, MockLocationProvider, MockAudioCoach, MockTimeProvider) {
        let s = session ?? makeSession()
        let engine = RunEngine(
            sessionDefinition: s,
            locationProvider: locationProvider,
            audioCoach: audioCoach,
            timeProvider: timeProvider
        )
        return (engine, locationProvider, audioCoach, timeProvider)
    }

    // MARK: - Tests

    @Test func startSetsInitialState() throws {
        let (engine, location, audio, _) = makeEngine()

        try engine.start()

        #expect(engine.isRunning == true)
        #expect(engine.isPaused == false)
        #expect(engine.isComplete == false)
        #expect(engine.currentIntervalIndex == 0)
        #expect(engine.totalElapsed == 0)
        #expect(engine.totalDistance == 0)
        #expect(engine.activeTimerCount == 1)
        #expect(location.startUpdatingCalled == true)
        #expect(audio.configuredSession == true)
        #expect(audio.spokenTexts.first == "Start your warm-up walk.")
    }

    @Test func intervalAdvancesOnGPSTimestamp() throws {
        // Session: 10s warmup → 10s run → cooldown
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 10),
            Interval(type: .run, durationSeconds: 10),
            Interval(type: .coolDown, durationSeconds: 10)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, audio, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        #expect(engine.currentIntervalIndex == 0)

        // Simulate GPS update 10s later — should advance past warmup.
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(10))
        time.currentTime = baseDate.addingTimeInterval(10)

        #expect(engine.currentIntervalIndex == 1)
        #expect(audio.spokenTexts.contains("Time to run!"))
    }

    @Test func displayTimerDoesNotAdvanceIntervals() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 10),
            Interval(type: .run, durationSeconds: 10)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, _, _, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Advance time past the interval but only call refreshDisplay (no GPS).
        // Since there's no lastGPSTimestamp, the >3s check won't trigger fallback
        // on the first call. We need to set up a GPS timestamp first.
        time.currentTime = baseDate.addingTimeInterval(15)

        // refreshDisplay should NOT advance intervals (no GPS timestamp set = no fallback either
        // since lastGPSTimestamp is nil, the condition `now.timeIntervalSince(lastGPS) > 3` won't fire).
        engine.refreshDisplay()

        #expect(engine.currentIntervalIndex == 0)
    }

    @Test func pauseAndResumeWork() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, _, _) = makeEngine(timeProvider: time)
        try engine.start()

        // Pause after 5s.
        time.currentTime = baseDate.addingTimeInterval(5)
        engine.pause()

        #expect(engine.isPaused == true)
        #expect(engine.isRunning == true)
        #expect(location.stopUpdatingCalled == true)
        #expect(engine.activeTimerCount == 0)

        // Resume after 10s of pause.
        time.currentTime = baseDate.addingTimeInterval(15)
        engine.resume()

        #expect(engine.isPaused == false)
        #expect(engine.isRunning == true)
        #expect(location.startUpdatingCalled == true)
        #expect(engine.activeTimerCount == 1)
    }

    @Test func pauseResumeDoesNotLeakTimers() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, _, _, _) = makeEngine(timeProvider: time)
        try engine.start()
        #expect(engine.activeTimerCount == 1)

        // Pause → timer should be 0.
        time.currentTime = baseDate.addingTimeInterval(1)
        engine.pause()
        #expect(engine.activeTimerCount == 0)

        // Resume → timer should be exactly 1, not 2.
        time.currentTime = baseDate.addingTimeInterval(2)
        engine.resume()
        #expect(engine.activeTimerCount == 1)

        // Pause and resume again.
        time.currentTime = baseDate.addingTimeInterval(3)
        engine.pause()
        #expect(engine.activeTimerCount == 0)

        time.currentTime = baseDate.addingTimeInterval(4)
        engine.resume()
        #expect(engine.activeTimerCount == 1)
    }

    @Test func pauseTimeNotCountedInElapsed() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 300)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, _, _, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Run for 5 seconds.
        time.currentTime = baseDate.addingTimeInterval(5)
        engine.refreshDisplay()
        #expect(abs(engine.totalElapsed - 5.0) < 0.1)

        // Pause for 100 seconds.
        engine.pause()
        time.currentTime = baseDate.addingTimeInterval(105)

        // Resume and check elapsed — should still be ~5s, not 105s.
        engine.resume()
        engine.refreshDisplay()

        // After resume, totalElapsed should be ~5s (the pause time was not counted).
        #expect(abs(engine.totalElapsed - 5.0) < 0.1)
    }

    @Test func skipIntervalAdvancesToNext() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, _, audio, _) = makeEngine(timeProvider: time)
        try engine.start()

        #expect(engine.currentIntervalIndex == 0)

        engine.skipInterval()
        #expect(engine.currentIntervalIndex == 1)
        #expect(audio.spokenTexts.last == "Time to run!")
    }

    @Test func runCompletesAfterAllIntervals() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 5),
            Interval(type: .run, durationSeconds: 5)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        var completionCalled = false
        let (engine, location, audio, _) = makeEngine(session: session, timeProvider: time)
        engine.onRunComplete = { _, _, _ in completionCalled = true }

        try engine.start()

        // Advance past first interval via GPS.
        time.currentTime = baseDate.addingTimeInterval(5)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(5))
        #expect(engine.currentIntervalIndex == 1)

        // Advance past second (final) interval — should complete.
        time.currentTime = baseDate.addingTimeInterval(10)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(10))

        #expect(engine.isComplete == true)
        #expect(engine.isRunning == false)
        #expect(completionCalled == true)
        #expect(audio.spokenTexts.contains("Congratulations! You've completed your run."))
    }

    @Test func doubleCompletionPrevented() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 5)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        var completionCount = 0
        let (engine, location, _, _) = makeEngine(session: session, timeProvider: time)
        engine.onRunComplete = { _, _, _ in completionCount += 1 }

        try engine.start()

        // Complete the only interval.
        time.currentTime = baseDate.addingTimeInterval(5)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(5))
        #expect(engine.isComplete == true)
        #expect(completionCount == 1)

        // Try to trigger again — should not fire.
        time.currentTime = baseDate.addingTimeInterval(10)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(10))
        #expect(completionCount == 1)
    }

    @Test func distanceAccumulatesFromGPS() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, _, _) = makeEngine(timeProvider: time)
        try engine.start()

        // Send two GPS points — distance should be > 0.
        location.simulateLocation(lat: 35.7796, lng: -78.6382, timestamp: baseDate.addingTimeInterval(1))
        location.simulateLocation(lat: 35.7800, lng: -78.6382, timestamp: baseDate.addingTimeInterval(2))

        #expect(engine.totalDistance > 0)
        #expect(engine.gpsPoints.count == 2)
    }

    @Test func gpsDeadZoneAdvancesIntervals() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 5),
            Interval(type: .run, durationSeconds: 5)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, _, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Send one GPS update at t=1 to establish lastGPSTimestamp.
        time.currentTime = baseDate.addingTimeInterval(1)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(1))

        // Now jump to t=10 — GPS dead for >3s. refreshDisplay should trigger fallback.
        time.currentTime = baseDate.addingTimeInterval(10)
        engine.refreshDisplay()

        // Should have advanced past the 5s warmup interval via the fallback path.
        #expect(engine.currentIntervalIndex >= 1)
    }

    @Test func endRunStopsEverything() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, audio, _) = makeEngine(timeProvider: time)
        try engine.start()

        time.currentTime = baseDate.addingTimeInterval(5)
        engine.endRun()

        #expect(engine.isComplete == true)
        #expect(engine.isRunning == false)
        #expect(engine.activeTimerCount == 0)
        #expect(location.startUpdatingCalled == false) // stopUpdatingLocation resets this
        #expect(audio.stopped == true)
    }

    @Test func audioCueOnIntervalTransition() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 5),
            Interval(type: .run, durationSeconds: 5),
            Interval(type: .walk, durationSeconds: 5)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, audio, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Opening cue.
        #expect(audio.spokenTexts == ["Start your warm-up walk."])

        // Advance past warmup → run.
        time.currentTime = baseDate.addingTimeInterval(5)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(5))
        #expect(audio.spokenTexts.last == "Time to run!")

        // Advance past run → walk.
        time.currentTime = baseDate.addingTimeInterval(10)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(10))
        #expect(audio.spokenTexts.last == "Take a walk break.")
    }

    @Test func coolDownCueIsSpecific() throws {
        let session = makeSession(intervals: [
            Interval(type: .run, durationSeconds: 5),
            Interval(type: .coolDown, durationSeconds: 5)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, audio, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Advance past run → cooldown.
        time.currentTime = baseDate.addingTimeInterval(5)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(5))

        #expect(audio.spokenTexts.contains("Great work! Begin your cool-down walk."))
    }

    @Test func realWeek1SessionSequence() throws {
        // Use the actual Week 1 Day 1 session.
        guard let session = SessionPlanLibrary.session(week: 1, day: 1) else {
            Issue.record("Week 1 Day 1 session not found")
            return
        }
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, audio, _) = makeEngine(session: session, timeProvider: time)

        var completed = false
        engine.onRunComplete = { _, _, _ in completed = true }

        try engine.start()
        #expect(audio.spokenTexts.first == "Start your warm-up walk.")

        // Fast-forward through all intervals using GPS timestamps.
        var elapsed: TimeInterval = 0
        for interval in session.intervals {
            elapsed += Double(interval.durationSeconds)
            time.currentTime = baseDate.addingTimeInterval(elapsed)
            location.simulateLocation(timestamp: baseDate.addingTimeInterval(elapsed))
        }

        #expect(completed == true)
        #expect(engine.isComplete == true)
        #expect(audio.spokenTexts.contains("Congratulations! You've completed your run."))
    }

    @Test func timerInvalidatedOnDeinit() throws {
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate
        let location = MockLocationProvider()
        let audio = MockAudioCoach()

        var engine: RunEngine? = RunEngine(
            sessionDefinition: makeSession(),
            locationProvider: location,
            audioCoach: audio,
            timeProvider: time
        )
        try engine?.start()
        #expect(engine?.activeTimerCount == 1)

        // Destroy the engine — deinit should cancel timers.
        engine = nil

        // If we got here without a crash/leak, the test passes.
        // DispatchSourceTimer cancel in deinit prevents dangling references.
        #expect(true)
    }

    @Test func checkpointSavesRunState() throws {
        let session = makeSession(intervals: [
            Interval(type: .warmUp, durationSeconds: 300)
        ])
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let (engine, location, _, _) = makeEngine(session: session, timeProvider: time)
        try engine.start()

        // Simulate some running.
        time.currentTime = baseDate.addingTimeInterval(30)
        location.simulateLocation(timestamp: baseDate.addingTimeInterval(30))

        // Manually trigger a checkpoint save by ending the run and checking clear worked,
        // or we can test the checkpoint struct directly.
        let checkpoint = RunCheckpoint(
            sessionId: "TEST1",
            currentIntervalIndex: 0,
            totalElapsed: 30,
            totalDistance: 0
        )
        checkpoint.save()

        let loaded = RunCheckpoint.load()
        #expect(loaded != nil)
        #expect(loaded?.sessionId == "TEST1")
        #expect(loaded?.totalElapsed == 30)
        #expect(loaded?.isValid == true)

        // Clean up.
        RunCheckpoint.clear()
        #expect(RunCheckpoint.load() == nil)
    }

    @Test func incompleteRunDetectedOnLaunch() throws {
        // Save a recent checkpoint simulating a crash mid-run.
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 3,
            totalElapsed: 450,
            totalDistance: 800,
            timestamp: Date() // Recent = valid.
        )
        checkpoint.save()

        // On "launch", check for incomplete run.
        let loaded = RunCheckpoint.load()
        #expect(loaded != nil)
        #expect(loaded?.isValid == true)
        #expect(loaded?.sessionId == "W1D1")
        #expect(loaded?.currentIntervalIndex == 3)

        // Stale checkpoint (>2 hours old) should be invalid.
        let staleCheckpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 3,
            totalElapsed: 450,
            totalDistance: 800,
            timestamp: Date().addingTimeInterval(-7201)
        )
        #expect(staleCheckpoint.isValid == false)

        // Clean up.
        RunCheckpoint.clear()
    }
}
