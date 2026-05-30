import Foundation
import Observation

// MARK: - OnboardingStep

/// The ordered steps of the onboarding flow.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case biometrics
    case activityLevel
    case schedule
    case permissions
}

// MARK: - OnboardingViewModel

/// Manages state for the multi-step onboarding flow.
@MainActor
@Observable
public final class OnboardingViewModel {

    // MARK: - Step Navigation

    public private(set) var currentStep: OnboardingStep = .welcome

    // MARK: - Biometrics

    public var heightCm: Double = 170
    public var weightKg: Double = 70
    public var birthYear: Int = 1990
    public var biologicalSex: BiologicalSex = .male
    public var unitPreference: UnitPreference = UnitPreference.default()

    // MARK: - Activity Level

    public var activityLevel: ActivityLevel = .couchPotato

    // MARK: - Schedule

    /// Selected run days (weekday numbers: 1=Sun, 2=Mon…7=Sat). Default Mon/Wed/Fri.
    public var runDays: Set<Int> = [2, 4, 6]
    public var reminderHour: Int = 7
    public var reminderMinute: Int = 0
    public var remindersEnabled: Bool = true

    // MARK: - Dependencies

    private let dataStore: any DataStoreProviding
    private let notificationService: NotificationService

    // MARK: - Init

    public init(
        dataStore: any DataStoreProviding,
        notificationService: NotificationService = NotificationService()
    ) {
        self.dataStore = dataStore
        self.notificationService = notificationService
    }

    // MARK: - Navigation

    public func advance() {
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep), idx + 1 < steps.count else { return }
        currentStep = steps[idx + 1]
    }

    public func goBack() {
        let steps = OnboardingStep.allCases
        guard let idx = steps.firstIndex(of: currentStep), idx > 0 else { return }
        currentStep = steps[idx - 1]
    }

    // MARK: - Completion

    /// Saves the profile and schedules notifications. Call on the final step.
    public func completeOnboarding() async throws {
        let suggestedWeek = DashboardViewModel.suggestedStartWeek(for: activityLevel)
        let sortedDays = Array(runDays).sorted()

        try await dataStore.saveUserProfile(
            heightCm: heightCm,
            weightKg: weightKg,
            birthYear: birthYear,
            biologicalSex: biologicalSex,
            currentWeek: suggestedWeek,
            completedSessionsThisWeek: 0,
            hasCompletedOnboarding: true,
            hasGraduated: false,
            startingWeek: suggestedWeek,
            usesMetric: unitPreference == .metric,
            runDays: sortedDays,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            remindersEnabled: remindersEnabled
        )

        if remindersEnabled {
            let timeComponents = DateComponents(hour: reminderHour, minute: reminderMinute)
            try await notificationService.scheduleRunReminders(
                runDays: sortedDays,
                time: timeComponents
            )
        }
    }
}
