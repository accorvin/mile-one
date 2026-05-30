import Testing
import Foundation
@testable import MileOne

// MARK: - RunCheckpointTests

@Suite("RunCheckpoint Tests")
struct RunCheckpointTests {

    // Each test uses a unique UserDefaults suite so they don't share state.
    private func makeDefaults(id: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: "com.mileone.test.checkpoint.\(id)")!
        suite.removePersistentDomain(forName: "com.mileone.test.checkpoint.\(id)")
        return suite
    }

    // MARK: - Persistence round-trip

    @Test("save then load returns identical checkpoint")
    func saveAndLoadRoundTrip() throws {
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 3,
            totalElapsed: 142.5,
            totalDistance: 0.87,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        )
        let defaults = makeDefaults(id: "roundtrip")

        checkpoint.save(to: defaults)
        let loaded = RunCheckpoint.load(from: defaults)

        let c = try #require(loaded, "load() should return a checkpoint after save()")
        #expect(c.sessionId == "W1D1")
        #expect(c.currentIntervalIndex == 3)
        #expect(abs(c.totalElapsed - 142.5) < 0.001)
        #expect(abs(c.totalDistance - 0.87) < 0.001)
        #expect(abs(c.timestamp.timeIntervalSince1970 - 1_000_000) < 0.001)
    }

    @Test("load returns nil when nothing saved")
    func loadReturnsNilWhenEmpty() {
        let defaults = makeDefaults(id: "empty")
        #expect(RunCheckpoint.load(from: defaults) == nil)
    }

    @Test("clear removes saved checkpoint")
    func clearRemovesCheckpoint() {
        let defaults = makeDefaults(id: "clear")
        RunCheckpoint(
            sessionId: "W2D3",
            currentIntervalIndex: 0,
            totalElapsed: 10,
            totalDistance: 0.05
        ).save(to: defaults)

        RunCheckpoint.clear(from: defaults)

        #expect(RunCheckpoint.load(from: defaults) == nil)
    }

    @Test("second save overwrites first")
    func saveOverwritesPrevious() throws {
        let defaults = makeDefaults(id: "overwrite")

        RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 1,
            totalElapsed: 60,
            totalDistance: 0.3
        ).save(to: defaults)

        RunCheckpoint(
            sessionId: "W3D2",
            currentIntervalIndex: 5,
            totalElapsed: 900,
            totalDistance: 2.1
        ).save(to: defaults)

        let loaded = try #require(RunCheckpoint.load(from: defaults))
        #expect(loaded.sessionId == "W3D2")
        #expect(loaded.currentIntervalIndex == 5)
    }

    // MARK: - isValid

    @Test("isValid returns true for fresh checkpoint")
    func isValidFreshCheckpoint() {
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 0,
            totalElapsed: 0,
            totalDistance: 0,
            timestamp: Date()
        )
        #expect(checkpoint.isValid == true)
    }

    @Test("isValid returns false for checkpoint older than 2 hours")
    func isValidExpiredCheckpoint() {
        let twoHoursAgo = Date().addingTimeInterval(-7201)
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 0,
            totalElapsed: 0,
            totalDistance: 0,
            timestamp: twoHoursAgo
        )
        #expect(checkpoint.isValid == false)
    }

    @Test("isValid returns true for checkpoint exactly at 2-hour boundary")
    func isValidAtBoundary() {
        // Slightly under 2 hours → valid
        let justUnder = Date().addingTimeInterval(-7199)
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 0,
            totalElapsed: 0,
            totalDistance: 0,
            timestamp: justUnder
        )
        #expect(checkpoint.isValid == true)
    }

    @Test("isValid returns false for future timestamp (clock skew)")
    func isValidFutureTimestamp() {
        // More than 2 hours in the future — treat as invalid
        let farFuture = Date().addingTimeInterval(7201)
        let checkpoint = RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 0,
            totalElapsed: 0,
            totalDistance: 0,
            timestamp: farFuture
        )
        #expect(checkpoint.isValid == false)
    }

    // MARK: - Data integrity

    @Test("checkpoint preserves zero values")
    func checkpointPreservesZeroValues() throws {
        let defaults = makeDefaults(id: "zeros")
        RunCheckpoint(
            sessionId: "",
            currentIntervalIndex: 0,
            totalElapsed: 0,
            totalDistance: 0,
            timestamp: Date(timeIntervalSince1970: 0)
        ).save(to: defaults)

        let loaded = try #require(RunCheckpoint.load(from: defaults))
        #expect(loaded.sessionId == "")
        #expect(loaded.currentIntervalIndex == 0)
        #expect(loaded.totalElapsed == 0)
        #expect(loaded.totalDistance == 0)
    }

    @Test("checkpoint preserves large elapsed and distance values")
    func checkpointPreservesLargeValues() throws {
        let defaults = makeDefaults(id: "large")
        RunCheckpoint(
            sessionId: "W9D3",
            currentIntervalIndex: 26,
            totalElapsed: 3599.99,
            totalDistance: 9.99,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        ).save(to: defaults)

        let loaded = try #require(RunCheckpoint.load(from: defaults))
        #expect(abs(loaded.totalElapsed - 3599.99) < 0.001)
        #expect(abs(loaded.totalDistance - 9.99) < 0.001)
        #expect(loaded.currentIntervalIndex == 26)
    }

    @Test("clear on empty store is a no-op")
    func clearOnEmptyStoreIsNoOp() {
        let defaults = makeDefaults(id: "clearempty")
        // Should not crash
        RunCheckpoint.clear(from: defaults)
        #expect(RunCheckpoint.load(from: defaults) == nil)
    }

    // MARK: - RunEngine integration: checkpoint written and cleared

    @Test("RunEngine clears checkpoint on completion")
    @MainActor
    func runEngineClearsCheckpointOnCompletion() throws {
        let defaults = makeDefaults(id: "engineclear")

        // Plant a stale checkpoint
        RunCheckpoint(
            sessionId: "W1D1",
            currentIntervalIndex: 0,
            totalElapsed: 10,
            totalDistance: 0.05
        ).save(to: defaults)
        #expect(RunCheckpoint.load(from: defaults) != nil)

        let session = SessionDefinition(
            id: "W1D1",
            week: 1,
            dayInWeek: 1,
            intervals: [Interval(type: .warmUp, durationSeconds: 5)]
        )
        let time = MockTimeProvider()
        let base = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = base
        let location = MockLocationProvider()

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: location,
            audioCoach: MockAudioCoach(),
            timeProvider: time,
            checkpointStore: defaults
        )

        try engine.start()
        // Advance past the single interval via GPS
        time.currentTime = base.addingTimeInterval(5)
        location.simulateLocation(timestamp: base.addingTimeInterval(5))

        #expect(engine.isComplete == true)
        #expect(RunCheckpoint.load(from: defaults) == nil,
                "RunEngine must clear the checkpoint when run completes")
    }
}
