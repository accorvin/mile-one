import Testing
import Foundation
@testable import MileOne

/// Tests for PaceFormatter, DateHelpers, CalorieCalculator edge cases,
/// NotificationService, and OnboardingViewModel completion.
@Suite("Utility Tests")
struct UtilityTests {

    // MARK: - PaceFormatter

    @Test("PaceFormatter: standard paces format correctly")
    func paceFormatterStandard() {
        #expect(PaceFormatter.format(secondsPerKm: 330) == "5:30")
        #expect(PaceFormatter.format(secondsPerKm: 360) == "6:00")
        #expect(PaceFormatter.format(secondsPerKm: 600) == "10:00")
    }

    @Test("PaceFormatter: zero returns --:--")
    func paceFormatterZero() {
        #expect(PaceFormatter.format(secondsPerKm: 0) == "--:--")
    }

    @Test("PaceFormatter: negative value returns --:--")
    func paceFormatterNegative() {
        #expect(PaceFormatter.format(secondsPerKm: -100) == "--:--")
    }

    @Test("PaceFormatter: NaN returns --:--")
    func paceFormatterNaN() {
        #expect(PaceFormatter.format(secondsPerKm: Double.nan) == "--:--")
    }

    @Test("PaceFormatter: infinity returns --:--")
    func paceFormatterInfinity() {
        #expect(PaceFormatter.format(secondsPerKm: Double.infinity) == "--:--")
    }

    @Test("PaceFormatter: per-mile conversion 360 s/km → 9:39/mi")
    func paceFormatterPerMile() {
        // 360 s/km × 1.60934 = 579.36 s/mi → rounds to 579s = 9:39
        let result = PaceFormatter.formatPerMile(secondsPerKm: 360)
        #expect(result == "9:39")
    }

    @Test("PaceFormatter: per-mile with zero returns --:--")
    func paceFormatterPerMileZero() {
        #expect(PaceFormatter.formatPerMile(secondsPerKm: 0) == "--:--")
    }

    // MARK: - DateHelpers

    @Test("DateHelpers.formatDuration: under 1 hour uses M:SS")
    func formatDurationUnderHour() {
        #expect(DateHelpers.formatDuration(0) == "0:00")
        #expect(DateHelpers.formatDuration(65) == "1:05")
        #expect(DateHelpers.formatDuration(3599) == "59:59")
    }

    @Test("DateHelpers.formatDuration: exactly 1 hour uses H:MM:SS")
    func formatDurationExactlyOneHour() {
        #expect(DateHelpers.formatDuration(3600) == "1:00:00")
    }

    @Test("DateHelpers.formatDuration: over 1 hour uses H:MM:SS")
    func formatDurationOverHour() {
        #expect(DateHelpers.formatDuration(3661) == "1:01:01")
        #expect(DateHelpers.formatDuration(7384) == "2:03:04")
    }

    @Test("DateHelpers.isToday: today returns true")
    func isTodayTrue() {
        #expect(DateHelpers.isToday(Date()) == true)
    }

