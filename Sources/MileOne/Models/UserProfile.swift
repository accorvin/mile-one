import Foundation
import SwiftData

// MARK: - UserProfile

@Model
public final class UserProfile {
    @Attribute(.unique) public var profileId: String  // always "singleton"

    // Biometrics
    public var heightCm: Double
    public var weightKg: Double
    public var birthYear: Int

    // CloudKit requires primitive storage — enums stored as raw String.
    // Use the computed `biologicalSexEnum` property for type-safe access.
    public var biologicalSex: String

    // Program Progress
    public var currentWeek: Int
    public var completedSessionsThisWeek: Int
    public var programStartDate: Date?
    public var hasGraduated: Bool
    public var startingWeek: Int

    // Schedule
    // ⚠️ CloudKit does not guarantee array ordering after round-trip.
    // Always sort on read: `profile.runDays.sorted()`
    public var runDays: [Int]
    public var reminderHour: Int
    public var reminderMinute: Int
    public var remindersEnabled: Bool

    // Preferences
    public var usesMetric: Bool
    public var iCloudSyncEnabled: Bool

    // Onboarding
    public var hasCompletedOnboarding: Bool

    // Timestamps
    public var createdAt: Date
    public var updatedAt: Date

    public init() {
        self.profileId = "singleton"
        self.heightCm = 170
        self.weightKg = 70
        self.birthYear = 1990
        self.biologicalSex = BiologicalSex.male.rawValue
        self.currentWeek = 1
        self.completedSessionsThisWeek = 0
        self.programStartDate = nil
        self.hasGraduated = false
        self.startingWeek = 1
        self.runDays = [2, 4, 6]  // Mon, Wed, Fri
        self.reminderHour = 7
        self.reminderMinute = 0
        self.remindersEnabled = true
        self.usesMetric = false
        self.iCloudSyncEnabled = true
        self.hasCompletedOnboarding = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Type-safe accessor for the stored raw string.
    public var biologicalSexEnum: BiologicalSex? {
        BiologicalSex(rawValue: biologicalSex)
    }
}
