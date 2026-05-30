import Foundation

// MARK: - EndRunConfirmation

/// State for the "End Run" confirmation flow.
/// The user must explicitly confirm before a run is terminated to prevent accidental data loss.
public struct EndRunConfirmation: Sendable {
    /// Whether the confirmation sheet/alert is currently visible.
    public var showingConfirmation: Bool

    /// Total elapsed time of the run in seconds.
    public let elapsedTime: TimeInterval

    /// Total distance covered in meters.
    public let distance: Double

    public init(
        showingConfirmation: Bool,
        elapsedTime: TimeInterval,
        distance: Double
    ) {
        self.showingConfirmation = showingConfirmation
        self.elapsedTime = elapsedTime
        self.distance = distance
    }
}
