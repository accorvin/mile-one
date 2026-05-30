import Testing
import Foundation
import CoreLocation
@testable import MileOne

/// Tests for pause/resume correctness across interval boundaries.
@MainActor
@Suite("RunEngine Pause/Resume Interval Tests")
struct RunEnginePauseResumeTests {

    private func makeEngine(intervals: [Interval], baseDate: Date, time: MockTimeProvider) -> (RunEngine, MockLocationProvider) {
        let session = SessionDefinition(id: "PAUSE_TEST", week: 1, dayInWeek: 1, intervals: intervals)
        let location = MockLocationProvider()
        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: location,
            audioCoach: MockAudioCoach(),
            timeProvider: time
        )
        time.currentTime = baseDate
        return (engine, location)
    }

    @Test("Pause mid-interval then resume: interval still advances at correct time")
    func pauseResumeIntervalAdvancesCorrectly() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let time = MockTimeProvider()
        let (engine, location) = makeEngine(
            intervals: [
                Interval(type: .warmUp, durationSeconds: 20),
                Interval(type: .run, durationSeconds: 20)
            ],
            baseDate: base,
            time: time
        )

        try engine.start()
        #expect(engine.currentIntervalIndex == 0)

        // Run for 8 seconds, then pause
        time.currentTime = base.addingTimeInterval(8)
        engine.pause()
        #expect(engine.isPaused == true)

        // Pause for 50 seconds (should not count)
        time.currentTime = base.addingTimeInterval(58)

        // Resume
        engine.resume()
        #expect(engine.isPaused == false)
        #expect(engine.currentIntervalIndex == 0, "Should still be in warmup after 8s active + pause")

        // Run 12 more seconds (total active = 8 + 12 = 20s → interval completes)
        let resumeTime = base.addingTimeInterval(58)
        time.currentTime = resumeTime.addingTimeInterval(12)
        location.simulateLocation(timestamp: resumeTime.addingTimeInterval(12))

        #expect(engine.currentIntervalIndex == 1, "Warmup (20s) should complete after 8s + 12s active time, ignoring the 50s pause")
    }

    @Test("Pause at exact interval boundary doesn't double-advance")
    func pauseAtBoundaryDoesNotDoubleAdvance() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let time = MockTimeProvider()
        let (engine, location) = makeEngine(
            intervals: [
                Interval(type: .warmUp, durationSeconds: 10),
                Interval(type: .run, durationSeconds: 10),
                Interval(type: .coolDown, durationSeconds: 10)
            ],
            baseDate: base,
            time: time
        )

        try engine.start()

        // GPS drives interval advance at exactly 10s
        time.currentTime = base.addingTimeInterval(10)
        location.simulateLocation(timestamp: base.addingTimeInterval(10))
        #expect(engine.currentIntervalIndex == 1)

        // Now pause immediately after advance
        engine.pause()
        #expect(engine.currentIntervalIndex == 1, "Should still be at index 1 after pause")
        #expect(engine.isPaused == true)

        // Resume and verify still at index 1
        time.currentTime = base.addingTimeInterval(15)
        engine.resume()
        #expect(engine.currentIntervalIndex == 1, "Index should not have changed during pause")
    }

    @Test("Multiple pause/resume cycles: elapsed time accurate")
    func multiplePauseResumeCyclesElapsedAccurate() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let time = MockTimeProvider()
        let (engine, _) = makeEngine(
            intervals: [Interval(type: .warmUp, durationSeconds: 300)],
            baseDate: base,
            time: time
        )

        try engine.start()

        // Run 5s, pause 10s, run 5s, pause 10s, run 5s = 15s active, 20s paused
        time.currentTime = base.addingTimeInterval(5)
        engine.pause()

        time.currentTime = base.addingTimeInterval(15)
        engine.resume()

        time.currentTime = base.addingTimeInterval(20)
        engine.pause()

        time.currentTime = base.addingTimeInterval(30)
        engine.resume()

        time.currentTime = base.addingTimeInterval(35)
        engine.refreshDisplay()

        // Total active = 15s, total wall = 35s
        #expect(abs(engine.totalElapsed - 15.0) < 0.5,
                "After 3 pauses totalling 20s, elapsed should be ~15s not \(engine.totalElapsed)")
    }

    @Test("Interval elapsed resets correctly after interval advance mid-run")
    func intervalElapsedResetsAfterAdvance() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let time = MockTimeProvider()
        let (engine, location) = makeEngine(
            intervals: [
                Interval(type: .warmUp, durationSeconds: 10),
                Interval(type: .run, durationSeconds: 20)
            ],
            baseDate: base,
            time: time
        )

        try engine.start()

        // Advance past warmup at t=10
        time.currentTime = base.addingTimeInterval(10)
        location.simulateLocation(timestamp: base.addingTimeInterval(10))
        #expect(engine.currentIntervalIndex == 1)

        // Run 8s into the run interval (t=18), then pause
        time.currentTime = base.addingTimeInterval(18)
        engine.pause()
        #expect(engine.isPaused == true)

        // Resume at t=25 (paused for 7s)
        time.currentTime = base.addingTimeInterval(25)
        engine.resume()

        // GPS at t=30: 5s since resume, 8+5=13s active in run interval — not yet complete
        time.currentTime = base.addingTimeInterval(30)
        location.simulateLocation(timestamp: base.addingTimeInterval(30))
        #expect(engine.currentIntervalIndex == 1, "Run interval needs 20s active; only 13s elapsed")

        // GPS at t=37: 12s since resume, 8+12=20s active in run interval — complete!
        time.currentTime = base.addingTimeInterval(37)
        location.simulateLocation(timestamp: base.addingTimeInterval(37))
        #expect(engine.isComplete == true, "After 20s active in run interval, run should complete")
    }
}
