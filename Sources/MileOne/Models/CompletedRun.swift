import Foundation
import SwiftData

// MARK: - CompletedRun

@Model
public final class CompletedRun {
    public var id: UUID
    public var date: Date
    public var distanceMeters: Double
    public var durationSeconds: Double
    public var calories: Double

    // CloudKit requires primitive storage — stored as raw String, nil when not rated.
    // Use the computed `effortRatingEnum` for type-safe access.
    public var effortRating: String?

    public var weekNumber: Int
    public var sessionNumber: Int
    public var isFreeRun: Bool
    public var averagePaceSecondsPerKm: Double?
    public var averageHeartRate: Double?

    // HealthKit reference UUID string
    public var healthKitWorkoutUUID: String?

    // GPS points — cascade delete, nil by default (not [] — CloudKit treats them differently)
    @Relationship(deleteRule: .cascade, inverse: \GPSPoint.run)
    public var gpsPoints: [GPSPoint]?

    public var createdAt: Date

    public init(weekNumber: Int, sessionNumber: Int, isFreeRun: Bool = false) {
        self.id = UUID()
        self.date = Date()
        self.distanceMeters = 0
        self.durationSeconds = 0
        self.calories = 0
        self.effortRating = nil
        self.weekNumber = weekNumber
        self.sessionNumber = sessionNumber
        self.isFreeRun = isFreeRun
        self.averagePaceSecondsPerKm = nil
        self.averageHeartRate = nil
        self.healthKitWorkoutUUID = nil
        self.gpsPoints = nil  // nil, NOT [] — CloudKit distinguishes nil from empty
        self.createdAt = Date()
    }

    /// Type-safe accessor for the stored raw string.
    public var effortRatingEnum: EffortRating? {
        guard let raw = effortRating else { return nil }
        return EffortRating(rawValue: raw)
    }
}
