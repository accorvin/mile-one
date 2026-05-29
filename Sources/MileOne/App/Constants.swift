import Foundation

// MARK: - App Constants

public enum Constants {

    // MARK: - Program

    /// Total number of weeks in the C25K program.
    public static let totalWeeks = 9
    /// Number of sessions per week.
    public static let sessionsPerWeek = 3

    // MARK: - Profile

    /// The singleton profileId used by UserProfile.
    public static let singletonProfileId = "singleton"

    // MARK: - GPS

    /// GPS accuracy threshold after the grace period (meters).
    public static let gpsAccuracyThreshold: Double = 50
    /// Grace period at the start of a run during which all GPS points are accepted.
    public static let gpsGracePeriodSeconds: TimeInterval = 60
    /// Minimum distance filter for CLLocationManager (meters).
    public static let gpsDistanceFilter: Double = 5

    // MARK: - Calorie Calculator

    public static let walkingMET: Double = 3.5
    public static let runningMET: Double = 8.0

    // MARK: - DataStore

    /// Number of GPS points to batch-insert at once.
    public static let gpsBatchSize = 50

    // MARK: - CloudKit

    public static let iCloudContainerIdentifier = "iCloud.com.mileone.app"
}
