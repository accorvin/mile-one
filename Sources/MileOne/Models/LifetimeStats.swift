import Foundation

// MARK: - LifetimeStats

/// Aggregated statistics across all of a user's completed runs.
public struct LifetimeStats: Sendable {
    public let totalDistance: Double   // meters
    public let totalDuration: Double   // seconds
    public let totalCalories: Double
    public let totalRuns: Int

    public init(
        totalDistance: Double,
        totalDuration: Double,
        totalCalories: Double,
        totalRuns: Int
    ) {
        self.totalDistance = totalDistance
        self.totalDuration = totalDuration
        self.totalCalories = totalCalories
        self.totalRuns = totalRuns
    }

    /// Zero-value for empty history.
    public static let zero = LifetimeStats(
        totalDistance: 0,
        totalDuration: 0,
        totalCalories: 0,
        totalRuns: 0
    )
}
