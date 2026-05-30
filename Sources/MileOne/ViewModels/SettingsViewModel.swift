import Foundation
import Observation

// MARK: - SettingsViewModel

/// ViewModel for the settings screen.
/// Reads and writes UserProfile via the DataStore.
/// Reschedules notifications when run days, reminder time, or notification toggle changes.
@MainActor
@Observable
public final class SettingsViewModel {

    // MARK: - Injected Dependencies

    private let dataStore: any DataStoreProviding
    private let notificationService: NotificationService

    // MARK: - Published State

    /// Whether the user prefers metric (true) or imperial (false).
    public var usesMetric: Bool = false

    /// Weekday numbers for scheduled runs (1=Sunday … 7=Saturday).
    public var runDays: [Int] = [2, 4, 6]  // Mon, Wed, Fri

    /// Hour component for daily reminder (0–23).
    public var reminderHour: Int = 8

    /// Minute component for daily reminder (0–59).
    public var reminderMinute: Int = 0

    /// Whether run reminders are enabled.
    public var remindersEnabled: Bool = true

    /// Starting week number (1–9).
    public var startingWeek: Int = 1

    /// User's height in centimeters.
    public var heightCm: Double = 170

    /// User's weight in kilograms.
    public var weightKg: Double = 70

    /// User's birth year.
    public var birthYear: Int = 1990

    /// User's biological sex.
    public var biologicalSex: BiologicalSex = .male

    /// Read-only: whether iCloud sync is currently enabled.
    /// This is set at first launch and cannot be changed at runtime.
    public private(set) var iCloudSyncEnabled: Bool = false

    /// Indicates a loading or saving operation is in progress.
    public private(set) var isLoading: Bool = false

    /// Non-nil when an error has occurred.
    public private(set) var errorMessage: String?

    // MARK: - Init

    public init(
        dataStore: any DataStoreProviding,
        notificationService: NotificationService = NotificationService()
    ) {
        self.dataStore = dataStore
        self.notificationService = notificationService
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    // MARK: - Actions

    /// Loads current settings from the DataStore (UserProfile).
    public func loadSettings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let profile = try await dataStore.fetchUserProfile() else { return }
            usesMetric = profile.usesMetric
            runDays = profile.runDays
            reminderHour = profile.reminderHour
            reminderMinute = profile.reminderMinute
            remindersEnabled = profile.remindersEnabled
            startingWeek = profile.startingWeek
            heightCm = profile.heightCm
            weightKg = profile.weightKg
            birthYear = profile.birthYear
            biologicalSex = profile.biologicalSex
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves current settings back to the DataStore and reschedules notifications if needed.
    public func saveSettings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Fetch current profile to preserve fields we're not editing here
            let existing = try await dataStore.fetchUserProfile()

            try await dataStore.saveUserProfile(
                heightCm: heightCm,
                weightKg: weightKg,
                birthYear: birthYear,
                biologicalSex: biologicalSex,
                currentWeek: existing?.currentWeek ?? 1,
                completedSessionsThisWeek: existing?.completedSessionsThisWeek ?? 0,
                hasCompletedOnboarding: existing?.hasCompletedOnboarding ?? true,
                hasGraduated: existing?.hasGraduated ?? false,
                startingWeek: startingWeek,
                usesMetric: usesMetric,
                runDays: runDays,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                remindersEnabled: remindersEnabled
            )

            // Reschedule notifications to reflect new settings
            if remindersEnabled {
                let time = DateComponents(hour: reminderHour, minute: reminderMinute)
                try await notificationService.scheduleRunReminders(runDays: runDays, time: time)
            } else {
                notificationService.cancelAllReminders()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
