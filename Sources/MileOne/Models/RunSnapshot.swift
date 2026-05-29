import Foundation

// MARK: - RunSnapshot

/// Immutable snapshot of run state for the view layer.
/// Published by RunEngine via callback, consumed by RunViewModel.
public struct RunSnapshot: Sendable {
    public let currentIntervalType: IntervalType
    public let currentIntervalLabel: String
    public let intervalRemaining: TimeInterval
    public let totalElapsed: TimeInterval
    public let totalDistance: Double
    public let currentIntervalIndex: Int
    public let totalIntervals: Int
    public let isRunning: Bool
    public let isPaused: Bool
    public let isComplete: Bool
    public let nextIntervalType: IntervalType?

    public init(
        currentIntervalType: IntervalType,
        currentIntervalLabel: String,
        intervalRemaining: TimeInterval,
        totalElapsed: TimeInterval,
        totalDistance: Double,
        currentIntervalIndex: Int,
        totalIntervals: Int,
        isRunning: Bool,
        isPaused: Bool,
        isComplete: Bool,
        nextIntervalType: IntervalType? = nil
    ) {
        self.currentIntervalType = currentIntervalType
        self.currentIntervalLabel = currentIntervalLabel
        self.intervalRemaining = intervalRemaining
        self.totalElapsed = totalElapsed
        self.totalDistance = totalDistance
        self.currentIntervalIndex = currentIntervalIndex
        self.totalIntervals = totalIntervals
        self.isRunning = isRunning
        self.isPaused = isPaused
        self.isComplete = isComplete
        self.nextIntervalType = nextIntervalType
    }

    /// Empty snapshot for initialization.
    public static let empty = RunSnapshot(
        currentIntervalType: .warmUp,
        currentIntervalLabel: "—",
        intervalRemaining: 0,
        totalElapsed: 0,
        totalDistance: 0,
        currentIntervalIndex: 0,
        totalIntervals: 0,
        isRunning: false,
        isPaused: false,
        isComplete: false,
        nextIntervalType: nil
    )
}
