import Foundation

// MARK: - SaveRunResult

/// Result returned from PostRunOrchestrator.saveRun(...).
/// Captures the outcome of both SwiftData and HealthKit save operations.
public struct SaveRunResult: Sendable {
    /// The UUID of the saved CompletedRun in SwiftData.
    public let runId: UUID

    /// Whether the run was successfully persisted to SwiftData.
    public let swiftDataSaved: Bool

    /// Whether the run was successfully saved to HealthKit.
    public let healthKitSaved: Bool

    /// Non-nil when HealthKit save failed (may be nil if HealthKit was skipped).
    public let healthKitError: Error?

    public init(
        runId: UUID,
        swiftDataSaved: Bool,
        healthKitSaved: Bool,
        healthKitError: Error?
    ) {
        self.runId = runId
        self.swiftDataSaved = swiftDataSaved
        self.healthKitSaved = healthKitSaved
        self.healthKitError = healthKitError
    }
}
