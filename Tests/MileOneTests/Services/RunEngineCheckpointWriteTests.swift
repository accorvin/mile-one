import Testing
import Foundation
@testable import MileOne

// MARK: - RunEngineCheckpointWriteTests

@MainActor
@Suite("RunEngine Checkpoint Write Tests")
struct RunEngineCheckpointWriteTests {

    // MARK: - Helpers

    private func makeDefaults(id: String) -> UserDefaults {
        let name = "com.mileone.test.checkpoint.write.\(id)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    private func makeSession(id: String = "W1D1") -> SessionDefinition {
        SessionDefinition(
            id: id,
            week: 1,
            dayInWeek: 1,
            intervals: [
                Interval(type: .warmUp,   durationSeconds: 300),
                Interval(type: .run,      durationSeconds: 600),
                Interval(type: .coolDown, durationSeconds: 300),
            ]
        )
    }

    // MARK: - Tests

    @Test("saveCheckpoint writes checkpoint with correct sessionId")
    func saveCheckpointWritesSessionId() throws {
        let defaults = makeDefaults(id: "write-sessionid")
        let session = makeSession(id: "W3D2")
        let time = MockTimeProvider()
        time.currentTime = Date(timeIntervalSince1970: 1_000_000)

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: MockLocationProvider(),
            audioCoach: MockAudioCoach(),
            timeProvider: time,
            checkpointStore: defaults
        )
        try engine.start()

        // Directly call the internal saveCheckpoint
        engine.saveCheckpoint()

        let checkpoint = RunCheckpoint.load(from: defaults)
        #expect(checkpoint != nil, "A checkpoint should be written")
        #expect(checkpoint?.sessionId == "W3D2",
                "Checkpoint sessionId must match the session's id")
    }

    @Test("saveCheckpoint records currentIntervalIndex")
    func saveCheckpointRecordsIntervalIndex() throws {
        let defaults = makeDefaults(id: "write-intervalindex")
        let session = makeSession()
        let time = MockTimeProvider()
        let base = Date(timeIntervalSince1970: 2_000_000)
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

        // Advance past the warm-up so the engine moves to interval 1
        time.currentTime = base.addingTimeInterval(301)
        location.simulateLocation(timestamp: base.addingTimeInterval(301))

        #expect(engine.currentIntervalIndex == 1)

        engine.saveCheckpoint()

        let checkpoint = RunCheckpoint.load(from: defaults)
        #expect(checkpoint?.currentIntervalIndex == 1,
                "Checkpoint interval index must match engine's currentIntervalIndex")
    }

    @Test("endRun clears the checkpoint")
    func endRunClearsCheckpoint() throws {
        let defaults = makeDefaults(id: "write-endrun-clear")
        let session = makeSession()
        let time = MockTimeProvider()
        let base = Date(timeIntervalSince1970: 3_000_000)
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

        // Save a checkpoint first so we have something to clear
        engine.saveCheckpoint()
        #expect(RunCheckpoint.load(from: defaults) != nil,
                "Checkpoint should be present before endRun")

        // End the run
        engine.endRun()

        #expect(RunCheckpoint.load(from: defaults) == nil,
                "endRun must clear the checkpoint from the store")
    }
}
