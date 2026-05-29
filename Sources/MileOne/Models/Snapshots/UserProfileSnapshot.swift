import Foundation

// MARK: - UserProfileSnapshot

/// Value-type DTO returned from DataStore. Safe to pass across actor boundaries.
/// Excludes profileId, createdAt, updatedAt, programStartDate, and iCloudSyncEnabled
/// (those are storage/sync concerns, not presentation concerns).
public struct UserProfileSnapshot: Sendable {
    public let heightCm: Double
    public let weightKg: Double
    public let birthYear: Int
    public let biologicalSex: BiologicalSex
    public let currentWeek: Int
    public let completedSessionsThisWeek: Int
    public let hasCompletedOnboarding: Bool
    public let hasGraduated: Bool
    public let startingWeek: Int
    public let usesMetric: Bool
    public let runDays: [Int]
    public let reminderHour: Int
    public let reminderMinute: Int
    public let remindersEnabled: Bool

    public init(
        heightCm: Double,
        weightKg: Double,
        birthYear: Int,
        biologicalSex: BiologicalSex,
        currentWeek: Int,
        completedSessionsThisWeek: Int,
        hasCompletedOnboarding: Bool,
        hasGraduated: Bool,
        startingWeek: Int,
        usesMetric: Bool,
        runDays: [Int],
        reminderHour: Int,
        reminderMinute: Int,
        remindersEnabled: Bool
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.birthYear = birthYear
        self.biologicalSex = biologicalSex
        self.currentWeek = currentWeek
        self.completedSessionsThisWeek = completedSessionsThisWeek
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasGraduated = hasGraduated
        self.startingWeek = startingWeek
        self.usesMetric = usesMetric
        self.runDays = runDays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.remindersEnabled = remindersEnabled
    }
}
