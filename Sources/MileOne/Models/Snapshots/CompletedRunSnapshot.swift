import Foundation

// MARK: - CompletedRunSnapshot

/// Value-type DTO returned from DataStore. Safe to pass across actor boundaries.
public struct CompletedRunSnapshot: Identifiable, Sendable {
    public let id: UUID
    public let weekNumber: Int
    public let sessionNumber: Int
    public let date: Date
    public let distanceMeters: Double
    public let durationSeconds: Double
    public let calories: Double
    public let averagePaceSecondsPerKm: Double?
    public let averageHeartRate: Double?
    public let effortRating: EffortRating?
    public let isFreeRun: Bool

    public init(
        id: UUID,
        weekNumber: Int,
        sessionNumber: Int,
        date: Date,
        distanceMeters: Double,
        durationSeconds: Double,
        calories: Double,
        averagePaceSecondsPerKm: Double?,
        averageHeartRate: Double?,
        effortRating: EffortRating?,
        isFreeRun: Bool
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.sessionNumber = sessionNumber
        self.date = date
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        self.averageHeartRate = averageHeartRate
        self.effortRating = effortRating
        self.isFreeRun = isFreeRun
    }
}