    @Test("DateHelpers.isToday: yesterday returns false")
    func isTodayFalse() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(DateHelpers.isToday(yesterday) == false)
    }

    // MARK: - CalorieCalculator edge cases

    @Test("CalorieCalculator: run-only intervals use running MET (8.0)")
    func caloriesRunOnlyMET() {
        // MET 8.0, 70 kg, 1 hour → 560 kcal
        let result = CalorieCalculator.calculate(
            weightKg: 70,
            intervals: [Interval(type: .run, durationSeconds: 3600)],
            actualDurationSeconds: 3600
        )
        #expect(abs(result - 560.0) < 1.0,
                "Run-only should use MET 8.0: expected ~560, got \(result)")
    }

    @Test("CalorieCalculator: walk-only intervals use walking MET (3.5)")
    func caloriesWalkOnlyMET() {
        // MET 3.5, 70 kg, 1 hour → 245 kcal
        let result = CalorieCalculator.calculate(
            weightKg: 70,
            intervals: [Interval(type: .walk, durationSeconds: 3600)],
            actualDurationSeconds: 3600
        )
        #expect(abs(result - 245.0) < 1.0,
                "Walk-only should use MET 3.5: expected ~245, got \(result)")
    }

    @Test("CalorieCalculator: halving actual duration halves calories")
    func caloriesScaleWithActualDuration() {
        let full = CalorieCalculator.calculate(
            weightKg: 70,
            intervals: [Interval(type: .run, durationSeconds: 3600)],
            actualDurationSeconds: 3600
        )
        let half = CalorieCalculator.calculate(
            weightKg: 70,
            intervals: [Interval(type: .run, durationSeconds: 3600)],
            actualDurationSeconds: 1800
        )
        #expect(abs(half - full / 2.0) < 1.0,
                "Halving actual duration should halve calories")
    }

    // MARK: - NotificationService

    @Test("NotificationService: empty runDays schedules nothing")
    func notificationServiceEmptyDays() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        mockCenter.authorizationGranted = true

        try await service.scheduleRunReminders(
            runDays: [],
            time: DateComponents(hour: 7, minute: 0)
        )

        #expect(mockCenter.addedRequests.isEmpty,
                "No notifications should be scheduled for empty day list")
    }

    @Test("NotificationService: skips scheduling when not authorized")
    func notificationServiceNotAuthorized() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        mockCenter.authorizationGranted = false

        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )

        #expect(mockCenter.addedRequests.isEmpty,
                "No notifications should be scheduled when not authorized")
    }

    @Test("NotificationService: clears existing requests before rescheduling")
    func notificationServiceClearsBeforeRescheduling() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        mockCenter.authorizationGranted = true

        try await service.scheduleRunReminders(
            runDays: [2],
            time: DateComponents(hour: 7, minute: 0)
        )
        #expect(mockCenter.addedRequests.count == 1)

        try await service.scheduleRunReminders(
            runDays: [3, 5],
            time: DateComponents(hour: 8, minute: 0)
        )

        #expect(mockCenter.removeAllCalled == true,
                "Must remove all pending requests before rescheduling")
        #expect(mockCenter.addedRequests.count == 2,
                "Should have exactly 2 requests for the 2 new days")
    }

    @Test("NotificationService: schedules one request per run day")
    func notificationServiceSchedulesOnePerDay() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        mockCenter.authorizationGranted = true

        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )

        #expect(mockCenter.addedRequests.count == 3,
                "Should schedule exactly 3 requests for Mon/Wed/Fri")
    }

    // MARK: - Onboarding completion

    @Test("OnboardingViewModel.completeOnboarding persists hasCompletedOnboarding = true")
    @MainActor
    func onboardingCompletionPersistsFlag() async throws {
        let mockCenter = MockNotificationCenter()
        let mock = MockDataStore()
        let vm = OnboardingViewModel(
            dataStore: mock,
            notificationService: NotificationService(center: mockCenter)
        )

        try await vm.completeOnboarding()

        let profile = try await mock.fetchUserProfile()
        #expect(profile?.hasCompletedOnboarding == true,
                "completeOnboarding must persist hasCompletedOnboarding = true")
    }

    @Test("OnboardingViewModel.completeOnboarding uses activityLevel to set startingWeek")
    @MainActor
    func onboardingUsesActivityLevelForStartingWeek() async throws {
        let mockCenter = MockNotificationCenter()
        let mock = MockDataStore()
        let vm = OnboardingViewModel(
            dataStore: mock,
            notificationService: NotificationService(center: mockCenter)
        )
        vm.activityLevel = .fairlyActive

        try await vm.completeOnboarding()

        let profile = try await mock.fetchUserProfile()
        #expect(profile?.currentWeek == 5,
                "fairlyActive should start at week 5")
        #expect(profile?.startingWeek == 5)
    }

    @Test("OnboardingViewModel.completeOnboarding with reminders disabled skips notification scheduling")
    @MainActor
    func onboardingSkipsNotificationsWhenDisabled() async throws {
        let mockCenter = MockNotificationCenter()
        let mock = MockDataStore()
        let vm = OnboardingViewModel(
            dataStore: mock,
            notificationService: NotificationService(center: mockCenter)
        )
        vm.remindersEnabled = false

        try await vm.completeOnboarding()

        #expect(mockCenter.addedRequests.isEmpty,
                "No notifications should be scheduled when reminders are disabled")
    }
}
